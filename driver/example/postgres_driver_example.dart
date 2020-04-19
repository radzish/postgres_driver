import 'package:postgres_driver/postgres_driver.dart';
import 'package:process_run/shell.dart';

main() async {
  await Shell(workingDirectory: "./c").run("make so");

  PGConnection conn = PGConnection("dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test");
  await conn.open();
  print("${time()} db call 1 started ... ");

  conn.execute('''
        select pg_sleep(5)
      ''').then((_) {
    print("${time()} db result 1 complete");
  });

  print("${time()} db call 2 started ... ");

  conn.execute('''
        select pg_sleep(10)
      ''').then((_) {
    print("${time()} db result 2 complete");
  });

  print("${time()} calculations started ...");

  print("${time()} calculations complete");
}

String time() {
  final now = DateTime.now();
  return "${now.hour}:${now.minute}:${now.second}";
}
