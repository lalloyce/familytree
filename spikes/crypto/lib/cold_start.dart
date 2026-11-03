// Spike 5: first run versus returning run, and the restore-without-key
// fallback (design section 9, "Backups": "A restored database without its key
// is unreadable, so a restore means a re-sync").
//
// Nothing here deletes a database or overwrites a stored key. When the app
// must start clean, the unreadable files are renamed aside ("quarantined").
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

  /// The local data could not be used. Any unreadable database was set aside
  /// (see [StartResult.quarantined]); the app now holds a clean, empty,
  /// encrypted database and must ask the user to sign in and re-sync.
  resyncNeeded,

  /// The key store could not be read (or returned something that is not a
  /// key). Nothing was opened, moved, deleted or written. Try again later.
  keyReadFailed,
}

enum ResyncReason {
  /// A database file exists but no key is stored (for example a backup
  /// restored the file but not the key, or secure storage was reset).
  keyMissing,

  /// A key is stored but it does not open the database file. The stored key
  /// is kept unchanged and reused for the new database.
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
    this.quarantined = const [],
    this.error,
  });

  /// Null only for [StartState.keyReadFailed].
  final SpikeDb? db;
  final StartState state;
  final ResyncReason? reason;

  /// Result of the first query (`SELECT count(*) FROM people`); 0 when no
  /// database was opened.
  final int peopleCount;

  /// Time spent reading the key from the [KeyStore].
  final Duration keyRead;

  /// From the start of [coldStart] to the first query result.
  final Duration total;

  /// Files renamed aside by this start (empty if none).
  final List<File> quarantined;

  /// For [StartState.keyReadFailed]: what went wrong.
  final Object? error;
}

/// Removes the database file and SQLite's side files. Not used by
/// [coldStart]; tests use it to simulate a lost file.
Future<void> deleteDatabaseFiles(File dbFile) async {
  for (final suffix in sideFileSuffixes) {
    final f = File('${dbFile.path}$suffix');
    if (await f.exists()) await f.delete();
  }
}

const sideFileSuffixes = ['', '-wal', '-shm', '-journal'];

/// Renames the database file and any side files to
/// `<name>.<UTC timestamp>.unreadable<suffix>` next to it. Returns the new
/// files. The bytes are kept so the data can be recovered later (for example
/// with an older key form) or removed deliberately.
Future<List<File>> quarantineDatabaseFiles(File dbFile) async {
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  final moved = <File>[];
  for (final suffix in sideFileSuffixes) {
    final f = File('${dbFile.path}$suffix');
    if (await f.exists()) {
      moved.add(await f.rename('${dbFile.path}.$stamp.unreadable$suffix'));
    }
  }
  return moved;
}

Future<int> _firstQuery(SpikeDb db) async {
  final row = await db
      .customSelect('SELECT count(*) AS c FROM people')
      .getSingle();
  return row.read<int>('c');
}

/// Opens the local database for this install.
///
/// - A key-store read failure returns [StartState.keyReadFailed] and touches
///   nothing.
/// - A database that the stored key cannot open (SQLITE_NOTADB only) is
///   quarantined, never deleted, and the stored key is never overwritten.
/// - Other errors are rethrown: errors from the first query that are not
///   SQLITE_NOTADB (including [CipherMissingError]), from writing a new key,
///   and from renaming files. Errors while closing a database that failed to
///   open are ignored.
Future<StartResult> coldStart({
  required KeyStore keys,
  required File dbFile,
  KeyForm form = KeyForm.passphrase,
}) async {
  final sw = Stopwatch()..start();
  final String? storedKey;
  try {
    storedKey = await keys.readKey();
  } on KeyReadException catch (e) {
    return StartResult(
      db: null,
      state: StartState.keyReadFailed,
      reason: null,
      peopleCount: 0,
      keyRead: sw.elapsed,
      total: sw.elapsed,
      error: e,
    );
  }
  final keyRead = sw.elapsed;

  if (storedKey != null && !isWellFormedKey(storedKey)) {
    // Inference from flutter_secure_storage 11.2.0's Android source, not
    // tested: with resetOnError it can answer a failed call with the string
    // "Data has been reset". Treat any malformed value as a read failure.
    return StartResult(
      db: null,
      state: StartState.keyReadFailed,
      reason: null,
      peopleCount: 0,
      keyRead: keyRead,
      total: sw.elapsed,
      error: const FormatException('stored value is not a 64-hex key'),
    );
  }

  Future<StartResult> open(
    String key,
    StartState state,
    ResyncReason? reason,
    List<File> quarantined,
  ) async {
    final db = openEncryptedDatabase(dbFile, key, form: form);
    final count = await _firstQuery(db);
    return StartResult(
      db: db,
      state: state,
      reason: reason,
      peopleCount: count,
      keyRead: keyRead,
      total: sw.elapsed,
      quarantined: quarantined,
    );
  }

  final fileExists = await dbFile.exists();

  if (storedKey == null) {
    // No key exists, so writing one overwrites nothing.
    final moved = await quarantineDatabaseFiles(dbFile);
    final key = generateKey();
    await keys.writeKey(key);
    return fileExists
        ? open(key, StartState.resyncNeeded, ResyncReason.keyMissing, moved)
        : open(key, StartState.firstRun, null, moved);
  }

  if (!fileExists) {
    final moved = await quarantineDatabaseFiles(dbFile); // stray side files
    return open(
      storedKey,
      StartState.resyncNeeded,
      ResyncReason.databaseMissing,
      moved,
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
    final moved = await quarantineDatabaseFiles(dbFile);
    // The stored key is kept as it is: the quarantined file may still open
    // with it (for example under the other KeyForm).
    return open(
      storedKey,
      StartState.resyncNeeded,
      ResyncReason.keyRejected,
      moved,
    );
  }
}
