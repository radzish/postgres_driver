import 'package:postgres_driver/postgres_driver.dart';

part 'service.g.dart';

abstract class _Service implements Transactional {
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

abstract class _Service1 implements Transactional {
  @override
  final DbContext db;

  _Service1(this.db);
}

abstract class _ParametrizedService<T extends String, K> implements Transactional {
  @override
  final DbContext db;

  _ParametrizedService(this.db);
}

abstract class _ServiceWithNamedConstructor implements Transactional {
  @override
  final DbContext db;

  _ServiceWithNamedConstructor.named(this.db);
}

abstract class _ServiceWithConstructorWithOptionalNotNamedParameters implements Transactional {
  @override
  final DbContext db;

  final String optional;

  _ServiceWithConstructorWithOptionalNotNamedParameters(this.db, [this.optional]);
}

abstract class _ServiceWithConstructorWithOptionalNamedParameters implements Transactional {
  @override
  final DbContext db;

  final String optional;

  _ServiceWithConstructorWithOptionalNamedParameters(this.db, {this.optional});
}

abstract class _ServiceWithDefaultRead implements Transactional {
  @override
  final DbContext db;

  _ServiceWithDefaultRead(this.db);
}

abstract class _ServiceWithDefaultWrite implements Transactional {
  @override
  final DbContext db;

  _ServiceWithDefaultWrite(this.db);
}

class Resource {
  final DbContext _db;

  Resource(this._db);

  Future<String> readFromDb() async {
    final rs = await _db.conn.select("select name from test_table where id = @id", params: {"id": "0"});
    final value = rs.rows[0][0];
    return value;
  }

  Future<void> writeToDb(String value) async {
    await _db.conn.update("test_table", {"name": value});
  }
}
