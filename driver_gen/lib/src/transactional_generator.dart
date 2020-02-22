import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';
import 'package:postgres_driver/postgres_driver.dart';
import 'package:source_gen/source_gen.dart';
import 'package:code_builder/code_builder.dart' as code;

TypeChecker _transactionalClassChecker = TypeChecker.fromRuntime(Transactional);
TypeChecker _transactionChecker = TypeChecker.fromRuntime(Transaction);
RegExp _publicClassNameRegexp = RegExp(r"_+([^_]+)");

class TransactionalGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final transactionalClasses = library.classes.where(_isTransactional);
    if (transactionalClasses.isEmpty) {
      return null;
    }

    return transactionalClasses.map(_generateTransactional).join("\n");
  }

  bool _isTransactional(ClassElement cls) => _transactionalClassChecker.isAssignableFrom(cls);

  String _generateTransactional(ClassElement cls) {
    _validateClass(cls);

    return code.Class(
      (b) => b
        ..name = _privateToPublicName(cls.displayName)
        ..types = _buildClassParameters(cls)
        ..extend = code.refer(_buildClassExtends(cls))
        ..constructors = _buildConstructors(cls)
        ..methods = _buildTransactionalMethods(cls)
      //
      ,
    ).accept(code.DartEmitter()).toString();
  }

  String _buildClassExtends(ClassElement cls) {
    if (cls.typeParameters.isEmpty ||
        cls.typeParameters.length == 1 && cls.typeParameters.first.displayName == "dynamic") {
      return cls.displayName;
    }

    return "${cls.displayName}<${cls.typeParameters.map((param) => param.displayName).join(",")}>";
  }

  ListBuilder<code.Reference> _buildClassParameters(ClassElement cls) {
    return ListBuilder(
      cls.typeParameters.map((param) => code.refer(param.toString())),
    );
  }

  String _privateToPublicName(String name) {
    return _publicClassNameRegexp.firstMatch(name).group(1);
  }

  void _validateClass(ClassElement cls) {
    if (!cls.isPrivate) {
      throw "Transactional class ${cls.displayName} must be private";
    }
  }

  ListBuilder<code.Constructor> _buildConstructors(ClassElement cls) {
    return ListBuilder(cls.constructors.map(_buildConstructor));
  }

  code.Constructor _buildConstructor(ConstructorElement constructor) {
    return code.Constructor(
      (b) => b
        ..name = constructor.displayName.isNotEmpty ? constructor.displayName : null
        ..requiredParameters = _buildMethodRequiredParams(constructor)
        ..optionalParameters = _buildMethodOptionalParams(constructor)
        ..initializers = _buildSuperInitializer(constructor)
      //
      ,
    );
  }

  ListBuilder<code.Parameter> _buildMethodRequiredParams(FunctionTypedElement constructor) {
    return ListBuilder(
      constructor.parameters.where((param) => param.isRequiredPositional).map(_buildMethodParam),
    );
  }

  ListBuilder<code.Parameter> _buildMethodOptionalParams(FunctionTypedElement constructor) {
    return ListBuilder(
      constructor.parameters.where((param) => param.isRequiredNamed || param.isOptional).map(_buildMethodParam),
    );
  }

  ListBuilder<code.Code> _buildSuperInitializer(ConstructorElement constructor) {
    return ListBuilder([
      code
          .refer("super${constructor.displayName.isNotEmpty ? ".${constructor.displayName}" : ""}")
          .call(
            _buildMethodPositionalParamNames(constructor),
            _buildMethodNamedParamNames(constructor),
          )
          .code
    ]);
  }

  code.Parameter _buildMethodParam(ParameterElement param) {
    return code.Parameter((b) => b
      ..name = param.name
      ..type = code.refer(param.type.name)
      ..named = param.isNamed);
  }

  Iterable<code.Expression> _buildMethodPositionalParamNames(FunctionTypedElement method) {
    return method.parameters
        .where((param) => param.isPositional)
        .map((param) => code.refer(param.displayName).expression);
  }

  Map<String, code.Expression> _buildMethodNamedParamNames(FunctionTypedElement method) {
    final paramNames = method.parameters.where((param) => param.isNamed).map((param) => param.displayName);
    return {
      for (var param in paramNames) param: code.refer(param).expression,
    };
  }

  ListBuilder<code.Method> _buildTransactionalMethods(ClassElement cls) {
    final suitableMethods = cls.methods
        .where((method) => method.isPublic && !method.isAbstract && !method.isStatic && method.isAsynchronous);

    return ListBuilder(
      suitableMethods.map(
        (method) => code.Method(
          (b) => b
            ..name = method.name
            ..requiredParameters = _buildMethodRequiredParams(method)
            ..optionalParameters = _buildMethodOptionalParams(method)
            ..returns = _buildMethodReturnType(method)
            ..annotations = ListBuilder([code.refer("override").expression])
            ..modifier = code.MethodModifier.async
            ..body = _buildMethodBody(method),
        ),
      ),
    );
  }

  code.Reference _buildMethodReturnType(MethodElement method) {
    return code.refer(method.returnType.displayName);
  }

  code.Code _buildMethodBody(MethodElement method) {
    final isTransaction =
        method.metadata.any((annotation) => _transactionChecker.isExactlyType(annotation.computeConstantValue().type));

    final wrapper = isTransaction ? "executeInWriteTransaction" : "executeInReadTransaction";

    final superCall = code.Method((b) => b
      ..body = code
          .refer("super.${method.displayName}")
          .call(
            _buildMethodPositionalParamNames(method),
            _buildMethodNamedParamNames(method),
          )
          .code).closure;

    final wrapperCall = code.refer('db.$wrapper').call([superCall]).awaited.returned.statement;

    return code.Block((b) => b..statements = ListBuilder([wrapperCall]));
  }
}
