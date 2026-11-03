import 'package:drift/drift.dart';

/// What a claim asserts. Stored as the enum name (text).
enum ClaimKind {
  belongsToHouse,
  wifeOfHouse,
  sire,
  joinedVia,
  originNote,
  samePerson,
}

/// Why a person belongs to a house. Only used with [ClaimKind.belongsToHouse].
enum Basis { bornTo, joined }

enum Sex { male, female }

/// Claim states. Stored as text so that a later state needs no migration.
const claimStatusActive = 'active';
const claimStatusSuperseded = 'superseded';

@DataClassName('PersonRow')
class Persons extends Table {
  TextColumn get id => text()();
  BoolColumn get isPlaceholder =>
      boolean().withDefault(const Constant(false))();
  TextColumn get nameKey => text().nullable()();
  TextColumn get sex => textEnum<Sex>().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HouseRow')
class Houses extends Table {
  TextColumn get id => text()();
  TextColumn get husbandId => text()();
  IntColumn get ordinal => integer().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only. [localSeq] orders claims on this device and never depends on
/// the device clock. [id] is the client-generated UUID that syncs.
@DataClassName('ClaimRow')
class Claims extends Table {
  IntColumn get localSeq => integer().autoIncrement()();
  TextColumn get id => text().unique()();
  TextColumn get kind => textEnum<ClaimKind>()();
  TextColumn get subjectId => text()();
  TextColumn get objectId => text().nullable()();
  TextColumn get basis => textEnum<Basis>().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get assertedBy => text()();
  TextColumn get baseClaimId => text().nullable()();
  // The check refers to the column being defined, as the Drift docs show.
  TextColumn get status => text()
      .withDefault(const Constant(claimStatusActive))
      // ignore: recursive_getters
      .check(status.isIn([claimStatusActive, claimStatusSuperseded]))();
  DateTimeColumn get createdAt => dateTime()();
}

/// Spelling variants and extra names. `Persons.nameKey` stays the primary
/// display name.
@DataClassName('PersonNameRow')
class PersonNames extends Table {
  TextColumn get id => text()();
  TextColumn get personId => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Edit history for low-stakes fields. Nothing is overwritten without a row
/// here. [localSeq] orders edits on this device.
@DataClassName('FieldEditRow')
class FieldEdits extends Table {
  IntColumn get localSeq => integer().autoIncrement()();
  TextColumn get id => text().unique()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get field => text()();
  TextColumn get value => text().nullable()();
  TextColumn get assertedBy => text()();
}
