// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// TransactionalGenerator
// **************************************************************************

class Service extends _Service {
  Service(DbContext db, Resource _resource) : super(db, _resource);

  @override
  Future<String> read() async {
    return await db.executeInReadTransaction(() => super.read());
  }

  @override
  Future<void> write(String value) async {
    return await db.executeInWriteTransaction(() => super.write(value));
  }

  @override
  Future<void> innerWrite(String value) async {
    return await db.executeInWriteTransaction(() => super.innerWrite(value));
  }
}

class Service1 extends _Service1 {
  Service1(DbContext db) : super(db);
}

class ParametrizedService<T extends String, K> extends _ParametrizedService<T, K> {
  ParametrizedService(DbContext db) : super(db);
}

class ServiceWithNamedConstructor extends _ServiceWithNamedConstructor {
  ServiceWithNamedConstructor.named(DbContext db) : super.named(db);
}

class ServiceWithConstructorWithOptionalNotNamedParameters
    extends _ServiceWithConstructorWithOptionalNotNamedParameters {
  ServiceWithConstructorWithOptionalNotNamedParameters(DbContext db, [String optional]) : super(db, optional);
}

class ServiceWithConstructorWithOptionalNamedParameters extends _ServiceWithConstructorWithOptionalNamedParameters {
  ServiceWithConstructorWithOptionalNamedParameters(DbContext db, {String optional}) : super(db, optional: optional);
}

class ServiceWithDefaultRead extends _ServiceWithDefaultRead {
  ServiceWithDefaultRead(DbContext db) : super(db);
}

class ServiceWithDefaultWrite extends _ServiceWithDefaultWrite {
  ServiceWithDefaultWrite(DbContext db) : super(db);
}
