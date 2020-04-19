import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'dart:ffi';

import 'package:db_context_lib/db_context_lib.dart';
import 'package:ffi/ffi.dart';

const _delayIncrement = 10;

const int _pgTypeInt0 = 20;
const int _pgTypeInt1 = 23;
const int _pgTypeVarchar = 1024;

const String _parameterNamePrefix = "@";
const String _paramNameRegexString = "[a-zA-Z0-9_]+";
final RegExp _paramNameRegexp = RegExp("^$_paramNameRegexString\$");
final RegExp _paramTemplateRegexp = RegExp("$_parameterNamePrefix($_paramNameRegexString)");
final RegExp _paramInTemplateRegexp =
    RegExp("\\s+in\\s*\\($_parameterNamePrefix($_paramNameRegexString)\\)", caseSensitive: false);

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
          dynamic value = _stringToValue(valueType, rawValue);
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
          dynamic value = _stringToValue(valueType, valueString);
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
}

class SendQueryResult extends Struct {
  Pointer<Utf8> error;
}

dynamic _stringToValue(int valueType, String valueString) {
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
    case 1114: //timestamp
      return DateTime.parse("${valueString}Z");
    case 1184: //date
      return valueString;
  }
  return valueString;
}

String _valueToString(dynamic value) {
  if (value == null) {
    return null;
  }

  //TODO: implement!!!!
  return value.toString();
}

typedef open_connection_func = Pointer<Int32> Function(Pointer<Utf8> connectionString);
typedef OpenConnection = Pointer<Int32> Function(Pointer<Utf8> connectionString);

typedef close_connection_func = Void Function(Pointer<Int32> connection);
typedef CloseConnection = void Function(Pointer<Int32> connection);

typedef close_result_set_func = Void Function(Pointer<RawResultSet> resultSet);
typedef CloseResultSet = void Function(Pointer<RawResultSet> resultSet);

typedef send_query_func = Pointer<SendQueryResult> Function(Pointer<Int32> connection, Pointer<Utf8> query,
    Int32 paramCount, Pointer<Pointer<Utf8>> paramValues, Int32 reconnect);
typedef SendQuery = Pointer<SendQueryResult> Function(
    Pointer<Int32> connection, Pointer<Utf8> query, int paramCount, Pointer<Pointer<Utf8>> paramValues, int reconnect);

typedef get_result_func = Pointer<RawResultSet> Function(Pointer<Int32> connection);
typedef GetResult = Pointer<RawResultSet> Function(Pointer<Int32> connection);

class PGConnection {
  static DynamicLibrary _dylib;

  final String connectionString;

  Pointer<Int32> _conn;

  bool _closed = false;

  int _transactionLevel = 0;

  bool _queryInProgress = false;

  factory PGConnection(String connectionString, {String driverPath = "./postgres-driver.so"}) {
    _initDynlib(driverPath);
    return PGConnection._(connectionString);
  }

  PGConnection._(this.connectionString);

  static void _initDynlib(String driverPath) {
    if (_dylib == null) {
      _dylib = DynamicLibrary.open(driverPath);
    }
  }

  bool get isClosed => _closed;

  Future<void> open() async {
    final OpenConnection openConnection =
        _dylib.lookup<NativeFunction<open_connection_func>>("open_connection").asFunction();
    _conn = openConnection(Utf8.toUtf8(connectionString));
  }

  Future<ResultSet> execute(String query, [List<Map<String, dynamic>> values]) async {
    _RawQuery rawQuery = _prepareQuery(query, values);

    // case for query with no params
    if (rawQuery.values.isEmpty) {
      RawResultSet rawResultSet = await _executeNativeQuery(rawQuery.query);
      return ResultSet(_dylib, [rawResultSet]);
    }

    // case for query with params
    List<RawResultSet> rawResults = [];
    for (List<String> rowValues in rawQuery.values) {
      RawResultSet rawResultSet = await _executeNativeQuery(rawQuery.query, rowValues);
      rawResults.add(rawResultSet);
    }

    return ResultSet(_dylib, rawResults);
  }

  Queue<_QueuedQuery> _queue = Queue<_QueuedQuery>();

  Future<RawResultSet> _executeNativeQuery(String query, [List<String> rowValues]) {
    final completer = Completer<RawResultSet>();

    _QueuedQuery _queuedQuery = _QueuedQuery(query, rowValues, completer);
    _queue.addFirst(_queuedQuery);

    _processNextQuery();

    return completer.future;
  }

