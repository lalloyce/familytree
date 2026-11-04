import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/tree/house_model.dart';
import 'package:related/ui/house_view.dart';
import 'package:related/ui/theme.dart';

import 'pump_app.dart';

HouseViewModel model(
  List<HouseRowModel> houses, {
  String husband = 'Rafa',
  bool husbandIsPlaceholder = false,
}) => HouseViewModel(
  husbandName: husband,
  houses: houses,
  husbandIsPlaceholder: husbandIsPlaceholder,
);

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
              wifeName: "Zawadi Bora",
              childLines: ['Kito, born to this house'],
            ),
          ]),
        ),
      );

      expect(find.text('Rafa'), findsOneWidget);
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
        ], husband: 'Nuru'),
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
          const HouseRowModel(ordinal: 2, wifeName: "Zawadi Bora"),
        ]),
      ),
    );

    expect(find.text("Zawadi Bora, married"), findsOneWidget);
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
            childLines: ['Lumo, born to this house'],
          ),
        ]),
      ),
    );

    expect(find.text('wife not known yet'), findsOneWidget);
    expect(find.text('not known yet'), findsNothing);
    expect(find.text('Lumo, born to this house'), findsOneWidget);
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
            childLines: ['Kito, born to this house'],
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

  testWidgets('a placeholder husband and a placeholder wife are drawn in a '
      'dashed outline, and their words and heading stay as they were', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      HouseView(
        house: model(
          [
            const HouseRowModel(
              ordinal: 1,
              wifeName: 'someone we forgot',
              wifeIsPlaceholder: true,
            ),
            const HouseRowModel(ordinal: 2, wifeName: 'Akinyi'),
          ],
          husband: 'someone we forgot',
          husbandIsPlaceholder: true,
        ),
      ),
    );

    final Color color = buildAppTheme().colorScheme.outline;
    final Finder husband = find.byKey(HouseView.husbandOutlineKey);
    expect(husband, findsOneWidget);
    expect(
      find.descendant(of: husband, matching: find.text('someone we forgot')),
      findsOneWidget,
    );
    expect(tester.renderObject(husband), paints..path(color: color));
    // Still a heading.
    expect(
      tester.getSemantics(find.text('someone we forgot')),
      matchesSemantics(isHeader: true, label: 'someone we forgot'),
    );

    // Only the placeholder wife's name is outlined, not the whole line.
    expect(find.byKey(HouseView.wifeOutlineKey(0)), findsOneWidget);
    expect(find.byKey(HouseView.wifeOutlineKey(1)), findsNothing);
    expect(find.text('someone we forgot, married'), findsOneWidget);
    expect(
      tester.renderObject(find.byKey(HouseView.wifeOutlineKey(0))),
      paints..path(color: color),
    );
    expect(find.text('Akinyi, married'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a named husband and wife have no outline', (tester) async {
    await pumpApp(
      tester,
      HouseView(
        house: model([const HouseRowModel(ordinal: 1, wifeName: 'Akinyi')]),
      ),
    );

    expect(find.byKey(HouseView.husbandOutlineKey), findsNothing);
    expect(find.byKey(HouseView.wifeOutlineKey(0)), findsNothing);
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
              'Kito, born to this house',
              'Pima, belongs to this house, same person, accounts differ',
            ],
          ),
        ]),
      ),
    );

    expect(find.text('Kito, born to this house'), findsOneWidget);
    expect(
      find.text('Pima, belongs to this house, same person, accounts differ'),
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

    for (final String heading in ['Rafa', 'House 1', 'House 2']) {
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
    expect(find.text('Rafa'), findsOneWidget);
    expect(find.text('not known yet'), findsNothing);
    expect(pressables(find.byType(HouseView)), findsNothing);
  });
}
