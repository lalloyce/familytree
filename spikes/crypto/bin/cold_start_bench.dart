// Spike 5 host-proxy cold-start benchmark. NOT a weak-phone result.
//
// Builds a database of 3,000 people per key form, then launches the compiled
// child (bin/cold_start_child.dart, built with `dart build cli`) once per run
// as a fresh OS process. Each child opens the database through coldStart()
// and runs the first query.
//
// Reported per run:
//   inner = from the start of coldStart() (key read, open, key derivation,
//           first query) to the first query result, measured in the child.
//   main  = from the child's main() to the first query result.
//   outer = from the parent's Process.run call to the child's exit.
//
// Usage:
//   dart build cli -t bin/cold_start_child.dart
//   dart run bin/cold_start_bench.dart \
//       --exe build/cli/macos_arm64/bundle/bin/cold_start_child --runs 40

import 'dart:io';

import 'package:crypto_spike/cold_start.dart';
import 'package:crypto_spike/database.dart';
import 'package:crypto_spike/key_store.dart';
import 'package:drift/drift.dart' show Value;

const people = 3000;

Future<void> fill(SpikeDb db) async {
  await db.batch((b) {
    for (var i = 0; i < people; i++) {
      b.insert(
        db.people,
        PeopleCompanion.insert(
          id: 'person-$i',
          name: 'Person $i, child of house ${i ~/ 5}',
          note: Value('note for $i' * 3),
        ),
      );
    }
  });
}

int pct(List<int> sorted, double p) {
  // Nearest-rank percentile.
  final rank = (p / 100 * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

String ms(int us) => (us / 1000).toStringAsFixed(1);

String summary(List<int> values) {
  final s = [...values]..sort();
  return 'min ${ms(s.first)} / median ${ms(pct(s, 50))} / '
      'p95 ${ms(pct(s, 95))} / max ${ms(s.last)} ms';
}

Future<void> main(List<String> args) async {
  String? arg(String n) {
    final i = args.indexOf(n);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final exe = arg('--exe');
  final runs = int.parse(arg('--runs') ?? '40');
  if (exe == null || !File(exe).existsSync()) {
    stderr.writeln(
      'build the child first: dart build cli -t '
      'bin/cold_start_child.dart; then pass --exe <path>',
    );
    exit(64);
  }

  final dir = Directory.systemTemp.createTempSync('crypto_bench_');
  stdout.writeln('HOST PROXY, NOT A WEAK-PHONE RESULT');
  stdout.writeln('runs per form: $runs; people in database: $people');

  for (final formName in ['passphrase', 'raw', 'plain-control']) {
    final dbFile = File('${dir.path}/$formName.db');
    final keyFile = File('${dir.path}/$formName.key');

    if (formName == 'plain-control') {
      final db = openPlaintextDatabaseForControl(dbFile);
      await fill(db);
      await db.close();
    } else {
      final form = formName == 'raw' ? KeyForm.raw : KeyForm.passphrase;
      final r = await coldStart(
        keys: PlainFileKeyStoreForTests(keyFile),
        dbFile: dbFile,
        form: form,
      );
      if (r.state != StartState.firstRun) {
        throw StateError('expected firstRun, got ${r.state}');
      }
      await fill(r.db!);
      await r.db!.close();
    }

    final inner = <int>[], sinceMain = <int>[], outer = <int>[];
    for (var i = 0; i < runs; i++) {
      final sw = Stopwatch()..start();
      final res = await Process.run(exe, [
        '--db',
        dbFile.path,
        '--key-file',
        keyFile.path,
        '--form',
        formName,
      ]);
      sw.stop();
      final out = (res.stdout as String).trim();
      final expectedState = formName == 'plain-control' ? 'plain' : 'returning';
      if (res.exitCode != 0 ||
          !out.contains('state=$expectedState') ||
          !out.contains('people=$people')) {
        throw StateError('run $i failed: $out ${res.stderr}');
      }
      int field(String name) =>
          int.parse(RegExp('$name=(\\d+)').firstMatch(out)!.group(1)!);
      inner.add(field('open_to_first_query_us'));
      sinceMain.add(field('since_main_us'));
      outer.add(sw.elapsedMicroseconds);
    }
    stdout.writeln('');
    stdout.writeln('[$formName] file ${dbFile.lengthSync()} bytes');
    stdout.writeln(
      '  first run inner ${ms(inner.first)} ms, '
      'outer ${ms(outer.first)} ms',
    );
    stdout.writeln('  inner (coldStart -> first result): ${summary(inner)}');
    stdout.writeln(
      '  main  (main() -> first result):    ${summary(sinceMain)}',
    );
    stdout.writeln('  outer (spawn -> exit):             ${summary(outer)}');
  }
  dir.deleteSync(recursive: true);
}
