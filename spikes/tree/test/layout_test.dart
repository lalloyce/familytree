import 'package:flutter_test/flutter_test.dart';
import 'package:tree_spike/gen.dart';
import 'package:tree_spike/layout.dart';

bool overlaps(LayoutNode a, LayoutNode b) =>
    a.x < b.right && b.x < a.right && a.y < b.bottom && b.y < a.bottom;

void expectNoOverlap(List<LayoutNode> nodes, String label) {
  // Sort by x and sweep, so the whole-tree case stays cheap.
  final s = [...nodes]..sort((a, b) => a.x.compareTo(b.x));
  for (var i = 0; i < s.length; i++) {
    for (var j = i + 1; j < s.length && s[j].x < s[i].right; j++) {
      expect(overlaps(s[i], s[j]), isFalse,
          reason: '$label: node ${s[i].personId} overlaps ${s[j].personId}');
    }
  }
}

void main() {
  late Dataset d;
  setUpAll(() => d = generate(seed: 1));

  test('a focused layout holds only the house, one generation up and one down',
      () {
    for (final h in d.houses) {
      final r = layoutFocusedHouse(d, h.id);
      final allowed = <int>{h.husbandId, h.wifeId, ...h.childIds};
      for (final person in [h.husbandId, h.wifeId]) {
        final fh = d.people[person].fatherHouse;
        if (fh != null) {
          allowed.add(d.houses[fh].husbandId);
          allowed.add(d.houses[fh].wifeId);
        }
      }
      expect(r.nodes.map((n) => n.personId).toSet(), allowed,
          reason: 'house ${h.id}');
      // Exactly one node per allowed person (no grandparents, no grandchildren).
      expect(r.nodes.length, allowed.length);
      expect(r.nodes.map((n) => n.row).toSet().difference({0, 1, 2}), isEmpty);
      for (final n in r.nodes) {
        switch (n.role) {
          case NodeRole.parent:
            expect(n.row, 0);
          case NodeRole.husband:
          case NodeRole.wife:
            expect(n.row, 1);
            expect(n.houseId, h.id);
          case NodeRole.child:
            expect(n.row, 2);
            expect(h.childIds, contains(n.personId));
        }
      }
    }
  });

  test('no focused node overlaps another, for every house at scales 1 and 2',
      () {
    for (final scale in [1.0, 2.0]) {
      for (final h in d.houses) {
        final r = layoutFocusedHouse(d, h.id, textScale: scale);
        expectNoOverlap(r.nodes, 'house ${h.id} scale $scale');
        for (final n in r.nodes) {
          expect(n.x, greaterThanOrEqualTo(0));
          expect(n.right, lessThanOrEqualTo(r.width + 1e-9));
          expect(n.bottom, lessThanOrEqualTo(r.height + 1e-9));
        }
      }
    }
  });

  test('the whole-tree stress layout places every person and does not overlap',
      () {
    final r = layoutWholeTree(d);
    final placed = r.nodes.map((n) => n.personId).toSet();
    expect(placed.length, d.people.length);
    expectNoOverlap(r.nodes, 'whole tree');
    final r2 = layoutWholeTree(d, textScale: 2.0);
    expectNoOverlap(r2.nodes, 'whole tree scale 2');
  });

  test('a 200 character name makes a taller node, never a clipped one', () {
    final long = 'Okello ' * 28; // 196 characters
    final short = estimateNodeHeight('Okello', 'son', 1.0);
    expect(estimateNodeHeight(long.trim(), 'son', 1.0), greaterThan(short));
    expect(estimateNodeHeight(long.trim(), 'son', 2.0),
        greaterThan(estimateNodeHeight(long.trim(), 'son', 1.0)));
  });

  test('the isolate result matches the in-process result', () async {
    final h = d.houses.firstWhere((h) => h.childIds.length == 6);
    final local = layoutFocusedHouse(d, h.id);
    final remote = await layoutFocusedInIsolate(d, h.id);
    expect(remote.nodes.length, local.nodes.length);
    for (var i = 0; i < local.nodes.length; i++) {
      expect(remote.nodes[i].personId, local.nodes[i].personId);
      expect(remote.nodes[i].x, local.nodes[i].x);
      expect(remote.nodes[i].y, local.nodes[i].y);
    }
  });
}
