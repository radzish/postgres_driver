import 'package:analyzer/dart/element/element.dart';
import 'package:postgres_driver_gen/src/template/params.dart';
import 'package:postgres_driver_gen/src/type_names.dart';
import 'package:source_gen/source_gen.dart';

TypeParamTemplate typeParamTemplate(TypeParameterElement param) => TypeParamTemplate()
  ..name = param.name
  ..bound = param.bound != null ? findTypeParameterBoundsTypeName(param) : null;

class AsyncTransactionMethodChecker {
  AsyncTransactionMethodChecker();

  bool returnsFuture(MethodElement method) =>
      method.returnType.isDartAsyncFuture ||
      (method.isAsynchronous && !method.isGenerator && method.returnType.isDynamic);
}

// ignore: avoid_annotating_with_dynamic
String surroundNonEmpty(String prefix, String suffix, dynamic content) {
  final contentStr = content.toString();
  return contentStr.isEmpty ? '' : '$prefix$contentStr$suffix';
}
