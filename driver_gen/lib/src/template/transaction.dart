import 'package:postgres_driver_gen/src/template/method_override.dart';

// TODO: consider removing this, as we can not have sync methods because begin/commit/rollback are async
class TransactionTemplate {
  MethodOverrideTemplate method;

  @override
  // ignore: prefer_single_quotes
  String toString() => """
    @override
    ${method.returnType} ${method.name}${method.typeParams}(${method.params}) {
      conn.begin();
      try {
        return super.${method.name}${method.typeArgs}(${method.args});
        conn.commit();
      } catch(e) {
        conn.rollback();
        rethrow;
      }
    }""";
}
