import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  PGConnection conn;
  ResultSet rs;

  List<Map<String, dynamic>> _testValues = [
    {"id": 0, "name": "name0"},
    {"id": 1, "name": "name1"}
  ];

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

  test("update should update table values with no critera", () async {
    await conn.insertMultiple("test_table", _testValues);

    Map<String, dynamic> updateValue = {"name": "nameUpdated"};
    await conn.update("test_table", updateValue);

    rs = await conn.execute("select id, name from test_table order by id");
    expect(rs.rowMaps, [
      {"id": 0, "name": "nameUpdated"},
      {"id": 1, "name": "nameUpdated"}
    ]);
  });

  test("update should update table with criteria", () async {
    await conn.insertMultiple("test_table", _testValues);

    Map<String, dynamic> updateValue = {"name": "name0updated"};
    await conn.update("test_table", updateValue, criteria: "id = 0");

    rs = await conn.execute("select id, name from test_table order by id");
    expect(rs.rowMaps, [
      {"id": 0, "name": "name0updated"},
      {"id": 1, "name": "name1"}
    ]);
  });

  test("update should update table with parametrized criteria", () async {
    await conn.insertMultiple("test_table", _testValues);

    Map<String, dynamic> updateValue = {"name": "name0updated"};
    await conn.update("test_table", updateValue, criteria: "id = @id", criteriaParams: {"id": 0});

    rs = await conn.execute("select id, name from test_table order by id");
    expect(rs.rowMaps, [
      {"id": 0, "name": "name0updated"},
      {"id": 1, "name": "name1"}
    ]);
  });
}
