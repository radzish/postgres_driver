import 'package:postgres_driver/postgres_driver.dart';
import 'package:process_run/shell.dart';
import 'package:test/test.dart';

import 'stuff.dart';

void main() {
  test("closing closed connection must not crash", () async {
    PGConnection conn = createConnection();

    await conn.open();

    await conn.execute("select 1");

    await conn.close();
    await conn.close();
  });

  test("bad connection should be recovered", () async {
    PGConnection conn = createConnection();

    await conn.open();

    await conn.execute("select 1");

    // killing connection
    try {
      await conn.execute("select pg_terminate_backend(pid) from pg_stat_activity where datname='postgres_dart_test'");
    } catch (e) {
      //ignoring
    }

    // on this call connection should be recovered
    ResultSet rs = await conn.select("select 1", params: {});
    expect(rs.rowsNumber, 1);
    expect(rs.rows[0]![0], 1);

    await conn.close();
  });

  test("closed connection from outside should be recovered", () async {
    PGConnection conn = createConnection();

    await conn.open();

    await conn.execute("select 1");

    // restarting server -> connection is closed
    try {
      await Shell().run("sudo service postgresql-9.6 restart");
    } catch (e) {
      //ignoring
    }

    // on this call connection should be recovered
    ResultSet rs = await conn.select("select 1", params: {});
    expect(rs.rowsNumber, 1);
    expect(rs.rows[0]![0], 1);

    await conn.close();
  });
}
