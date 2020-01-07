import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';
import 'package:build/build.dart';
import 'package:postgres_driver/postgres_driver.dart';
import 'package:postgres_driver_gen/src/errors.dart';
import 'package:postgres_driver_gen/src/template/async_transaction.dart';
import 'package:postgres_driver_gen/src/template/method_override.dart';
import 'package:postgres_driver_gen/src/template/transaction.dart';
import 'package:postgres_driver_gen/src/template/transactional.dart';
import 'package:postgres_driver_gen/src/template/util.dart';
import 'package:source_gen/source_gen.dart';

class TransactionalClassVisitor extends SimpleElementVisitor {
  TransactionalClassVisitor(
    String publicTypeName,
    ClassElement userClass,
    TransactionalTemplate template,
  ) : _errors = TransactionalClassCodegenErrors(publicTypeName) {
    _transactionalTemplate = template
      ..typeParams.templates.addAll(userClass.typeParameters.map(typeParamTemplate))
      ..typeArgs.templates.addAll(userClass.typeParameters.map((t) => t.name))
      ..parentTypeName = userClass.name
      ..publicTypeName = publicTypeName;
  }

  final _transactionChecker = const TypeChecker.fromRuntime(Transaction);

  TransactionalTemplate _transactionalTemplate;

  final TransactionalClassCodegenErrors _errors;

  String get source {
    if (_errors.hasErrors) {
      log.severe(_errors.message);
      return '';
    }
    return _transactionalTemplate.toString();
  }

  @override
  void visitClassElement(ClassElement element) {
    _errors.nonAbstractTransactionalDeclarations.addIf(!element.isAbstract, element.name);
    _errors.nonPrivateTransactionalDeclarations.addIf(!element.isPrivate, element.name);
  }

  @override
  void visitMethodElement(MethodElement element) {
    if (_transactionChecker.hasAnnotationOfExact(element)) {
      if (_transactionIsNotValid(element)) {
        return;
      }

      if (element.isAsynchronous) {
        final template = AsyncTransactionTemplate()..method = MethodOverrideTemplate.fromElement(element);
        _transactionalTemplate.asyncTransactionMethods.add(template);
      } else {
        final template = TransactionTemplate()..method = MethodOverrideTemplate.fromElement(element);
        _transactionalTemplate.transactionMethods.add(template);
      }
    }

    return;
  }

  bool _transactionIsNotValid(MethodElement element) => _any([
        _errors.staticMethods.addIf(element.isStatic, element.name),
        _errors.asyncGeneratorActions.addIf(element.isAsynchronous && element.isGenerator, element.name),
      ]);
}

const _transactionalChecker = TypeChecker.fromRuntime(Transactional);

bool isTransactionalClass(ClassElement classElement) =>
    classElement.interfaces.any(_transactionalChecker.isExactlyType);

bool _any(List<bool> list) => list.any(_identity);

T _identity<T>(T value) => value;
