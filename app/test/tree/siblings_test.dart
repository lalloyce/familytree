import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/tree/ancestors.dart';
import 'package:related/tree/siblings.dart';

import '../fixtures/winyo_family.dart';

/// The text of every string literal in Dart [source], comments excluded.
/// Handles single, double and triple quotes, raw strings and escapes. A
/// literal's text is its fixed part: an interpolation (`$name` or `${...}`)
/// is left out of it, and string literals nested inside `${...}` are
/// collected as literals of their own.
List<String> stringLiterals(String source) {
  final lexer = _Lexer(source)..lexCode(inInterpolation: false);
  return lexer.literals;
}

class _Lexer {
  _Lexer(this.source);

  final String source;
  final literals = <String>[];
  int i = 0;

  static final RegExp _identChar = RegExp(r'[A-Za-z0-9_]');

  /// Lexes code from [i]. With [inInterpolation], stops after the `}` that
  /// closes the enclosing `${`.
  void lexCode({required bool inInterpolation}) {
    int depth = 0;
    while (i < source.length) {
      final String c = source[i];
      if (source.startsWith('//', i)) {
        final int end = source.indexOf('\n', i);
        i = end == -1 ? source.length : end;
      } else if (source.startsWith('/*', i)) {
        final int end = source.indexOf('*/', i + 2);
        i = end == -1 ? source.length : end + 2;
      } else if (c == "'" || c == '"') {
        _lexString();
      } else if (c == '{') {
        depth++;
        i++;
      } else if (c == '}') {
        i++;
        if (inInterpolation && depth == 0) {
          return;
        }
        depth--;
      } else {
        i++;
      }
    }
  }

  /// Lexes the string literal that starts at [i].
  void _lexString() {
    final String c = source[i];
    final bool raw =
        i > 0 &&
        source[i - 1] == 'r' &&
        (i < 2 ||
            !(_identChar.hasMatch(source[i - 2]) || source[i - 2] == r'$'));
    final String quote = source.startsWith(c * 3, i) ? c * 3 : c;
    i += quote.length;
    final text = StringBuffer();
    while (i < source.length && !source.startsWith(quote, i)) {
      if (!raw && source[i] == r'\') {
        // A backslash escapes the next character.
        i += 2;
      } else if (!raw && source.startsWith(r'${', i)) {
        i += 2;
        lexCode(inInterpolation: true);
      } else if (!raw &&
          source[i] == r'$' &&
          i + 1 < source.length &&
          RegExp(r'[A-Za-z_]').hasMatch(source[i + 1])) {
        i++;
        while (i < source.length && _identChar.hasMatch(source[i])) {
          i++;
        }
      } else {
        text.write(source[i]);
        i++;
      }
    }
    i += quote.length;
    literals.add(text.toString());
  }
}

final RegExp _forbidden = RegExp(r'\b(step|half)\b', caseSensitive: false);

/// The string literals in [source] that hold the word "step" or "half".
List<String> forbiddenLiterals(String source) => [
  for (final s in stringLiterals(source))
    if (_forbidden.hasMatch(s)) s,
];

