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

  // Still 1: no build has run on any device yet, so adding [AppSettings] needs
  // no migration. The first release that ships must bump this and migrate.
  @override
  int get schemaVersion => 1;
}
