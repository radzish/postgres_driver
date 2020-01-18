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
    conn = PGConnection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");

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

  test("delete should delete table records with no critera", () async {
    await conn.insertMultiple("test_table", _testValues);

    await conn.delete("test_table");

    rs = await conn.execute("select id, name from test_table");
    expect(rs.rowsNumber, 0);
  });

  test("delete should delete table records with criteria", () async {
    await conn.insertMultiple("test_table", _testValues);

    await conn.delete("test_table", criteria: "id = 0");

    rs = await conn.execute("select id, name from test_table order by id");
    expect(rs.rowMaps, [
      {"id": 1, "name": "name1"}
    ]);
  });

  test("delete should delete table records with parametrized criteria", () async {
    await conn.insertMultiple("test_table", _testValues);

    await conn.delete("test_table", criteria: "id = @id", criteriaParams: {"id": 0});

    rs = await conn.execute("select id, name from test_table order by id");
    expect(rs.rowMaps, [
      {"id": 1, "name": "name1"}
    ]);
  });
}
