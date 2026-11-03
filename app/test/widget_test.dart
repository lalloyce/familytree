import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/first_run_save.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/ui/theme.dart';
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

    // The error is reported, and shown in words.
    expect(tester.takeException(), isA<StateError>());
    expect(find.byType(FirstRunScreen), findsNothing);
    expect(find.byType(FamilyTab), findsNothing);
    expect(find.text('Could not open your family.'), findsOneWidget);
  });

  testWidgets('first run with the father not known shows him as a dashed '
      '"someone we forgot" in both views', (tester) async {
    // The path the real app takes: a household saved by first run with no
    // father named.
    await tester.runAsync(() async {
      final builder = HouseholdBuilder(
        db,
        ClaimService(db, accountId: 'device'),
        accountId: 'device',
      );
      final String me = await saveFirstRun(
        builder,
        const FirstRunAnswers(name: 'Me', sex: Sex.male),
      );
      await db.setSelfPersonId(me);
    });
    await pumpRoot(tester);

    // Chain: the words are as before, with the dashed outline inside the line.
    expect(tester.takeException(), isNull);
    expect(find.text('Me, son of someone we forgot'), findsOneWidget);
    expect(find.text('someone we forgot'), findsNothing);
    final Finder span = find.byKey(ChainView.forgottenSpanKey(0));
    expect(span, findsOneWidget);
    final Color color = buildAppTheme().colorScheme.outline;
    expect(tester.renderObject(span), paints..path(color: color));

    // Houses: the father's heading, outlined, with the same words.
    await tester.tap(find.text('Houses'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('someone we forgot'), findsOneWidget);
    expect(find.text('Me, born to this house'), findsOneWidget);
    final Finder husband = find.byKey(HouseView.husbandOutlineKey);
    expect(husband, findsOneWidget);
    expect(
      find.descendant(of: husband, matching: find.text('someone we forgot')),
      findsOneWidget,
    );
    expect(tester.renderObject(husband), paints..path(color: color));
  });
}
