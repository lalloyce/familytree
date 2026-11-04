// Synthetic family data for spike 4 (tree at scale). Throwaway.
//
// Model (design section 4): a husband has houses numbered by order, each house
// has one wife and 0 to 6 children. A woman is a child in her father's house
// and a wife in her husband's house. 20 women head two houses under two
// different husbands.
//
// Roots: a person with no recorded father house is a root. The generator
// starts from a few founders and their married-in wives (parents not
// recorded). Every other person has a father house. If the tree dies out
// before the target size, another founder is added, so the count is exact.
import 'dart:collection';
import 'dart:math';

class Person {
  const Person(this.id, this.name, this.isFemale, this.fatherHouse);

  final int id;
  final String name;
  final bool isFemale;

  /// Index into [Dataset.houses] of the house this person was born into,
  /// or null for a root.
  final int? fatherHouse;
}

class House {
  House(this.id, this.husbandId, this.wifeId, this.order, this.childIds);

  final int id;
  final int husbandId;
  final int wifeId;

  /// 1 to 4: the wife's number among this husband's houses.
  final int order;
  final List<int> childIds;
}

class Dataset {
  Dataset(this.people, this.houses, this.rootIds)
      : husbandHouses = List.generate(people.length, (_) => <int>[]),
        wifeHouses = List.generate(people.length, (_) => <int>[]) {
    for (final h in houses) {
      husbandHouses[h.husbandId].add(h.id);
      wifeHouses[h.wifeId].add(h.id);
    }
  }

  final List<Person> people;
  final List<House> houses;
  final Set<int> rootIds;

  /// Houses headed by a man, in order. Indexed by person id.
  final List<List<int>> husbandHouses;

  /// Houses a woman is the wife of. Indexed by person id.
  final List<List<int>> wifeHouses;

  /// Father of [personId] (husband of their father house), or null for a root.
  int? fatherOf(int personId) {
    final fh = people[personId].fatherHouse;
    return fh == null ? null : houses[fh].husbandId;
  }

  /// A stable text form, used to compare two generated datasets.
  String fingerprint() {
    final b = StringBuffer();
    for (final p in people) {
      b.write('${p.id}|${p.name}|${p.isFemale ? 1 : 0}|${p.fatherHouse};');
    }
    for (final h in houses) {
      b.write('${h.id}|${h.husbandId}|${h.wifeId}|${h.order}|'
          '${h.childIds.join(",")};');
    }
    return b.toString();
  }
}

const _maleNames = [
  'Deko', 'Rafa', 'Tembo', 'Kito', 'Pima', 'Lumo', 'Nuru', 'Seko',
  'Odhiambo', 'Otieno', 'Onyango', 'Omondi', 'Okoth', 'Ouma', 'Odongo',
  'Opiyo', 'Oloo', 'Ogola', 'Owino', 'Oduor', 'Okello', 'Ojwang', 'Odera',
  'Orwa', 'Oketch', 'Ombewa',
];
const _femaleNames = [
  'Zawadi', 'Akinyi', 'Adhiambo', 'Awino', 'Anyango', 'Apiyo', 'Zuri',
  'Auma', 'Adoyo', 'Aoko', 'Atoo', 'Akoth', 'Adongo', 'Awuor', 'Anyim',
  'Ajwang',
];

String _name(Random rng, bool female) {
  final pool = female ? _femaleNames : _maleNames;
  final first = pool[rng.nextInt(pool.length)];
  final r = rng.nextInt(1000);
  if (r < 20) {
    // About 2 percent carry extra given names, which exercises wrapping.
    final extra = 1 + rng.nextInt(3);
    final b = StringBuffer(first);
    for (var i = 0; i < extra; i++) {
      b.write(' ${_maleNames[rng.nextInt(_maleNames.length)]}');
    }
    return b.toString();
  }
  if (r < 22) {
    // About 0.2 percent carry a very long name (80+ characters).
    final b = StringBuffer(first);
    while (b.length < 85) {
      b.write(' ${_maleNames[rng.nextInt(_maleNames.length)]}');
    }
    return b.toString();
  }
  return first;
}

