// Spike 5: one cold start in a fresh OS process.
//
// Reads the key from a plain file (PlainFileKeyStoreForTests: test and
// benchmark only), opens the encrypted database through coldStart(), runs the
// first query and prints one line:
//   state=<state> people=<n> key_read_us=<n> open_to_first_query_us=<n>
//   since_main_us=<n>
//
// Usage: dart run bin/cold_start_child.dart --db <path> --key-file <path>
//        [--form passphrase|raw|plain-control]
// plain-control opens an UNENCRYPTED file without a key, for comparison only.

import 'dart:io';

import 'package:crypto_spike/cold_start.dart';
import 'package:crypto_spike/database.dart';
import 'package:crypto_spike/key_store.dart';
import 'package:drift/native.dart';

Future<void> main(List<String> args) async {
  final sinceMain = Stopwatch()..start();
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final db = arg('--db');
  final keyFile = arg('--key-file');
  if (db == null || keyFile == null) {
    stderr.writeln('usage: --db <path> --key-file <path> [--form raw]');
    exit(64);
  }
  if (arg('--form') == 'plain-control') {
    // CONTROL: same Drift + background isolate path, no key, unencrypted file.
    final sw = Stopwatch()..start();
    final plain = SpikeDb(NativeDatabase.createInBackground(File(db)));
    final row = await plain
        .customSelect('SELECT count(*) AS c FROM people')
        .getSingle();
    final t = sw.elapsedMicroseconds;
    final since = sinceMain.elapsedMicroseconds;
    await plain.close();
    stdout.writeln(
      'state=plain people=${row.read<int>('c')} key_read_us=0 '
      'open_to_first_query_us=$t since_main_us=$since',
    );
    return;
  }
  final form = arg('--form') == 'raw' ? KeyForm.raw : KeyForm.passphrase;

  final r = await coldStart(
    keys: PlainFileKeyStoreForTests(File(keyFile)),
    dbFile: File(db),
    form: form,
  );
  final since = sinceMain.elapsedMicroseconds;
  await r.db.close();
  stdout.writeln(
    'state=${r.state.name} people=${r.peopleCount} '
    'key_read_us=${r.keyRead.inMicroseconds} '
    'open_to_first_query_us=${r.total.inMicroseconds} '
    'since_main_us=$since',
  );
}
