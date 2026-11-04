/// Spike 2 fuzz. Run: dart test (from spikes/claims).
///
/// SEEDS=1,2,3 overrides the seed list. A failing seed prints its replay
/// command: dart run bin/fuzz.dart --seed N ...
library;

import 'dart:io';

import 'package:claims_spike/fake_server.dart';
import 'package:claims_spike/fuzz.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:test/test.dart';

final seeds =
    Platform.environment['SEEDS']?.split(',').map(int.parse).toList() ??
    [for (var s = 1; s <= 20; s++) s];

/// Negative controls run on the first five seeds; each must fail the
/// assertion it targets on every one of them.
final controlSeeds = seeds.take(5).toList();

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Mode `correct` (the default, used by every group except the second) is
  // the Task 8 text rule. `supersedeOwnUnderContest` is the rule the
  // controller ruled Task 8 will use.
  for (final (name, mode) in [
    ('correct server (Task 8 text rule, baseline)', ServerMode.correct),
    (
      'ruled rule: supersedeOwnUnderContest',
      ServerMode.supersedeOwnUnderContest,
    ),
  ]) {
    group('$name, 1,000 operations per seed', () {
      for (final seed in seeds) {
        test('seed $seed', () async {
          final r = await runFuzz(FuzzConfig(seed: seed, mode: mode));
          print(r.summary());
          expect(
            r.passed,
            isTrue,
            reason: 'seed $seed failed. ${r.config.replay}',
          );
        });
      }
    });
  }

  group('negative controls (the fuzz must fail)', () {
    final controls = <(String, FuzzConfig Function(int), String)>[
      (
        'server overwrites on conflict',
        (s) => FuzzConfig(seed: s, mode: ServerMode.overwriteOnConflict),
        a2,
      ),
      (
        'server drops the tail of a batch silently',
        (s) => FuzzConfig(seed: s, mode: ServerMode.dropBatchTail),
        a1,
      ),
      (
        'server rewrites references on merge',
        (s) => FuzzConfig(seed: s, mode: ServerMode.rewriteOnMerge),
        a3,
      ),
      (
        'stale base supersedes the asserter\'s current claim',
        (s) => FuzzConfig(seed: s, mode: ServerMode.staleBaseSupersedesHead),
        a2,
      ),
      (
        'client queue blocks behind a failing row',
        (s) => FuzzConfig(seed: s, blockingQueue: true),
        a4,
      ),
    ];
    for (final (name, make, target) in controls) {
      for (final seed in controlSeeds) {
        test('$name, seed $seed, fails "$target"', () async {
          final r = await runFuzz(make(seed));
          print(r.summary());
          expect(
            r.failed(target),
            isTrue,
            reason: 'negative control passed: the fuzz has no teeth here',
          );
          if (target == a3) {
            // A3 must fail through non-cascade pairs, which the real server
            // never produces; cascade pairs alone would prove nothing.
            expect(
              r.stats['undoPairsNonCascade'] as int,
              greaterThan(0),
              reason: 'A3 control failed without non-cascade pairs',
            );
          }
        });
      }
    }
  });
}
