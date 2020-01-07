import 'package:postgres_driver_gen/src/template/async_transaction.dart';
import 'package:postgres_driver_gen/src/template/comma_list.dart';
import 'package:postgres_driver_gen/src/template/params.dart';
import 'package:postgres_driver_gen/src/template/rows.dart';
import 'package:postgres_driver_gen/src/template/transaction.dart';

class TransactionalTemplate {
  final SurroundedCommaList<TypeParamTemplate> typeParams = SurroundedCommaList('<', '>', []);
  final SurroundedCommaList<String> typeArgs = SurroundedCommaList('<', '>', []);
  String publicTypeName;
  String parentTypeName;

  final Rows<TransactionTemplate> transactionMethods = Rows();
  final Rows<AsyncTransactionTemplate> asyncTransactionMethods = Rows();

  String get body => '''

  $asyncTransactionMethods

  $transactionMethods

  ''';

  @override
  String toString() => '''
  mixin _\$$publicTypeName$typeParams on $parentTypeName$typeArgs {
    $body
  }''';
}
