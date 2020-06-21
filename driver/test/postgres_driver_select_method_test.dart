import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  PGConnection conn;
  ResultSet rs;

  Future<void> _testInsert(PGConnection conn) async {
    (await conn.execute("insert into test_table(id, name) values(0, 'name0'),(1, 'name1')")).close();
  }

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
    await conn.close();
    rs?.close();
  });

  test("select should accept named parameters as map", () async {
    await _testInsert(conn);

    rs = await conn.select("select id, name from test_table where id = @id", params: {"id": 0});

    expect(rs.rowMaps, [
      {"id": 0, "name": "name0"},
    ]);
  });

  test("select should work with no named parameters", () async {
    await _testInsert(conn);

    rs = await conn.select("select id, name from test_table order by id");

    expect(rs.rowMaps, [
      {"id": 0, "name": "name0"},
      {"id": 1, "name": "name1"},
    ]);
  });
}
