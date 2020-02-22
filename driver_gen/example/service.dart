import 'package:postgres_driver/postgres_driver.dart';

part 'service.g.dart';

class Service = _Service with _$Service;

class _Service implements Transactional {
  @override
  final DbContext db;

  final Resource _resource;

  _Service(this.db, this._resource);

  Future<String> read() async {
    final value = await _resource.readFromDb();
    print("value read from db: $value");
    return value;
  }

  @transaction
  Future<void> write(String value) async {
    await innerWrite("000: $value");
    await innerWrite("111: $value");
  }

  @transaction
  Future<void> innerWrite(String value) async {
    await _resource.writeToDb(value);
    print("value $value written to db");
  }
}

class Service1 extends _Service1 with _$Service1 {
  Service1(DbContext db) : super(db);
}

abstract class _Service1 implements Transactional {
  @override
  final DbContext db;

  _Service1(this.db);
}

class ParametrizedService<T extends String, K> extends _ParametrizedService<T, K> with _$ParametrizedService<T, K> {
  ParametrizedService(DbContext db) : super(db);
}

abstract class _ParametrizedService<T extends String, K> implements Transactional {
  @override
  final DbContext db;

  _ParametrizedService(this.db);
}

class ServiceWithNamedConstructor extends _ServiceWithNamedConstructor with _$ServiceWithNamedConstructor {
  ServiceWithNamedConstructor.named(DbContext db) : super.named(db);
}

abstract class _ServiceWithNamedConstructor implements Transactional {
  @override
  final DbContext db;

  _ServiceWithNamedConstructor.named(this.db);
}

class ServiceWithConstructorWithOptionalNotNamedParameters extends _ServiceWithConstructorWithOptionalNotNamedParameters
    with _$ServiceWithConstructorWithOptionalNotNamedParameters {
  ServiceWithConstructorWithOptionalNotNamedParameters(DbContext db) : super(db);
}

abstract class _ServiceWithConstructorWithOptionalNotNamedParameters implements Transactional {
  @override
  final DbContext db;

  final String optional;

  _ServiceWithConstructorWithOptionalNotNamedParameters(this.db, [this.optional]);
}

class ServiceWithConstructorWithOptionalNamedParameters extends _ServiceWithConstructorWithOptionalNamedParameters
    with _$ServiceWithConstructorWithOptionalNamedParameters {
  ServiceWithConstructorWithOptionalNamedParameters(DbContext db, { String optional}) : super(db, optional: optional);
}


abstract class _ServiceWithConstructorWithOptionalNamedParameters implements Transactional {
  @override
  final DbContext db;

  final String optional;

  _ServiceWithConstructorWithOptionalNamedParameters(this.db, {this.optional});
}

class Resource = _Resource with _$Resource;

class _Resource implements Transactional {
  @override
  final DbContext db;

  _Resource(this.db);

  Future<String> readFromDb() async {
    final rs = await db.conn.select("select name from test_table where id = @id", params: {"id": "0"});
    final value = rs.rows[0][0];
    return value;
  }

  Future<void> writeToDb(String value) async {
    await db.conn.update("test_table", {"name": value});
  }
}
