// Spike 5 host proofs. Every test runs the real SQLite3MultipleCiphers build
// bundled by the sqlite3 package's hook (pubspec.yaml: source: sqlite3mc).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto_spike/cold_start.dart';
import 'package:crypto_spike/database.dart';
import 'package:crypto_spike/key_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

const marker = 'PLAINTEXT_MARKER_Akinyi_Odhiambo_7f3c19';
final sqliteHeader = ascii.encode('SQLite format 3\u0000');

bool containsBytes(Uint8List hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// Every file SQLite left next to the database (main file, -wal, -journal).
List<File> filesFor(File db) => db.parent
    .listSync()
    .whereType<File>()
    .where((f) => f.path.startsWith(db.path))
    .toList();

Future<void> writeRows(SpikeDb db, {int n = 200}) async {
  await db.batch((b) {
    for (var i = 0; i < n; i++) {
      b.insert(
        db.people,
        PeopleCompanion.insert(
          id: 'p$i',
          name: i == 7 ? marker : 'Person $i',
          note: Value(i == 9 ? 'note $marker' : ''),
        ),
      );
    }
  });
}

void main() {
  late Directory dir;
  late File dbFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crypto_spike_');
    dbFile = File('${dir.path}/lineage.db');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('the linked SQLite is SQLite3MultipleCiphers', () {
    final db = sql.sqlite3.openInMemory();
    addTearDown(db.close);
    final cipher = db.select('PRAGMA cipher;');
    String mcVersion;
    try {
      mcVersion = '${db.select('SELECT sqlite3mc_version() AS v;').first['v']}';
    } on sql.SqliteException catch (e) {
      mcVersion = 'not available (${e.message})';
    }
    // ignore: avoid_print
    print(
      'PRAGMA cipher -> ${cipher.rows}; '
      'sqlite3mc_version() -> $mcVersion; '
      'sqlite_version() -> '
      '${db.select('SELECT sqlite_version() AS v').first['v']}',
    );
    expect(cipher, isNotEmpty);
  });

  test('generateKey gives 64 hex characters and differs each call', () {
    final a = generateKey();
    final b = generateKey();
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(a, isNot(b));
  });

  test(
    'CONTROL: an unkeyed database DOES contain the marker and header',
    () async {
      final db = openPlaintextDatabaseForControl(dbFile);
      await writeRows(db);
      await db.close();
      final bytes = dbFile.readAsBytesSync();
      expect(bytes.sublist(0, 16), sqliteHeader);
      expect(containsBytes(bytes, utf8.encode(marker)), isTrue);
    },
  );

  for (final form in KeyForm.values) {
    group('key form ${form.name}', () {
      test(
        'file on disk is not plain SQLite and has no plaintext marker',
        () async {
          final key = generateKey();
          final db = openEncryptedDatabase(dbFile, key, form: form);
          await writeRows(db);
          expect(
            await db
                .customSelect('SELECT count(*) AS c FROM people')
                .map((r) => r.read<int>('c'))
                .getSingle(),
            200,
          );
          await db.close();

          final files = filesFor(dbFile);
          expect(files, isNotEmpty);
          var total = 0;
          for (final f in files) {
            final bytes = f.readAsBytesSync();
            total += bytes.length;
            expect(
              containsBytes(bytes, utf8.encode(marker)),
              isFalse,
              reason: '${f.path} contains the marker',
            );
            expect(
              containsBytes(bytes, utf8.encode('Person 1')),
              isFalse,
              reason: '${f.path} contains a row value',
            );
            expect(
              containsBytes(bytes, utf8.encode('CREATE TABLE')),
              isFalse,
              reason: '${f.path} contains the schema',
            );
          }
          expect(dbFile.readAsBytesSync().sublist(0, 16), isNot(sqliteHeader));
          // ignore: avoid_print
          print(
            '[${form.name}] ${files.length} file(s), $total bytes, '
            'no marker, no schema text, no SQLite header',
          );
        },
      );

      test('opening without a key fails with SQLITE_NOTADB', () async {
        final db = openEncryptedDatabase(dbFile, generateKey(), form: form);
        await writeRows(db, n: 5);
        await db.close();

        final raw = sql.sqlite3.open(dbFile.path);
        addTearDown(raw.close);
        expect(
          () => raw.select('SELECT count(*) FROM sqlite_master'),
          throwsA(
            isA<sql.SqliteException>().having(
              (e) => e.resultCode,
              'resultCode',
              26,
            ),
          ),
        );
      });

      test(
        'opening with the wrong key fails, and the error is recognised',
        () async {
          final db = openEncryptedDatabase(dbFile, generateKey(), form: form);
          await writeRows(db, n: 5);
          await db.close();

          final wrong = openEncryptedDatabase(
            dbFile,
            generateKey(),
            form: form,
          );
          Object? caught;
          try {
            await wrong.customSelect('SELECT count(*) FROM people').get();
          } catch (e) {
            caught = e;
          }
          // ignore: avoid_print
          print(
            '[${form.name}] wrong key error type: ${caught.runtimeType}; '
                    '$caught'
                .split('\n')
                .first,
          );
          expect(caught, isNotNull);
          expect(isNotADatabase(caught!), isTrue);
          try {
            await wrong.close();
          } catch (_) {}
        },
      );
    });
  }

  test(
    'a system SQLite (python3 sqlite3 module) cannot read the file',
    () async {
      final py = await Process.run('which', ['python3']);
      if (py.exitCode != 0) {
        markTestSkipped('python3 not found');
        return;
      }
      final db = openEncryptedDatabase(dbFile, generateKey());
      await writeRows(db, n: 5);
      await db.close();
      final r = await Process.run('python3', [
        '-I',
        '-c',
        'import sqlite3,sys\n'
            'c=sqlite3.connect(sys.argv[1])\n'
            'print(sqlite3.sqlite_version)\n'
            'c.execute("select count(*) from sqlite_master").fetchall()',
        dbFile.path,
      ]);
      // ignore: avoid_print
      print(
        'python3 sqlite3: exit ${r.exitCode}; stdout ${r.stdout.trim()}; '
        '${(r.stderr as String).trim().split('\n').last}',
      );
      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('file is not a database'));
    },
  );

  group('cold start flow', () {
    test(
      'first run generates and stores a key, then returning run reads it',
      () async {
        final keys = MemoryKeyStore();
        final first = await coldStart(keys: keys, dbFile: dbFile);
        expect(first.state, StartState.firstRun);
        expect(first.peopleCount, 0);
        final key = await keys.readKey();
        expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
        await writeRows(first.db, n: 10);
        await first.db.close();

        final second = await coldStart(keys: keys, dbFile: dbFile);
        expect(second.state, StartState.returning);
        expect(second.peopleCount, 10);
        expect(await keys.readKey(), key);
        await second.db.close();
      },
    );

    test('simulated app update: a SEPARATE dart process reopens with the '
        'persisted key', () async {
      // Process 1 (this test): first run, key persisted to a file.
      final keyFile = File('${dir.path}/key.txt');
      final keys = PlainFileKeyStoreForTests(keyFile);
      final first = await coldStart(keys: keys, dbFile: dbFile);
      expect(first.state, StartState.firstRun);
      await writeRows(first.db, n: 25);
      await first.db.close();

      // Process 2: a new OS process with nothing in memory from process 1.
      final r = await Process.run('dart', [
        'run',
        'bin/cold_start_child.dart',
        '--db',
        dbFile.path,
        '--key-file',
        keyFile.path,
      ]);
      // ignore: avoid_print
      print('child stdout: ${(r.stdout as String).trim()}');
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(r.stdout, contains('state=returning'));
      expect(r.stdout, contains('people=25'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test(
      'restore without the key: file copied to a fresh key store is '
      'unreadable, app falls back to a clean database and resyncNeeded',
      () async {
        final phoneA = MemoryKeyStore();
        final a = await coldStart(keys: phoneA, dbFile: dbFile);
        await writeRows(a.db, n: 30);
        await a.db.close();

        // "Restore": the database file arrives on an install whose key store
        // is empty (Android Keystore keys are not part of a backup).
        final restoredDir = Directory('${dir.path}/restored')..createSync();
        final restored = File('${restoredDir.path}/lineage.db');
        dbFile.copySync(restored.path);
        final copiedBytes = restored.readAsBytesSync();
        expect(containsBytes(copiedBytes, utf8.encode(marker)), isFalse);

        final phoneB = MemoryKeyStore();
        final b = await coldStart(keys: phoneB, dbFile: restored);
        expect(b.state, StartState.resyncNeeded);
        expect(b.reason, ResyncReason.keyMissing);
        expect(b.peopleCount, 0);
        expect(await phoneB.readKey(), isNotNull);
        await b.db.close();

        // The restored bytes were removed, not kept next to the new database.
        expect(restored.readAsBytesSync(), isNot(copiedBytes));
      },
    );

    test('restore with a different key in the store: key rejected, clean '
        'database and resyncNeeded, no exception reaches the caller', () async {
      final phoneA = MemoryKeyStore();
      final a = await coldStart(keys: phoneA, dbFile: dbFile);
      await writeRows(a.db, n: 30);
      await a.db.close();

      final phoneB = MemoryKeyStore()..writeKey(generateKey());
      final b = await coldStart(keys: phoneB, dbFile: dbFile);
      expect(b.state, StartState.resyncNeeded);
      expect(b.reason, ResyncReason.keyRejected);
      expect(b.peopleCount, 0);
      await writeRows(b.db, n: 3);
      await b.db.close();

      final again = await coldStart(keys: phoneB, dbFile: dbFile);
      expect(again.state, StartState.returning);
      expect(again.peopleCount, 3);
      await again.db.close();
    });

    test(
      'key present but database gone: clean database and resyncNeeded',
      () async {
        final keys = MemoryKeyStore();
        final a = await coldStart(keys: keys, dbFile: dbFile);
        await a.db.close();
        await deleteDatabaseFiles(dbFile);
        final b = await coldStart(keys: keys, dbFile: dbFile);
        expect(b.state, StartState.resyncNeeded);
        expect(b.reason, ResyncReason.databaseMissing);
        await b.db.close();
      },
    );
  });
}
