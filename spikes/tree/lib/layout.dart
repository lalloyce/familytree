// Diagram layout for spike 4. Pure Dart (no dart:ui), so it runs in an isolate.
//
// Design section 7: the diagram draws only the focused house plus one
// generation each way. Names wrap, never truncate. No blur, shadow or
// animation. Node heights come from a text-wrap estimate (no TextPainter
// off the main thread); the diagram widget uses the same font size and line
// height so the estimate and the drawn text agree. `layoutWholeTree` is the
// stress variant: it lays out every person in the dataset, to test the
// "3,000 synthetic nodes" threshold literally.
import 'dart:isolate';
import 'dart:math';

import 'gen.dart';

const double kNodeWidth = 150;
const double kNodePad = 8;
const double kHGap = 12;
const double kVGap = 28;
const double kNameFont = 14;
const double kCaptionFont = 12;
const double kLineHeight = 1.3;

/// Average glyph width as a fraction of the font size. Deliberately on the
/// wide side so the estimate errs towards taller boxes.
const double kCharEm = 0.6;

enum NodeRole { husband, wife, parent, child }

class LayoutNode {
  LayoutNode({
    required this.personId,
    required this.houseId,
    required this.role,
    required this.row,
    required this.name,
    required this.caption,
    required this.w,
    required this.h,
    this.x = 0,
    this.y = 0,
  });

  final int personId;

  /// The house this placement belongs to (the focused house for the husband,
  /// wife and children; the parents' house for parent nodes).
  final int houseId;
  final NodeRole role;
  final int row;
  final String name;
  final String caption;
  final double w;
  final double h;
  double x;
  double y;

  double get right => x + w;
  double get bottom => y + h;
}

class LayoutEdge {
  const LayoutEdge(this.x1, this.y1, this.x2, this.y2);
  final double x1, y1, x2, y2;
}

class LayoutResult {
  const LayoutResult({
    required this.nodes,
    required this.edges,
    required this.width,
    required this.height,
    required this.computeMicros,
  });

  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final double width;
  final double height;

  /// Time spent inside the layout function, measured where it ran.
  final int computeMicros;
}

/// Greedy word wrap on an average glyph width. Returns the line count.
int estimateLines(String text, double maxWidth, double fontSize) {
  final perLine = max(1, (maxWidth / (fontSize * kCharEm)).floor());
  var total = 0;
  for (final para in text.split('\n')) {
    var lines = 1;
    var cur = 0;
    for (final word in para.split(' ')) {
      final len = word.length;
      if (len == 0) continue;
      if (cur == 0) {
        // start of a line
      } else if (cur + 1 + len <= perLine) {
        cur += 1 + len;
        continue;
      } else {
        lines++;
        cur = 0;
      }
      if (len <= perLine) {
        cur = len;
      } else {
        final extra = (len - 1) ~/ perLine;
        lines += extra;
        cur = len - extra * perLine;
      }
    }
    total += lines;
  }
  return total;
}

double estimateNodeHeight(String name, String caption, double textScale) {
  const inner = kNodeWidth - 2 * kNodePad;
  final nf = kNameFont * textScale;
  final cf = kCaptionFont * textScale;
  final nameH = estimateLines(name, inner, nf) * nf * kLineHeight;
  final capH = estimateLines(caption, inner, cf) * cf * kLineHeight;
  return max(48.0, 2 * kNodePad + nameH + capH);
}

LayoutNode _node(Dataset d, int personId, int houseId, NodeRole role, int row,
    String caption, double textScale) {
  final name = d.people[personId].name;
  return LayoutNode(
    personId: personId,
    houseId: houseId,
    role: role,
    row: row,
    name: name,
    caption: caption,
    w: kNodeWidth,
    h: estimateNodeHeight(name, caption, textScale),
  );
}

String _sonOrDaughter(Person p) => p.isFemale ? 'daughter' : 'son';

