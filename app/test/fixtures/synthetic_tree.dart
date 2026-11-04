import 'dart:collection';
import 'dart:math';

import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';

/// The ids of a generated tree. See [buildSyntheticTree].
class SyntheticTree {
  const SyntheticTree({
    required this.personIds,
    required this.houseIds,
    required this.depths,
    required this.deepestPersonId,
    required this.focusHouseId,
    required this.twiceWifeIds,
    required this.daughterAndWifeIds,
  });

  /// Every person created, in creation order.
  final List<String> personIds;

  /// Every house created, in creation order.
  final List<String> houseIds;

  /// Length of each person's father line: 0 for a person with no recorded
  /// father house, 1 for a child of a root, and so on.
  final Map<String, int> depths;

  /// A person with the longest father line (the first created, on a tie).
  final String deepestPersonId;

  /// The house with the most children among the houses whose husband and
  /// wife both have a recorded father house: the same pick as spike 4.
  final String focusHouseId;

  /// Ten women, each the wife of two houses under two different husbands who
  /// are brothers (same father). Reading 1 of "20 women in two houses".
  final List<String> twiceWifeIds;

  /// Ten other women, each a daughter in one house and the wife of another.
  /// Reading 2 of "20 women in two houses".
  final List<String> daughterAndWifeIds;
}

/// Builds a deterministic family of exactly [persons] people in [db], through
/// [HouseholdBuilder], and returns the ids the scale check needs.
///
/// Same shape as `spikes/tree/lib/gen.dart`. A husband has 1 to 4 houses
/// (weights 50, 30, 15 and 5 percent), each house has one wife and 0 to 6
/// children, and the tree is generations deep. A person with no recorded
/// father house is a root: the founders and the wives who married into a
/// founder's house. Roots get no placeholder father, so the person count is
/// exact. The same [seed] gives the same shape; the ids are fresh UUIDs. The
/// spike's very-long-name branch (names of 80 or more characters) is not
/// reproduced. Rows are written as [accountId]; the app's own account is
/// 'local', so a tree meant to be opened as the app's own must pass that.
///
/// Ruling on "20 women who appear in two houses". The plan's wording is
/// ambiguous, so both readings are built, ten women each:
///
/// 1. [SyntheticTree.twiceWifeIds]: ten women who are the wife of two houses
///    of two different husbands, who are brothers.
/// 2. [SyntheticTree.daughterAndWifeIds]: ten women who are a daughter in one
///    house and the wife of another. In this model every married woman who
///    has a recorded father already fits this reading, so the ten are picked
///    from them (not from the first ten) and exist so a test can name them.
///
/// The two sets do not overlap, so 20 distinct women are named in all.
///
/// Rows are written through the builder in one transaction: every person,
/// then every house, then every `belongsToHouse` claim, then every
/// `wifeOfHouse` claim. If this ever takes too long on the host, the
/// fallback is direct Drift batch inserts of the same rows and claims.
Future<SyntheticTree> buildSyntheticTree(
  AppDatabase db, {
  int persons = 3000,
  int seed = 1,
  int twiceWives = 10,
  int daughterWives = 10,
  int founders = 3,
  String accountId = 'synthetic',
}) async {
  final _Plan plan = _plan(
    Random(seed),
    persons: persons,
    twiceWives: twiceWives,
    daughterWives: daughterWives,
    founders: founders,
  );
  final builder = HouseholdBuilder(
    db,
    ClaimService(db, accountId: accountId),
    accountId: accountId,
  );

  late List<String> personIds;
  late List<String> houseIds;
  await builder.atomically(() async {
    personIds = [
      for (final p in plan.people)
        await builder.addPerson(
          name: p.name,
          sex: p.female ? Sex.female : Sex.male,
        ),
    ];
    houseIds = [
      for (final h in plan.houses)
        await builder.addHouse(
          husbandId: personIds[h.husband],
          ordinal: h.order,
        ),
    ];
    for (int i = 0; i < plan.people.length; i++) {
      final int? fatherHouse = plan.people[i].fatherHouse;
      if (fatherHouse != null) {
        await builder.placeChild(
          personId: personIds[i],
          houseId: houseIds[fatherHouse],
          basis: Basis.bornTo,
        );
      }
    }
    for (int i = 0; i < plan.houses.length; i++) {
      await builder.addWife(
        wifeId: personIds[plan.houses[i].wife],
        houseId: houseIds[i],
      );
    }
  });

  return SyntheticTree(
    personIds: personIds,
    houseIds: houseIds,
    depths: {
      for (int i = 0; i < personIds.length; i++) personIds[i]: plan.depths[i],
    },
    deepestPersonId: personIds[plan.deepest],
    focusHouseId: houseIds[plan.focusHouse],
    twiceWifeIds: [for (final i in plan.twiceWives) personIds[i]],
    daughterAndWifeIds: [for (final i in plan.daughterWives) personIds[i]],
  );
}

