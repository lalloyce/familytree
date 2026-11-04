/// Replay or run fuzz seeds from the command line.
///   dart run bin/fuzz.dart --seed 7 [--seed 8] [--ops 1000]
///       [--mode correct|overwriteOnConflict|dropBatchTail|rewriteOnMerge]
///       [--blocking]
import 'dart:io';

import 'package:claims_spike/fake_server.dart';
import 'package:claims_spike/fuzz.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;

Future<void> main(List<String> args) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final seeds = <int>[];
  var ops = 1000;
  var mode = ServerMode.correct;
  var blocking = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--seed':
        seeds.add(int.parse(args[++i]));
      case '--ops':
        ops = int.parse(args[++i]);
      case '--mode':
        mode = ServerMode.values.byName(args[++i]);
      case '--blocking':
        blocking = true;
    }
  }
  if (seeds.isEmpty) seeds.add(1);
  var ok = true;
  for (final s in seeds) {
    final r = await runFuzz(
      FuzzConfig(seed: s, ops: ops, mode: mode, blockingQueue: blocking),
    );
    print(r.summary());
    ok &= r.passed;
  }
  exit(ok ? 0 : 1);
}
