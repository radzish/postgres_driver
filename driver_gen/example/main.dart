import 'dart:math';

import 'package:postgres_driver/postgres_driver.dart';

import 'service.dart';

Future<void> main() async {
  final db = DbContext("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");
  final resource = Resource(db);
  final service = Service(db, resource);

  final valueToWrite = Random().nextInt(10000).toString();
  await service.write(valueToWrite);
  final readValue = await service.read();

  print("done: $valueToWrite\t$readValue");
}