class _Person {
  _Person(this.name, this.female, this.fatherHouse);

  final String name;
  final bool female;

  /// Index into [_Plan.houses], or null for a root.
  final int? fatherHouse;
}

class _House {
  _House(this.husband, this.wife, this.order);

  final int husband;
  final int wife;
  final int order;
  final List<int> children = [];
}

class _Plan {
  _Plan(
    this.people,
    this.houses,
    this.depths,
    this.deepest,
    this.focusHouse,
    this.twiceWives,
    this.daughterWives,
  );

  final List<_Person> people;
  final List<_House> houses;
  final List<int> depths;
  final int deepest;
  final int focusHouse;
  final List<int> twiceWives;
  final List<int> daughterWives;
}

const _maleNames = [
  'Deko', 'Rafa', 'Tembo', 'Kito', 'Pima', 'Lumo', 'Nuru', 'Seko',
  'Odhiambo', 'Otieno', 'Onyango', 'Omondi', 'Okoth', 'Ouma', 'Odongo',
  'Opiyo', 'Oloo', 'Ogola', 'Owino', 'Oduor', 'Okello', 'Ojwang', 'Odera',
  'Orwa', 'Oketch', 'Ombewa', //
];
const _femaleNames = [
  'Zawadi', 'Akinyi', 'Adhiambo', 'Awino', 'Anyango', 'Apiyo', 'Zuri',
  'Auma', 'Adoyo', 'Aoko', 'Atoo', 'Akoth', 'Adongo', 'Awuor', 'Anyim',
  'Ajwang', //
];

String _name(Random rng, bool female) {
  final pool = female ? _femaleNames : _maleNames;
  final String first = pool[rng.nextInt(pool.length)];
  final int r = rng.nextInt(1000);
  if (r < 20) {
    // About 2 percent carry extra given names, which exercises wrapping.
    final StringBuffer b = StringBuffer(first);
    for (int i = 0, n = 1 + rng.nextInt(3); i < n; i++) {
      b.write(' ${_maleNames[rng.nextInt(_maleNames.length)]}');
    }
    return b.toString();
  }
  return first;
}

