import 'dart:async';
import 'dart:core';
import 'dart:ffi';

import 'package:conn_pool/conn_pool.dart';
import 'package:ffi/ffi.dart';

const int _pgTypeInt0 = 20;
const int _pgTypeInt1 = 23;
const int _pgTypeVarchar = 1024;

const String _parameterNamePrefix = "@";
const String _paramNameRegexString = "[a-zA-Z0-9_]+";
final RegExp _paramNameRegexp = RegExp("^$_paramNameRegexString\$");
final RegExp _paramTemplateRegexp = RegExp("$_parameterNamePrefix($_paramNameRegexString)");

class ResultSet {
  final DynamicLibrary _dylib;

  final List<RawResultSet> _rawResultSets;

  ResultSet(this._dylib, this._rawResultSets);

  bool _closed = false;

  int get columnsNumber {
    return _rawResultSets.isNotEmpty ? _rawResultSets.first.columnsNumber : 0;
  }

  int get rowsNumber {
    return _rawResultSets.isNotEmpty
        ? _rawResultSets.fold(0, (count, rawResultSet) => count + rawResultSet.rowsNumber)
        : 0;
  }

  List<String> get columnNames {
    return _rawResultSets.isNotEmpty ? _rawResultSets.first.columnNames : [];
  }

  List<List<dynamic>> get rows {
    return _rawResultSets.expand((rawResultSet) => rawResultSet.rows).toList();
  }

  List<Map<String, dynamic>> get rowMaps {
    return _rawResultSets.expand((rawResultSet) => rawResultSet.rowsMap).toList();
  }

  void close() {
    if (!_closed) {
      _rawResultSets.forEach((rawResultSet) => rawResultSet.close(_dylib));
      _closed = true;
    }
  }
}

class RawResultSet extends Struct {
  Pointer<Utf8> error;

  @Int32()
  int columnsNumber;

  @Int32()
  int rowsNumber;

  Pointer<Pointer<Utf8>> _columnNames;

  Pointer<Int32> _columnTypes;

  Pointer<Pointer<Pointer<Utf8>>> _rows;

  List<String> get columnNames {
    List<String> result = List<String>(columnsNumber);
    for (int col = 0; col < columnsNumber; col++) {
      Pointer<Utf8> columnNamePtr = _columnNames[col];
      String columnName = Utf8.fromUtf8(columnNamePtr);
      result[col] = columnName;
    }
    return result;
  }

