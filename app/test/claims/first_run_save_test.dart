import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/first_run_save.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';

void main() {
  late AppDatabase db;
  late HouseholdBuilder builder;

  setUp(() {
    db = AppDatabase.memory();
    builder = HouseholdBuilder(
      db,
      ClaimService(db, accountId: 'x'),
      accountId: 'x',
    );
  });
  tearDown(() => db.close());

  test(
    'answers with everything known write the family and return me',
    () async {
      final String me = await saveFirstRun(
        builder,
        const FirstRunAnswers(
          name: 'Me',
          sex: Sex.female,
          fatherName: 'Juma',
          houseNumber: 2,
          siblingNames: ['Achieng', 'Otieno'],
        ),
      );

      final people = await db.select(db.persons).get();
      expect(people, hasLength(4));
      expect(people.singleWhere((p) => p.id == me).nameKey, 'Me');
      final houses = await db.select(db.houses).get();
      expect(houses.single.ordinal, 2);
      expect(await db.select(db.claims).get(), hasLength(3));
    },
  );

  test(
    'empty answers write a placeholder father and a house of his own',
    () async {
      await saveFirstRun(builder, const FirstRunAnswers());

      final people = await db.select(db.persons).get();
      expect(people.where((p) => p.isPlaceholder), hasLength(1));
      expect(people, hasLength(2));
      expect((await db.select(db.houses).get()).single.ordinal, isNull);
    },
  );

  test('a house number below one counts as not known', () async {
    await saveFirstRun(builder, const FirstRunAnswers(houseNumber: 0));
    await saveFirstRun(builder, const FirstRunAnswers(houseNumber: -3));

    final houses = await db.select(db.houses).get();
    expect(houses.map((h) => h.ordinal), [null, null]);
  });

  test('atomically rolls back everything when the body throws', () async {
    await expectLater(
      builder.atomically(() async {
        await saveFirstRun(builder, const FirstRunAnswers(name: 'Me'));
        throw StateError('stop');
      }),
      throwsStateError,
    );

    expect(await db.select(db.persons).get(), isEmpty);
    expect(await db.select(db.houses).get(), isEmpty);
    expect(await db.select(db.claims).get(), isEmpty);
  });
}
