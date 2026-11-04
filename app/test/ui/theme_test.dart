import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/ui/theme.dart';

/// WCAG 2.x relative luminance of an opaque sRGB colour.
double luminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// WCAG contrast ratio, from 1 (none) to 21 (black on white).
double contrastRatio(Color a, Color b) {
  final double la = luminance(a);
  final double lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final ThemeData theme = buildAppTheme();

  // The thresholds are written out here, not read from theme.dart, so a
  // weaker threshold there cannot pass.
  double threshold(ContrastUse use) => switch (use) {
    ContrastUse.bodyText => 4.5,
    ContrastUse.largeText => 3.0,
    ContrastUse.graphic => 3.0,
  };

  test('the contrast helper matches the WCAG reference values', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.001),
    );
    expect(
      contrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF123456), const Color(0xFF123456)),
      closeTo(1, 0.001),
    );
  });

  test('every text and background pair the screens use meets WCAG', () {
    final pairs = screenContrastPairs(theme);
    expect(pairs, isNotEmpty);
    for (final p in pairs) {
      expect(p.foreground.a, 1.0, reason: '${p.name}: foreground is opaque');
      expect(p.background.a, 1.0, reason: '${p.name}: background is opaque');
      expect(
        contrastRatio(p.foreground, p.background),
        greaterThanOrEqualTo(threshold(p.use)),
        reason: p.name,
      );
    }
  });

  test('the pairs cover body, muted, heading, button and outline use', () {
    final names = [for (final p in screenContrastPairs(theme)) p.name];
    expect(
      names,
      containsAll([
        'body text',
        'heading',
        'not known yet and the disabled diagram label',
        'enabled diagram button label',
        'dashed outline and tag outline',
      ]),
    );
  });

  test('every button the theme styles has a pair for both states', () {
    final names = [for (final p in screenContrastPairs(theme)) p.name];
    for (final kind in ['text', 'outlined', 'elevated', 'filled']) {
      for (final state in ['enabled', 'disabled']) {
        expect(names, contains('$kind button label, $state'));
      }
    }
  });

  test('a button label reads at 4.5:1 in every state, on its own fill', () {
    final styles = {
      'text': theme.textButtonTheme.style!,
      'outlined': theme.outlinedButtonTheme.style!,
      'elevated': theme.elevatedButtonTheme.style!,
      'filled': theme.filledButtonTheme.style!,
    };
    final states = <Set<WidgetState>>[
      {},
      {WidgetState.disabled},
      {WidgetState.hovered},
      {WidgetState.focused},
      {WidgetState.pressed},
    ];
    for (final e in styles.entries) {
      for (final s in states) {
        final Color fg = e.value.foregroundColor!.resolve(s)!;
        final Color bg =
            e.value.backgroundColor?.resolve(s) ??
            theme.scaffoldBackgroundColor;
        expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '${e.key} button in $s',
        );
      }
    }
  });

  test('the pairs are read from the theme the app really uses', () {
    final pairs = {for (final p in screenContrastPairs(theme)) p.name: p};
    expect(pairs['body text']!.foreground, theme.textTheme.bodyLarge!.color);
    expect(pairs['body text']!.background, theme.scaffoldBackgroundColor);
    expect(
      pairs['not known yet and the disabled diagram label']!.foreground,
      theme.colorScheme.onSurfaceVariant,
    );
    final style = theme.textButtonTheme.style!;
    expect(
      pairs['not known yet and the disabled diagram label']!.foreground,
      style.foregroundColor!.resolve({WidgetState.disabled}),
    );
    expect(
      pairs['enabled diagram button label']!.foreground,
      style.foregroundColor!.resolve({}),
    );
  });

  test('body text and plain grey are readable on the page background', () {
    final Color page = theme.scaffoldBackgroundColor;
    expect(
      contrastRatio(theme.textTheme.bodyLarge!.color!, page),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(theme.colorScheme.onSurfaceVariant, page),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('the theme is light, with no elevation or shadow anywhere', () {
    expect(theme.brightness, Brightness.light);
    expect(theme.shadowColor, Colors.transparent);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    for (final ButtonStyle? s in [
      theme.elevatedButtonTheme.style,
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
    ]) {
      expect(s, isNotNull);
      expect(s!.elevation!.resolve({}), 0);
      expect(s.elevation!.resolve({WidgetState.pressed}), 0);
      expect(s.shadowColor!.resolve({}), Colors.transparent);
    }
  });

  test('there is no ripple, and tap targets are padded to 48dp', () {
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.splashColor, Colors.transparent);
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    for (final ButtonStyle? s in [
      theme.elevatedButtonTheme.style,
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
    ]) {
      expect(s!.minimumSize!.resolve({}), const Size(48, 48));
    }
  });

  testWidgets('a button measures at least 48 by 48dp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: () {}, child: Text('a')),
          ),
        ),
      ),
    );
    final Size size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('pages change with no transition animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const Text('second')),
            ),
            child: const Text('first'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('first'));
    // One frame with no time passing: a zero-length transition is already
    // done, so the new page is on stage and the old one is gone.
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
    expect(
      theme.pageTransitionsTheme.builders.values
          .map((b) => b.transitionDuration)
          .toSet(),
      {Duration.zero},
    );
  });
}
