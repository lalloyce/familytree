import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/data/database.dart';

void main() {
  late AppDatabase db;
  late ClaimService alice;
  late ClaimService bob;
  late DateTime Function() clock;

  setUp(() {
    db = AppDatabase.memory();
    // One clock shared by both accounts that runs backwards by an hour per
    // call, so ordering by createdAt can never agree with arrival order.
    var t = DateTime.utc(2026, 11, 3, 12);
    clock = () => t = t.subtract(const Duration(hours: 1));
    alice = ClaimService(db, accountId: 'alice', now: clock);
    bob = ClaimService(db, accountId: 'bob', now: clock);
  });
  tearDown(() => db.close());

  Future<ClaimRow> belongs(
    ClaimService s,
    String house, {
    String? base,
    String person = 'person-1',
  }) {
    return s.assertClaim(
      kind: ClaimKind.belongsToHouse,
      subjectId: person,
      objectId: house,
      basis: Basis.bornTo,
      baseClaimId: base,
    );
  }

  Future<ClaimRow> row(String id) {
    return (db.select(db.claims)..where((c) => c.id.equals(id))).getSingle();
  }

  test('first claim is active and not competing', () async {
    final ClaimRow first = await belongs(alice, 'house-1');

    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views, hasLength(1));
    expect(views.single.claim.id, first.id);
    expect(views.single.claim.status, 'active');
    expect(views.single.claim.assertedBy, 'alice');
    expect(views.single.competing, isFalse);
  });

  test('same asserter replacing own claim with the current claim as base '
      'supersedes it', () async {
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow second = await belongs(alice, 'house-2', base: first.id);

    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views.map((v) => v.claim.id), [second.id]);
    expect(views.single.competing, isFalse);
    expect((await row(first.id)).status, 'superseded');
  });

  test('a different asserter replacing a claim never supersedes it', () async {
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow second = await belongs(bob, 'house-2', base: first.id);

    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views.map((v) => v.claim.id), [first.id, second.id]);
    expect(views.every((v) => v.competing), isTrue);
  });

  test('own claim is superseded even when another account\'s claim is '
      'active', () async {
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow bobs = await belongs(bob, 'house-2');
    final ClaimRow third = await belongs(alice, 'house-3', base: first.id);

    expect((await row(first.id)).status, 'superseded');
    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views.map((v) => v.claim.id), [bobs.id, third.id]);
    expect(views.every((v) => v.competing), isTrue);
  });

  test('a stale base becomes a competing claim', () async {
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow second = await belongs(bob, 'house-2');

    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views.map((v) => v.claim.id), [first.id, second.id]);
    expect(views.every((v) => v.competing), isTrue);
  });

  test('wifeOfHouse competes by house', () async {
    Future<ClaimRow> wife(ClaimService s, String woman, String house) {
      return s.assertClaim(
        kind: ClaimKind.wifeOfHouse,
        subjectId: woman,
        objectId: house,
      );
    }

    await wife(alice, 'woman-1', 'house-1');
    await wife(bob, 'woman-2', 'house-1');
    await wife(alice, 'woman-3', 'house-2');
    await wife(alice, 'woman-3', 'house-3');

    final views = await alice.activeClaims(ClaimKind.wifeOfHouse);
    final byWoman = <String, List<bool>>{};
    for (final v in views) {
      byWoman.putIfAbsent(v.claim.subjectId, () => []).add(v.competing);
    }
    // Two women claimed for house-1 compete.
    expect(byWoman['woman-1'], [true]);
    expect(byWoman['woman-2'], [true]);
    // One woman asserted for two houses does not compete.
    expect(byWoman['woman-3'], [false, false]);
  });

  test('two accounts asserting the same content agree and do not '
      'compete', () async {
    final ClaimRow a = await belongs(alice, 'house-1');
    final ClaimRow b = await belongs(bob, 'house-1');

    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views.map((v) => v.claim.id), [a.id, b.id]);
    expect(views.every((v) => !v.competing), isTrue);
  });

  test('ordering ignores the device clock', () async {
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow second = await belongs(bob, 'house-2');

    expect(second.createdAt.isBefore(first.createdAt), isTrue);
    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views.map((v) => v.claim.id), [first.id, second.id]);
    expect(views.every((v) => v.competing), isTrue);
  });

  test('supersession ignores the device clock', () async {
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow second = await belongs(alice, 'house-2', base: first.id);

    expect(second.createdAt.isBefore(first.createdAt), isTrue);
    final views = await alice.activeClaims(ClaimKind.belongsToHouse);
    expect(views.map((v) => v.claim.id), [second.id]);
    expect((await row(first.id)).status, 'superseded');
  });

  test('originNote claims with different text compete', () async {
    Future<ClaimRow> note(ClaimService s, String text, {String? subject}) {
      return s.assertClaim(
        kind: ClaimKind.originNote,
        subjectId: subject ?? 'person-1',
        body: text,
      );
    }

    await note(alice, 'came from the lake');
    await note(bob, 'came from the hills');
    await note(alice, 'same story', subject: 'person-2');
    await note(bob, 'same story', subject: 'person-2');

    final views = await alice.activeClaims(ClaimKind.originNote);
    final byPerson = <String, List<bool>>{};
    for (final v in views) {
      byPerson.putIfAbsent(v.claim.subjectId, () => []).add(v.competing);
    }
    expect(byPerson['person-1'], [true, true]);
    expect(byPerson['person-2'], [false, false]);
  });

  test('a superseded base or a base on another contest key is stale, not an '
      'error', () async {
    // Superseded base: alice replaces her claim, then cites the old one.
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow second = await belongs(alice, 'house-2', base: first.id);
    final ClaimRow third = await belongs(alice, 'house-3', base: first.id);

    expect((await row(first.id)).status, 'superseded');
    expect((await row(second.id)).status, 'active');
    expect((await row(third.id)).status, 'active');
    var views = await alice.activeClaims(
      ClaimKind.belongsToHouse,
      subjectId: 'person-1',
    );
    expect(views.map((v) => v.claim.id), [second.id, third.id]);
    expect(views.every((v) => v.competing), isTrue);

    // Base on another contest key: person-1's claim cited for person-2.
    final ClaimRow p2 = await belongs(alice, 'house-1', person: 'person-2');
    final ClaimRow p2again = await belongs(
      alice,
      'house-2',
      person: 'person-2',
      base: second.id,
    );

    expect((await row(second.id)).status, 'active');
    expect((await row(p2.id)).status, 'active');
    expect((await row(p2again.id)).status, 'active');
    views = await alice.activeClaims(
      ClaimKind.belongsToHouse,
      subjectId: 'person-2',
    );
    expect(views.map((v) => v.claim.id), [p2.id, p2again.id]);
    expect(views.every((v) => v.competing), isTrue);
  });

  test('a wife replaced by the same account in another house supersedes '
      'her first claim', () async {
    Future<ClaimRow> wife(String house, {String? base}) {
      return alice.assertClaim(
        kind: ClaimKind.wifeOfHouse,
        subjectId: 'woman-1',
        objectId: house,
        baseClaimId: base,
      );
    }

    // The contest key of a wife claim is the house, so the two claims are on
    // different keys. The same subject and the same account still replace.
    final ClaimRow first = await wife('house-1');
    final ClaimRow second = await wife('house-2', base: first.id);

    expect((await row(first.id)).status, 'superseded');
    expect((await row(second.id)).status, 'active');
    final views = await alice.activeClaims(ClaimKind.wifeOfHouse);
    expect(views.map((v) => v.claim.id), [second.id]);
    expect(views.single.competing, isFalse);
  });

  test('a base of another account, another subject and another key stays '
      'stale', () async {
    Future<ClaimRow> wife(
      ClaimService s,
      String woman,
      String house, {
      String? base,
    }) {
      return s.assertClaim(
        kind: ClaimKind.wifeOfHouse,
        subjectId: woman,
        objectId: house,
        baseClaimId: base,
      );
    }

    // Another account's claim is never replaced, even for the same woman.
    final ClaimRow bobs = await wife(bob, 'woman-1', 'house-1');
    final ClaimRow alices = await wife(
      alice,
      'woman-1',
      'house-2',
      base: bobs.id,
    );
    expect((await row(bobs.id)).status, 'active');
    expect((await row(alices.id)).status, 'active');

    // Own claim, but a different woman and a different house: stale.
    final ClaimRow other = await wife(alice, 'woman-2', 'house-3');
    final ClaimRow third = await wife(
      alice,
      'woman-3',
      'house-4',
      base: other.id,
    );
    expect((await row(other.id)).status, 'active');
    expect((await row(third.id)).status, 'active');
  });

  test('wifeOfHouse without a house throws ArgumentError and inserts '
      'nothing', () async {
    await expectLater(
      alice.assertClaim(kind: ClaimKind.wifeOfHouse, subjectId: 'woman-1'),
      throwsArgumentError,
    );
    expect(await db.select(db.claims).get(), isEmpty);
  });

  test('a wifeOfHouse row without a house does not break reading', () async {
    await alice.assertClaim(
      kind: ClaimKind.wifeOfHouse,
      subjectId: 'woman-1',
      objectId: 'house-1',
    );
    await bob.assertClaim(
      kind: ClaimKind.wifeOfHouse,
      subjectId: 'woman-2',
      objectId: 'house-1',
    );
    // Could arrive from sync; the write path would refuse it.
    await db
        .into(db.claims)
        .insert(
          ClaimsCompanion.insert(
            id: 'orphan-1',
            kind: ClaimKind.wifeOfHouse,
            subjectId: 'woman-3',
            assertedBy: 'carol',
            createdAt: DateTime.utc(2026, 11, 3),
          ),
        );

    final views = await alice.activeClaims(ClaimKind.wifeOfHouse);
    expect(views, hasLength(3));
    expect(
      {for (final v in views) v.claim.subjectId: v.competing},
      {'woman-1': true, 'woman-2': true, 'woman-3': false},
    );
  });

  test('no claim row is ever updated except status', () async {
    final ClaimRow first = await belongs(alice, 'house-1');
    final ClaimRow before = await row(first.id);

    await belongs(bob, 'house-2');
    await belongs(alice, 'house-3', base: first.id);
    await belongs(alice, 'house-4');
    await belongs(bob, 'house-5');

    final ClaimRow after = await row(first.id);
    expect(after.status, 'superseded');
    expect(
      after.copyWith(status: before.status),
      before,
      reason: 'every column but status must be unchanged',
    );
    expect(await db.select(db.claims).get(), hasLength(5));
  });
}
