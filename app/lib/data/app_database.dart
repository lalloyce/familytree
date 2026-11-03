import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Empty schema. Tables arrive in Task 7. This file exists so that
/// `dart run build_runner build` proves code generation works.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
