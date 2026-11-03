import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/tree/house_model.dart';
import 'package:related/ui/house_view.dart';

import '../fixtures/winyo_family.dart';
import 'pump_app.dart';

void main() {
  late AppDatabase db;
  late WinyoFamily f;

  setUp(() async {
    db = AppDatabase.memory();
    f = await buildWinyoFamily(db);
  });
  tearDown(() => db.close());

  // The database runs on real time, so models are built outside the test's
  // fake clock.
  Future<HouseViewModel> modelOf(WidgetTester tester, String husband) async =>
      (await tester.runAsync(() => buildHouseViewModel(db, husband)))!;

  testWidgets('the aunt reads "same person" in all three places she '
      'appears', (tester) async {
    // As a child in Manyi's house: the tag is part of her line.
    await pumpApp(tester, HouseView(house: await modelOf(tester, f.manyi)));
    expect(tester.takeException(), isNull);
    expect(
      find.text('unnamed, born to this house, same person'),
      findsOneWidget,
    );
    expect(find.textContaining('same person'), findsOneWidget);

    // As the wife of A and of B: a tag beside her name.
    for (final String husband in [f.auntHusbandA, f.auntHusbandB]) {
      await pumpApp(tester, HouseView(house: await modelOf(tester, husband)));
      expect(tester.takeException(), isNull);
      expect(find.text('unnamed, married'), findsOneWidget);
      expect(find.text('same person'), findsOneWidget);
    }
  });

  testWidgets('Winyo\'s four houses show as the family would say them', (
    tester,
  ) async {
    await pumpApp(tester, HouseView(house: await modelOf(tester, f.winyo)));

    expect(tester.takeException(), isNull);
    for (final String t in [
      'House 1',
      'House 2',
      'House 3',
      'House 4',
      "Atieno Nyang'or, married",
      'Manyi, born to this house',
      'Wade, born to this house',
      'wife not known yet',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // Houses 1 and 3 are empty.
    expect(find.text('not known yet'), findsNWidgets(2));
    expect(find.textContaining('same person'), findsNothing);
  });

  testWidgets('a wife whose person row is missing reads "unnamed, married"', (
    tester,
  ) async {
    final b = HouseholdBuilder(
      db,
      ClaimService(db, accountId: 'x'),
      accountId: 'x',
    );
    final String husband = (await tester.runAsync(() async {
      final String h = await b.addPerson(name: 'Otieno');
      final String house = await b.addHouse(husbandId: h, ordinal: 1);
      await b.addWife(wifeId: 'no-such-person', houseId: house);
      return h;
    }))!;

    await pumpApp(tester, HouseView(house: await modelOf(tester, husband)));

    expect(tester.takeException(), isNull);
    expect(find.text('unnamed, married'), findsOneWidget);
  });
}
