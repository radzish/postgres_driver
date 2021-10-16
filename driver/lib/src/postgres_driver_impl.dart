import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:core';
import 'dart:ffi';

import 'package:db_context_lib/db_context_lib.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';

const int _pgTypeBool = 16;
const int _pgTypeInt0 = 20;
const int _pgTypeInt1 = 23;
const int _pgTypeVarchar = 1024;
const int _pgTypeTimestamp = 1114;
const int _pgTypeDate = 1184;
const int _pgTypeDoublePrecision = 701;
const int _pgTypeJson = 114;
const int _pgTypeJsonb = 3802;

const String _parameterNamePrefix = "@";
const String _paramNameRegexString = "[a-zA-Z0-9_]+";
final RegExp _paramNameRegexp = RegExp("^$_paramNameRegexString\$");
final RegExp _paramTemplateRegexp = RegExp("$_parameterNamePrefix($_paramNameRegexString)");
final RegExp _paramInTemplateRegexp =
    RegExp("\\s+in\\s*\\($_parameterNamePrefix($_paramNameRegexString)\\)", caseSensitive: false);

Logger get _logger => Logger.root;

class ResultSet {
  final DynamicLibrary _dylib;

  final Map<RawResultSet, Pointer<RawResultSet>> _rawResultSets;

  ResultSet(this._dylib, this._rawResultSets);

  bool _closed = false;

  int get columnsNumber {
    return _rawResultSets.isNotEmpty ? _rawResultSets.keys.first.columnsNumber : 0;
  }

  int get rowsNumber {
    return _rawResultSets.isNotEmpty
        ? _rawResultSets.keys.fold(0, (count, rawResultSet) => count + rawResultSet.rowsNumber)
        : 0;
  }

  List<String> get columnNames {
    return _rawResultSets.isNotEmpty ? _rawResultSets.keys.first.columnNames : [];
  }

  List<List<dynamic>> get rows {
    return _rawResultSets.keys.expand((rawResultSet) => rawResultSet.rows).toList();
  }

  List<Map<String, dynamic>> get rowMaps {
    return _rawResultSets.keys.expand((rawResultSet) => rawResultSet.rowsMap).toList();
  }

  void close() {
    if (!_closed) {
      _rawResultSets.forEach((rawResultSet, address) => rawResultSet.close(_dylib, address));
      _closed = true;
    }
  }
}

class RawResultSet extends Struct {
  external Pointer<Utf8> error;

  @Int32()
  external int columnsNumber;

  @Int32()
  external int rowsNumber;

  external Pointer<Pointer<Utf8>> _columnNames;

  external Pointer<Int32> _columnTypes;

  external Pointer<Pointer<Pointer<Utf8>>> _rows;

  List<String> get columnNames {
    final result = <String>[];
    for (var col = 0; col < columnsNumber; col++) {
      final columnNamePtr = _columnNames[col];
      final columnName = columnNamePtr.toDartString();
      result.add(columnName);
    }
    return result;
  }

  List<List<dynamic>> get rows {
    final result = <List<Object?>>[];

    for (var rowNumber = 0; rowNumber < rowsNumber; rowNumber++) {
      final row = <Object?>[];
      result.add(row);

      final rowPtr = _rows[rowNumber];
      for (var col = 0; col < columnsNumber; col++) {
        final valueType = _columnTypes[col];
        final valuePtr = rowPtr[col];
        if (valuePtr.address != 0) {
          final rawValue = valuePtr.toDartString();
          dynamic value = _stringToValue(valueType, rawValue);
          row.add(value);
        } else {
          row.add(null);
        }
      }
    }

    return result;
  }

  List<Map<String, dynamic>> get rowsMap {
    final result = <Map<String, dynamic>>[];
    for (var rowNum = 0; rowNum < rowsNumber; rowNum++) {
      final row = <String, dynamic>{};
      result.add(row);
      final rowPtr = _rows[rowNum];
      for (var col = 0; col < columnsNumber; col++) {
        final valuePtr = rowPtr[col];
        if (valuePtr.address != 0) {
          final valueType = _columnTypes[col];
          final valueString = valuePtr.toDartString();
          dynamic value = _stringToValue(valueType, valueString);
          final columnNamePtr = _columnNames[col];
          final columnName = columnNamePtr.toDartString();

          final nameParts = columnName.split("\.");

          var curMap = row;

          for (var i = 0; i < nameParts.length; i++) {
            final namePart = nameParts[i];
            if (i < nameParts.length - 1) {
              curMap[namePart] ??= <String, dynamic>{};
              curMap = curMap[namePart];
            } else {
              // last part, just assign value
              curMap[namePart] = value;
            }
          }
        }
      }
    }
    return result;
  }

