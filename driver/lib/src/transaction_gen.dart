import 'package:postgres_driver/src/db_context.dart';

class Transaction {
  const Transaction._();
}

const Transaction transaction = Transaction._();

abstract class Transactional {
  DbContext get db;
}