/// The shape of the tree, with no database. Deterministic for [rng].
_Plan _plan(
  Random rng, {
  required int persons,
  required int twiceWives,
  required int daughterWives,
  required int founders,
}) {
  final people = <_Person>[];
  final houses = <_House>[];
  final queue = ListQueue<int>(); // men who may marry
  final pool = <int>[]; // unmarried daughters
  final housesOf = <int, List<int>>{}; // husband -> his house indices
  final wifeHouseCount = <int, int>{};

  bool full() => people.length >= persons;

  int addPerson(bool female, int? fatherHouse) {
    people.add(_Person(_name(rng, female), female, fatherHouse));
    return people.length - 1;
  }

  int? fatherOf(int id) {
    final int? fh = people[id].fatherHouse;
    return fh == null ? null : houses[fh].husband;
  }

  // A woman may not marry her own father, her brother (same father), or the
  // man whose mother she is.
  bool eligible(int woman, int man) {
    if (fatherOf(woman) == man) return false;
    final int? manFatherHouse = people[man].fatherHouse;
    if (manFatherHouse != null) {
      if (houses[manFatherHouse].wife == woman) return false;
      final int? womanFatherHouse = people[woman].fatherHouse;
      if (womanFatherHouse != null &&
          houses[womanFatherHouse].husband == houses[manFatherHouse].husband) {
        return false;
      }
    }
    return true;
  }

  int addHouse(int husband, int wife) {
    final list = housesOf.putIfAbsent(husband, () => []);
    houses.add(_House(husband, wife, list.length + 1));
    list.add(houses.length - 1);
    wifeHouseCount[wife] = (wifeHouseCount[wife] ?? 0) + 1;
    return houses.length - 1;
  }

  int? pickPoolWife(int man) {
    if (pool.isEmpty) return null;
    final int start = rng.nextInt(pool.length);
    for (int k = 0; k < pool.length; k++) {
      final int i = (start + k) % pool.length;
      if (eligible(pool[i], man)) {
        final int w = pool[i];
        pool[i] = pool.last;
        pool.removeLast();
        return w;
      }
    }
    return null;
  }

  void newFounder() {
    queue.add(addPerson(false, null));
  }

  for (int i = 0; i < founders && !full(); i++) {
    newFounder();
  }

  while (!full()) {
    if (queue.isEmpty) {
      newFounder();
      continue;
    }
    final int man = queue.removeFirst();
    final int r = rng.nextInt(100);
    final int wives = r < 50 ? 1 : (r < 80 ? 2 : (r < 95 ? 3 : 4));
    for (int k = 0; k < wives && !full(); k++) {
      final int wife;
      if (people[man].fatherHouse == null) {
        // A founder's wife has no recorded parents: she is a root.
        wife = addPerson(true, null);
      } else {
        final int? picked = pickPoolWife(man);
        if (picked == null) break; // no wife available: fewer houses
        wife = picked;
      }
      final int houseIndex = addHouse(man, wife);
      final int children = rng.nextInt(7);
      for (int c = 0; c < children && !full(); c++) {
        final bool female = rng.nextBool();
        final int id = addPerson(female, houseIndex);
        houses[houseIndex].children.add(id);
        if (female) {
          pool.add(id);
        } else if (rng.nextDouble() < 0.7) {
          queue.add(id);
        }
      }
    }
  }

  // Reading 1: wives of a man with a recorded father marry his brother too.
  // The second house has no children, which is a normal state in the model.
  final candidates = <int>[
    for (int h = 0; h < houses.length; h++)
      if (people[houses[h].wife].fatherHouse != null &&
          people[houses[h].husband].fatherHouse != null)
        h,
  ]..shuffle(rng);
  final twice = <int>[];
  for (final int h in candidates) {
    if (twice.length >= twiceWives) break;
    final int woman = houses[h].wife;
    final int husband = houses[h].husband;
    final int father = houses[people[husband].fatherHouse!].husband;
    final brothers = <int>[
      for (final int fh in housesOf[father] ?? const <int>[])
        for (final int c in houses[fh].children)
          if (c != husband &&
              !people[c].female &&
              (housesOf[c]?.length ?? 0) < 4 &&
              eligible(woman, c))
            c,
    ];
    if (brothers.isEmpty || wifeHouseCount[woman] != 1) continue;
    addHouse(brothers[rng.nextInt(brothers.length)], woman);
    twice.add(woman);
  }
  if (twice.length < twiceWives) {
    throw StateError(
      'only ${twice.length} of $twiceWives women could marry two brothers; '
      'use more people',
    );
  }

  // Reading 2: daughters of a recorded house who are wives of another house.
  final daughters = <int>[
    for (final h in candidates)
      if (wifeHouseCount[houses[h].wife] == 1 &&
          !twice.contains(houses[h].wife))
        houses[h].wife,
  ];
  if (daughters.length < daughterWives) {
    throw StateError(
      'only ${daughters.length} of $daughterWives daughters are wives; '
      'use more people',
    );
  }

  // Father line length. A father is always created before his children.
  final depths = List<int>.filled(people.length, 0);
  int deepest = 0;
  for (int i = 0; i < people.length; i++) {
    final int? father = fatherOf(i);
    depths[i] = father == null ? 0 : depths[father] + 1;
    if (depths[i] > depths[deepest]) deepest = i;
  }

  int focus = 0;
  int focusSize = -1;
  for (int h = 0; h < houses.length; h++) {
    final bool recorded =
        people[houses[h].wife].fatherHouse != null &&
        people[houses[h].husband].fatherHouse != null;
    if (recorded && houses[h].children.length > focusSize) {
      focus = h;
      focusSize = houses[h].children.length;
    }
  }

  return _Plan(
    people,
    houses,
    depths,
    deepest,
    focus,
    twice,
    daughters.sublist(0, daughterWives),
  );
}
