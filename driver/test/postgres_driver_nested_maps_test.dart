import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

void main() {
  PGConnection conn;
  ResultSet rs;

  Future<void> _testInsert(PGConnection conn) async {
    (await conn.execute(
            "insert into test_table(id, street, house, apartment) values(0, 'street0', 0, 0),(1, 'street1', 1, 1)"))
        .close();
  }

  setUp(() async {
    conn = PGConnection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");

    await conn.open();

    (await conn.execute('''
        drop table if exists test_table
      ''')).close();

    (await conn.execute('''
        create table test_table(
          id int primary key,
          street varchar,
          house int,
          apartment int
        )
      ''')).close();
  });

  tearDown(() async {
    await conn.close();
    rs?.close();
  });

  test("select rowMaps should support nested maps", () async {
    await _testInsert(conn);

    rs = await conn.select(
      'select id, street as "address.street", house as "address.home.house", apartment as "address.home.apartment" from test_table order by id',
    );

    expect(
      rs.rowMaps,
      [
        {
          "id": 0,
          "address": {
            "street": "street0",
            "home": {"house": 0, "apartment": 0}
          }
        },
        {
          "id": 1,
          "address": {
            "street": "street1",
            "home": {"house": 1, "apartment": 1}
          }
        },
      ],
    );
  });

  test("select rows should show nested maps as simple values", () async {
    await _testInsert(conn);

    rs = await conn.select(
      'select id, street as "address.street", house as "address.home.house", apartment as "address.home.apartment" from test_table order by id',
    );

    expect(
      rs.rows,
      [
        [0, "street0", 0, 0],
        [1, "street1", 1, 1]
      ],
    );
  });
}
