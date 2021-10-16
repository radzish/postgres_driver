import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  late PGConnection conn;
  ResultSet? rs;

  setUp(() async {
    conn = createConnection();

    await conn.open();

    (await conn.execute('''
        drop table if exists test_table
      ''')).close();

    (await conn.execute('''
        create table test_table(
          id int primary key,
          name varchar(16),
          description varchar(16)
        )
      ''')).close();
  });

  tearDown(() async {
    rs?.close();
    await conn.close();
  });

  test("'in' with int values should be properly handled on select", () async {
    await conn.insert("test_table", {"id": 0, "name": "item0"});
    await conn.insert("test_table", {"id": 1, "name": "item1"});
    await conn.insert("test_table", {"id": 2, "name": "item2"});

    rs = await conn.select(
      "select id from test_table where id in (@ids) order by id",
      params: {
        "ids": [0, 2]
      },
    );

    expect(rs!.rowMaps, [
      {"id": 0},
      {"id": 2},
    ]);
  });

  test("'in' with string values should be properly handled on select", () async {
    await conn.insert("test_table", {"id": 0, "name": "item0"});
    await conn.insert("test_table", {"id": 1, "name": "item1"});
    await conn.insert("test_table", {"id": 2, "name": "item2"});

    rs = await conn.select(
      "select name from test_table where name in (@names) order by name",
      params: {
        "names": ["item0", "item2"]
      },
    );

    expect(rs!.rowMaps, [
      {"name": "item0"},
      {"name": "item2"},
    ]);
  });

  test("in in combination with other criterias should be properly handled on select", () async {
    await conn.insert("test_table", {"id": 0, "name": "item0", "description": "desc0"});
    await conn.insert("test_table", {"id": 1, "name": "item1", "description": "desc0"});
    await conn.insert("test_table", {"id": 2, "name": "item2", "description": "desc1"});
    await conn.insert("test_table", {"id": 3, "name": "item3", "description": "desc2"});

    rs = await conn.select(
      "select name from test_table where id > @id and name in (@names) and description = @desc order by name",
      params: {
        "id": 0,
        "names": ["item0", "item1", "item2"],
        "desc": "desc1",
      },
    );

    expect(rs!.rowMaps, [
      {"name": "item2"},
    ]);
  });

  test("in with single value should be properly handled on select", () async {
    await conn.insert("test_table", {"id": 0, "name": "item0"});

    rs = await conn.select(
      "select name from test_table where name in (@names) order by name",
      params: {
        "names": ["item0"]
      },
    );

    expect(rs!.rowMaps, [
      {"name": "item0"},
    ]);
  });

  test("multiple 'in' in combination with other criterias should be properly handled on select", () async {
    await conn.insert("test_table", {"id": 0, "name": "item0", "description": "desc0"});
    await conn.insert("test_table", {"id": 1, "name": "item1", "description": "desc0"});
    await conn.insert("test_table", {"id": 2, "name": "item2", "description": "desc1"});
    await conn.insert("test_table", {"id": 3, "name": "item3", "description": "desc2"});

    rs = await conn.select(
      "select name from test_table where (id > @id and name in (@names) and description = @desc) or id in (@ids) order by name",
      params: {
        "id": 0,
        "names": ["item0", "item1", "item2"],
        "desc": "desc1",
        "ids": [2, 3],
      },
    );

    expect(rs!.rowMaps, [
      {"name": "item2"},
      {"name": "item3"},
    ]);
  });
}
