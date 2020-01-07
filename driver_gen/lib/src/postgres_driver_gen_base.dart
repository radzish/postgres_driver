import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:build/build.dart';
import 'package:postgres_driver_gen/src/template/transactional.dart';
import 'package:postgres_driver_gen/src/template/transactional_file.dart';
import 'package:postgres_driver_gen/src/transactional_class_visitor.dart';
import 'package:source_gen/source_gen.dart';

class TransactionalGenerator extends Generator {
  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    if (library.allElements.isEmpty) {
      return "";
    }

    final typeSystem = await library.allElements.first.session.typeSystem;
    final file = TransactionalFileTemplate()..storeSources = _generateCodeForLibrary(library, typeSystem).toSet();
    return file.toString();
  }

  Iterable<String> _generateCodeForLibrary(
    LibraryReader library,
    TypeSystem typeSystem,
  ) sync* {
    for (final classElement in library.classes) {
      if (isTransactionalClass(classElement)) {
        yield* _generateCodeForTransactional(library, classElement, typeSystem);
      }
    }
  }

  Iterable<String> _generateCodeForTransactional(
    LibraryReader library,
    ClassElement transactionalClass,
    TypeSystem typeSystem,
  ) sync* {
    final otherClasses = library.classes.where((c) => c != transactionalClass);
    final mixedClass = otherClasses.firstWhere((c) {
      // If our base class has different type parameterization requirements than
      // the class we're evaluating provides, we know it's not a subclass.
      if (transactionalClass.typeParameters.length != c.supertype.typeArguments.length) {
        return false;
      }

      // Apply the subclass' type arguments to the base type (if there are none
      // this has no impact), and perform a supertype check.
      return typeSystem.isSubtypeOf(c.type, transactionalClass.type.instantiate(c.supertype.typeArguments));
    }, orElse: () => null);

    if (mixedClass != null) {
      yield _generateCodeFromTemplate(mixedClass.name, transactionalClass, TransactionalTemplate());
    }
  }

  String _generateCodeFromTemplate(
    String publicTypeName,
    ClassElement userStoreClass,
      TransactionalTemplate template,
  ) {
    final visitor = TransactionalClassVisitor(publicTypeName, userStoreClass, template);
    userStoreClass
      ..accept(visitor)
      ..visitChildren(visitor);
    return visitor.source;
  }
}
