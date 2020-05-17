import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

void main() {
  PGConnection conn;
  ResultSet rs;

  setUp(() async {
    conn = PGConnection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");

    await conn.open();

    (await conn.execute('''
        drop table if exists test_table
      ''')).close();

    (await conn.execute('''
        create table test_table(
          id int primary key,
          update_time timestamp,
          double_value double precision,
          json_object json
        )
      ''')).close();
  });

  tearDown(() async {
    rs?.close();
    await conn.close();
  });

  test("timestamp data should be properly inserted and selected", () async {
    DateTime time = DateTime.utc(2020, 1, 2, 3, 4, 5);

    await conn.insert("test_table", {"id": 0, "update_time": time});

    rs = await conn.select("select update_time from test_table", params: {});

    expect(rs.rowMaps, [
      {"update_time": time}
    ]);
  });

  test("double data should be properly inserted and selected", () async {
    double doubleValue = 0.1;
    await conn.insert("test_table", {"id": 0, "double_value": doubleValue});

    rs = await conn.select("select double_value from test_table", params: {});

    expect(rs.rowMaps, [
      {"double_value": doubleValue}
    ]);
  });

  test("json object should be properly inserted and selected", () async {
    Map<String, dynamic> jsonObject = {
      "stringValue": "a",
      "intValue": 0,
      "boolValue": true,
      "doubleValue": 0.1,
      "innerObject": {
        "innerValue": "innerValue",
      }
    };

    await conn.insert("test_table", {"id": 0, "json_object": jsonObject});

    rs = await conn.select("select json_object from test_table");

    expect(rs.rowMaps, [
      {"json_object": jsonObject}
    ]);
  });

  test("json object array should be properly inserted and selected", () async {
    List<Map<String, dynamic>> jsonObjectArray = [
      {
        "stringValue": "a",
        "intValue": 0,
        "boolValue": true,
        "doubleValue": 0.1,
        "innerObject": {
          "innerValue": "innerValue",
        }
      },
    ];

    await conn.insert("test_table", {"id": 0, "json_object": jsonObjectArray});

    rs = await conn.select("select json_object from test_table");

    expect(rs.rowMaps, [
      {"json_object": jsonObjectArray}
    ]);
  });

  test("json object array of simple values should be properly inserted and selected", () async {
    List<dynamic> jsonObjectArray = [
      "a",
      0,
      true,
      0.1,
    ];

    await conn.insert("test_table", {"id": 0, "json_object": jsonObjectArray});

    rs = await conn.select("select json_object from test_table");

    expect(rs.rowMaps, [
      {"json_object": jsonObjectArray}
    ]);
  });
}
