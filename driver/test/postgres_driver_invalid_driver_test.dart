import 'package:postgres_driver/postgres_driver.dart';
import 'package:test/test.dart';

void main() {
  test("opening connection with missing driver should throw argument error", () async {
    expect(
      () {
        PGConnection(
          "dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test",
          driverPath: "missing-driver.so",
        );
      },
      throwsArgumentError,
    );
  });

  test("opening connection with invalid driver should throw argument error", () async {
    expect(
      () {
        PGConnection(
          "dbname=postgres_dart_test user=postgres_dart_test password=postgres_dart_test",
          driverPath: "test/invalid-driver.so",
        );
      },
      throwsArgumentError,
    );
  });
}