  Future<void> _processNextQuery() async {
    if (_queue.isEmpty) {
      return;
    }

    if (_queryInProgress) {
      return;
    }

    _QueuedQuery _lastQuery = _queue.last;
    try {
      _queryInProgress = true;

      _sendQuery(_lastQuery.query, _lastQuery.rowValues);
      RawResultSet rawResultSet = await _getResult();
      _lastQuery.completer.complete(rawResultSet);
    } catch (e) {
      _lastQuery.completer.completeError(e);
    } finally {
      _queryInProgress = false;
      _queue.removeLast();
      await _processNextQuery();
    }
  }

  Future<RawResultSet> _getResult() async {
    RawResultSet rawResultSet;
    int delay = 0;

    while (true) {
      RawResultSet currentRawResultSet = await Future<RawResultSet>.delayed(Duration(milliseconds: delay), () {
        final GetResult getResult = _dylib.lookup<NativeFunction<get_result_func>>("get_result").asFunction();
        Pointer<RawResultSet> result = getResult(_conn);

        if (result.address == 0) {
          return null;
        }

        RawResultSet rawResultSet = result.ref;
        if (rawResultSet.error.address != 0) {
          throw _extractError(rawResultSet.error);
        }

        return rawResultSet;
      });

      if (currentRawResultSet == null) {
        break;
      }

      if (rawResultSet != null) {
        rawResultSet.close(_dylib);
      }

      rawResultSet = currentRawResultSet;

      delay += _delayIncrement;
    }

    return rawResultSet;
  }

  void _sendQuery(String query, List<String> rowValues) {
    final SendQuery sendQuery = _dylib.lookup<NativeFunction<send_query_func>>("send_query").asFunction();
    Pointer<SendQueryResult> sendQueryResultPointer =
        sendQuery(_conn, Utf8.toUtf8(query), rowValues?.length ?? 0, _toValuesArray(rowValues ?? []), 1);
    SendQueryResult sendQueryResult = sendQueryResultPointer.ref;
    if (sendQueryResult.error.address != 0) {
      throw _extractError(sendQueryResult.error);
    }
  }

  String _extractError(Pointer<Utf8> errorPointer) {
    return Utf8.fromUtf8(errorPointer);
  }

  Future<ResultSet> select(String query, {Map<String, dynamic> params}) async {
    return await execute(query, params != null && params.isNotEmpty ? [params] : null);
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

    int paramsNumber = 0;

    // first handle "in (@param)" params
    String rawQuery = query.replaceAllMapped(
      _paramInTemplateRegexp,
      (match) {
        String param = match.group(1);
        // as this is a query, taking first line of values only
        final listValue = values.first[param] as List;
        int position = paramPositions.putIfAbsent(param, () => paramsNumber);
        paramsNumber += listValue.length;
        final parameterPlaceholders = Iterable.generate(listValue.length, (i) => "\$${position + 1 + i}").join(",");
        return " in(${parameterPlaceholders})";
      },
    );

    // then handle all other params
    rawQuery = rawQuery.replaceAllMapped(
      _paramTemplateRegexp,
      (match) {
        String param = match.group(1);
        int position = paramPositions.putIfAbsent(param, () => paramsNumber++);
        return "\$${position + 1}";
      },
    );

    Iterable<List<String>> rawValues = values != null
        ? values.map(
            (rowValues) {
              List<String> rowValuesList = List<String>(paramsNumber);

              paramPositions.forEach((param, position) {
                dynamic value = rowValues[param];
                if (value is List) {
                  for (int i = 0; i < value.length; i++) {
                    String rawValue = _valueToString(value[i]);
                    rowValuesList[position + i] = rawValue;
                  }
                } else {
                  String rawValue = _valueToString(value);
                  rowValuesList[position] = rawValue;
                }
              });

              return rowValuesList;
            },
          )
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

class PGConnectionManager implements ConnectionManager<PGConnection> {
  final String connectionString;

  PGConnectionManager(this.connectionString);

  @override
  Future<PGConnection> create() async {
    PGConnection connection = PGConnection(connectionString);

    try {
      await connection.open();
    } catch (e) {
      throw "Can not open DB connection: ${e}";
    }

    return connection;
  }

  @override
  Future<void> beginTransaction(PGConnection conn) => conn.begin();

  @override
  Future<void> commitTransaction(PGConnection conn) => conn.commit();

  @override
  Future<void> rollbackTransaction(PGConnection conn) => conn.rollback();

  @override
  bool isValid(PGConnection conn) => !conn.isClosed;
}

class _QueuedQuery {
  final String query;
  final List<String> rowValues;
  final Completer<RawResultSet> completer;

  _QueuedQuery(this.query, this.rowValues, this.completer);
}
