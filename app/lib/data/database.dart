import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Persons, Houses, Claims, PersonNames, FieldEdits, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// An empty in-memory database, for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  // Still 1: this is the schema the first device database is created with.
  // Once the app has run on a device, any table change needs a bump of this
  // version and a migration.
  @override
  int get schemaVersion => 1;
}
