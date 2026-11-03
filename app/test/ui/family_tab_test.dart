import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/ui/chain_view.dart';
import 'package:related/ui/family_tab.dart';
import 'package:related/ui/first_run.dart';
import 'package:related/ui/house_view.dart';
import 'package:related/ui/theme.dart';

import '../fixtures/winyo_family.dart';
import 'pump_app.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  HouseholdBuilder builderFor(String account) => HouseholdBuilder(
    db,
    ClaimService(db, accountId: account),
    accountId: account,
  );

  Future<void> pumpTab(WidgetTester tester, String me) async {
    await pumpApp(tester, FamilyTab(db: db, selfPersonId: me));
    await settle(tester);
  }

  /// Everything the family tab says is read from the database; run `setup`
  /// in real time.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() setup) async {
    late T result;
    await tester.runAsync(() async => result = await setup());
    return result;
  }

  const List<String> chain = [
    'Me, son of Juma',
    'Juma, son of Manyi',
    'Manyi, son of Winyo, house 2',
    'Winyo, son of Ochieng',
    'Ochieng, son of Winyo',
    'Winyo, son of someone we forgot',
  ];

  testWidgets('shows the spoken chain by default, with nothing to edit', (
    tester,
  ) async {
    final WinyoFamily f = await real(tester, () => buildWinyoFamily(db));
    await pumpTab(tester, f.me);

    expect(tester.takeException(), isNull);
    expect(find.byType(ChainView), findsOneWidget);
    expect(find.byType(HouseView), findsNothing);
    for (final String line in chain) {
      expect(find.text(line), findsOneWidget, reason: line);
    }
    // Read-only: no edit controls, and the diagram stays off for now.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Diagram: not available yet'), findsOneWidget);
  });

  testWidgets('the toggle shows the houses of the person\'s father', (
    tester,
  ) async {
    final WinyoFamily f = await real(tester, () => buildWinyoFamily(db));
    await pumpTab(tester, f.me);

    await tester.tap(find.text('Houses'));
    await tester.pump();

    expect(find.byType(HouseView), findsOneWidget);
    expect(find.byType(ChainView), findsNothing);
    // Me's father is Juma: his one house holds Me.
    expect(find.text('Juma'), findsOneWidget);
    expect(find.text('Me, born to this house'), findsOneWidget);

    await tester.tap(find.text('Chain'));
    await tester.pump();
    expect(find.byType(ChainView), findsOneWidget);
    expect(find.byType(HouseView), findsNothing);
  });

  testWidgets('the selected option is shown by weight and underline, and in '
      'semantics, not by colour alone', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final WinyoFamily f = await real(tester, () => buildWinyoFamily(db));
    await pumpTab(tester, f.me);

    TextStyle? styleOf(String label) =>
        tester.widget<Text>(find.text(label)).style;
    bool selected(String label) => tester
        .getSemantics(find.bySemanticsLabel(label))
        .flagsCollection
        .isSelected
        .toBoolOrNull()!;

    expect(styleOf('Chain')!.fontWeight, FontWeight.w700);
    expect(styleOf('Chain')!.decoration, TextDecoration.underline);
    expect(styleOf('Houses')!.fontWeight, isNot(FontWeight.w700));
    expect(styleOf('Houses')!.decoration, isNot(TextDecoration.underline));
    expect(selected('Chain'), isTrue);
    expect(selected('Houses'), isFalse);

    await tester.tap(find.text('Houses'));
    await tester.pump();
    expect(styleOf('Houses')!.fontWeight, FontWeight.w700);
    expect(styleOf('Chain')!.fontWeight, isNot(FontWeight.w700));
    expect(selected('Houses'), isTrue);
    expect(selected('Chain'), isFalse);
    semantics.dispose();
  });

  testWidgets('toggling does not load again', (tester) async {
    final WinyoFamily f = await real(tester, () => buildWinyoFamily(db));
    await pumpTab(tester, f.me);
    final Finder builder = find.byWidgetPredicate((w) => w is FutureBuilder);
    final before = tester.widget(builder) as FutureBuilder;

    await tester.tap(find.text('Houses'));
    await tester.pump();
    await tester.tap(find.text('Chain'));
    await tester.pump();

    final after = tester.widget(builder) as FutureBuilder;
    expect(identical(before.future, after.future), isTrue);
  });

  testWidgets('a person with no father reads sensibly and does not throw', (
    tester,
  ) async {
    final String lone = await real(
      tester,
      () => builderFor('a').addPerson(name: 'Achieng', sex: Sex.female),
    );
    await pumpTab(tester, lone);

    expect(tester.takeException(), isNull);
    expect(find.text('Achieng, daughter of someone we forgot'), findsOneWidget);

    await tester.tap(find.text('Houses'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(HouseView), findsNothing);
    expect(find.text('accounts differ'), findsNothing);
    final Finder unknown = find.text('not known yet');
    expect(unknown, findsOneWidget);
    // Plain grey, no button under it.
    final RenderParagraph label = tester.renderObject<RenderParagraph>(unknown);
    expect(
      label.text.style?.color,
      buildAppTheme().colorScheme.onSurfaceVariant,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a person whose own parentage is disputed has no houses to '
      'show and says accounts differ', (tester) async {
    final String kid = await real(tester, () async {
      final a = builderFor('a');
      final b = builderFor('b');
      final String kid = await a.addPerson(name: 'Kid');
      final String fa = await a.addPerson(name: 'Fa', sex: Sex.male);
      final String fb = await b.addPerson(name: 'Fb', sex: Sex.male);
      await a.placeChild(
        personId: kid,
        houseId: await a.addHouse(husbandId: fa),
        basis: Basis.bornTo,
      );
      await b.placeChild(
        personId: kid,
        houseId: await b.addHouse(husbandId: fb),
        basis: Basis.bornTo,
      );
      return kid;
    });
    await pumpTab(tester, kid);

    expect(find.text('Kid, accounts differ'), findsOneWidget);
    await tester.tap(find.text('Houses'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    // The chain says accounts differ, so the houses say the same, not "not
    // known yet": that is for a person with no father step at all.
    expect(find.byType(HouseView), findsNothing);
    expect(find.text('not known yet'), findsNothing);
    final Finder differ = find.text('accounts differ');
    expect(differ, findsOneWidget);
    // Plain grey, no button under it.
    final RenderParagraph label = tester.renderObject<RenderParagraph>(differ);
    expect(
      label.text.style?.color,
      buildAppTheme().colorScheme.onSurfaceVariant,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a person saved by first run with a placeholder father builds '
      'in both views', (tester) async {
    late String me;
    await real(tester, () async {
      final b = builderFor('a');
      me = await b.addPerson(name: 'Me', sex: Sex.male);
      final String father = await b.addPlaceholder(sex: Sex.male);
      final String house = await b.addHouse(husbandId: father);
      await b.placeChild(personId: me, houseId: house, basis: Basis.bornTo);
    });
    await pumpTab(tester, me);

    expect(tester.takeException(), isNull);
    expect(find.text('Me, son of someone we forgot'), findsOneWidget);
    // The placeholder father was said once, so he has no line of his own.
    expect(find.text('someone we forgot'), findsNothing);

    await tester.tap(find.text('Houses'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('someone we forgot'), findsOneWidget);
    expect(find.text('Me, born to this house'), findsOneWidget);
  });

  testWidgets('every screen builds with a placeholder-father person, at text '
      'scale 2.0', (tester) async {
    late String me;
    await real(tester, () async {
      final b = builderFor('a');
      me = await b.addPerson();
      final String father = await b.addPlaceholder(sex: Sex.male);
      final String house = await b.addHouse(husbandId: father);
      await b.placeChild(personId: me, houseId: house, basis: Basis.bornTo);
    });

    // The first-run screen, then the family tab in both views.
    await pumpApp(
      tester,
      FirstRunScreen(builder: builderFor('a')),
      textScale: 2.0,
      height: 4000,
    );
    expect(tester.takeException(), isNull);

    await pumpApp(tester, FamilyTab(db: db, selfPersonId: me), textScale: 2.0);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('unnamed, child of someone we forgot'), findsOneWidget);
    await tester.tap(find.text('Houses'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(HouseView), findsOneWidget);
  });

  testWidgets('a failed read is reported as well as shown', (tester) async {
    // A database that cannot be opened: every read fails.
    final AppDatabase broken = AppDatabase(
      NativeDatabase.memory(setup: (_) => throw StateError('cannot open')),
    );
    addTearDown(() => tester.runAsync(broken.close));
    await pumpApp(tester, FamilyTab(db: broken, selfPersonId: 'me'));
    await settle(tester);

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Could not read the family.'), findsOneWidget);
  });
}
