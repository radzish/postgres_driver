import 'package:build/build.dart';
import 'package:postgres_driver_gen/src/postgres_driver_gen_base.dart';
import 'package:source_gen/source_gen.dart';

Builder storeGenerator(BuilderOptions options) =>
    SharedPartBuilder([TransactionalGenerator()], 'transactional_generator');
