import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  late PGConnection conn;
  ResultSet? rs;

  Future<void> _testInsert(PGConnection conn) async {
    (await conn.execute("insert into test_table(id, name) values(0, 'name0'),(1, 'name1')")).close();
  }

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
    await conn.close();
    rs?.close();
  });

  test("select should returns non null result set", () async {
    await _testInsert(conn);

    rs = await conn.execute("select id, name from test_table");

    expect(rs, isNotNull);
  });

  test("select should return correct number of rows", () async {
    await _testInsert(conn);

    rs = await conn.execute("select id, name from test_table");

    expect(rs!.columnsNumber, 2);
  });

  test("select should returns correct column names", () async {
    await _testInsert(conn);

    rs = await conn.execute("select id, name from test_table");

    expect(rs!.columnNames, ["id", "name"]);
  });

  test("select should returns correct rows", () async {
    await _testInsert(conn);

    rs = await conn.execute("select id, name from test_table");

    expect(rs!.rows, [
      [0, "name0"],
      [1, "name1"]
    ]);
  });

  test("select should returns correct row map", () async {
    await _testInsert(conn);

    rs = await conn.execute("select id, name from test_table");

    expect(rs!.rowMaps, _testValues);
  });

  test("select result set rows must contain null values", () async {
    List<Map<String, dynamic>> testValues = [
      {"id": 0},
    ];

    rs = await conn.execute("insert into test_table(id) values(@id)", testValues);

    rs = await conn.execute("select id, name from test_table");
    expect(rs!.rows, [
      [0, null]
    ]);
  });

  test("select result set rowMaps must not contain null value entries", () async {
    List<Map<String, dynamic>> testValues = [
      {"id": 0},
    ];

    rs = await conn.execute("insert into test_table(id) values(@id)", testValues);

    rs = await conn.execute("select id, name from test_table");
    expect(rs!.rowMaps, [
      {"id": 0}
    ]);
  });

  test("insert should add new records", () async {
    rs = await conn.execute("insert into test_table(id, name) values(0, 'name0'),(1, 'name1')");

    rs = await conn.execute("select id, name from test_table");
    expect(rs!.rowMaps, _testValues);
  });

  test("insert should return correct id", () async {
    rs = await conn.execute("insert into test_table(id, name) values(0, 'name0'),(1, 'name1') returning id");

    expect(rs!.rowMaps, [
      {"id": 0},
      {"id": 1}
    ]);
  });

  test("insert null values should insert NULL db values", () async {
    List<Map<String, dynamic>> testValues = [
      {"id": 0, "name": null},
      {"id": 1},
    ];

    rs = await conn.execute("insert into test_table(id, name) values(@id, @name)", testValues);

    rs = await conn.execute("select id, name from test_table");
    expect(rs!.rows, [
      [0, null],
      [1, null],
    ]);
  });

  test("insert should handle named parameters", () async {
    rs = await conn.execute("insert into test_table(id, name) values(@id, @name)", _testValues);

    rs = await conn.execute("select id, name from test_table");
    expect(rs!.rowMaps, _testValues);
  });

  test("insert should handle named parameters and return correct ids", () async {
    rs = await conn.execute("insert into test_table(id, name) values(@id, @name) returning id", _testValues);

    expect(rs!.rowMaps, [
      {"id": 0},
      {"id": 1}
    ]);
  });

  test("named parameters must only contain numbers, digits or underscores", () async {
    List<Map<String, dynamic>> testValues = [
      {"id": 0, "a0_": "name0"},
    ];

    rs = await conn.execute("insert into test_table(id, name) values(@id, @a0_) returning id", testValues);

    rs = await conn.execute("select id, name from test_table");
    expect(rs!.rowMaps, [
      {"id": 0, "name": "name0"}
    ]);
  });

  test("query with named parameters having not numbers, digits or underscores must fail", () async {
    List<Map<String, dynamic>> testValues = [
      {"id": 0, "a!": "name0"},
    ];

    expect(() async {
      await conn.execute("insert into test_table(id, name) values(@id, @a!) returning id", testValues);
    }, throwsA(predicate((dynamic e) => e is PGException && e.message == "param name \"a!\" invalid")));

    rs = await conn.execute("select id, name from test_table");
    expect(rs!.rowsNumber, 0);
  });

  test("empty result set should have proper values", () async {
    rs = await conn.execute("insert into test_table(id, name) values(@id, @name)", _testValues);

    expect(rs!.columnsNumber, 0);
    expect(rs!.columnNames, isEmpty);
    expect(rs!.rowsNumber, 0);
    expect(rs!.rows, isEmpty);
    expect(rs!.rowMaps, isEmpty);
  });
}
