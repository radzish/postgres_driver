import 'package:conn_pool/conn_pool.dart';
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

  ResultSet rs = await conn.execute("insert into test_table(id, name) values(:id, :name)", [
    {"id": 0, "name": "name0"},
//    {"id": 1, "name": "name1"},
  ]);

  rs.close();
  await conn.close();
}
