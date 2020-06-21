import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  PGConnection conn;
  ResultSet rs;

  setUp(() async {
    conn = createConnection();

    await conn.open();

    (await conn.execute('''
        drop table if exists test_table
      ''')).close();

    (await conn.execute('''
        create table test_table(
          id int primary key,
          name varchar
        )
      ''')).close();
  });

  tearDown(() async {
    rs?.close();
    await conn.close();
  });

  test("execute should fail on invalid query", () async {
    expect(() async {
      await conn.execute("select invalid query");
    }, throwsA(anything));
  });
}
