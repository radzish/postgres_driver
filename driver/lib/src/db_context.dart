import 'dart:async';

import 'package:postgres_driver/postgres_driver.dart';
import 'package:resource_pool/resource_pool.dart';

const int _defaultMaxConnectionsInPool = 3;

class DbContext {
  static const _zoneConnectionKey = "postgres_driver.connection_key";
  ResourcePool<PGConnection> _pool;

  DbContext(String connectionString, {int maxConnections = _defaultMaxConnectionsInPool}) {
    _pool = ResourcePool<PGConnection>(maxConnections, () => _createConnection(connectionString));
  }

  Future<PGConnection> open() async {
    var connection = await _pool.get();
    print("connection opened: ${connection.hashCode}");

    if (connection.isClosed) {
      await _pool.remove(connection);
      connection = await _pool.get();
    }

    return connection;
  }

  void close(PGConnection connection) {
    print("connection closing: ${connection.hashCode}");
    _pool.release(connection);
  }

  static Future<PGConnection> _createConnection(String connectionString) async {
    PGConnection connection = PGConnection(connectionString);

    try {
      await connection.open();
    } catch (e) {
      throw "Can not open DB connection: ${e}";
    }

    return connection;
  }

  Future<T> executeInReadTransaction<T>(Future<T> Function() block) async {
    bool connectionExisted = conn != null;
    final connection = connectionExisted ? conn : await open();
    try {
      if (connectionExisted) {
        return await block();
      } else {
        return await runZoned(() async => await block(),
            zoneValues: {_zoneConnectionKey: _ConnectionWrapper()..connection = connection});
      }
    } finally {
      if (!connectionExisted) {
        await close(connection);
      }
    }
  }

  Future<T> executeInWriteTransaction<T>(Future<T> Function() block) async {
    return executeInReadTransaction(() async {
      bool transactionExisted = _info.inTransaction;
      if (!transactionExisted) {
        await conn.begin();
        _info.inTransaction = true;
      }
      try {
        final result = await block();

        if (!transactionExisted) {
          _info.inTransaction = false;
          await conn.commit();
        }

        return result;
      } catch (e) {
        await conn.rollback();
        _info.inTransaction = false;

        rethrow;
      }
    });
  }

  PGConnection get conn => _info?.connection;

  _ConnectionWrapper get _info => Zone.current[_zoneConnectionKey] as _ConnectionWrapper;
}

class _ConnectionWrapper {
  PGConnection connection;
  bool inTransaction = false;
}
