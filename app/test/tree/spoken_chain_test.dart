import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/tree/spoken_chain.dart';

import '../fixtures/rafa_family.dart';

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
    int? ordinal,
  }) async {
    final String houseId = await who.addHouse(
      husbandId: husbandId,
      ordinal: ordinal,
    );
    await who.placeChild(personId: personId, houseId: houseId, basis: basis);
    return houseId;
  }

  List<(String, String, bool, bool)> shape(List<ChainLine> lines) => [
    for (final l in lines) (l.personId, l.text, l.disputed, l.placeholder),
  ];

  test('Kito line is "Kito, son of Rafa, house 2"', () async {
    final RafaFamily f = await buildRafaFamily(db);

    final lines = await spokenChain(db, f.kito);

    expect(lines.first.personId, f.kito);
    expect(lines.first.text, 'Kito, son of Rafa, house 2');
    expect(lines.first.disputed, isFalse);
    expect(lines.first.placeholder, isFalse);
  });

  test('the chain for me reads me, son of Tembo; Tembo, son of Kito; '
      'Kito, son of Rafa, house 2; Rafa, son of Deko; '
      'Deko, son of Rafa; Rafa, son of someone we forgot', () async {
    final RafaFamily f = await buildRafaFamily(db);

    final lines = await spokenChain(db, f.me);

    expect(
      lines.map((l) => l.text).join('; '),
      'Me, son of Tembo; Tembo, son of Kito; '
      'Kito, son of Rafa, house 2; Rafa, son of Deko; '
      'Deko, son of Rafa; Rafa, son of someone we forgot',
    );
    // The forgotten father was told on the last line; he gets none of his own.
    expect(lines.map((l) => l.personId), [
      f.me,
      f.tembo,
      f.kito,
      f.rafa,
      f.deko,
      f.rafaElder,
    ]);
    expect(lines.every((l) => !l.disputed && !l.placeholder), isTrue);
  });

  test(
    'only the last Rafa line says its father is someone we forgot',
    () async {
      final RafaFamily f = await buildRafaFamily(db);

      final lines = await spokenChain(db, f.me);

      expect(lines.map((l) => l.fatherPlaceholder), [
        false,
        false,
        false,
        false,
        false,
        true,
      ]);
      expect(lines.last.personId, f.rafaElder);
      // The words stay as they were.
      expect(lines.last.text, 'Rafa, son of someone we forgot');
    },
  );

  test('a father is marked when he is a placeholder with a line of his own, '
      'or when there is no father at all', () async {
    final String kid = await alice.addPerson(name: 'Kid', sex: Sex.male);
    final String ghost = await alice.addPlaceholder(sex: Sex.male);
    final String grand = await alice.addPerson(name: 'Grand', sex: Sex.male);
    await placeUnder(alice, kid, ghost);
    await placeUnder(alice, ghost, grand);
    final String lone = await alice.addPerson(name: 'Lone');

    final lines = await spokenChain(db, kid);
    final alone = await spokenChain(db, lone);

    expect(shape(lines), [
      (kid, 'Kid, son of someone we forgot', false, false),
      (ghost, 'someone we forgot, son of Grand', false, true),
      (grand, 'Grand, son of someone we forgot', false, false),
    ]);
    // The line about the placeholder is outlined as a whole; only the lines
    // that name him as a father are marked.
    expect(lines.map((l) => l.fatherPlaceholder), [true, false, true]);
    expect(alone.single.text, 'Lone, child of someone we forgot');
    expect(alone.single.fatherPlaceholder, isTrue);
  });

  test('a disputed end and a named father are not marked', () async {
    final String kid = await alice.addPerson(name: 'Kid');
    final String fa = await alice.addPerson(name: 'Fa', sex: Sex.male);
    final String fb = await bob.addPerson(name: 'Fb', sex: Sex.male);
    await placeUnder(alice, kid, fa);
    await placeUnder(bob, kid, fb);
    final String solo = await alice.addPerson(name: 'Solo');
    final String dad = await alice.addPerson(name: 'Dad', sex: Sex.male);
    await placeUnder(alice, solo, dad, basis: Basis.joined);

    final disputed = await spokenChain(db, kid);
    final joined = await spokenChain(db, solo);

    expect(disputed.single.text, 'Kid, accounts differ');
    expect(disputed.single.fatherPlaceholder, isFalse);
    expect(joined.first.text, "Solo, belongs to Dad's house");
    expect(joined.first.fatherPlaceholder, isFalse);
  });

  test('the two Rafas are told apart by their father', () async {
    final RafaFamily f = await buildRafaFamily(db);

    final lines = await spokenChain(db, f.me);

    final byId = {for (final l in lines) l.personId: l.text};
    expect(byId[f.rafa], 'Rafa, son of Deko');
    expect(byId[f.rafaElder], 'Rafa, son of someone we forgot');
    expect(f.rafa, isNot(f.rafaElder));
  });

  test('unknown sex reads "child of"', () async {
    final String kid = await alice.addPerson(name: 'Kid');
    final String dad = await alice.addPerson(name: 'Dad', sex: Sex.male);
    await placeUnder(alice, kid, dad);

    final lines = await spokenChain(db, kid);

    expect(shape(lines), [
      (kid, 'Kid, child of Dad', false, false),
      (dad, 'Dad, son of someone we forgot', false, false),
    ]);
  });

  test('no name reads "unnamed"', () async {
    final RafaFamily f = await buildRafaFamily(db);
    final String kid = await alice.addPerson(name: 'Kid', sex: Sex.male);
    final String dad = await alice.addPerson(sex: Sex.male);
    await placeUnder(alice, kid, dad);

    // The aunt has no name in the fixture; she is Kito's daughter.
    final aunt = await spokenChain(db, f.aunt);
    final child = await spokenChain(db, kid);

    expect(aunt.first.text, 'unnamed, daughter of Kito');
    expect(aunt.first.placeholder, isFalse);
    expect(shape(child), [
      (kid, 'Kid, son of unnamed', false, false),
      (dad, 'unnamed, son of someone we forgot', false, false),
    ]);
  });

  test('no ordinal omits the house suffix', () async {
    final String kid = await alice.addPerson(name: 'Kid', sex: Sex.male);
    final String dad = await alice.addPerson(name: 'Dad', sex: Sex.male);
    final String kid2 = await alice.addPerson(name: 'Kid2', sex: Sex.male);
    await placeUnder(alice, kid, dad);
    await placeUnder(alice, kid2, dad, ordinal: 3);

    final lines = await spokenChain(db, kid);
    final withOrdinal = await spokenChain(db, kid2);

    expect(lines.first.text, 'Kid, son of Dad');
    expect(withOrdinal.first.text, 'Kid2, son of Dad, house 3');
  });

  test('joined basis never prints the word "joined"', () async {
    final String kid = await alice.addPerson(name: 'Kid', sex: Sex.male);
    final String dad = await alice.addPerson(name: 'Dad', sex: Sex.male);
    final String grandad = await alice.addPerson(
      name: 'Grandad',
      sex: Sex.male,
    );
    // Dad belongs to his house by joining it, and the house has an ordinal,
    // which a joined line also leaves out.
    await placeUnder(alice, kid, dad, ordinal: 2);
    await placeUnder(alice, dad, grandad, basis: Basis.joined, ordinal: 1);

    final lines = await spokenChain(db, kid);

    expect(shape(lines), [
      (kid, 'Kid, son of Dad, house 2', false, false),
      (dad, "Dad, belongs to Grandad's house", false, false),
      (grandad, 'Grandad, son of someone we forgot', false, false),
    ]);
    expect(lines.any((l) => l.text.toLowerCase().contains('joined')), isFalse);
  });

  test('a cycle ends with "accounts differ" and the chain has finite '
      'length', () async {
    final String p = await alice.addPerson(name: 'P', sex: Sex.male);
    final String f1 = await alice.addPerson(name: 'F1', sex: Sex.male);
    final String f2 = await alice.addPerson(name: 'F2', sex: Sex.male);
    await placeUnder(alice, p, f1);
    await placeUnder(alice, f1, f2);
    await placeUnder(alice, f2, p);

    final lines = await spokenChain(db, p);

    expect(shape(lines), [
      (p, 'P, son of F1', false, false),
      (f1, 'F1, son of F2', false, false),
      (f2, 'F2, son of P', false, false),
      (p, 'P, accounts differ', true, false),
    ]);
  }, timeout: const Timeout(Duration(seconds: 2)));

  test('a person with no father reads "son of someone we forgot"', () async {
    final String lone = await alice.addPerson(name: 'Lone', sex: Sex.male);

    final lines = await spokenChain(db, lone);

    expect(shape(lines), [
      (lone, 'Lone, son of someone we forgot', false, false),
    ]);
    // A person the database has never heard of does not throw either.
    final unknown = await spokenChain(db, 'no-such-person');
    expect(shape(unknown), [
      ('no-such-person', 'unnamed, child of someone we forgot', false, false),
    ]);
  });

  test('a disputed starting person reads accounts differ and the list has '
      'one line', () async {
    final String kid = await alice.addPerson(name: 'Kid', sex: Sex.male);
    final String dadA = await alice.addPerson(name: 'DadA');
    final String dadB = await alice.addPerson(name: 'DadB');
    await placeUnder(alice, kid, dadA);
    await placeUnder(bob, kid, dadB);

    final lines = await spokenChain(db, kid);

    expect(shape(lines), [(kid, 'Kid, accounts differ', true, false)]);
  });

  test('a disputed ancestor ends the list with accounts differ', () async {
    final String kid = await alice.addPerson(name: 'Kid', sex: Sex.male);
    final String dad = await alice.addPerson(name: 'Dad', sex: Sex.male);
    final String grandA = await alice.addPerson(name: 'GrandA');
    final String grandB = await alice.addPerson(name: 'GrandB');
    await placeUnder(alice, kid, dad);
    // Two accounts disagree about whose house Dad belongs to.
    await placeUnder(alice, dad, grandA);
    await placeUnder(bob, dad, grandB);

    final lines = await spokenChain(db, kid);

    expect(shape(lines), [
      (kid, 'Kid, son of Dad', false, false),
      (dad, 'Dad, accounts differ', true, false),
    ]);
  });

  test('a placeholder in the middle of a chain gets its own line', () async {
    final String kid = await alice.addPerson(name: 'Kid', sex: Sex.male);
    final String dad = await alice.addPerson(name: 'Dad', sex: Sex.male);
    final String gap = await alice.addPlaceholder(sex: Sex.male);
    final String grandad = await alice.addPerson(
      name: 'Grandad',
      sex: Sex.male,
    );
    await placeUnder(alice, kid, dad);
    await placeUnder(alice, dad, gap);
    await placeUnder(alice, gap, grandad, ordinal: 2);

    final lines = await spokenChain(db, kid);

    expect(shape(lines), [
      (kid, 'Kid, son of Dad', false, false),
      (dad, 'Dad, son of someone we forgot', false, false),
      (gap, 'someone we forgot, son of Grandad, house 2', false, true),
      (grandad, 'Grandad, son of someone we forgot', false, false),
    ]);
  });

  test('the placeholder flag and disputed flag are set only where they '
      'apply', () async {
    // A placeholder start with a named father, then a dispute above him.
    final String gap = await alice.addPlaceholder(sex: Sex.male);
    final String dad = await alice.addPerson(name: 'Dad', sex: Sex.male);
    final String grandA = await alice.addPerson(name: 'GrandA');
    final String grandB = await alice.addPerson(name: 'GrandB');
    await placeUnder(alice, gap, dad);
    await placeUnder(alice, dad, grandA);
    await placeUnder(bob, dad, grandB);

    final lines = await spokenChain(db, gap);

    expect(shape(lines), [
      (gap, 'someone we forgot, son of Dad', false, true),
      (dad, 'Dad, accounts differ', true, false),
    ]);
    expect(lines.where((l) => l.placeholder).map((l) => l.personId), [gap]);
    expect(lines.where((l) => l.disputed).map((l) => l.personId), [dad]);
  });
}