  void close(DynamicLibrary dylib, Pointer<RawResultSet> address) {
    final CloseResultSet closeResultSet =
        dylib.lookup<NativeFunction<close_result_set_func>>("close_result_set").asFunction();
    closeResultSet(address);
  }
}

class SendQueryResult extends Struct {
  external Pointer<Utf8> error;
}

dynamic _stringToValue(int valueType, String valueString) {
  switch (valueType) {
    case _pgTypeBool:
      return valueString == "t";
    case _pgTypeInt0:
    case _pgTypeInt1:
      return int.parse(valueString);
    case _pgTypeVarchar:
      return valueString;
    case _pgTypeTimestamp: //timestamp
      return DateTime.parse("${valueString}Z");
    case _pgTypeDate: //date
      return valueString;
    case _pgTypeDoublePrecision: //date
      return double.parse(valueString);
    case _pgTypeJson:
    case _pgTypeJsonb:
      return jsonDecode(valueString);
  }

  return valueString;
}

String? _valueToString(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is Map) {
    return jsonEncode(value);
  }

  // we treat all lists as json arrays
  if (value is List) {
    return jsonEncode(value);
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
    Pointer<Int32> onnection, Pointer<Utf8> query, int paramCount, Pointer<Pointer<Utf8>> paramValues, int reconnect);

typedef get_result_func = Pointer<RawResultSet> Function(Pointer<Int32> connection);
typedef GetResult = Pointer<RawResultSet> Function(Pointer<Int32> connection);

typedef test_func = Void Function(Pointer<Int32> connection);
typedef TestFunc = void Function(Pointer<Int32> connection);

class PGConnection {
  static late DynamicLibrary _dylib;

  final String connectionString;

  late Pointer<Int32> _conn;

  bool _closed = false;

  int _transactionLevel = 0;

  bool _queryInProgress = false;

  factory PGConnection(String connectionString, {String driverPath = "./postgres-driver.so"}) {
    _dylib = DynamicLibrary.open(driverPath);
    return PGConnection._(connectionString);
  }

  PGConnection._(this.connectionString);

  bool get isClosed => _closed;

  Future<void> open() async {
    final openConnection = _dylib.lookupFunction<open_connection_func, OpenConnection>("open_connection");
    _conn = openConnection(connectionString.toNativeUtf8());
  }

  Future<ResultSet> execute(String query, [List<Map<String, dynamic>> values = const []]) async {
    final rawQuery = _prepareQuery(query, values);

    // case for query with no params
    if (rawQuery.values.isEmpty) {
      final rawResultSet = await _executeNativeQuery(rawQuery.query);
      return ResultSet(_dylib, {rawResultSet.key: rawResultSet.value});
    }

    // case for query with params
    final rawResults = <MapEntry<RawResultSet, Pointer<RawResultSet>>>[];
    for (final rowValues in rawQuery.values) {
      final rawResultSet = await _executeNativeQuery(rawQuery.query, rowValues);
      rawResults.add(rawResultSet);
    }

    return ResultSet(_dylib, Map.fromEntries(rawResults));
  }

  final _queue = Queue<_QueuedQuery>();

  Future<MapEntry<RawResultSet, Pointer<RawResultSet>>> _executeNativeQuery(String query, [List<String?> rowValues = const []]) {
    final completer = Completer<MapEntry<RawResultSet, Pointer<RawResultSet>>>();

    final _queuedQuery = _QueuedQuery(query, rowValues, completer);
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

    final _lastQuery = _queue.last;
    try {
      _queryInProgress = true;

      _sendQuery(_lastQuery.query, _lastQuery.rowValues);
      final rawResultSet = await _getResult();
      _lastQuery.completer.complete(rawResultSet);
    } catch (e, st) {
      _lastQuery.completer.completeError(e, st);
    } finally {
      _queryInProgress = false;
      _queue.removeLast();
      await _processNextQuery();
    }
  }