void main() {
  late AppDatabase db;
  late WinyoFamily f;

  setUp(() async {
    db = AppDatabase.memory();
    f = await buildWinyoFamily(db);
  });
  tearDown(() => db.close());

  Future<List<ClaimView>> views(ClaimKind kind) => activeClaimViews(db, kind);

  SiblingHouse houseOf(SiblingGroups g, String houseId) =>
      g.otherHouses.singleWhere((h) => h.houseId == houseId);

  test('Wade is in Manyi\'s sameHouse; Owala is under otherHouses '
      'ordinal 4, not sameHouse', () async {
    final SiblingGroups g = await siblingsOf(db, f.manyi);

    expect(g.sameHouse, [f.wade]);
    expect(g.sameHouse, isNot(contains(f.owala)));
    final SiblingHouse four = houseOf(g, f.winyoHouse4);
    expect(four.ordinal, 4);
    expect(four.personIds, [f.owala]);
    // Houses 1 and 3 are listed too, empty, in ordinal order.
    expect([for (final h in g.otherHouses) h.ordinal], [1, 3, 4]);
  });

  test('Obuolo is in Winyo\'s sameHouse; Olembo is under another '
      'house', () async {
    final SiblingGroups g = await siblingsOf(db, f.winyo);

    expect(g.sameHouse, [f.obuolo]);
    expect(g.sameHouse, isNot(contains(f.olembo)));
    expect(g.otherHouses, hasLength(1));
    expect(g.otherHouses.single.houseId, f.ochiengHouseOlembo);
    expect(g.otherHouses.single.ordinal, isNull);
    expect(g.otherHouses.single.personIds, [f.olembo]);
  });

  test('houses 1 and 3 exist with no wife claim and no children', () async {
    final houses = await db.select(db.houses).get();
    final byHusband = [
      for (final h in houses)
        if (h.husbandId == f.winyo) h,
    ];
    expect({for (final h in byHusband) h.ordinal}, {1, 2, 3, 4});

    final wives = await views(ClaimKind.wifeOfHouse);
    final children = await views(ClaimKind.belongsToHouse);
    for (final String id in [f.winyoHouse1, f.winyoHouse3]) {
      expect(byHusband.map((h) => h.id), contains(id));
      expect(wives.where((v) => v.claim.objectId == id), isEmpty);
      expect(children.where((v) => v.claim.objectId == id), isEmpty);
    }
    // House 2 has Atieno as wife, and house 4 has none ("not known").
    expect(
      [
        for (final v in wives)
          if (v.claim.objectId == f.winyoHouse2) v.claim.subjectId,
      ],
      [f.atieno],
    );
    expect(wives.where((v) => v.claim.objectId == f.winyoHouse4), isEmpty);
  });

  test('the aunt belongs to Manyi\'s house as a child and is wife of two '
      'houses; her children are in each of those houses', () async {
    final belongs = await views(ClaimKind.belongsToHouse);
    final wives = await views(ClaimKind.wifeOfHouse);

    // A child only in Manyi's house.
    expect(
      [
        for (final v in belongs)
          if (v.claim.subjectId == f.aunt) v.claim.objectId,
      ],
      [f.manyiHouse],
    );
    // Wife of exactly two houses.
    expect(
      {
        for (final v in wives)
          if (v.claim.subjectId == f.aunt) v.claim.objectId,
      },
      {f.auntHouseA, f.auntHouseB},
    );
    // Her children sit in those houses, one each.
    expect(
      [
        for (final v in belongs)
          if (v.claim.objectId == f.auntHouseA) v.claim.subjectId,
      ],
      [f.auntChildA],
    );
    expect(
      [
        for (final v in belongs)
          if (v.claim.objectId == f.auntHouseB) v.claim.subjectId,
      ],
      [f.auntChildB],
    );
    // The houses belong to A and B, who are brothers: same father house.
    final houses = {for (final h in await db.select(db.houses).get()) h.id: h};
    expect(houses[f.auntHouseA]!.husbandId, f.auntHusbandA);
    expect(houses[f.auntHouseB]!.husbandId, f.auntHusbandB);
    expect((await siblingsOf(db, f.auntHusbandA)).sameHouse, [f.auntHusbandB]);

    // She is never an ancestor of her children, and the walks end.
    for (final String child in [f.auntChildA, f.auntChildB]) {
      final steps = await ancestorsOf(db, child);
      expect(steps, isNotEmpty);
      expect(steps.map((s) => s.personId), isNot(contains(f.aunt)));
    }
    final auntSteps = await ancestorsOf(db, f.aunt);
    expect(auntSteps.first.personId, f.manyi);
    expect(auntSteps.map((s) => s.personId), isNot(contains(f.aunt)));
  });

  test('two people named Winyo are different ids and the chain from me '
      'reaches both', () async {
    expect(f.winyo, isNot(f.winyoElder));
    final names = {
      for (final p in await db.select(db.persons).get()) p.id: p.nameKey,
    };
    expect(names[f.winyo], 'Winyo');
    expect(names[f.winyoElder], 'Winyo');

    final steps = await ancestorsOf(db, f.me);

    expect(steps, hasLength(6));
    expect(steps.take(5).map((s) => s.personId), [
      f.juma,
      f.manyi,
      f.winyo,
      f.ochieng,
      f.winyoElder,
    ]);
    expect(steps.map((s) => s.houseId).take(4), [
      f.jumaHouse,
      f.manyiHouse,
      f.winyoHouse2,
      f.ochiengHouseWinyo,
    ]);
    // The last step is the one we forgot: a placeholder with no name.
    final persons = {
      for (final p in await db.select(db.persons).get()) p.id: p,
    };
    expect(persons[steps.last.personId]!.isPlaceholder, isTrue);
    expect(persons[steps.last.personId]!.nameKey, isNull);
    expect(steps.every((s) => !s.disputed), isTrue);
  });

  List<File> scannedFiles() => [
    for (final String dir in ['lib/ui', 'lib/tree'])
      if (Directory(dir).existsSync())
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'),
            ),
  ];

  test('the real scan examines the lib/tree sources', () {
    // A scan of nothing proves nothing.
    final files = scannedFiles();
    expect(files, isNotEmpty);
    expect(
      files.any((file) => file.path.endsWith('lib/tree/ancestors.dart')),
      isTrue,
    );
    expect(
      files.any((file) => file.path.endsWith('lib/tree/siblings.dart')),
      isTrue,
    );
  });

  test('no user-visible string in app/lib/ contains "step" or '
      '"half"', () async {
    final offenders = <String>[
      for (final file in scannedFiles())
        for (final s in forbiddenLiterals(file.readAsStringSync()))
          '${file.path}: $s',
    ];
    expect(offenders, isEmpty);
  });

  test('the scanner flags forbidden words in literals only', () {
    expect(forbiddenLiterals("final a = 'half brother';"), ['half brother']);
    expect(forbiddenLiterals('final b = "a step in the road";'), [
      'a step in the road',
    ]);
    expect(forbiddenLiterals(r"final c = 'Step ${x} of';"), ['Step  of']);
    expect(forbiddenLiterals("class AncestorStep {}"), isEmpty);
    expect(forbiddenLiterals("final d = 'AncestorStep';"), isEmpty);
    expect(
      forbiddenLiterals(
        "// the next step\n/* half a step */\nfinal e = 'father';",
      ),
      isEmpty,
    );
  });

  test('the scanner reads string literals nested in interpolation', () {
    expect(forbiddenLiterals(r"final g = '${f ? 'full' : 'half'} brother';"), [
      'half',
    ]);
    expect(forbiddenLiterals(r"final h = '${name} son';"), isEmpty);
    expect(forbiddenLiterals(r"final i = '$name son of ${a['k']}';"), isEmpty);
    // Braces inside the interpolation do not end it early.
    expect(forbiddenLiterals(r"final j = '${{'a': 1}['a']} ${'step'}';"), [
      'step',
    ]);
  });

  test('otherHouses sorts by ordinal with unknown last, ties by house '
      'id', () async {
    final b = HouseholdBuilder(
      db,
      ClaimService(db, accountId: 'sort'),
      accountId: 'sort',
    );
    final String husband = await b.addPerson();
    final String own = await b.addHouse(husbandId: husband, ordinal: 2);
    final String three = await b.addHouse(husbandId: husband, ordinal: 3);
    final String unknownA = await b.addHouse(husbandId: husband);
    final String one = await b.addHouse(husbandId: husband, ordinal: 1);
    final String unknownB = await b.addHouse(husbandId: husband);
    final String child = await b.addPerson();
    await b.placeChild(personId: child, houseId: own, basis: Basis.bornTo);

    final SiblingGroups g = await siblingsOf(db, child);

    expect(
      [for (final h in g.otherHouses) h.houseId],
      [
        one,
        three,
        ...[unknownA, unknownB]..sort(),
      ],
    );
    expect([for (final h in g.otherHouses) h.ordinal], [1, 3, null, null]);
  });

  test('wives are never counted as siblings', () async {
    // Juma's house holds only his sister; his sister's husbands' houses
    // hold their own children, not her.
    expect((await siblingsOf(db, f.juma)).sameHouse, [f.aunt]);
    for (final String child in [f.auntChildA, f.auntChildB]) {
      final SiblingGroups g = await siblingsOf(db, child);
      expect(g.sameHouse, isNot(contains(f.aunt)));
      for (final SiblingHouse h in g.otherHouses) {
        expect(h.personIds, isNot(contains(f.aunt)));
      }
    }
    // The aunt is a wife of both houses, so no group of her husband's
    // children lists her either.
    final SiblingGroups a = await siblingsOf(db, f.auntHusbandA);
    expect(a.sameHouse, [f.auntHusbandB]);
    expect([
      for (final h in a.otherHouses) ...h.personIds,
    ], isNot(contains(f.aunt)));
  });
}
