// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// TransactionalGenerator
// **************************************************************************

mixin _$Service on _Service {
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

mixin _$Service1 on _Service1 {}

mixin _$ParametrizedService<T extends String, K> on _ParametrizedService<T, K> {
}

mixin _$ServiceWithNamedConstructor on _ServiceWithNamedConstructor {}

mixin _$ServiceWithConstructorWithOptionalNotNamedParameters
    on _ServiceWithConstructorWithOptionalNotNamedParameters {}

mixin _$ServiceWithConstructorWithOptionalNamedParameters
    on _ServiceWithConstructorWithOptionalNamedParameters {}

mixin _$Resource on _Resource {
  @override
  Future<String> readFromDb() async {
    return await db.executeInReadTransaction(() => super.readFromDb());
  }

  @override
  Future<void> writeToDb(String value) async {
    return await db.executeInReadTransaction(() => super.writeToDb(value));
  }
}
