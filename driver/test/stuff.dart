import 'package:postgres_driver/postgres_driver.dart';

createConnection() => PGConnection("host=localhost dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");