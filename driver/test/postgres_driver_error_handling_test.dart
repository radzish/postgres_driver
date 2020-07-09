import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  PGConnection conn;
  ResultSet rs;

  setUp(() async {
    conn = createConnection();
    await conn.open();
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

  test("execute should work after failed invalid query on same connection", () async {
    try {
      await conn.execute("select invalid query");
    } catch (_) {}

    final rs = await conn.select("select 1");
    expect(rs.rows.first.first, 1);
  });
}
