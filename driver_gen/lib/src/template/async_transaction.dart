import 'package:postgres_driver_gen/src/template/method_override.dart';

class AsyncTransactionTemplate {
  MethodOverrideTemplate method;

  @override
  // ignore: prefer_single_quotes
  String toString() => """
    @override
    ${method.returnType} ${method.name}${method.typeParams}(${method.params}) async {
      await conn.begin();
      try {
        ${method.returnTypeArgsRaw} result = await runZoned(() async => await super.${method.name}${method.typeArgs}(${method.args}));
        await conn.commit();
        return result;
      } catch(e) {
        await conn.rollback();
        rethrow;
      }
    }""";
}
