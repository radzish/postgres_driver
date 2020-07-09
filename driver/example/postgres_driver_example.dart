import 'package:postgres_driver/postgres_driver.dart';
import 'package:process_run/shell.dart';

main() async {
  await Shell(workingDirectory: "./c").run("make so");

  PGConnection conn = PGConnection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test host=localhost");
  await conn.open();

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
  await conn.close();

  print("OK");
}
