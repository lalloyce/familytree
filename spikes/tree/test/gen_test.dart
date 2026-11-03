import 'package:flutter_test/flutter_test.dart';
import 'package:tree_spike/gen.dart';

void main() {
  late Dataset d;
  setUpAll(() => d = generate(seed: 1));

  test('is deterministic for a seed and differs across seeds', () {
    expect(generate(seed: 1).fingerprint(), d.fingerprint());
    expect(generate(seed: 2).fingerprint(), isNot(d.fingerprint()));
  });

  test('produces exactly 3,000 people with ids equal to their index', () {
    expect(d.people.length, 3000);
    for (var i = 0; i < d.people.length; i++) {
      expect(d.people[i].id, i);
    }
  });

  test('exactly 20 women are wife in two houses, none in more than two', () {
    final counts = <int>[for (final w in d.wifeHouses) w.length];
    expect(counts.where((c) => c == 2).length, 20);
    expect(counts.where((c) => c > 2).length, 0);
    for (var i = 0; i < d.people.length; i++) {
      if (d.wifeHouses[i].length > 1) {
        expect(d.people[i].isFemale, isTrue);
        final husbands = d.wifeHouses[i].map((h) => d.houses[h].husbandId);
        expect(husbands.toSet().length, d.wifeHouses[i].length,
            reason: 'two different husbands');
      }
    }
  });

  test('every non-root person has a father house, and roots are few', () {
    for (final p in d.people) {
      if (d.rootIds.contains(p.id)) {
        expect(p.fatherHouse, isNull);
      } else {
        expect(p.fatherHouse, isNotNull, reason: 'person ${p.id}');
        expect(d.houses[p.fatherHouse!].childIds, contains(p.id));
      }
    }
    expect(d.rootIds, isNotEmpty);
    expect(d.rootIds.length, lessThanOrEqualTo(30));
  });

  test('houses follow the model: 1 to 4 per husband, 0 to 6 children', () {
    for (var i = 0; i < d.people.length; i++) {
      expect(d.husbandHouses[i].length, inInclusiveRange(0, 4));
      final orders = [for (final h in d.husbandHouses[i]) d.houses[h].order];
      expect(orders, [for (var k = 1; k <= orders.length; k++) k]);
    }
    for (final h in d.houses) {
      expect(h.childIds.length, inInclusiveRange(0, 6));
      expect(d.people[h.husbandId].isFemale, isFalse);
      expect(d.people[h.wifeId].isFemale, isTrue);
      expect(d.fatherOf(h.wifeId), isNot(h.husbandId));
    }
    expect(d.houses.any((h) => h.order == 4), isTrue);
    expect(d.houses.any((h) => h.childIds.length == 6), isTrue);
    expect(d.houses.any((h) => h.childIds.isEmpty), isTrue);
  });
}
