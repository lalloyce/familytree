import 'package:flutter/material.dart';

// Every colour the screens draw text or outlines with is defined here and
// checked against the page background in test/ui/theme_test.dart. Against
// white, the ink is 17:1, the plain grey 7:1, the link blue 8:1 and the
// outline grey 4.6:1. Button labels meet 4.5:1 in every state.
const Color _page = Color(0xFFFFFFFF);
const Color _ink = Color(0xFF1A1A1A);

/// The plain grey of "not known yet" and of the disabled diagram label.
const Color _plainGrey = Color(0xFF595959);
const Color _action = Color(0xFF0B4F8A);
const Color _outline = Color(0xFF757575);
const Color _divider = Color(0xFFBDBDBD);

/// The fill of elevated buttons and of a disabled filled button, a pale
/// grey-blue that both the action blue and the plain grey read well on.
const Color _tint = Color(0xFFEAEFF4);

/// Which WCAG threshold a [ContrastPair] must meet: 4.5:1 for body text, 3:1
/// for large text and for graphics such as an outline.
enum ContrastUse { bodyText, largeText, graphic }

/// A foreground and the background it is drawn on, taken from a theme.
class ContrastPair {
  const ContrastPair(this.name, this.foreground, this.background, this.use);

  final String name;
  final Color foreground;
  final Color background;
  final ContrastUse use;
}

/// Every foreground and background pair the screens draw, read from [theme]
/// itself so that the contrast test checks the colours the screens really use.
/// A screen that draws text in a colour not listed here is a bug.
List<ContrastPair> screenContrastPairs(ThemeData theme) {
  final Color page = theme.scaffoldBackgroundColor;
  final ButtonStyle button = theme.textButtonTheme.style!;
  return [
    ContrastPair(
      'body text',
      theme.textTheme.bodyLarge!.color!,
      page,
      ContrastUse.bodyText,
    ),
    ContrastPair(
      'heading',
      theme.textTheme.titleLarge!.color!,
      page,
      ContrastUse.largeText,
    ),
    ContrastPair(
      'not known yet and the disabled diagram label',
      theme.colorScheme.onSurfaceVariant,
      page,
      ContrastUse.bodyText,
    ),
    ContrastPair(
      'enabled diagram button label',
      button.foregroundColor!.resolve({})!,
      page,
      ContrastUse.bodyText,
    ),
    ..._buttonPairs('text', theme.textButtonTheme.style!, page),
    ..._buttonPairs('outlined', theme.outlinedButtonTheme.style!, page),
    ..._buttonPairs('elevated', theme.elevatedButtonTheme.style!, page),
    ..._buttonPairs('filled', theme.filledButtonTheme.style!, page),
    ContrastPair(
      'dashed outline and tag outline',
      theme.colorScheme.outline,
      page,
      ContrastUse.graphic,
    ),
  ];
}

/// The label and fill of a button style in its enabled and disabled states. A
/// style with no fill of its own is drawn on [page].
List<ContrastPair> _buttonPairs(String name, ButtonStyle style, Color page) => [
  for (final (String label, Set<WidgetState> states) in [
    ('enabled', <WidgetState>{}),
    ('disabled', {WidgetState.disabled}),
  ])
    ContrastPair(
      '$name button label, $label',
      style.foregroundColor!.resolve(states)!,
      style.backgroundColor?.resolve(states) ?? page,
      ContrastUse.bodyText,
    ),
];

/// Shows a new page at once: no slide, fade or zoom.
class _InstantTransitions extends PageTransitionsBuilder {
  const _InstantTransitions();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Flat buttons: no elevation or shadow, at least 48dp, and a plain grey
/// label when disabled so that it stays readable.
ButtonStyle _flatButton({Color? foreground, Color? fill}) => ButtonStyle(
  backgroundColor: fill == null
      ? null
      : WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? _tint : fill,
        ),
  elevation: const WidgetStatePropertyAll(0),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? _plainGrey
        : foreground ?? _action,
  ),
);

/// The light theme. There is no dark theme in the first release.
ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.light(
    primary: _action,
    onPrimary: _page,
    surface: _page,
    onSurface: _ink,
    onSurfaceVariant: _plainGrey,
    outline: _outline,
    outlineVariant: _divider,
    shadow: Colors.transparent,
    surfaceTint: Colors.transparent,
  );
  final ThemeData base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _page,
    shadowColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final TargetPlatform p in TargetPlatform.values)
          p: const _InstantTransitions(),
      },
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      backgroundColor: _page,
      foregroundColor: _ink,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _flatButton(fill: _tint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _flatButton(foreground: _page, fill: _action),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _flatButton()),
    textButtonTheme: TextButtonThemeData(style: _flatButton()),
  );
  // The system font scale applies as it is; only the colour is set.
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: _ink, displayColor: _ink),
  );
}
