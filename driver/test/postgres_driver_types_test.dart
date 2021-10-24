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
          update_time timestamp,
          double_value double precision,
          json_object json,
          jsonb_object jsonb,
          boolean_value boolean 
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

    expect(rs!.rowMaps, [
      {"update_time": time}
    ]);
  });

  test("double data should be properly inserted and selected", () async {
    double doubleValue = 0.1;
    await conn.insert("test_table", {"id": 0, "double_value": doubleValue});

    rs = await conn.select("select double_value from test_table", params: {});

    expect(rs!.rowMaps, [
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

    expect(rs!.rowMaps, [
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

    expect(rs!.rowMaps, [
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

    expect(rs!.rowMaps, [
      {"json_object": jsonObjectArray}
    ]);
  });

  test("jsonb object should be properly inserted and selected", () async {
    Map<String, dynamic> jsonObject = {
      "stringValue": "a",
      "intValue": 0,
      "boolValue": true,
      "doubleValue": 0.1,
      "innerObject": {
        "innerValue": "innerValue",
      }
    };

    await conn.insert("test_table", {"id": 0, "jsonb_object": jsonObject});

    rs = await conn.select("select jsonb_object from test_table");

    expect(rs!.rowMaps, [
      {"jsonb_object": jsonObject}
    ]);
  });

  test("jsonb object array should be properly inserted and selected", () async {
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

    await conn.insert("test_table", {"id": 0, "jsonb_object": jsonObjectArray});

    rs = await conn.select("select jsonb_object from test_table");

    expect(rs!.rowMaps, [
      {"jsonb_object": jsonObjectArray}
    ]);
  });

  test("jsonb object array of simple values should be properly inserted and selected", () async {
    List<dynamic> jsonObjectArray = [
      "a",
      0,
      true,
      0.1,
    ];

    await conn.insert("test_table", {"id": 0, "jsonb_object": jsonObjectArray});

    rs = await conn.select("select jsonb_object from test_table");

    expect(rs!.rowMaps, [
      {"jsonb_object": jsonObjectArray}
    ]);
  });

  test("jsonb object array of json objects should be properly inserted and selected", () async {
    List<dynamic> jsonObjectArray = [
      {"a": 0},
      {"b": 1},
    ];

    await conn.insert("test_table", {"id": 0, "jsonb_object": jsonObjectArray});

    rs = await conn.select("select jsonb_object from test_table");

    expect(rs!.rowMaps, [
      {"jsonb_object": jsonObjectArray}
    ]);
  });

  test("jsonb object with array of json objects should be properly updated", () async {
    await conn.insert("test_table", {"id": 0});

    List<dynamic> array = [
      {"id": "0"},
      {"id": "1"},
      {"id": "2"},
    ];

    Map<String, dynamic> jsonObject = {
      "jsonb_object": array,
      "id": "0",
    };

    await conn.update("test_table", jsonObject, criteria: "id = @id", criteriaParams: {"id": "0"});

    rs = await conn.select("select jsonb_object from test_table");
    expect(rs!.rowMaps, [
      {"jsonb_object": array}
    ]);
  });
}