  Future<MapEntry<RawResultSet, Pointer<RawResultSet>>?> _getResult() async {
    MapEntry<RawResultSet, Pointer<RawResultSet>>? rawResultSet;
    while (true) {
      final currentRawResultSet =
          await Future<MapEntry<RawResultSet, Pointer<RawResultSet>>?>.delayed(Duration(milliseconds: 3), () {
        final getResult = _dylib.lookupFunction<get_result_func, GetResult>("get_result");
        final result = getResult(_conn);

        if (result.address == 0) {
          return null;
        }

        final rawResultSet = result.ref;
        if (rawResultSet.error.address != 0) {
          throw _extractError(rawResultSet.error);
        }

        return MapEntry(rawResultSet, result);
      });

      if (currentRawResultSet == null) {
        break;
      }

      if (rawResultSet != null) {
        rawResultSet.key.close(_dylib, rawResultSet.value);
      }

      rawResultSet = currentRawResultSet;
    }

    return rawResultSet;
  }

  void _sendQuery(String query, List<String?>? rowValues) {
    final sendQuery = _dylib.lookupFunction<send_query_func, SendQuery>("send_query");
    final sendQueryResultPointer =
        sendQuery(_conn, query.toNativeUtf8(), rowValues?.length ?? 0, _toValuesArray(rowValues ?? []), 1);
    final sendQueryResult = sendQueryResultPointer.ref;
    if (sendQueryResult.error.address != 0) {
      throw _extractError(sendQueryResult.error);
    }
  }

  PGException _extractError(Pointer<Utf8> errorPointer) {
    return PGException(errorPointer.toDartString().trim());
  }

  Future<ResultSet> select(String query, {Map<String, dynamic> params = const {}}) async {
    return await execute(query, [params]);
  }

  Future<void> insert(String table, Map<String, dynamic> record) async {
    await execute(_prepareInsertQuery(table, record.keys), [record]);
  }

  Future<void> insertMultiple(String table, List<Map<String, dynamic>> records) async {
    Iterable<String> allKeys = records.expand((record) => record.keys).toSet();
    await execute(_prepareInsertQuery(table, allKeys), records);
  }

  Future<void> update(
    String table,
    Map<String, dynamic> updateParams, {
    String? criteria,
    Map<String, dynamic>? criteriaParams,
  }) async {
    Map<String, dynamic> params;
    if (criteriaParams != null) {
      params = Map.of(updateParams);
      params.addAll(criteriaParams);
    } else {
      params = updateParams;
    }
    //TODO: https://github.com/radzish/postgres_driver/issues/29
    await execute(_prepareUpdateQuery(table, params.keys, criteria), [params]);
  }

  Future<void> delete(String table, {String? criteria, Map<String, dynamic>? criteriaParams}) async {
    await execute(_prepareDeleteQuery(table, criteria), [criteriaParams ?? {}]);
  }

  Future<void> begin() async {
    if (_transactionLevel++ == 0) {
      _logger.fine("beginning transaction: ${hashCode} ...");
      await execute("BEGIN");
    }
  }

  Future<void> commit() async {
    if (--_transactionLevel == 0) {
      _logger.fine("committing transaction: ${hashCode} ...");
      await execute("COMMIT");
    }
  }

