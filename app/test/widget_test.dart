import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/app.dart';
import 'package:related/data/app_settings.dart';
import 'package:related/data/database.dart';
import 'package:related/ui/chain_view.dart';
import 'package:related/ui/family_tab.dart';
import 'package:related/ui/first_run.dart';
import 'package:related/ui/house_view.dart';

import 'fixtures/winyo_family.dart';
import 'ui/pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  Future<void> pumpRoot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RelatedApp(db: db));
    await settle(tester);
  }

  testWidgets('an empty database opens the first-run screen', (tester) async {
    await pumpRoot(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(FirstRunScreen), findsOneWidget);
    expect(find.byType(FamilyTab), findsNothing);
  });

  testWidgets('saving on first run opens the chain of the person just '
      'entered, and remembers who they are', (tester) async {
    await pumpRoot(tester);

    await tester.enterText(find.byKey(FirstRunScreen.nameKey), 'Me');
    await tester.enterText(find.byKey(FirstRunScreen.fatherKey), 'Juma');
    await tester.ensureVisible(find.text('Son'));
    await tester.tap(find.text('Son'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(FirstRunScreen.saveKey));
    await tester.tap(find.byKey(FirstRunScreen.saveKey));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.byType(FamilyTab), findsOneWidget);
    expect(find.text('Me, son of Juma'), findsOneWidget);
    expect(find.text('Juma, son of someone we forgot'), findsOneWidget);

    final String? self = await tester.runAsync<String?>(db.selfPersonId);
    expect(self, isNotNull);
    final List<PersonRow> people = (await tester.runAsync(
      () => db.select(db.persons).get(),
    ))!;
    expect(people.singleWhere((p) => p.id == self).nameKey, 'Me');
  });

  testWidgets('with a self person set it opens the chain at once, and the '
      'toggle switches to the houses', (tester) async {
    late WinyoFamily f;
    await tester.runAsync(() async {
      f = await buildWinyoFamily(db);
      await db.setSelfPersonId(f.me);
    });
    await pumpRoot(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.byType(ChainView), findsOneWidget);
    // The six lines of paper test part A.
    for (final String line in [
      'Me, son of Juma',
      'Juma, son of Manyi',
      'Manyi, son of Winyo, house 2',
      'Winyo, son of Ochieng',
      'Ochieng, son of Winyo',
      'Winyo, son of someone we forgot',
    ]) {
      expect(find.text(line), findsOneWidget, reason: line);
    }

    await tester.tap(find.text('Houses'));
    await tester.pump();
    expect(find.byType(HouseView), findsOneWidget);
    expect(find.byType(ChainView), findsNothing);
  });

  testWidgets('a self person that is not in the database still opens '
      'without throwing', (tester) async {
    await tester.runAsync(() => db.setSelfPersonId('no-such-person'));
    await pumpRoot(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(FamilyTab), findsOneWidget);
    expect(find.text('unnamed, child of someone we forgot'), findsOneWidget);
  });

  testWidgets('after a successful first run, a restart opens the family tab', (
    tester,
  ) async {
    await pumpRoot(tester);
    await tester.enterText(find.byKey(FirstRunScreen.nameKey), 'Me');
    await tester.ensureVisible(find.byKey(FirstRunScreen.saveKey));
    await tester.tap(find.byKey(FirstRunScreen.saveKey));
    await settle(tester);
    expect(find.byType(FamilyTab), findsOneWidget);

    // A second app over the same database, as after a restart.
    await tester.pumpWidget(const SizedBox());
    await pumpRoot(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.byType(FamilyTab), findsOneWidget);
    expect(find.text('unnamed, child of someone we forgot'), findsNothing);
    expect(find.text('Me, child of someone we forgot'), findsOneWidget);
  });

  testWidgets('a failed read of the self setting says so and does not open '
      'first run', (tester) async {
    // A database that cannot be opened: every read fails.
    final AppDatabase broken = AppDatabase(
      NativeDatabase.memory(setup: (_) => throw StateError('cannot open')),
    );
    addTearDown(() => tester.runAsync(broken.close));
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RelatedApp(db: broken));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.byType(FamilyTab), findsNothing);
    expect(find.text('Could not open your family.'), findsOneWidget);
  });
}
