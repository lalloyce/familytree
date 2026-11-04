import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';

void main() {
  late AppDatabase db;
  late ClaimService claims;
  late HouseholdBuilder builder;
  late DateTime Function() clock;

  setUp(() {
    db = AppDatabase.memory();
    // Runs backwards by an hour per call, so ordering by createdAt can never
    // agree with arrival order.
    var t = DateTime.utc(2026, 11, 3, 12);
    clock = () => t = t.subtract(const Duration(hours: 1));
    claims = ClaimService(db, accountId: 'alice', now: clock);
    builder = HouseholdBuilder(db, claims, accountId: 'alice');
  });
  tearDown(() => db.close());

  Future<PersonRow> person(String id) {
    return (db.select(db.persons)..where((p) => p.id.equals(id))).getSingle();
  }

  Future<HouseRow> house(String id) {
    return (db.select(db.houses)..where((h) => h.id.equals(id))).getSingle();
  }

  Future<int> countClaims() async => (await db.select(db.claims).get()).length;

  Future<int> countPersons() async =>
      (await db.select(db.persons).get()).length;

  Future<int> countHouses() async => (await db.select(db.houses).get()).length;

  Future<List<ClaimView>> belongs(String personId) {
    return claims.activeClaims(ClaimKind.belongsToHouse, subjectId: personId);
  }

  test('addPerson with no name creates an unnamed person that is not a '
      'placeholder', () async {
    final String id = await builder.addPerson();

    final PersonRow p = await person(id);
    expect(p.nameKey, isNull);
    expect(p.isPlaceholder, isFalse);
    expect(p.sex, isNull);
    expect(p.createdBy, 'alice');
  });

  test('ensureFatherHouse for a person with no parents creates a fresh '
      'placeholder husband and a fresh house and places the person in '
      'it', () async {
    final String child = await builder.addPerson(name: 'Zuri');

    final String houseId = await builder.ensureFatherHouse(child);

    final HouseRow h = await house(houseId);
    expect(h.ordinal, isNull);
    expect(h.createdBy, 'alice');
    final PersonRow husband = await person(h.husbandId);
    expect(husband.isPlaceholder, isTrue);
    expect(husband.nameKey, isNull);
    expect(husband.sex, Sex.male);
    final views = await belongs(child);
    expect(views, hasLength(1));
    expect(views.single.claim.objectId, houseId);
    expect(views.single.claim.basis, Basis.bornTo);
    expect(views.single.claim.assertedBy, 'alice');
  });

  test('two orphans get different houses and different husbands', () async {
    final String a = await builder.addPerson(name: 'Zuri');
    final String b = await builder.addPerson(name: 'Otieno');

    final String houseA = await builder.ensureFatherHouse(a);
    final String houseB = await builder.ensureFatherHouse(b);

    expect(houseA, isNot(houseB));
    expect(
      (await house(houseA)).husbandId,
      isNot((await house(houseB)).husbandId),
    );
    expect((await belongs(a)).single.claim.objectId, houseA);
    expect((await belongs(b)).single.claim.objectId, houseB);
    // No house holds both, so they are not siblings.
    final inA = await claims.activeClaims(
      ClaimKind.belongsToHouse,
      objectId: houseA,
    );
    expect(inA.map((v) => v.claim.subjectId), [a]);
  });

  test('ensureFatherHouse is idempotent', () async {
    final String child = await builder.addPerson(name: 'Zuri');
    final String first = await builder.ensureFatherHouse(child);
    final int persons = await countPersons();
    final int houses = await countHouses();
    final int claimRows = await countClaims();

    final String second = await builder.ensureFatherHouse(child);

    expect(second, first);
    expect(await countPersons(), persons);
    expect(await countHouses(), houses);
    expect(await countClaims(), claimRows);
  });

  test('addWife creates a wifeOfHouse claim and a woman can be wife of two '
      'houses', () async {
    final String husband1 = await builder.addPerson(
      name: 'Ouma',
      sex: Sex.male,
    );
    final String husband2 = await builder.addPerson(
      name: 'Odhiambo',
      sex: Sex.male,
    );
    final String house1 = await builder.addHouse(
      husbandId: husband1,
      ordinal: 1,
    );
    final String house2 = await builder.addHouse(husbandId: husband2);
    final String wife = await builder.addPerson(
      name: 'Zawadi',
      sex: Sex.female,
    );

    await builder.addWife(wifeId: wife, houseId: house1);
    await builder.addWife(wifeId: wife, houseId: house2);

    final views = await claims.activeClaims(
      ClaimKind.wifeOfHouse,
      subjectId: wife,
    );
    expect(views.map((v) => v.claim.objectId), [house1, house2]);
    expect(views.every((v) => v.claim.basis == null), isTrue);
    expect(views.every((v) => v.claim.assertedBy == 'alice'), isTrue);
    expect((await house(house1)).ordinal, 1);
    expect((await house(house2)).ordinal, isNull);
  });

  test('two persons named Rafa get different ids and both are kept', () async {
    final String a = await builder.addPerson(name: 'Rafa');
    final String b = await builder.addPerson(name: 'Rafa');

    expect(a, isNot(b));
    final rows = await db.select(db.persons).get();
    expect(rows.map((p) => p.id), unorderedEquals([a, b]));
    expect(rows.every((p) => p.nameKey == 'Rafa'), isTrue);
  });

  test(
    'placeChild by the same account replaces its own earlier placement',
    () async {
      final String husband = await builder.addPerson(sex: Sex.male);
      final String house1 = await builder.addHouse(husbandId: husband);
      final String house2 = await builder.addHouse(
        husbandId: husband,
        ordinal: 2,
      );
      final String child = await builder.addPerson(name: 'Zuri');

      await builder.placeChild(
        personId: child,
        houseId: house1,
        basis: Basis.bornTo,
      );
      await builder.placeChild(
        personId: child,
        houseId: house2,
        basis: Basis.joined,
      );

      final views = await belongs(child);
      expect(views, hasLength(1));
      expect(views.single.claim.objectId, house2);
      expect(views.single.claim.basis, Basis.joined);
      expect(views.single.competing, isFalse);

      final int rows = await countClaims();
      await builder.placeChild(
        personId: child,
        houseId: house2,
        basis: Basis.joined,
      );
      expect(await countClaims(), rows);
    },
  );

  test('two concurrent ensureFatherHouse calls for one person make one '
      'house', () async {
    final String child = await builder.addPerson(name: 'Zuri');

    final ids = await Future.wait([
      builder.ensureFatherHouse(child),
      builder.ensureFatherHouse(child),
    ]);

    expect(ids[0], ids[1]);
    expect(await countHouses(), 1);
    final placeholders = (await db.select(db.persons).get()).where(
      (p) => p.isPlaceholder,
    );
    expect(placeholders, hasLength(1));
    final views = await belongs(child);
    expect(views, hasLength(1));
    expect(views.single.claim.objectId, ids[0]);
    expect(views.single.competing, isFalse);
  });

  test('two concurrent identical placeChild calls leave one active '
      'claim', () async {
    final String husband = await builder.addPerson(sex: Sex.male);
    final String h = await builder.addHouse(husbandId: husband);
    final String child = await builder.addPerson(name: 'Zuri');

    await Future.wait([
      builder.placeChild(personId: child, houseId: h, basis: Basis.bornTo),
      builder.placeChild(personId: child, houseId: h, basis: Basis.bornTo),
    ]);

    final views = await belongs(child);
    expect(views, hasLength(1));
    expect(views.single.claim.assertedBy, 'alice');
    expect(views.single.competing, isFalse);
  });

  test('ensureFatherHouse returns the earliest arrival across accounts, '
      'not the earliest createdAt', () async {
    final bob = ClaimService(db, accountId: 'bob', now: clock);
    final String husband = await builder.addPerson(sex: Sex.male);
    final String bobsHouse = await builder.addHouse(husbandId: husband);
    final String alicesHouse = await builder.addHouse(husbandId: husband);
    final String child = await builder.addPerson(name: 'Zuri');
    // Bob's claim arrives first; the clock runs backwards, so Alice's
    // claim carries the earlier createdAt.
    await bob.assertClaim(
      kind: ClaimKind.belongsToHouse,
      subjectId: child,
      objectId: bobsHouse,
      basis: Basis.bornTo,
    );
    await builder.placeChild(
      personId: child,
      houseId: alicesHouse,
      basis: Basis.bornTo,
    );
    final int persons = await countPersons();
    final int houses = await countHouses();
    final int claimRows = await countClaims();

    final String result = await builder.ensureFatherHouse(child);

    expect(result, bobsHouse);
    expect(await countPersons(), persons);
    expect(await countHouses(), houses);
    expect(await countClaims(), claimRows);
  });
}