  Future<void> rollback() async {
    _logger.fine("rolling back transaction: ${hashCode} ...");
    await execute("ROLLBACK");
    _transactionLevel = 0;
  }

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      final closeConnection = _dylib.lookupFunction<close_connection_func, CloseConnection>("close_connection");
      closeConnection(_conn);
    }
  }

  _RawQuery _prepareQuery(String query, [List<Map<String, dynamic>> values = const []]) {
    final paramPositions = <String, int>{};

    var inParamNumber = 0;

    _validateParamNames(values);

    var paramsNumber = 0;

    // first handle "in (@param)" params
    var rawQuery = query.replaceAllMapped(
      _paramInTemplateRegexp,
      (match) {
        final param = match.group(1)!;
        // as this is a query, taking first line of values only
        final listValue = values.first[param] as List;
        final position = paramPositions.putIfAbsent(param, () => paramsNumber);
        paramsNumber += listValue.length;
        final parameterPlaceholders = Iterable.generate(listValue.length, (i) => "\$${position + 1 + i}").join(",");
        return " in(${parameterPlaceholders})";
      },
    );

    inParamNumber = paramsNumber;

    // then handle all other params
    rawQuery = rawQuery.replaceAllMapped(
      _paramTemplateRegexp,
      (match) {
        final param = match.group(1)!;
        final position = paramPositions.putIfAbsent(param, () => paramsNumber++);
        return "\$${position + 1}";
      },
    );

    final rawValues = values.map(
      (rowValues) {
        final rowValuesList = List.filled(paramsNumber, null as String?);

        paramPositions.forEach((param, position) {
          dynamic value = rowValues[param];
          // we treat List params as IN only in case if they are indeed in,
          // otherwise list params should be handled regularly
          // TODO: introduce dedicated class for IN params so we do not have
          // ambiguity with Lists
          if (value is List && position < inParamNumber) {
            for (var i = 0; i < value.length; i++) {
              final rawValue = _valueToString(value[i]);
              rowValuesList[position + i] = rawValue;
            }
          } else {
            final rawValue = _valueToString(value);
            rowValuesList[position] = rawValue;
          }
        });

        return rowValuesList;
      },
    );

    return _RawQuery(rawQuery, rawValues);
  }

  Pointer<Pointer<Utf8>> _toValuesArray(List<String?> parameterValues) {
    final result = calloc<Pointer<Utf8>>(parameterValues.length);

    for (var i = 0; i < parameterValues.length; i++) {
      final parameterValue = parameterValues[i];
      final value = parameterValue != null ? parameterValue.toNativeUtf8() : nullptr;
      result.elementAt(i).value = value;
    }

    return result;
  }

  String _prepareInsertQuery(String table, Iterable<String> keys) {
    if (keys.isEmpty) {
      throw PGException("insert: values are empty");
    }

    final columns = StringBuffer();
    final params = StringBuffer();

    final it = keys.iterator;

    do {
      final hasNext = it.moveNext();

      if (hasNext) {
        if (columns.isNotEmpty) {
          columns.write(",");
          params.write(",");
        }

        columns.write(it.current);

        params.write(_parameterNamePrefix);
        params.write(it.current);
      } else {
        break;
      }
    } while (true);

    return "insert into $table($columns) values($params)";
  }

  String _prepareUpdateQuery(String table, Iterable<String> keys, String? criteria) {
    if (keys.isEmpty) {
      throw PGException("update: values are empty");
    }

    String pairs = keys.map((key) => "$key = $_parameterNamePrefix$key").join(",");

    return "update $table set ${pairs.toString()} ${criteria != null ? "where $criteria" : ''}";
  }

  String _prepareDeleteQuery(String table, String? criteria) {
    return "delete from $table ${criteria != null ? "where $criteria" : ''}";
  }

  void _validateParamNames(List<Map<String, dynamic>> values) {
    if (values.isNotEmpty) {
      values.forEach((value) => value.keys.forEach(_validateParamName));
    }
  }

  void _validateParamName(String key) {
    if (!_paramNameRegexp.hasMatch(key)) {
      throw PGException("param name \"$key\" invalid");
    }
  }

  void testFunc() {
    final testFunc = _dylib.lookupFunction<test_func, TestFunc>("test");
    testFunc(_conn);
  }
}

class _RawQuery {
  final String query;
  final Iterable<List<String?>> values;

  _RawQuery(this.query, this.values);
}

class PGConnectionManager implements ConnectionManager<PGConnection> {
  final String connectionString;

  PGConnectionManager(this.connectionString);

  @override
  Future<PGConnection> create() async {
    final connection = PGConnection(connectionString);

    try {
      await connection.open();
    } catch (e) {
      throw PGException("Can not open DB connection: ${e}");
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

  @override
  Future<void> close(PGConnection conn) => conn.close();
}

class _QueuedQuery {
  final String query;
  final List<String?> rowValues;
  final Completer<MapEntry<RawResultSet, Pointer<RawResultSet>>> completer;

  _QueuedQuery(this.query, this.rowValues, this.completer);
}

class PGException implements Exception {
  final String message;

  PGException(this.message);

  @override
  String toString() {
    return "PG Exception: $message";
  }
}
