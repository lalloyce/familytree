import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/tree/ancestors.dart';

void main() {
  late AppDatabase db;
  late HouseholdBuilder alice;
  late HouseholdBuilder bob;

  setUp(() {
    db = AppDatabase.memory();
    // One clock shared by both accounts that runs backwards by an hour per
    // call, so ordering by createdAt can never agree with arrival order.
    var t = DateTime.utc(2026, 11, 3, 12);
    DateTime clock() => t = t.subtract(const Duration(hours: 1));
    alice = HouseholdBuilder(
      db,
      ClaimService(db, accountId: 'alice', now: clock),
      accountId: 'alice',
    );
    bob = HouseholdBuilder(
      db,
      ClaimService(db, accountId: 'bob', now: clock),
      accountId: 'bob',
    );
  });
  tearDown(() => db.close());

  /// Makes [personId] a child of a new house whose husband is [husbandId].
  Future<String> placeUnder(
    HouseholdBuilder who,
    String personId,
    String husbandId, {
    Basis basis = Basis.bornTo,
  }) async {
    final String houseId = await who.addHouse(husbandId: husbandId);
    await who.placeChild(personId: personId, houseId: houseId, basis: basis);
    return houseId;
  }

  List<(String, String, int, bool)> shape(List<AncestorStep> steps) => [
    for (final s in steps) (s.personId, s.houseId, s.depth, s.disputed),
  ];

  test('follows the father line through placeholders', () async {
    final String child = await alice.addPerson(name: 'Achieng');
    final String father = await alice.addPerson(name: 'Otieno');
    final String top = await alice.addPlaceholder(sex: Sex.male);
    final String houseOfFather = await placeUnder(alice, child, father);
    final String houseOfTop = await placeUnder(alice, father, top);

    final steps = await ancestorsOf(db, child);

    expect(shape(steps), [
      (father, houseOfFather, 1, false),
      (top, houseOfTop, 2, false),
    ]);
  });

  test('stops with disputed true when a person has two competing '
      'belongsToHouse claims', () async {
    final String child = await alice.addPerson();
    final String father = await alice.addPerson();
    final String uncle = await alice.addPerson();
    final String grandfather = await alice.addPerson();
    final String houseOfFather = await placeUnder(alice, child, father);
    // Two accounts disagree about whose house the father belongs to.
    await placeUnder(alice, father, grandfather);
    await placeUnder(bob, father, uncle);

    final steps = await ancestorsOf(db, child);

    expect(shape(steps), [(father, houseOfFather, 1, true)]);
  });

  test('terminates on a cycle', () async {
    final String p = await alice.addPerson(name: 'P');
    final String f1 = await alice.addPerson(name: 'F1');
    final String f2 = await alice.addPerson(name: 'F2');
    final String h1 = await placeUnder(alice, p, f1);
    final String h2 = await placeUnder(alice, f1, f2);
    final String h3 = await placeUnder(alice, f2, p);

    final steps = await ancestorsOf(db, p);

    expect(shape(steps), [
      (f1, h1, 1, false),
      (f2, h2, 2, false),
      (p, h3, 3, true),
    ]);
  }, timeout: const Timeout(Duration(seconds: 2)));

  test("a woman who is wife of two houses does not appear in anyone's "
      'ancestors', () async {
    final String wife = await alice.addPerson(name: 'Wanjiru');
    final String wifeFather = await alice.addPerson(name: 'Kamau');
    final String a = await alice.addPerson(name: 'A');
    final String b = await alice.addPerson(name: 'B');
    final String childA = await alice.addPerson(name: 'ChildA');
    final String childB = await alice.addPerson(name: 'ChildB');
    final String houseOfWife = await placeUnder(alice, wife, wifeFather);
    final String houseA = await placeUnder(alice, childA, a);
    final String houseB = await placeUnder(alice, childB, b);
    await alice.addWife(wifeId: wife, houseId: houseA);
    await alice.addWife(wifeId: wife, houseId: houseB);

    final List<AncestorStep> ofA = await ancestorsOf(db, childA);
    final List<AncestorStep> ofB = await ancestorsOf(db, childB);
    final List<AncestorStep> ofWife = await ancestorsOf(db, wife);

    expect(shape(ofA), [(a, houseA, 1, false)]);
    expect(shape(ofB), [(b, houseB, 1, false)]);
    expect(ofA.followedBy(ofB).map((s) => s.personId), isNot(contains(wife)));
    // Her own line is her father's; the houses she married into never appear.
    expect(shape(ofWife), [(wifeFather, houseOfWife, 1, false)]);
  });

  test('joined basis is followed like bornTo', () async {
    final String child = await alice.addPerson();
    final String father = await alice.addPerson();
    final String houseId = await placeUnder(
      alice,
      child,
      father,
      basis: Basis.joined,
    );

    final steps = await ancestorsOf(db, child);

    expect(shape(steps), [(father, houseId, 1, false)]);
  });

  test(
    'returns an empty list for a person with no belongsToHouse claim',
    () async {
      final String loner = await alice.addPerson();

      expect(await ancestorsOf(db, loner), isEmpty);
      expect(await ancestorsOf(db, 'no-such-person'), isEmpty);
    },
  );

  test('a disputed starting person returns a single disputed step', () async {
    final String child = await alice.addPerson();
    final String fatherA = await alice.addPerson();
    final String fatherB = await alice.addPerson();
    await placeUnder(alice, child, fatherA);
    await placeUnder(bob, child, fatherB);

    final steps = await ancestorsOf(db, child);

    expect(shape(steps), [(child, '', 0, true)]);
  });

  test(
    'agreeing claims from two accounts are followed, not disputed',
    () async {
      final String child = await alice.addPerson();
      final String father = await alice.addPerson();
      final String grandfather = await alice.addPerson();
      final String houseOfFather = await alice.addHouse(husbandId: father);
      for (final who in [alice, bob]) {
        await who.placeChild(
          personId: child,
          houseId: houseOfFather,
          basis: Basis.bornTo,
        );
      }
      final String houseOfGrandfather = await placeUnder(
        alice,
        father,
        grandfather,
      );

      final steps = await ancestorsOf(db, child);

      expect(shape(steps), [
        (father, houseOfFather, 1, false),
        (grandfather, houseOfGrandfather, 2, false),
      ]);
    },
  );

  test('stops at maxDepth without flagging', () async {
    final String child = await alice.addPerson();
    final String father = await alice.addPerson();
    final String grandfather = await alice.addPerson();
    final String greatGrandfather = await alice.addPerson();
    final String houseOfFather = await placeUnder(alice, child, father);
    final String houseOfGrandfather = await placeUnder(
      alice,
      father,
      grandfather,
    );
    await placeUnder(alice, grandfather, greatGrandfather);

    final steps = await ancestorsOf(db, child, maxDepth: 2);

    expect(shape(steps), [
      (father, houseOfFather, 1, false),
      (grandfather, houseOfGrandfather, 2, false),
    ]);
  });

  test('basis-only disagreement between accounts stops the chain as '
      'disputed', () async {
    final String child = await alice.addPerson();
    final String father = await alice.addPerson();
    final String houseId = await alice.addHouse(husbandId: father);
    // This is the Task 8 contest rule (basis is part of a claim's content).
    // It is an open question for the founder, pinned so any change is
    // deliberate.
    await alice.placeChild(
      personId: child,
      houseId: houseId,
      basis: Basis.joined,
    );
    await bob.placeChild(
      personId: child,
      houseId: houseId,
      basis: Basis.bornTo,
    );

    final steps = await ancestorsOf(db, child);

    expect(shape(steps), [(child, '', 0, true)]);
  });

  test('a person who is the husband of the house they belong to is flagged '
      'disputed at depth 1', () async {
    final String p = await alice.addPerson();
    final String houseId = await placeUnder(alice, p, p);

    final steps = await ancestorsOf(db, p);

    expect(shape(steps), [(p, houseId, 1, true)]);
  });

  test('a claim pointing at a house that does not exist ends the walk with '
      'no step', () async {
    final String child = await alice.addPerson();
    await alice.placeChild(
      personId: child,
      houseId: 'no-such-house',
      basis: Basis.bornTo,
    );

    expect(await ancestorsOf(db, child), isEmpty);
  });
}
