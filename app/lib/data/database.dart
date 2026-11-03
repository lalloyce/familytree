import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Persons, Houses, Claims, PersonNames, FieldEdits])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// An empty in-memory database, for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
