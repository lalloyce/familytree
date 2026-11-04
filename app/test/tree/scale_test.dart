@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/tree/ancestors.dart';
import 'package:related/tree/spoken_chain.dart';

import '../fixtures/synthetic_tree.dart';

/// Scale check for design section 10, spike 4, against the real readers.
///
/// Every duration printed here is a host proxy: `flutter test` on this Mac,
/// in-memory SQLite. None of it is a result for the weakest phone, and none
/// of it is compared with a phone threshold. The 100 ms bound in the first
/// test is the plan's own number, not the design's.
void main() {
  const persons = 3000;

  /// The default `maxDepth` of [ancestorsOf].
  const depthCap = 60;

  late AppDatabase db;
  late SyntheticTree tree;
  late Duration buildTime;

  setUpAll(() async {
    db = AppDatabase.memory();
    final sw = Stopwatch()..start();
    tree = await buildSyntheticTree(db, persons: persons);
    buildTime = sw.elapsed;
  });
  tearDownAll(() => db.close());

  /// The two middle values averaged for an even count.
  double median(List<double> sorted) {
    final int n = sorted.length;
    return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }

  /// Nearest rank on the sorted values, as spike 4 does.
  double p95(List<double> sorted) {
    final int rank = (0.95 * sorted.length).ceil();
    return sorted[rank - 1];
  }

  test(
    'spokenChain for the deepest of 3000 people returns in under 100 ms',
    () async {
      final List<ChainLine> chain = await spokenChain(db, tree.deepestPersonId);
      expect(chain.length, greaterThan(5));

      for (int i = 0; i < 3; i++) {
        await spokenChain(db, tree.deepestPersonId);
      }
      final timesMs = <double>[];
      for (int i = 0; i < 20; i++) {
        final sw = Stopwatch()..start();
        await spokenChain(db, tree.deepestPersonId);
        timesMs.add(sw.elapsedMicroseconds / 1000);
      }
      timesMs.sort();
      final double med = median(timesMs);
      // ignore: avoid_print
      print(
        'host proxy, in-memory SQLite: spokenChain, ${chain.length} lines, '
        '20 timed calls after 3 warmups: median ${med.toStringAsFixed(2)} ms, '
        'p95 ${p95(timesMs).toStringAsFixed(2)} ms, '
        'max ${timesMs.last.toStringAsFixed(2)} ms',
      );
      expect(med, lessThan(100));
    },
  );

  test(
    'ancestorsOf terminates for every person within the depth cap',
    () async {
      // Every person, not a stride: 3,000 calls took about 17 s on this host
      // (host proxy, in-memory SQLite), a little over the 15 s planning
      // figure, and the whole file about 27 s.
      final sw = Stopwatch()..start();
      int calls = 0;
      int longest = 0;
      for (final String id in tree.personIds) {
        final List<AncestorStep> steps = await ancestorsOf(db, id);
        calls++;
        if (steps.length > longest) {
          longest = steps.length;
        }
        expect(steps.length, lessThanOrEqualTo(depthCap));
        // On the clean tree nothing is disputed or cyclic, and the chain has
        // one step per ancestor: the generator's depth (the length of the
        // father line, 0 for a root) is the same count, with no offset.
        expect(steps.length, tree.depths[id], reason: id);
        expect(steps.any((s) => s.disputed), isFalse, reason: id);
      }
      // ignore: avoid_print
      print(
        'host proxy, in-memory SQLite: ancestorsOf for $calls people took '
        '${sw.elapsedMilliseconds} ms, longest chain $longest steps',
      );

      // The same tree, with one cycle and one disputed person added as extra
      // claims that are rolled back at the end, so the shared tree is
      // untouched.
      final int claimsBefore = (await db.select(db.claims).get()).length;
      try {
        await db.transaction(() async {
          // Cycle: the top of the deepest person's father line is placed in a
          // house of the deepest person, so the line loops back to its start.
          final String deepest = tree.deepestPersonId;
          final List<AncestorStep> line = await ancestorsOf(db, deepest);
          final String top = line.last.personId;
          final builder = HouseholdBuilder(
            db,
            ClaimService(db, accountId: 'cycle'),
            accountId: 'cycle',
          );
          final String loopHouse = await builder.addHouse(husbandId: deepest);
          await builder.placeChild(
            personId: top,
            houseId: loopHouse,
            basis: Basis.bornTo,
          );

          final List<AncestorStep> looped = await ancestorsOf(db, deepest);
          expect(looped.length, lessThanOrEqualTo(depthCap));
          expect(looped.last.personId, deepest);
          expect(looped.last.disputed, isTrue);
          final List<ChainLine> loopedChain = await spokenChain(db, deepest);
          expect(loopedChain.last.disputed, isTrue);
          expect(loopedChain.last.text, endsWith('accounts differ'));

          // Disputed: another account places the father of the deepest person
          // in a different house, so that man's parentage is contested.
          final String contested = line.first.personId;
          final String otherHouse = tree.houseIds.firstWhere(
            (h) => h != line[1].houseId,
          );
          final other = HouseholdBuilder(
            db,
            ClaimService(db, accountId: 'other'),
            accountId: 'other',
          );
          await other.placeChild(
            personId: contested,
            houseId: otherHouse,
            basis: Basis.bornTo,
          );
          final List<AncestorStep> own = await ancestorsOf(db, contested);
          expect(own.length, lessThanOrEqualTo(depthCap));
          expect(own.single.disputed, isTrue);
          final List<ChainLine> ownChain = await spokenChain(db, contested);
          expect(ownChain.single.disputed, isTrue);
          // The chain of a descendant stops at the contested man.
          final List<AncestorStep> below = await ancestorsOf(db, deepest);
          expect(below.last.personId, contested);
          expect(below.last.disputed, isTrue);

          throw _RollBack();
        });
      } on _RollBack {
        // Expected: the transaction is discarded.
      }
      expect((await db.select(db.claims).get()).length, claimsBefore);
    },
  );

  test('building 3000 people with 1 to 4 wives per husband and 20 women in '
      'two houses completes', () async {
    // ignore: avoid_print
    print(
      'host proxy, in-memory SQLite: building $persons people took '
      '${buildTime.inMilliseconds} ms',
    );

    final people = await db.select(db.persons).get();
    expect(people.length, persons);
    expect(tree.personIds.length, persons);
    expect({for (final p in people) p.id}, tree.personIds.toSet());

    // Every husband has 1 to 4 houses.
    final houses = await db.select(db.houses).get();
    final housesOfHusband = <String, int>{};
    for (final h in houses) {
      housesOfHusband[h.husbandId] = (housesOfHusband[h.husbandId] ?? 0) + 1;
    }
    expect(housesOfHusband, isNotEmpty);
    expect(housesOfHusband.values.every((n) => n >= 1 && n <= 4), isTrue);
    expect(
      housesOfHusband.values.any((n) => n == 4),
      isTrue,
      reason: 'the tree should exercise the upper bound',
    );
    String husbandOf(String houseId) =>
        houses.firstWhere((h) => h.id == houseId).husbandId;

    final wifeClaims = await ClaimService(
      db,
      accountId: 'reader',
    ).activeClaims(ClaimKind.wifeOfHouse);
    final belongsClaims = await ClaimService(
      db,
      accountId: 'reader',
    ).activeClaims(ClaimKind.belongsToHouse);
    // The focus house is a real house with at least one child.
    expect(houses.any((h) => h.id == tree.focusHouseId), isTrue);
    expect(
      belongsClaims.where((v) => v.claim.objectId == tree.focusHouseId),
      isNotEmpty,
    );

    List<String> wifeHouses(String woman) => [
      for (final v in wifeClaims)
        if (v.claim.subjectId == woman) v.claim.objectId!,
    ];
    List<String> birthHouses(String woman) => [
      for (final v in belongsClaims)
        if (v.claim.subjectId == woman) v.claim.objectId!,
    ];

    // Reading 1: ten women are the wife of two houses of two different
    // husbands, who are brothers (the same father).
    expect(tree.twiceWifeIds.length, 10);
    for (final String woman in tree.twiceWifeIds) {
      final List<String> mine = wifeHouses(woman);
      expect(mine.length, 2, reason: woman);
      final String a = husbandOf(mine[0]);
      final String b = husbandOf(mine[1]);
      expect(a, isNot(b));
      final List<String> fatherOfA = birthHouses(a);
      final List<String> fatherOfB = birthHouses(b);
      expect(fatherOfA.length, 1);
      expect(fatherOfB.length, 1);
      expect(husbandOf(fatherOfA.single), husbandOf(fatherOfB.single));
    }

    // Reading 2: ten other women are a daughter in one house and the wife of
    // another.
    expect(tree.daughterAndWifeIds.length, 10);
    for (final String woman in tree.daughterAndWifeIds) {
      final List<String> born = birthHouses(woman);
      final List<String> married = wifeHouses(woman);
      expect(born.length, 1, reason: woman);
      expect(married.length, 1, reason: woman);
      expect(born.single, isNot(married.single));
    }
    expect({...tree.twiceWifeIds, ...tree.daughterAndWifeIds}.length, 20);
  });
}

/// Thrown to roll back the transaction that seeds the cycle and the dispute.
class _RollBack implements Exception {}
