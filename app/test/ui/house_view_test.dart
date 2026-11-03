import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/tree/house_model.dart';
import 'package:related/ui/house_view.dart';
import 'package:related/ui/theme.dart';

import 'pump_app.dart';

HouseViewModel model(List<HouseRowModel> houses, {String husband = 'Winyo'}) =>
    HouseViewModel(husbandName: husband, houses: houses);

Finder row(int i) => find.byKey(HouseView.rowKey(i));

/// Anything in [scope] that a finger could press.
Finder pressables(Finder scope) => find.descendant(
  of: scope,
  matching: find.byWidgetPredicate(
    (w) =>
        w is ElevatedButton ||
        w is TextButton ||
        w is OutlinedButton ||
        w is FilledButton ||
        w is IconButton ||
        w is InkWell ||
        w is GestureDetector,
  ),
);

void main() {
  testWidgets(
    'HouseView shows "not known yet" for an empty house and offers no '
    'button in it',
    (tester) async {
      await pumpApp(
        tester,
        HouseView(
          house: model([
            const HouseRowModel(ordinal: 1),
            const HouseRowModel(
              ordinal: 2,
              wifeName: "Atieno Nyang'or",
              childLines: ['Manyi, born to this house'],
            ),
          ]),
        ),
      );

      expect(find.text('Winyo'), findsOneWidget);
      expect(find.text('House 1'), findsOneWidget);
      // "not known yet" appears once, inside house 1 and nowhere else.
      expect(find.text('not known yet'), findsOneWidget);
      expect(
        find.descendant(of: row(0), matching: find.text('not known yet')),
        findsOneWidget,
      );
      expect(pressables(row(0)), findsNothing);
      // It is plain grey, in the theme's muted colour.
      expect(
        tester.widget<Text>(find.text('not known yet')).style?.color,
        buildAppTheme().colorScheme.onSurfaceVariant,
      );
      // The house with people in it does not say it.
      expect(
        find.descendant(of: row(1), matching: find.text('not known yet')),
        findsNothing,
      );
    },
  );

  testWidgets('a woman in two houses shows the text "same person" in each '
      'place', (tester) async {
    await pumpApp(
      tester,
      HouseView(
        house: model([
          const HouseRowModel(
            ordinal: 1,
            wifeName: 'Akinyi',
            wifeSameAsElsewhere: true,
          ),
          const HouseRowModel(
            ordinal: 2,
            wifeName: 'Akinyi',
            wifeSameAsElsewhere: true,
            childLines: ['Ouma, born to this house'],
          ),
          const HouseRowModel(ordinal: 3, wifeName: 'Adhiambo'),
        ], husband: 'Obuolo'),
      ),
    );

    expect(find.text('same person'), findsNWidgets(2));
    expect(
      find.descendant(of: row(0), matching: find.text('same person')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row(1), matching: find.text('same person')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row(2), matching: find.text('same person')),
      findsNothing,
    );
  });

  testWidgets('basis is shown as a word', (tester) async {
    await pumpApp(
      tester,
      HouseView(
        house: model([
          const HouseRowModel(ordinal: 2, wifeName: "Atieno Nyang'or"),
        ]),
      ),
    );

    expect(find.text("Atieno Nyang'or, married"), findsOneWidget);
    expect(
      find.descendant(of: row(0), matching: find.textContaining('married')),
      findsOneWidget,
    );
  });

  testWidgets('a house with children and no wife says "wife not known yet" in '
      'plain grey with no button', (tester) async {
    await pumpApp(
      tester,
      HouseView(
        house: model([
          const HouseRowModel(
            ordinal: 4,
            childLines: ['Owala, born to this house'],
          ),
        ]),
      ),
    );

    expect(find.text('wife not known yet'), findsOneWidget);
    expect(find.text('not known yet'), findsNothing);
    expect(find.text('Owala, born to this house'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('wife not known yet')).style?.color,
      buildAppTheme().colorScheme.onSurfaceVariant,
    );
    expect(pressables(row(0)), findsNothing);
  });

  testWidgets('competing wives read "accounts differ" with no name', (
    tester,
  ) async {
    await pumpApp(
      tester,
      HouseView(
        house: model([
          const HouseRowModel(
            ordinal: 2,
            wifeAccountsDiffer: true,
            childLines: ['Manyi, born to this house'],
          ),
          const HouseRowModel(ordinal: 3, wifeAccountsDiffer: true),
        ]),
      ),
    );

    expect(find.text('accounts differ'), findsNWidgets(2));
    expect(find.text('wife not known yet'), findsNothing);
    // A house whose wife is disputed is not "not known yet".
    expect(find.text('not known yet'), findsNothing);
  });

  testWidgets('the house number is left out when it is not known', (
    tester,
  ) async {
    await pumpApp(
      tester,
      HouseView(house: model([const HouseRowModel(wifeName: 'Akinyi')])),
    );

    expect(find.text('House'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('children appear one per line, as supplied', (tester) async {
    await pumpApp(
      tester,
      HouseView(
        house: model([
          const HouseRowModel(
            ordinal: 2,
            wifeName: 'Akinyi',
            childLines: [
              'Manyi, born to this house',
              'Wade, belongs to this house, same person, accounts differ',
            ],
          ),
        ]),
      ),
    );

    expect(find.text('Manyi, born to this house'), findsOneWidget);
    expect(
      find.text('Wade, belongs to this house, same person, accounts differ'),
      findsOneWidget,
    );
  });

  testWidgets('200-character names wrap at text scale 2.0 and are never '
      'truncated', (tester) async {
    final String longWord = 'W' * 200;
    await pumpApp(
      tester,
      HouseView(
        house: model([
          HouseRowModel(
            ordinal: 2,
            wifeName: longWord,
            wifeSameAsElsewhere: true,
            childLines: ['$longWord, born to this house'],
          ),
        ], husband: longWord),
      ),
      textScale: 2.0,
      height: 4000,
    );

    expectTextScale(tester, 2.0);
    expect(tester.takeException(), isNull);
    for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.overflow, isNot(TextOverflow.ellipsis));
      expect(t.maxLines, isNull);
    }
    for (final Finder f in [
      find.text(longWord),
      find.text('$longWord, married'),
      find.text('$longWord, born to this house'),
    ]) {
      expect(f, findsOneWidget);
      final RenderParagraph p = tester.renderObject<RenderParagraph>(f);
      expect(p.didExceedMaxLines, isFalse);
      expect(tester.getSize(f).width, lessThanOrEqualTo(360));
      expect(tester.getSize(f).height, greaterThan(p.preferredLineHeight * 3));
    }
  });

  testWidgets('the husband and each house number are marked as headings', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      HouseView(
        house: model([
          const HouseRowModel(ordinal: 1),
          const HouseRowModel(ordinal: 2, wifeName: 'Akinyi'),
        ]),
      ),
    );

    for (final String heading in ['Winyo', 'House 1', 'House 2']) {
      expect(
        tester.getSemantics(find.text(heading)),
        matchesSemantics(isHeader: true, label: heading),
        reason: heading,
      );
    }
    // A body line is not a heading.
    expect(
      tester.getSemantics(find.text('not known yet')),
      isNot(matchesSemantics(isHeader: true)),
    );
    handle.dispose();
  });

  testWidgets('an empty house list builds with no exception', (tester) async {
    await pumpApp(tester, HouseView(house: model(const [])));

    expect(tester.takeException(), isNull);
    expect(find.text('Winyo'), findsOneWidget);
    expect(find.text('not known yet'), findsNothing);
    expect(pressables(find.byType(HouseView)), findsNothing);
  });
}
