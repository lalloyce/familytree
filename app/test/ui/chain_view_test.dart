import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/tree/spoken_chain.dart';
import 'package:related/ui/chain_view.dart';
import 'package:related/ui/theme.dart';

import 'pump_app.dart';

ChainLine line(
  String text, {
  String id = 'p',
  bool disputed = false,
  bool placeholder = false,
}) => ChainLine(
  personId: id,
  text: text,
  disputed: disputed,
  placeholder: placeholder,
);

void main() {
  testWidgets('ChainView wraps a 200-character name at text scale 2.0 with no '
      'overflow and no ellipsis', (tester) async {
    // One 200-character word is the worst case: it has no space to break at.
    final String longWord = 'N' * 200;
    final String longSpaced = List.filled(25, "Nyang'or").join(' ');
    expect(longWord.length, 200);
    expect(longSpaced.length, 224);

    await pumpApp(
      tester,
      ChainView(
        lines: [
          line('$longWord, son of Winyo, house 2', id: 'a'),
          line('$longSpaced, daughter of someone we forgot', id: 'b'),
        ],
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
    for (final String s in [longWord, longSpaced]) {
      final Finder f = find.textContaining(s);
      expect(f, findsOneWidget);
      final RenderParagraph p = tester.renderObject<RenderParagraph>(f);
      expect(p.didExceedMaxLines, isFalse);
      // It wrapped inside the 360dp screen onto several lines.
      expect(tester.getSize(f).width, lessThanOrEqualTo(360));
      expect(tester.getSize(f).height, greaterThan(p.preferredLineHeight * 3));
    }
  });

  testWidgets('placeholder line shows dashed outline and the words '
      '"someone we forgot"', (tester) async {
    await pumpApp(
      tester,
      ChainView(
        lines: [
          line('Juma, son of someone we forgot', id: 'juma'),
          line('someone we forgot', id: 'ph', placeholder: true),
        ],
      ),
    );

    // The placeholder is line 1, and only it is outlined.
    final Finder outline = find.byKey(ChainView.placeholderKey(1));
    expect(outline, findsOneWidget);
    expect(find.byKey(ChainView.placeholderKey(0)), findsNothing);
    expect(
      find.descendant(of: outline, matching: find.text('someone we forgot')),
      findsOneWidget,
    );

    final CustomPaint paint = tester.widget<CustomPaint>(outline);
    final painter = paint.painter! as DashedOutlinePainter;
    expect(painter.dash, greaterThan(0));
    expect(painter.gap, greaterThan(0));
    // A dashed outline is many separate strokes, not one closed line.
    final Path dashes = painter.dashedPath(tester.getSize(outline));
    expect(dashes.computeMetrics().length, greaterThan(8));
    // And it is really painted.
    expect(tester.renderObject(outline), paints..path(color: painter.color));
  });

  testWidgets('a disputed line reads as supplied, in the normal text style', (
    tester,
  ) async {
    await pumpApp(
      tester,
      ChainView(
        lines: [
          line('Manyi, son of Winyo, house 2', id: 'm'),
          line('Winyo, accounts differ', id: 'w', disputed: true),
        ],
      ),
    );

    expect(find.text('Winyo, accounts differ'), findsOneWidget);
    final a = tester.widget<Text>(find.text('Manyi, son of Winyo, house 2'));
    final b = tester.widget<Text>(find.text('Winyo, accounts differ'));
    expect(b.style, a.style);
    expect(find.byKey(ChainView.placeholderKey(1)), findsNothing);
  });

  testWidgets('with no diagram callback the control is disabled and says why', (
    tester,
  ) async {
    await pumpApp(tester, ChainView(lines: [line('Manyi, son of Winyo')]));

    final Finder button = find.widgetWithText(
      TextButton,
      'Diagram: not available yet',
    );
    expect(button, findsOneWidget);
    expect(tester.widget<TextButton>(button).onPressed, isNull);
    expect(find.text('Show diagram'), findsNothing);
    // The reason is drawn in the theme's plain grey, not a faded disabled tint.
    final RenderParagraph label = tester.renderObject<RenderParagraph>(
      find.text('Diagram: not available yet'),
    );
    expect(
      label.text.style?.color,
      buildAppTheme().colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('with a diagram callback the control is enabled and fires', (
    tester,
  ) async {
    int taps = 0;
    await pumpApp(
      tester,
      ChainView(lines: const [], onShowDiagram: () => taps++),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Show diagram'));
    expect(taps, 1);
    expect(find.text('Diagram: not available yet'), findsNothing);
  });

  testWidgets('the diagram control comes after the last line', (tester) async {
    await pumpApp(
      tester,
      ChainView(
        lines: [
          line('A, son of B'),
          line('B, son of C', id: 'b'),
        ],
      ),
    );

    final double last = tester.getTopLeft(find.text('B, son of C')).dy;
    final double control = tester
        .getTopLeft(find.text('Diagram: not available yet'))
        .dy;
    expect(control, greaterThan(last));
  });

  testWidgets('an empty chain builds with no exception and only the control', (
    tester,
  ) async {
    await pumpApp(tester, const ChainView(lines: []));

    expect(tester.takeException(), isNull);
    expect(find.text('Diagram: not available yet'), findsOneWidget);
    expect(find.byKey(ChainView.placeholderKey(0)), findsNothing);
  });
}
