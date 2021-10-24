import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  late PGConnection conn;
  ResultSet? rs;

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

  test("update should save data when transaction is commited", () async {
    await conn.insertMultiple("test_table", _testValues);

    await conn.begin();
    await conn.update("test_table", {"name": "name0updated"}, criteria: "id = @id", criteriaParams: {"id": 0});
    await conn.commit();

    rs = await conn.execute("select id, name from test_table where id = @id", [
      {"id": 0}
    ]);

    expect(rs!.rowMaps, [
      {"id": 0, "name": "name0updated"}
    ]);
  });

  test("update should not save data when transaction is rolled back", () async {
    await conn.insertMultiple("test_table", _testValues);

    await conn.begin();
    await conn.update("test_table", {"name": "name0updated"}, criteria: "id = @id", criteriaParams: {"id": 0});
    await conn.rollback();

    rs = await conn.execute("select id, name from test_table where id = @id", [
      {"id": 0}
    ]);

    expect(rs!.rowMaps, [
      {"id": 0, "name": "name0"}
    ]);
  });

  test("data within transaction should display updated value before rolled back", () async {
    await conn.insertMultiple("test_table", _testValues);

    await conn.begin();

    await conn.update("test_table", {"name": "name0updated"}, criteria: "id = @id", criteriaParams: {"id": 0});

    rs = await conn.execute("select id, name from test_table where id = @id", [
      {"id": 0}
    ]);

    expect(rs!.rowMaps, [
      {"id": 0, "name": "name0updated"}
    ]);

    await conn.rollback();

    rs = await conn.execute("select id, name from test_table where id = @id", [
      {"id": 0}
    ]);

    expect(rs!.rowMaps, [
      {"id": 0, "name": "name0"}
    ]);
  });
}
