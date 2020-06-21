import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

void main() {
  PGConnection conn;
  ResultSet rs;

  List<Map<String, dynamic>> _testValues = [
    {"id": 0, "name": "name0"},
    {"id": 1, "name": "name1"}
  ];

  setUp(() async {
    conn = PGConnection("host=localhost dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");

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

  test("insert should add single record", () async {
    await conn.insert("test_table", _testValues.last);

    rs = await conn.execute("select id, name from test_table");
    expect(rs.rowMaps, [_testValues.last]);
  });

  test("insert should add multiple records", () async {
    await conn.insertMultiple("test_table", _testValues);

    rs = await conn.execute("select id, name from test_table");
    expect(rs.rowMaps, _testValues);
  });

  test("insert should add multiple records combining different keys", () async {
    (await conn.execute('''
        drop table if exists test_table_diff_keys
      ''')).close();

    (await conn.execute('''
        create table test_table_diff_keys(
          id int primary key,
          name0 varchar,
          name1 varchar
        )
      ''')).close();

    List<Map<String, dynamic>> differentValues = [
      {"id": 0, "name0": "name0"},
      {"id": 1, "name1": "name1"}
    ];

    await conn.insertMultiple("test_table_diff_keys", differentValues);

    rs = await conn.execute("select id, name0, name1 from test_table_diff_keys");
    expect(rs.rowMaps, differentValues);
  });
}
