import 'package:postgres_driver/postgres_driver.dart';

main() async {
//  ConnectionPool pool = ConnectionPool("dbname=pexaconnect_app user=pexaconnect_app password=pexaconnect_app");
//  Connection pooledConnection = await pool.open();
//
//  ResultSet rs = await pooledConnection.connection.execute(
//      "SELECT id, name, tagline, logo is not null as has_logo FROM company  WHERE  name ~* CONCAT('(^|[\s])(','a'::varchar,')') ");
//
//  print(rs.columnNames);
//  print(rs.columnTypes);
//  print(rs.rows);
//  print(rs.rowsMap);
//
//  rs.close();
//
//  await pooledConnection.release();

  PGConnection conn = PGConnection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");
  await conn.open();

  ResultSet rs = await conn.execute('''
        drop table if exists test_table
      ''');
  rs.close();
//
//  rs = await conn.execute('''
//        create table test_table(
//          id int primary key,
//          update_time timestamp
//        )
//      ''');
//  rs.close();
//
//  rs = await conn.select("select update_time from test_table", params: {});
//  rs.close();

//  print("${rs.rows}");

//  (await conn.execute('''
//        create table test_table(
//          id int primary key,
//          update_time timestamp
//        )
//      ''')).close();
}
