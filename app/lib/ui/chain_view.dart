import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tree/display_name.dart';
import '../tree/spoken_chain.dart';

/// The spoken chain as a plain list, one row per line, with the control for
/// the diagram under it.
///
/// Text wraps and is never cut short: no ellipsis and no line limit, so a long
/// name grows its row. A placeholder line gets a dashed outline, and so do the
/// words "someone we forgot" inside a line that names a forgotten father; a
/// disputed line reads as supplied, with no colour of its own.
class ChainView extends StatelessWidget {
  const ChainView({super.key, required this.lines, this.onShowDiagram});

  final List<ChainLine> lines;

  /// Called to show the diagram. Null while there is no diagram: the control
  /// is then disabled and says so in words.
  final VoidCallback? onShowDiagram;

  /// The key of the outlined row at [index], present only for placeholders.
  static Key placeholderKey(int index) => ValueKey('chain-placeholder-$index');

  /// The key of the outline around the forgotten father's words inside the
  /// line at [index], present only for lines with `fatherPlaceholder`.
  static Key forgottenSpanKey(int index) => ValueKey('chain-forgotten-$index');

  Widget _text(int index, TextStyle? style) {
    final ChainLine line = lines[index];
    final int start = line.text.lastIndexOf(forgottenName);
    if (!line.fatherPlaceholder || start < 0) {
      return Text(line.text, style: style);
    }
    return OutlinedSpanText(
      key: forgottenSpanKey(index),
      text: line.text,
      start: start,
      end: start + forgottenName.length,
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = theme.textTheme.bodyLarge;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (int i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: lines[i].placeholder
                ? CustomPaint(
                    key: placeholderKey(i),
                    painter: DashedOutlinePainter(
                      color: theme.colorScheme.outline,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _text(i, style),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: _text(i, style),
                  ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: onShowDiagram,
            child: Text(
              onShowDiagram == null
                  ? 'Diagram: not available yet'
                  : 'Show diagram',
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws a rounded rectangle just inside its box as separate dashes.
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({
    required this.color,
    this.dash = 6,
    this.gap = 4,
    this.strokeWidth = 1.5,
    this.radius = 8,
  });

  final Color color;
  final double dash;
  final double gap;
  final double strokeWidth;
  final double radius;

  /// The outline of a box of [size], cut into dashes. Each dash is its own
  /// sub-path.
  Path dashedPath(Size size) {
    final Rect box = (Offset.zero & size).deflate(strokeWidth / 2);
    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius(box, Radius.circular(radius)));
    final Path dashes = Path();
    for (final metric in outline.computeMetrics()) {
      for (double at = 0; at < metric.length; at += dash + gap) {
        dashes.addPath(
          metric.extractPath(at, math.min(at + dash, metric.length)),
          Offset.zero,
        );
      }
    }
    return dashes;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      dashedPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(DashedOutlinePainter old) =>
      old.color != color ||
      old.dash != dash ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

/// One piece of text, drawn as a single [Text] so it reads and wraps as
/// supplied, with a dashed outline around the characters from [start] to
/// [end]. A run that wraps onto another line is outlined once per line.
class OutlinedSpanText extends StatelessWidget {
  const OutlinedSpanText({
    super.key,
    required this.text,
    required this.start,
    required this.end,
    this.style,
  });

  final String text;

  /// The first outlined character, and the one after the last.
  final int start;
  final int end;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: SpanOutlinePainter(
        text: text,
        // The same style the Text below resolves to.
        style: DefaultTextStyle.of(context).style.merge(style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        start: start,
        end: end,
        color: Theme.of(context).colorScheme.outline,
      ),
      child: Text(text, style: style),
    );
  }
}

/// Paints the dashed outline of [OutlinedSpanText] over its text.
class SpanOutlinePainter extends CustomPainter {
  const SpanOutlinePainter({
    required this.text,
    required this.style,
    required this.textScaler,
    required this.textDirection,
    required this.start,
    required this.end,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final int start;
  final int end;
  final Color color;

  /// The boxes of the outlined run when the text is laid out [width] wide:
  /// one per line it falls on, each a little larger than the characters.
  List<Rect> boxes(double width) {
    final TextPainter layout = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: width);
    final List<TextBox> found = layout.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    layout.dispose();
    return [for (final TextBox b in found) b.toRect().inflate(2)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outline = DashedOutlinePainter(color: color);
    for (final Rect box in boxes(size.width)) {
      canvas.save();
      canvas.translate(box.left, box.top);
      outline.paint(canvas, box.size);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SpanOutlinePainter old) =>
      old.text != text ||
      old.style != style ||
      old.textScaler != textScaler ||
      old.textDirection != textDirection ||
      old.start != start ||
      old.end != end ||
      old.color != color;
}