/// Generates exactly [people] people, deterministic for [seed].
///
/// Wives per husband: 1 to 4 (weights 50, 30, 15, 5). Children per house:
/// 0 to 6, uniform. Exactly [remarriedWomen] women are wives in two houses.
Dataset generate({
  int seed = 1,
  int people = 3000,
  int remarriedWomen = 20,
  int founders = 3,
  double sonMarriesProbability = 0.7,
}) {
  final rng = Random(seed);
  final ppl = <Person>[];
  final hs = <House>[];
  final roots = <int>{};
  final queue = ListQueue<int>();
  final pool = <int>[]; // unmarried daughters
  final wivesOnce = <int>[]; // women who are wife in exactly one house
  final housesOf = <int, int>{}; // husband id -> number of houses
  final firstHouseOfWife = <int, int>{}; // wife id -> her first house id
  var remarried = 0;

  bool full() => ppl.length >= people;

  int addPerson(bool female, int? fatherHouse) {
    final p = Person(ppl.length, _name(rng, female), female, fatherHouse);
    ppl.add(p);
    return p.id;
  }

  int? fatherOfPerson(int id) {
    final fh = ppl[id].fatherHouse;
    return fh == null ? null : hs[fh].husbandId;
  }

  // A woman may not marry her own father, her brother (same father), or the
  // man whose mother she is.
  bool eligible(int womanId, int manId) {
    if (fatherOfPerson(womanId) == manId) return false;
    final manFatherHouse = ppl[manId].fatherHouse;
    if (manFatherHouse != null) {
      if (hs[manFatherHouse].wifeId == womanId) return false;
      final womanFatherHouse = ppl[womanId].fatherHouse;
      if (womanFatherHouse != null &&
          hs[womanFatherHouse].husbandId == hs[manFatherHouse].husbandId) {
        return false;
      }
    }
    return true;
  }

  int addHouse(int husband, int wife) {
    final order = (housesOf[husband] ?? 0) + 1;
    housesOf[husband] = order;
    final id = hs.length;
    hs.add(House(id, husband, wife, order, <int>[]));
    return id;
  }

  int? pickPoolWife(int man) {
    if (pool.isEmpty) return null;
    final start = rng.nextInt(pool.length);
    for (var k = 0; k < pool.length; k++) {
      final i = (start + k) % pool.length;
      if (eligible(pool[i], man)) {
        final w = pool[i];
        pool[i] = pool.last;
        pool.removeLast();
        return w;
      }
    }
    return null;
  }

  int? pickRemarryWife(int man) {
    if (remarried >= remarriedWomen || wivesOnce.isEmpty) return null;
    final start = rng.nextInt(wivesOnce.length);
    for (var k = 0; k < wivesOnce.length; k++) {
      final i = (start + k) % wivesOnce.length;
      final w = wivesOnce[i];
      if (hs[firstHouseOfWife[w]!].husbandId != man && eligible(w, man)) {
        wivesOnce[i] = wivesOnce.last;
        wivesOnce.removeLast();
        remarried++;
        return w;
      }
    }
    return null;
  }

  void newFounder() {
    final id = addPerson(false, null);
    roots.add(id);
    queue.add(id);
  }

  for (var i = 0; i < founders && !full(); i++) {
    newFounder();
  }

  while (!full()) {
    if (queue.isEmpty) {
      newFounder();
      continue;
    }
    final man = queue.removeFirst();
    final r = rng.nextInt(100);
    final wives = r < 50 ? 1 : (r < 80 ? 2 : (r < 95 ? 3 : 4));
    for (var k = 0; k < wives && !full(); k++) {
      int wife;
      if (ppl[man].fatherHouse == null) {
        // A founder's wife has no recorded parents: she is a root.
        wife = addPerson(true, null);
        roots.add(wife);
        wivesOnce.add(wife);
      } else {
        // Remarriage is tried on 1 in 40 marriages until the quota is met.
        int? picked;
        if (rng.nextInt(40) == 0) picked = pickRemarryWife(man);
        picked ??= pickPoolWife(man);
        if (picked == null) break; // no wife available: fewer houses
        wife = picked;
        if (!firstHouseOfWife.containsKey(wife)) wivesOnce.add(wife);
      }
      final houseId = addHouse(man, wife);
      firstHouseOfWife.putIfAbsent(wife, () => houseId);

      final children = rng.nextInt(7);
      for (var c = 0; c < children && !full(); c++) {
        final female = rng.nextBool();
        final id = addPerson(female, houseId);
        hs[houseId].childIds.add(id);
        if (female) {
          pool.add(id);
        } else if (rng.nextDouble() < sonMarriesProbability) {
          queue.add(id);
        }
      }
    }
  }

  // Top up to the exact quota with childless second houses (an empty house is
  // a normal state in the model). Normally the loop above already met it.
  if (remarried < remarriedWomen) {
    final husbands = <int>[
      for (var i = 0; i < ppl.length; i++)
        if ((housesOf[i] ?? 0) >= 1 && (housesOf[i] ?? 0) < 4) i,
    ];
    var guard = 0;
    while (remarried < remarriedWomen && guard++ < 100000) {
      final man = husbands[rng.nextInt(husbands.length)];
      if ((housesOf[man] ?? 0) >= 4) continue;
      final w = pickRemarryWife(man);
      if (w != null) addHouse(man, w);
    }
  }

  return Dataset(ppl, hs, roots);
}