  List<List<dynamic>> get rows {
    List<List<dynamic>> result = List<List<dynamic>>(rowsNumber);
    for (int row = 0; row < rowsNumber; row++) {
      result[row] = List<dynamic>(columnsNumber);
      Pointer<Pointer<Utf8>> rowPtr = _rows[row];
      for (int col = 0; col < columnsNumber; col++) {
        int valueType = _columnTypes[col];
        Pointer<Utf8> valuePtr = rowPtr[col];
        if (valuePtr.address != 0) {
          String rawValue = Utf8.fromUtf8(valuePtr);
          dynamic value = _resolveValue(valueType, rawValue);
          result[row][col] = value;
        }
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get rowsMap {
    List<Map<String, dynamic>> result = List<Map<String, dynamic>>(rowsNumber);
    for (int row = 0; row < rowsNumber; row++) {
      result[row] = {};
      Pointer<Pointer<Utf8>> rowPtr = _rows[row];
      for (int col = 0; col < columnsNumber; col++) {
        Pointer<Utf8> valuePtr = rowPtr[col];
        if (valuePtr.address != 0) {
          int valueType = _columnTypes[col];
          String valueString = Utf8.fromUtf8(valuePtr);
          dynamic value = _resolveValue(valueType, valueString);
          Pointer<Utf8> columnNamePtr = _columnNames[col];
          String columnName = Utf8.fromUtf8(columnNamePtr);
          result[row][columnName] = value;
        }
      }
    }
    return result;
  }

  void close(DynamicLibrary dylib) {
    final CloseResultSet closeResultSet =
        dylib.lookup<NativeFunction<close_result_set_func>>("close_result_set").asFunction();
    closeResultSet(this.addressOf);
  }

  dynamic _resolveValue(int valueType, String valueString) {
    if (valueString == null) {
      return null;
    }

    switch (valueType) {
      case 16:
        return valueString == "t";
      case _pgTypeInt0:
      case _pgTypeInt1:
        return int.parse(valueString);
      case _pgTypeVarchar:
        return valueString;
      case 1184: //date
        return valueString;
    }
    return valueString;
  }
}

typedef open_connection_func = Pointer<Int32> Function(Pointer<Utf8> connectionString);
typedef OpenConnection = Pointer<Int32> Function(Pointer<Utf8> connectionString);

typedef close_connection_func = Void Function(Pointer<Int32> connection);
typedef CloseConnection = void Function(Pointer<Int32> connection);

typedef close_result_set_func = Void Function(Pointer<RawResultSet> resultSet);
typedef CloseResultSet = void Function(Pointer<RawResultSet> resultSet);

typedef perform_query_func = Pointer<RawResultSet> Function(
    Pointer<Int32> connection, Pointer<Utf8> query, Int32 paramCount, Pointer<Pointer<Utf8>> paramValues);
typedef PerformQuery = Pointer<RawResultSet> Function(
    Pointer<Int32> connection, Pointer<Utf8> query, int paramCount, Pointer<Pointer<Utf8>> paramValues);

typedef test_func = Pointer<RawResultSet> Function();
typedef Test = Pointer<RawResultSet> Function();

class PGConnection {
  static DynamicLibrary _dylib;

  final String connectionString;

  Pointer<Int32> _conn;

  bool _closed = false;

  int _transactionLevel = 0;

  factory PGConnection(String connectionString) {
    _initDynlib();
    return PGConnection._(connectionString);
  }

  PGConnection._(this.connectionString);

  static void _initDynlib() {
    if (_dylib == null) {
      String path = "./postgres-driver.so";
      _dylib = DynamicLibrary.open(path);
    }
  }

  Future<void> open() async {
    final OpenConnection openConnection =
        _dylib.lookup<NativeFunction<open_connection_func>>("open_connection").asFunction();
    _conn = openConnection(Utf8.toUtf8(connectionString));
  }

  Future<ResultSet> execute(String query, [List<Map<String, dynamic>> values]) async {
    _RawQuery rawQuery = _prepareQuery(query, values);
    final PerformQuery performQuery = _dylib.lookup<NativeFunction<perform_query_func>>("perform_query").asFunction();

    // case for query with no params
    if (rawQuery.values.isEmpty) {
      Pointer<RawResultSet> result = performQuery(_conn, Utf8.toUtf8(rawQuery.query), 0, _toValuesArray([]));
      if (result.ref.error.address != 0) {
        throw _extractError(result.ref.error);
      }
      return ResultSet(_dylib, [result.ref]);
    }

    // case for query with params
    List<RawResultSet> rawResults = rawQuery.values.map((rowValues) {
      Pointer<RawResultSet> result =
          performQuery(_conn, Utf8.toUtf8(rawQuery.query), rowValues.length, _toValuesArray(rowValues));
      RawResultSet rawResultSet = result.ref;
      if (rawResultSet.error.address != 0) {
        throw _extractError(rawResultSet.error);
      }
      return rawResultSet;
    }).toList();

    return ResultSet(_dylib, rawResults);
  }

  String _extractError(Pointer<Utf8> errorPointer) {
    return Utf8.fromUtf8(errorPointer);
  }

  Future<ResultSet> select(String query, {Map<String, dynamic> params}) async {
    return await execute(query, [params]);
  }

  Future<void> insert(String table, Map<String, dynamic> record) async {
    await execute(_prepareInsertQuery(table, record.keys), [record]);
  }

  Future<void> insertMultiple(String table, List<Map<String, dynamic>> records) async {
    Iterable<String> allKeys = records.expand((record) => record.keys).toSet();
    await execute(_prepareInsertQuery(table, allKeys), records);
  }

  Future<void> update(String table, Map<String, dynamic> updateParams,
      {String criteria, Map<String, dynamic> criteriaParams}) async {
    Map<String, dynamic> params;
    if (criteriaParams != null) {
      params = Map.of(updateParams);
      params.addAll(criteriaParams);
    } else {
      params = updateParams;
    }
    await execute(_prepareUpdateQuery(table, params.keys, criteria), [params]);
  }

  Future<void> delete(String table, {String criteria, Map<String, dynamic> criteriaParams}) async {
    await execute(_prepareDeleteQuery(table, criteria), criteriaParams != null ? [criteriaParams] : null);
  }

  Future<void> begin() async {
    if (_transactionLevel++ == 0) {
      print("beginning transaction ...");
      await execute("BEGIN");
    }
  }

  Future<void> commit() async {
    if (--_transactionLevel == 0) {
      print("committing transaction ...");
      await execute("COMMIT");
    }
  }

  Future<void> rollback() async {
    print("rolling back transaction ...");
    await execute("ROLLBACK");
    _transactionLevel = 0;
  }

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      final CloseConnection closeConnection =
          _dylib.lookup<NativeFunction<close_connection_func>>("close_connection").asFunction();
      closeConnection(_conn);
    }
  }

  _RawQuery _prepareQuery(String query, [List<Map<String, dynamic>> values]) {
    Map<String, int> paramPositions = {};

    _validateParamNames(values);

    String rawQuery = query.replaceAllMapped(_paramTemplateRegexp, (match) {
      String param = match.group(1);
      int position = paramPositions.putIfAbsent(param, () => paramPositions.length);
      return "\$${position + 1}";
    });

    Iterable<List<String>> rawValues = values != null
        ? values.map((rowValues) {
            List<String> rowValuesList = List<String>(paramPositions.length);

            paramPositions.forEach((param, position) {
              dynamic value = rowValues[param];
              String rawValue = _valueToString(value);
              rowValuesList[position] = rawValue;
            });

            return rowValuesList;
          })
        : [];

    return _RawQuery(rawQuery, rawValues);
  }

  Pointer<Pointer<Utf8>> _toValuesArray(List<String> parameterValues) {
    Pointer<Pointer<Utf8>> result =
        allocate<Pointer<Utf8>>(count: parameterValues != null ? parameterValues.length : 0);

    if (parameterValues != null) {
      for (int i = 0; i < parameterValues.length; i++) {
        String parameterValue = parameterValues[i];
        Pointer<Utf8> value = parameterValue != null ? Utf8.toUtf8(parameterValue) : Pointer.fromAddress(0);
        result.elementAt(i).value = value;
      }
    }

    return result;
  }

  String _valueToString(dynamic value) {
    if (value == null) {
      return null;
    }
    //TODO: implement!!!!
    return value.toString();
  }

  String _prepareInsertQuery(String table, Iterable<String> keys) {
    if (keys.isEmpty) {
      throw "insert: values are empty";
    }

    StringBuffer columns = StringBuffer();
    StringBuffer params = StringBuffer();

    Iterator<String> it = keys.iterator;
    do {
      if (it.current == null) {
        it.moveNext();
      } else {
        columns.write(",");
        params.write(",");
      }

      columns.write(it.current);

      params.write(_parameterNamePrefix);
      params.write(it.current);
    } while (it.moveNext());

    return "insert into $table($columns) values($params)";
  }

  String _prepareUpdateQuery(String table, Iterable<String> keys, String criteria) {
    if (keys.isEmpty) {
      throw "update: values are empty";
    }

    String pairs = keys.map((key) => "$key = $_parameterNamePrefix$key").join(",");

    return "update $table set ${pairs.toString()} ${criteria != null ? "where $criteria" : ''}";
  }

  String _prepareDeleteQuery(String table, String criteria) {
    return "delete from $table ${criteria != null ? "where $criteria" : ''}";
  }

  void _validateParamNames(List<Map<String, dynamic>> values) {
    if (values != null && values.isNotEmpty) {
      values.forEach((value) => value.keys.forEach(_validateParamName));
    }
  }

  void _validateParamName(String key) {
    if (!_paramNameRegexp.hasMatch(key)) {
      throw "param name \"$key\" invalid";
    }
  }
}

class _RawQuery {
  final String query;
  final Iterable<List<String>> values;

  _RawQuery(this.query, this.values);
}

class ConnectionPool {
  final String connectionString;

  final SharedPool<PGConnection> pool;

  ConnectionPool(this.connectionString)
      : pool = SharedPool<PGConnection>(_ConnectionManager(connectionString), minSize: 0, maxSize: 3);

  Future<Connection<PGConnection>> open() async {
    return pool.get();
  }

  Future<void> close(Connection<PGConnection> connection) async {
    await pool.release(connection);
  }
}

class _ConnectionManager implements ConnectionManager<PGConnection> {
  final String connectionString;

  _ConnectionManager(this.connectionString);

  @override
  Future<PGConnection> open() async {
    PGConnection connection = PGConnection(connectionString);
    await connection.open();
    return connection;
  }

  @override
  FutureOr<void> close(PGConnection connection) async {
    await connection.close();
  }
}
