// The diagram view: draws a LayoutResult. No blur, shadow or animation.
// Basis and kind are words in the caption, never colour or line style alone.
import 'package:flutter/material.dart';

import 'layout.dart';

class DiagramView extends StatelessWidget {
  const DiagramView({super.key, required this.layout});

  final LayoutResult layout;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: layout.width,
            height: layout.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(layout.width, layout.height),
                  painter: _EdgePainter(layout.edges),
                ),
                for (final n in layout.nodes)
                  Positioned(
                    left: n.x,
                    top: n.y,
                    width: n.w,
                    child: DiagramNode(node: n),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiagramNode extends StatelessWidget {
  const DiagramNode({super.key, required this.node});

  final LayoutNode node;

  @override
  Widget build(BuildContext context) {
    final focus =
        node.role == NodeRole.husband || node.role == NodeRole.wife;
    return Container(
      constraints: BoxConstraints(minHeight: node.h),
      padding: const EdgeInsets.all(kNodePad),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: focus ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(node.name,
              softWrap: true,
              style: const TextStyle(
                  fontSize: kNameFont,
                  height: kLineHeight,
                  color: Colors.black87)),
          Text(node.caption,
              softWrap: true,
              style: const TextStyle(
                  fontSize: kCaptionFont,
                  height: kLineHeight,
                  color: Color(0xFF424242))),
        ],
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges);

  final List<LayoutEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;
    for (final e in edges) {
      canvas.drawLine(Offset(e.x1, e.y1), Offset(e.x2, e.y2), paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.edges != edges;
}
