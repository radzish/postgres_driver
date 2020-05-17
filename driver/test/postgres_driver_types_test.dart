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
          double_value double precision
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
}
