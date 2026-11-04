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
  bool fatherPlaceholder = false,
}) => ChainLine(
  personId: id,
  text: text,
  disputed: disputed,
  placeholder: placeholder,
  fatherPlaceholder: fatherPlaceholder,
);

void main() {
  testWidgets('ChainView wraps a 200-character name at text scale 2.0 with no '
      'overflow and no ellipsis', (tester) async {
    // One 200-character word is the worst case: it has no space to break at.
    final String longWord = 'N' * 200;
    final String longSpaced = List.filled(25, 'Borabora').join(' ');
    expect(longWord.length, 200);
    expect(longSpaced.length, 224);

    await pumpApp(
      tester,
      ChainView(
        lines: [
          line('$longWord, son of Rafa, house 2', id: 'a'),
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
          line('Tembo, son of someone we forgot', id: 'tembo'),
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

  testWidgets('a forgotten father is outlined inside the line, and the line '
      'still reads as one piece of text', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpApp(
      tester,
      ChainView(
        lines: [
          line(
            'Rafa, son of someone we forgot',
            id: 'w',
            fatherPlaceholder: true,
          ),
          line('Tembo, son of Kito', id: 'j'),
          line(
            "Nuru, belongs to someone we forgot's house",
            id: 'o',
            fatherPlaceholder: true,
          ),
        ],
      ),
    );

    final Finder span = find.byKey(ChainView.forgottenSpanKey(0));
    expect(span, findsOneWidget);
    expect(find.byKey(ChainView.forgottenSpanKey(1)), findsNothing);
    expect(find.byKey(ChainView.forgottenSpanKey(2)), findsOneWidget);
    // No whole-line outline: the person on the line is not a placeholder.
    expect(find.byKey(ChainView.placeholderKey(0)), findsNothing);
    // The text is one widget, unchanged and complete.
    expect(find.text('Rafa, son of someone we forgot'), findsOneWidget);
    expect(find.text('someone we forgot'), findsNothing);
    expect(
      tester.getSemantics(find.text('Rafa, son of someone we forgot')).label,
      'Rafa, son of someone we forgot',
    );
    // The outline is really painted, as separate dashes, in the outline
    // colour, and only around the words, not the whole line.
    final Color color = buildAppTheme().colorScheme.outline;
    expect(tester.renderObject(span), paints..path(color: color));
    final Size size = tester.getSize(span);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(of: span, matching: find.byType(CustomPaint)),
                )
                .foregroundPainter!
            as SpanOutlinePainter;
    final List<Rect> boxes = painter.boxes(size.width);
    // The test font is wide, so the line wraps inside the 360dp screen; the
    // outline stays inside the text, one box per line the words fall on.
    expect(boxes, isNotEmpty);
    for (final Rect box in boxes) {
      expect(box.right, lessThanOrEqualTo(size.width + 2));
      expect(box.top, greaterThanOrEqualTo(-2));
      expect(box.bottom, lessThanOrEqualTo(size.height + 2));
    }
    semantics.dispose();
  });

  test('the outline covers the chosen words only', () {
    const String text = 'Rafa, son of someone we forgot';
    const SpanOutlinePainter painter = SpanOutlinePainter(
      text: text,
      style: TextStyle(fontSize: 14),
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
      start: 14,
      end: 31,
      color: Color(0xFF000000),
    );
    TestWidgetsFlutterBinding.ensureInitialized();

    // Wide enough for one line: one box, after "Rafa, son of ", to the end.
    final List<Rect> one = painter.boxes(2000);
    expect(one, hasLength(1));
    final List<Rect> all = SpanOutlinePainter(
      text: text,
      style: painter.style,
      textScaler: TextScaler.noScaling,
      textDirection: TextDirection.ltr,
      start: 0,
      end: text.length,
      color: painter.color,
    ).boxes(2000);
    expect(one.single.left, greaterThan(all.single.left + 20));
    expect(one.single.right, closeTo(all.single.right, 4));
  });

  testWidgets('the outlined words keep wrapping at text scale 2.0, with no '
      'ellipsis', (tester) async {
    final String name = List.filled(12, "Bora").join(' ');
    await pumpApp(
      tester,
      ChainView(
        lines: [
          line(
            '$name, son of someone we forgot',
            id: 'a',
            fatherPlaceholder: true,
          ),
        ],
      ),
      textScale: 2.0,
      height: 3000,
    );

    expect(tester.takeException(), isNull);
    final Finder f = find.text('$name, son of someone we forgot');
    final RenderParagraph p = tester.renderObject<RenderParagraph>(f);
    expect(p.didExceedMaxLines, isFalse);
    expect(tester.getSize(f).width, lessThanOrEqualTo(360));
    expect(tester.getSize(f).height, greaterThan(p.preferredLineHeight * 3));
    expect(find.byKey(ChainView.forgottenSpanKey(0)), findsOneWidget);
    expect(
      tester.renderObject(find.byKey(ChainView.forgottenSpanKey(0))),
      paints..path(),
    );
  });

  testWidgets('a disputed line reads as supplied, in the normal text style', (
    tester,
  ) async {
    await pumpApp(
      tester,
      ChainView(
        lines: [
          line('Kito, son of Rafa, house 2', id: 'm'),
          line('Rafa, accounts differ', id: 'w', disputed: true),
        ],
      ),
    );

    expect(find.text('Rafa, accounts differ'), findsOneWidget);
    final a = tester.widget<Text>(find.text('Kito, son of Rafa, house 2'));
    final b = tester.widget<Text>(find.text('Rafa, accounts differ'));
    expect(b.style, a.style);
    expect(find.byKey(ChainView.placeholderKey(1)), findsNothing);
  });

  testWidgets('with no diagram callback the control is disabled and says why', (
    tester,
  ) async {
    await pumpApp(tester, ChainView(lines: [line('Kito, son of Rafa')]));

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
