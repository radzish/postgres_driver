import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

void main() {
  test("closing closed connection must not crash", () async {
    PGConnection conn = PGConnection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");

    await conn.open();

    await conn.execute("select 1");

    await conn.close();
    await conn.close();
  });
}
