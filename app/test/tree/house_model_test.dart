import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/tree/house_model.dart';

import '../fixtures/winyo_family.dart';

/// Counts every statement the database runs.
class _CountingInterceptor extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late AppDatabase db;
  late HouseholdBuilder alice;
  late HouseholdBuilder bob;

  setUp(() {
    db = AppDatabase.memory();
    alice = HouseholdBuilder(
      db,
      ClaimService(db, accountId: 'alice'),
      accountId: 'alice',
    );
    bob = HouseholdBuilder(
      db,
      ClaimService(db, accountId: 'bob'),
      accountId: 'bob',
    );
  });
  tearDown(() => db.close());

  group('the Winyo family', () {
    late WinyoFamily f;

    setUp(() async {
      f = await buildWinyoFamily(db);
    });

    test('Winyo has four houses in order, only house 2 with people '
        'beyond Owala', () async {
      final HouseViewModel m = await buildHouseViewModel(db, f.winyo);

      expect(m.husbandName, 'Winyo');
      expect([for (final h in m.houses) h.ordinal], [1, 2, 3, 4]);

      final h1 = m.houses[0], h2 = m.houses[1], h3 = m.houses[2];
      final h4 = m.houses[3];
      expect(h2.wifeName, "Atieno Nyang'or");
      expect(h2.wifeSameAsElsewhere, isFalse);
      expect(h2.wifeAccountsDiffer, isFalse);
      expect(h2.childLines, [
        'Manyi, born to this house',
        'Wade, born to this house',
      ]);
      for (final h in [h1, h3]) {
        expect(h.wifeName, isNull);
        expect(h.wifeAccountsDiffer, isFalse);
        expect(h.wifeSameAsElsewhere, isFalse);
        expect(h.childLines, isEmpty);
      }
      expect(h4.wifeName, isNull);
      expect(h4.childLines, ['Owala, born to this house']);
    });

    test(
      'the aunt is "same person" as a child in Manyi\'s own model',
      () async {
        final HouseViewModel m = await buildHouseViewModel(db, f.manyi);

        expect(m.husbandName, 'Manyi');
        expect(m.houses, hasLength(1));
        expect(m.houses.single.ordinal, isNull);
        expect(m.houses.single.childLines, [
          'Juma, born to this house',
          'unnamed, born to this house, same person',
        ]);
      },
    );

    test('the aunt is a wife marked same person in A\'s and B\'s models, '
        'each with her own child', () async {
      for (final husband in [f.auntHusbandA, f.auntHusbandB]) {
        final HouseViewModel m = await buildHouseViewModel(db, husband);
        final HouseRowModel h = m.houses.single;

        expect(m.husbandName, 'unnamed');
        expect(h.wifeName, 'unnamed');
        expect(h.wifeSameAsElsewhere, isTrue);
        expect(h.wifeAccountsDiffer, isFalse);
        expect(h.childLines, ['unnamed, born to this house']);
      }
    });

    test('a placeholder husband is named "someone we forgot"', () async {
      final HouseViewModel m = await buildHouseViewModel(db, f.ochieng);
      // Ochieng is a person; his father is the placeholder.
      expect(m.husbandName, 'Ochieng');
      final String placeholder = (await (db.select(
        db.persons,
      )..where((p) => p.isPlaceholder.equals(true))).get()).first.id;

      expect(
        (await buildHouseViewModel(db, placeholder)).husbandName,
        'someone we forgot',
      );
    });

    test('a husband with no houses reads empty', () async {
      final HouseViewModel m = await buildHouseViewModel(db, f.wade);
      expect(m.husbandName, 'Wade');
      expect(m.houses, isEmpty);

      final HouseViewModel none = await buildHouseViewModel(db, 'no-such-id');
      expect(none.husbandName, 'unnamed');
      expect(none.houses, isEmpty);
    });

    test('the query count does not grow with the size of the family', () async {
      // A second database beside setUp's is deliberate: it is the counted one.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final counter = _CountingInterceptor();
      final cdb = AppDatabase(NativeDatabase.memory().interceptWith(counter));
      addTearDown(cdb.close);
      final WinyoFamily cf = await buildWinyoFamily(cdb);

      counter.selects = 0;
      await buildHouseViewModel(cdb, cf.winyo); // 4 houses, 3 people
      final int big = counter.selects;
      counter.selects = 0;
      await buildHouseViewModel(cdb, cf.juma); // 1 house, 1 person
      final int small = counter.selects;

      expect(big, small);
      expect(big, lessThanOrEqualTo(5));
    });
  });

  test('houses sort by ordinal, unknown last, ties by house id', () async {
    final String husband = await alice.addPerson(name: 'Otieno');
    final String none = await alice.addHouse(husbandId: husband);
    final String three = await alice.addHouse(husbandId: husband, ordinal: 3);
    final String one = await alice.addHouse(husbandId: husband, ordinal: 1);
    final String threeToo = await alice.addHouse(
      husbandId: husband,
      ordinal: 3,
    );
    // Another man's house must not appear.
    final String other = await alice.addPerson(name: 'Other');
    await alice.addHouse(husbandId: other, ordinal: 1);
    // Mark each house by a child so rows can be told apart.
    for (final (h, n) in [
      (none, 'none'),
      (three, 'three'),
      (one, 'one'),
      (threeToo, 'threeToo'),
    ]) {
      final String c = await alice.addPerson(name: n);
      await alice.placeChild(personId: c, houseId: h, basis: Basis.bornTo);
    }

    final HouseViewModel m = await buildHouseViewModel(db, husband);

    final tiedFirst = [three, threeToo]..sort();
    final String tiedFirstChild = tiedFirst.first == three
        ? 'three, born to this house'
        : 'threeToo, born to this house';
    expect([for (final h in m.houses) h.ordinal], [1, 3, 3, null]);
    expect(m.houses[0].childLines, ['one, born to this house']);
    expect(m.houses[1].childLines, [tiedFirstChild]);
    expect(m.houses[3].childLines, ['none, born to this house']);
  });

  test(
    'a name is trimmed, and a missing or blank name reads "unnamed"',
    () async {
      final String husband = await alice.addPerson(name: '  Otieno ');
      final String house = await alice.addHouse(husbandId: husband, ordinal: 1);
      final String blank = await alice.addPerson(name: '   ');
      final String nameless = await alice.addPerson();
      await alice.placeChild(
        personId: blank,
        houseId: house,
        basis: Basis.bornTo,
      );
      await alice.placeChild(
        personId: nameless,
        houseId: house,
        basis: Basis.bornTo,
      );

      final HouseViewModel m = await buildHouseViewModel(db, husband);

      expect(m.husbandName, 'Otieno');
      expect(m.houses.single.childLines, [
        'unnamed, born to this house',
        'unnamed, born to this house',
      ]);
    },
  );

  test(
    'a joined child reads "belongs to this house", never "joined"',
    () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String house = await alice.addHouse(husbandId: husband, ordinal: 1);
      final String herder = await alice.addPerson(name: 'Herder');
      await alice.placeChild(
        personId: herder,
        houseId: house,
        basis: Basis.joined,
      );

      final HouseViewModel m = await buildHouseViewModel(db, husband);

      expect(m.houses.single.childLines, ['Herder, belongs to this house']);
      expect(m.houses.single.childLines.single, isNot(contains('joined')));
    },
  );

  test('a placeholder child and a placeholder wife read "someone we '
      'forgot"', () async {
    final String husband = await alice.addPerson(name: 'Otieno');
    final String house = await alice.addHouse(husbandId: husband, ordinal: 1);
    final String wife = await alice.addPlaceholder(sex: Sex.female);
    await alice.addWife(wifeId: wife, houseId: house);
    final String child = await alice.addPlaceholder();
    await alice.placeChild(
      personId: child,
      houseId: house,
      basis: Basis.bornTo,
    );

    final HouseRowModel h = (await buildHouseViewModel(
      db,
      husband,
    )).houses.single;

    expect(h.wifeName, 'someone we forgot');
    expect(h.childLines, ['someone we forgot, born to this house']);
  });

  test('a wife claim whose person row is missing reads "unnamed" and does '
      'not throw', () async {
    final String husband = await alice.addPerson(name: 'Otieno');
    final String house = await alice.addHouse(husbandId: husband, ordinal: 1);
    await alice.addWife(wifeId: 'no-such-person', houseId: house);

    final HouseRowModel h = (await buildHouseViewModel(
      db,
      husband,
    )).houses.single;

    expect(h.wifeName, 'unnamed');
    expect(h.wifeAccountsDiffer, isFalse);
    expect(h.wifeSameAsElsewhere, isFalse);
  });

  group('competing accounts', () {
    test('two accounts naming different wives give accounts differ and no '
        'name', () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String house = await alice.addHouse(husbandId: husband, ordinal: 2);
      final String w1 = await alice.addPerson(name: 'Akinyi');
      final String w2 = await bob.addPerson(name: 'Adhiambo');
      await alice.addWife(wifeId: w1, houseId: house);
      await bob.addWife(wifeId: w2, houseId: house);

      final HouseRowModel h = (await buildHouseViewModel(
        db,
        husband,
      )).houses.single;

      expect(h.wifeAccountsDiffer, isTrue);
      expect(h.wifeName, isNull);
      expect(h.wifeSameAsElsewhere, isFalse);
    });

    test('two accounts naming the same wife agree: one name, no '
        'dispute', () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String house = await alice.addHouse(husbandId: husband, ordinal: 2);
      final String w = await alice.addPerson(name: 'Akinyi');
      await alice.addWife(wifeId: w, houseId: house);
      await bob.addWife(wifeId: w, houseId: house);

      final HouseRowModel h = (await buildHouseViewModel(
        db,
        husband,
      )).houses.single;

      expect(h.wifeAccountsDiffer, isFalse);
      expect(h.wifeName, 'Akinyi');
      expect(h.wifeSameAsElsewhere, isFalse);
    });

    test('a person placed in two houses by two accounts gets "accounts '
        'differ" and "same person" in each', () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String h1 = await alice.addHouse(husbandId: husband, ordinal: 1);
      final String h2 = await alice.addHouse(husbandId: husband, ordinal: 2);
      final String kid = await alice.addPerson(name: 'Kwach');
      await alice.placeChild(personId: kid, houseId: h1, basis: Basis.bornTo);
      await bob.placeChild(personId: kid, houseId: h2, basis: Basis.bornTo);
      final String steady = await alice.addPerson(name: 'Steady');
      await alice.placeChild(
        personId: steady,
        houseId: h1,
        basis: Basis.bornTo,
      );

      final HouseViewModel m = await buildHouseViewModel(db, husband);

      expect(m.houses[0].childLines, [
        'Kwach, born to this house, same person, accounts differ',
        'Steady, born to this house',
      ]);
      expect(m.houses[1].childLines, [
        'Kwach, born to this house, same person, accounts differ',
      ]);
    });

    test('two accounts giving different bases for one house list the child '
        'once, with accounts differ', () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String house = await alice.addHouse(husbandId: husband, ordinal: 1);
      final String kid = await alice.addPerson(name: 'Kwach');
      await alice.placeChild(
        personId: kid,
        houseId: house,
        basis: Basis.bornTo,
      );
      await bob.placeChild(personId: kid, houseId: house, basis: Basis.joined);

      final HouseRowModel h = (await buildHouseViewModel(
        db,
        husband,
      )).houses.single;

      // The earliest to arrive supplies the basis; both stay recorded.
      expect(h.childLines, ['Kwach, born to this house, accounts differ']);
    });

    test('a woman claimed as wife of a second house is marked in the first '
        'even when the second is disputed', () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String h1 = await alice.addHouse(husbandId: husband, ordinal: 1);
      final String h2 = await alice.addHouse(husbandId: husband, ordinal: 2);
      final String w = await alice.addPerson(name: 'Akinyi');
      await alice.addWife(wifeId: w, houseId: h1);
      await alice.addWife(wifeId: w, houseId: h2);
      // Bob says someone else is the wife of house 2.
      final String other = await bob.addPerson(name: 'Adhiambo');
      await bob.addWife(wifeId: other, houseId: h2);

      final HouseViewModel m = await buildHouseViewModel(db, husband);

      expect(m.houses[0].wifeName, 'Akinyi');
      // Alice also names her for house 2, so house 1 marks her.
      expect(m.houses[0].wifeSameAsElsewhere, isTrue);
      expect(m.houses[1].wifeAccountsDiffer, isTrue);
    });
  });

  group('same person', () {
    test('a wife who is also a daughter of a house is marked in both '
        'places', () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String home = await alice.addHouse(husbandId: husband, ordinal: 1);
      final String woman = await alice.addPerson(name: 'Akinyi');
      await alice.placeChild(
        personId: woman,
        houseId: home,
        basis: Basis.bornTo,
      );
      // She is also a wife in a house of a man who is not in this model.
      final String other = await alice.addPerson(name: 'Brother');
      final String otherHouse = await alice.addHouse(husbandId: other);
      await alice.addWife(wifeId: woman, houseId: otherHouse);

      final HouseRowModel mine = (await buildHouseViewModel(
        db,
        husband,
      )).houses.single;
      final HouseRowModel theirs = (await buildHouseViewModel(
        db,
        other,
      )).houses.single;

      expect(mine.childLines, ['Akinyi, born to this house, same person']);
      expect(theirs.wifeName, 'Akinyi');
      expect(theirs.wifeSameAsElsewhere, isTrue);
    });

    test('a woman who is the wife of one house only is not marked', () async {
      final String husband = await alice.addPerson(name: 'Otieno');
      final String house = await alice.addHouse(husbandId: husband, ordinal: 1);
      final String w = await alice.addPerson(name: 'Akinyi');
      await alice.addWife(wifeId: w, houseId: house);

      final HouseRowModel h = (await buildHouseViewModel(
        db,
        husband,
      )).houses.single;

      expect(h.wifeSameAsElsewhere, isFalse);
    });
  });
}
