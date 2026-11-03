// Spike 5: first run versus returning run, and the restore-without-key
// fallback (design section 9, "Backups": "A restored database without its key
// is unreadable, so a restore means a re-sync").
//
// Pure Dart, so the benchmark can call it from a `dart` process.

import 'dart:io';

import 'database.dart';
import 'key_store.dart';

enum StartState {
  /// No key and no database: a new install. A key was generated and stored.
  firstRun,

  /// Key and database both present and the key opens the database.
  returning,

  /// The local data could not be used. The app now holds a clean, empty,
  /// encrypted database and must ask the user to sign in and re-sync.
  resyncNeeded,
}

enum ResyncReason {
  /// A database file exists but no key is stored (for example a backup
  /// restored the file but not the key, or secure storage was reset).
  keyMissing,

  /// A key is stored but it does not open the database file.
  keyRejected,

  /// A key is stored but the database file is gone.
  databaseMissing,
}

class StartResult {
  StartResult({
    required this.db,
    required this.state,
    required this.reason,
    required this.peopleCount,
    required this.keyRead,
    required this.total,
  });

  final SpikeDb db;
  final StartState state;
  final ResyncReason? reason;

  /// Result of the first query (`SELECT count(*) FROM people`).
  final int peopleCount;

  /// Time spent reading the key from the [KeyStore].
  final Duration keyRead;

  /// From the start of [coldStart] to the first query result.
  final Duration total;
}

/// Removes the database file and SQLite's side files.
Future<void> deleteDatabaseFiles(File dbFile) async {
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('${dbFile.path}$suffix');
    if (await f.exists()) await f.delete();
  }
}

Future<int> _firstQuery(SpikeDb db) async {
  final row = await db
      .customSelect('SELECT count(*) AS c FROM people')
      .getSingle();
  return row.read<int>('c');
}

/// Opens the local database for this install. Never throws for the
/// "unreadable local data" cases: it falls back to a clean database and
/// reports [StartState.resyncNeeded]. Other errors (disk full, bugs) are
/// rethrown so they are not hidden.
Future<StartResult> coldStart({
  required KeyStore keys,
  required File dbFile,
  KeyForm form = KeyForm.passphrase,
}) async {
  final sw = Stopwatch()..start();
  final storedKey = await keys.readKey();
  final keyRead = sw.elapsed;
  final fileExists = await dbFile.exists();

  Future<StartResult> fresh(StartState state, ResyncReason? reason) async {
    await deleteDatabaseFiles(dbFile);
    final key = generateKey();
    await keys.writeKey(key);
    final db = openEncryptedDatabase(dbFile, key, form: form);
    final count = await _firstQuery(db);
    return StartResult(
      db: db,
      state: state,
      reason: reason,
      peopleCount: count,
      keyRead: keyRead,
      total: sw.elapsed,
    );
  }

  if (storedKey == null) {
    return fileExists
        ? fresh(StartState.resyncNeeded, ResyncReason.keyMissing)
        : fresh(StartState.firstRun, null);
  }

  if (!fileExists) {
    final db = openEncryptedDatabase(dbFile, storedKey, form: form);
    final count = await _firstQuery(db);
    return StartResult(
      db: db,
      state: StartState.resyncNeeded,
      reason: ResyncReason.databaseMissing,
      peopleCount: count,
      keyRead: keyRead,
      total: sw.elapsed,
    );
  }

  final db = openEncryptedDatabase(dbFile, storedKey, form: form);
  try {
    final count = await _firstQuery(db);
    return StartResult(
      db: db,
      state: StartState.returning,
      reason: null,
      peopleCount: count,
      keyRead: keyRead,
      total: sw.elapsed,
    );
  } catch (e) {
    if (!isNotADatabase(e)) rethrow;
    try {
      await db.close();
    } catch (_) {
      // The executor may already have failed to open; nothing to close.
    }
    return fresh(StartState.resyncNeeded, ResyncReason.keyRejected);
  }
}
