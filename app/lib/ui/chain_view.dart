import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tree/spoken_chain.dart';

/// The spoken chain as a plain list, one row per line, with the control for
/// the diagram under it.
///
/// Text wraps and is never cut short: no ellipsis and no line limit, so a long
/// name grows its row. A placeholder line gets a dashed outline; a disputed
/// line reads as supplied, with no colour of its own.
class ChainView extends StatelessWidget {
  const ChainView({super.key, required this.lines, this.onShowDiagram});

  final List<ChainLine> lines;

  /// Called to show the diagram. Null while there is no diagram: the control
  /// is then disabled and says so in words.
  final VoidCallback? onShowDiagram;

  /// The key of the outlined row at [index], present only for placeholders.
  static Key placeholderKey(int index) => ValueKey('chain-placeholder-$index');

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
                      child: Text(lines[i].text, style: style),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(lines[i].text, style: style),
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