/// Lays out [houseId] with one generation up (the parents of the husband and
/// of the wife) and one generation down (the children).
///
/// Rows: 0 parents, 1 husband and wife, 2 children. Every row is centred on
/// the widest row. Nodes in a row are laid left to right with a fixed gap, so
/// no two nodes overlap by construction (the test checks it anyway).
LayoutResult layoutFocusedHouse(Dataset d, int houseId,
    {double textScale = 1.0}) {
  final sw = Stopwatch()..start();
  final house = d.houses[houseId];
  final rows = <List<LayoutNode>>[<LayoutNode>[], <LayoutNode>[], <LayoutNode>[]];

  void addParents(int personId, String who) {
    final fh = d.people[personId].fatherHouse;
    if (fh == null) return;
    final ph = d.houses[fh];
    rows[0].add(_node(d, ph.husbandId, fh, NodeRole.parent, 0,
        '$who father', textScale));
    rows[0].add(_node(d, ph.wifeId, fh, NodeRole.parent, 0,
        '$who mother, house ${ph.order}', textScale));
  }

  addParents(house.husbandId, 'his');
  addParents(house.wifeId, 'her');

  rows[1].add(_node(d, house.husbandId, houseId, NodeRole.husband, 1,
      'husband', textScale));
  final headsTwo = d.wifeHouses[house.wifeId].length > 1;
  rows[1].add(_node(d, house.wifeId, houseId, NodeRole.wife, 1,
      'wife, house ${house.order}${headsTwo ? ', same person' : ''}',
      textScale));

  for (final c in house.childIds) {
    rows[2].add(_node(d, c, houseId, NodeRole.child, 2,
        _sonOrDaughter(d.people[c]), textScale));
  }

  double rowWidth(List<LayoutNode> r) =>
      r.isEmpty ? 0 : r.length * kNodeWidth + (r.length - 1) * kHGap;
  final width = rows.map(rowWidth).fold<double>(0, max);

  var y = 0.0;
  final nodes = <LayoutNode>[];
  final rowTop = <double>[];
  final rowBottom = <double>[];
  for (final r in rows) {
    if (r.isEmpty) {
      rowTop.add(y);
      rowBottom.add(y);
      continue;
    }
    final rowH = r.map((n) => n.h).fold<double>(0, max);
    var x = (width - rowWidth(r)) / 2;
    for (final n in r) {
      n.x = x;
      n.y = y;
      x += kNodeWidth + kHGap;
      nodes.add(n);
    }
    rowTop.add(y);
    rowBottom.add(y + rowH);
    y += rowH + kVGap;
  }
  final height = nodes.isEmpty ? 0.0 : y - kVGap;

  // Edges: each parent pair to the person it produced; the house to each child.
  final edges = <LayoutEdge>[];
  final husband = rows[1][0];
  final wifeNode = rows[1][1];
  final parents = rows[0];
  for (var i = 0; i + 1 < parents.length; i += 2) {
    final a = parents[i];
    final b = parents[i + 1];
    final child = i == 0 && d.people[house.husbandId].fatherHouse != null
        ? husband
        : wifeNode;
    edges.add(LayoutEdge((a.x + b.right) / 2, rowBottom[0],
        child.x + child.w / 2, child.y));
  }
  final midX = (husband.x + wifeNode.right) / 2;
  final midY = max(husband.bottom, wifeNode.bottom);
  for (final c in rows[2]) {
    edges.add(LayoutEdge(midX, midY, c.x + c.w / 2, c.y));
  }

  sw.stop();
  return LayoutResult(
    nodes: nodes,
    edges: edges,
    width: width,
    height: height,
    computeMicros: sw.elapsedMicroseconds,
  );
}

