import 'dart:async';

import 'package:postgres_driver/src/postgres_driver_impl.dart';

class Transaction {
  const Transaction._();
}

const Transaction transaction = Transaction._();

abstract class Transactional {
  PGConnection get conn;
}
