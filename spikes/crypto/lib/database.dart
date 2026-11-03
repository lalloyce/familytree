// Spike 5: an encrypted Drift database.
//
// Approach (Drift docs, "Encryption", read 2026-11-03,
// https://drift.simonbinder.eu/platforms/encryption/): the `sqlite3` package
// bundles SQLite3MultipleCiphers when pubspec.yaml sets
// `hooks: user_defines: sqlite3: source: sqlite3mc`. Drift's
// `package:drift/native.dart` is used unchanged; the key is applied with
// `PRAGMA key` in the `setup` callback, before Drift touches the database.
//
// Pure Dart (no Flutter import), so the benchmark can run in a `dart` process.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
// Experimental library; used only to unwrap errors from the background
// isolate. The message check in isNotADatabase is the fallback.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:sqlite3/sqlite3.dart' as sql;

part 'database.g.dart';

class People extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [People])
class SpikeDb extends _$SpikeDb {
  SpikeDb(super.e);

  @override
  int get schemaVersion => 1;
}

/// How the 64-hex-character key is handed to SQLite3MultipleCiphers.
enum KeyForm {
  /// `PRAGMA key = '<hex>'`: the hex string is a passphrase and goes through
  /// the cipher's key derivation (the form in the Drift docs).
  passphrase,

  /// `PRAGMA key = 'raw:<hex>'`: the SQLite3MultipleCiphers docs say raw key
  /// material "will be converted directly to 32 bytes (256 bits) of key data".
  /// Whether this skips key derivation is not stated on the pages read; the
  /// benchmark measures it.
  raw,
}

/// Thrown when the cipher library is not linked (plain SQLite was bundled).
/// Fail closed: never create an unencrypted database by accident.
class CipherMissingError extends Error {
  @override
  String toString() =>
      'CipherMissingError: PRAGMA cipher returned nothing; '
      'SQLite3MultipleCiphers is not linked. Check hooks.user_defines.';
}

/// True when the linked SQLite is SQLite3MultipleCiphers. Upstream SQLite has
/// no `cipher` pragma (Drift docs, "Important notice").
bool hasCipher(sql.Database db) => db.select('PRAGMA cipher;').isNotEmpty;

String _pragmaKey(String key, KeyForm form) {
  final value = form == KeyForm.raw ? 'raw:$key' : key;
  return "PRAGMA key = '${value.replaceAll("'", "''")}';";
}

/// Opens [file] as an encrypted Drift database with [key].
///
/// The key is checked inside `setup` with a read of `sqlite_master`, because
/// SQLite3MultipleCiphers' `PRAGMA key` returns ok even for a wrong key (its
/// docs, "SQL pragmas"). A wrong key, or a file that is not this database,
/// therefore surfaces on the first query Drift runs.
SpikeDb openEncryptedDatabase(
  File file,
  String key, {
  KeyForm form = KeyForm.passphrase,
  bool background = true,
}) {
  void setup(sql.Database raw) {
    if (!hasCipher(raw)) throw CipherMissingError();
    raw.execute(_pragmaKey(key, form));
    raw.select('SELECT count(*) FROM sqlite_master;');
  }

  final executor = background
      ? NativeDatabase.createInBackground(file, setup: setup)
      : NativeDatabase(file, setup: setup);
  return SpikeDb(executor);
}

/// CONTROL ONLY, for tests: opens without a key, so the file is plain SQLite.
/// Used to show that the byte search would find the marker if the file were
/// not encrypted.
SpikeDb openPlaintextDatabaseForControl(File file) =>
    SpikeDb(NativeDatabase(file));

/// True when [error] means "this file cannot be read with this key":
/// SQLITE_NOTADB (26), possibly wrapped by Drift's isolate layer.
bool isNotADatabase(Object error) {
  Object? e = error;
  for (var depth = 0; e != null && depth < 4; depth++) {
    if (e is sql.SqliteException) return e.resultCode == 26;
    if (e is DriftRemoteException) {
      e = e.remoteCause;
      continue;
    }
    if (e is DriftWrappedException) {
      e = e.cause;
      continue;
    }
    break;
  }
  return error.toString().contains('file is not a database');
}