/// Stress variant: lays out every person in [d] as a descendant tree. Each man
/// is one node; below him sit his houses' wives, and below each wife her
/// children. A daughter is a leaf; a son who heads houses repeats the pattern.
/// Subtrees occupy disjoint x ranges, so nothing overlaps by construction.
LayoutResult layoutWholeTree(Dataset d, {double textScale = 1.0}) {
  final sw = Stopwatch()..start();
  final manW = List<double>.filled(d.people.length, -1);
  final houseW = List<double>.filled(d.houses.length, -1);

  // Forward declaration: houseWidth and personWidth are mutually recursive.
  late double Function(int) personWidth;

  double houseWidth(int hid) {
    if (houseW[hid] >= 0) return houseW[hid];
    var sum = 0.0;
    final kids = d.houses[hid].childIds;
    for (var i = 0; i < kids.length; i++) {
      sum += (i > 0 ? kHGap : 0) + personWidth(kids[i]);
    }
    return houseW[hid] = max(kNodeWidth, sum);
  }

  personWidth = (int pid) {
    if (manW[pid] >= 0) return manW[pid];
    final hs = d.husbandHouses[pid];
    var sum = 0.0;
    for (var i = 0; i < hs.length; i++) {
      sum += (i > 0 ? kHGap : 0) + houseWidth(hs[i]);
    }
    return manW[pid] = max(kNodeWidth, sum);
  };

  final nodes = <LayoutNode>[];

  void place(int pid, double x0, int row, NodeRole role, int houseId) {
    final w = personWidth(pid);
    final p = d.people[pid];
    final caption = role == NodeRole.child
        ? _sonOrDaughter(p)
        : 'earliest we know of';
    final n = _node(d, pid, houseId, role, row, caption, textScale);
    n.x = x0 + (w - kNodeWidth) / 2;
    nodes.add(n);
    final hs = d.husbandHouses[pid];
    var cursor = x0;
    if (hs.isNotEmpty) {
      var total = 0.0;
      for (var i = 0; i < hs.length; i++) {
        total += (i > 0 ? kHGap : 0) + houseWidth(hs[i]);
      }
      cursor = x0 + (w - total) / 2;
    }
    for (final hid in hs) {
      final hw = houseWidth(hid);
      final house = d.houses[hid];
      final wn = _node(d, house.wifeId, hid, NodeRole.wife, row + 1,
          'wife, house ${house.order}', textScale);
      wn.x = cursor + (hw - kNodeWidth) / 2;
      nodes.add(wn);
      final kids = d.houses[hid].childIds;
      var kidsTotal = 0.0;
      for (var i = 0; i < kids.length; i++) {
        kidsTotal += (i > 0 ? kHGap : 0) + personWidth(kids[i]);
      }
      var kx = cursor + (hw - kidsTotal) / 2;
      for (final c in kids) {
        place(c, kx, row + 2, NodeRole.child, hid);
        kx += personWidth(c) + kHGap;
      }
      cursor += hw + kHGap;
    }
  }

  var x = 0.0;
  final roots = d.rootIds.toList()..sort();
  for (final r in roots) {
    // Root wives are placed as wives of their husband's houses, not as trees.
    if (d.people[r].isFemale) continue;
    place(r, x, 0, NodeRole.husband, -1);
    x += personWidth(r) + kHGap;
  }
  final width = x > 0 ? x - kHGap : 0.0;

  // Row heights, then y.
  var maxRow = 0;
  for (final n in nodes) {
    maxRow = max(maxRow, n.row);
  }
  final rowH = List<double>.filled(maxRow + 1, 0);
  for (final n in nodes) {
    rowH[n.row] = max(rowH[n.row], n.h);
  }
  final rowY = List<double>.filled(maxRow + 1, 0);
  var y = 0.0;
  for (var i = 0; i <= maxRow; i++) {
    rowY[i] = y;
    y += rowH[i] + kVGap;
  }
  for (final n in nodes) {
    n.y = rowY[n.row];
  }
  sw.stop();
  return LayoutResult(
    nodes: nodes,
    edges: const [],
    width: width,
    height: y - kVGap,
    computeMicros: sw.elapsedMicroseconds,
  );
}

/// Runs [layoutFocusedHouse] in a fresh isolate. The closure captures [d], so
/// the whole dataset is copied into the isolate: this is the worst case for
/// transfer cost. In the app, pass only the neighbourhood.
Future<LayoutResult> layoutFocusedInIsolate(Dataset d, int houseId,
    {double textScale = 1.0}) {
  return Isolate.run(
      () => layoutFocusedHouse(d, houseId, textScale: textScale));
}

Future<LayoutResult> layoutWholeTreeInIsolate(Dataset d,
    {double textScale = 1.0}) {
  return Isolate.run(() => layoutWholeTree(d, textScale: textScale));
}
