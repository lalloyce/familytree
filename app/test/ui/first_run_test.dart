import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/claims/claim_service.dart';
import 'package:related/claims/household_builder.dart';
import 'package:related/data/database.dart';
import 'package:related/ui/first_run.dart';

import 'pump_app.dart';

/// A builder that notes each call it receives, in order.
class _RecordingBuilder extends HouseholdBuilder {
  _RecordingBuilder(AppDatabase db)
    : super(db, ClaimService(db, accountId: 'x'), accountId: 'x');

  final List<String> calls = [];

  /// When true, the next `placeChild` throws once, then it works again.
  bool failNextPlaceChild = false;

  @override
  Future<String> addPerson({String? name, Sex? sex}) {
    calls.add('addPerson($name, ${sex?.name})');
    return super.addPerson(name: name, sex: sex);
  }

  @override
  Future<String> addPlaceholder({Sex? sex}) {
    calls.add('addPlaceholder(${sex?.name})');
    return super.addPlaceholder(sex: sex);
  }

  @override
  Future<String> addHouse({required String husbandId, int? ordinal}) {
    calls.add('addHouse($ordinal)');
    return super.addHouse(husbandId: husbandId, ordinal: ordinal);
  }

  @override
  Future<void> placeChild({
    required String personId,
    required String houseId,
    required Basis basis,
  }) {
    calls.add('placeChild(${basis.name})');
    if (failNextPlaceChild) {
      failNextPlaceChild = false;
      throw StateError('placeChild failed');
    }
    return super.placeChild(personId: personId, houseId: houseId, basis: basis);
  }
}

void main() {
  late AppDatabase db;
  late _RecordingBuilder builder;
  late List<String> saved;

  setUp(() {
    db = AppDatabase.memory();
    builder = _RecordingBuilder(db);
    saved = [];
  });
  tearDown(() => db.close());

  // A tall page keeps the whole form built, so every control can be found.
  Future<void> pumpForm(
    WidgetTester tester, {
    double textScale = 1.0,
    Future<void> Function(String)? remember,
  }) => pumpApp(
    tester,
    FirstRunScreen(builder: builder, remember: remember, onSaved: saved.add),
    textScale: textScale,
    height: textScale > 1 ? 4000 : 1400,
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(FirstRunScreen.saveKey));
    // Drift runs on real time, outside the test's fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, Key field, String text) async {
    await tester.enterText(find.byKey(field), text);
  }

  Future<List<PersonRow>> people() => db.select(db.persons).get();
  Future<List<HouseRow>> houses() => db.select(db.houses).get();
  Future<List<ClaimRow>> claims() => db.select(db.claims).get();

  testWidgets('FirstRunScreen with an empty database lets the user save with '
      'father unknown and creates a fresh placeholder father and house', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.tap(find.byKey(FirstRunScreen.fatherUnknownKey));
    await tester.pump();
    await type(tester, FirstRunScreen.nameKey, 'Lawrence');
    await tester.tap(find.text('Son'));
    await tester.pump();
    await save(tester);

    final List<PersonRow> all = (await tester.runAsync(people))!;
    final List<PersonRow> placeholders = [
      for (final p in all)
        if (p.isPlaceholder) p,
    ];
    expect(all, hasLength(2));
    expect(placeholders, hasLength(1));
    expect(placeholders.single.sex, Sex.male);
    final PersonRow me = all.singleWhere((p) => !p.isPlaceholder);
    expect(me.nameKey, 'Lawrence');
    expect(me.sex, Sex.male);

    final List<HouseRow> hs = (await tester.runAsync(houses))!;
    expect(hs, hasLength(1));
    expect(hs.single.husbandId, placeholders.single.id);
    expect(hs.single.ordinal, isNull);

    final List<ClaimRow> cs = (await tester.runAsync(claims))!;
    expect(cs, hasLength(1));
    expect(cs.single.kind, ClaimKind.belongsToHouse);
    expect(cs.single.subjectId, me.id);
    expect(cs.single.objectId, hs.single.id);
    expect(cs.single.basis, Basis.bornTo);

    expect(saved, [me.id]);
  });

  testWidgets('saving with every slot blank also works', (tester) async {
    await pumpForm(tester);
    await save(tester);

    final List<PersonRow> all = (await tester.runAsync(people))!;
    expect(all, hasLength(2));
    final PersonRow me = all.singleWhere((p) => !p.isPlaceholder);
    expect(me.nameKey, isNull);
    expect(me.sex, isNull);
    expect(all.singleWhere((p) => p.isPlaceholder).sex, Sex.male);
    final List<HouseRow> hs = (await tester.runAsync(houses))!;
    expect(hs.single.ordinal, isNull);
    expect(saved, [me.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every slot ticked "I don\'t know" saves the same as blank', (
    tester,
  ) async {
    await pumpForm(tester);
    for (final Key k in [
      FirstRunScreen.nameUnknownKey,
      FirstRunScreen.fatherUnknownKey,
      FirstRunScreen.houseUnknownKey,
      FirstRunScreen.siblingsUnknownKey,
    ]) {
      await tester.tap(find.byKey(k));
    }
    await tester.pump();
    await save(tester);

    expect((await tester.runAsync(people))!, hasLength(2));
    expect(saved, hasLength(1));
  });

  testWidgets('a known father with a house number and two siblings creates '
      'the father, the house with its number, me and the siblings', (
    tester,
  ) async {
    await pumpForm(tester);
    await type(tester, FirstRunScreen.nameKey, 'Me');
    await tester.tap(find.text('Daughter'));
    await type(tester, FirstRunScreen.fatherKey, "  Juma Nyang'or ");
    await type(tester, FirstRunScreen.houseKey, '2');
    await type(tester, FirstRunScreen.siblingsKey, 'Achieng\n\n  Otieno  \n');
    await tester.pump();
    await save(tester);

    final List<PersonRow> all = (await tester.runAsync(people))!;
    expect(all, hasLength(4));
    expect(all.where((p) => p.isPlaceholder), isEmpty);
    final PersonRow me = all.singleWhere((p) => p.nameKey == 'Me');
    expect(me.sex, Sex.female);
    final PersonRow father = all.singleWhere(
      (p) => p.nameKey == "Juma Nyang'or",
    );
    expect(father.sex, Sex.male);
    final PersonRow achieng = all.singleWhere((p) => p.nameKey == 'Achieng');
    final PersonRow otieno = all.singleWhere((p) => p.nameKey == 'Otieno');

    final List<HouseRow> hs = (await tester.runAsync(houses))!;
    expect(hs, hasLength(1));
    expect(hs.single.husbandId, father.id);
    expect(hs.single.ordinal, 2);

    final List<ClaimRow> cs = (await tester.runAsync(claims))!;
    expect(cs, hasLength(3));
    for (final c in cs) {
      expect(c.kind, ClaimKind.belongsToHouse);
      expect(c.objectId, hs.single.id);
      expect(c.basis, Basis.bornTo);
    }
    expect({for (final c in cs) c.subjectId}, {me.id, achieng.id, otieno.id});
    expect(saved, [me.id]);
  });

  testWidgets('the builder is called in the specified order', (tester) async {
    await pumpForm(tester);
    await type(tester, FirstRunScreen.nameKey, 'Me');
    await type(tester, FirstRunScreen.fatherKey, 'Juma');
    await type(tester, FirstRunScreen.houseKey, '3');
    await type(tester, FirstRunScreen.siblingsKey, 'A\nB');
    await save(tester);

    expect(builder.calls, [
      'addPerson(Me, null)',
      'addPerson(Juma, male)',
      'addHouse(3)',
      'placeChild(bornTo)',
      'addPerson(A, null)',
      'placeChild(bornTo)',
      'addPerson(B, null)',
      'placeChild(bornTo)',
    ]);
  });

  for (final String bad in ['abc', '0', '-2', '1.5', '   ']) {
    testWidgets('a house number of "$bad" counts as not known', (tester) async {
      await pumpForm(tester);
      await type(tester, FirstRunScreen.houseKey, bad);
      await save(tester);
      expect(builder.calls, contains('addHouse(null)'));
    });
  }

  testWidgets('"I don\'t know" clears a field and disables it', (tester) async {
    await pumpForm(tester);
    final fields = {
      FirstRunScreen.nameKey: FirstRunScreen.nameUnknownKey,
      FirstRunScreen.fatherKey: FirstRunScreen.fatherUnknownKey,
      FirstRunScreen.houseKey: FirstRunScreen.houseUnknownKey,
      FirstRunScreen.siblingsKey: FirstRunScreen.siblingsUnknownKey,
    };
    for (final MapEntry(key: field, value: unknown) in fields.entries) {
      await type(tester, field, '2');
      await tester.tap(find.byKey(unknown));
      await tester.pump();
      final TextField f = tester.widget(find.byKey(field));
      expect(f.enabled, isFalse, reason: '$field disabled');
      expect(f.controller!.text, isEmpty, reason: '$field cleared');

      // Unticking makes it usable again.
      await tester.tap(find.byKey(unknown));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byKey(field)).enabled,
        isTrue,
        reason: '$field enabled again',
      );
    }
  });

  testWidgets('sex defaults to "I don\'t know" and is a plain radio list', (
    tester,
  ) async {
    await pumpForm(tester);
    expect(find.text('Son'), findsOneWidget);
    expect(find.text('Daughter'), findsOneWidget);
    expect(find.byType(RadioListTile<Sex?>), findsNWidgets(3));
    expect(
      tester.widget<RadioGroup<Sex?>>(find.byType(RadioGroup<Sex?>)).groupValue,
      isNull,
    );
    // Choosing one changes the group; choosing "I don't know" returns it.
    await tester.tap(find.text('Daughter'));
    await tester.pump();
    expect(
      tester.widget<RadioGroup<Sex?>>(find.byType(RadioGroup<Sex?>)).groupValue,
      Sex.female,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(RadioListTile<Sex?>).last,
        matching: find.text("I don't know"),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<RadioGroup<Sex?>>(find.byType(RadioGroup<Sex?>)).groupValue,
      isNull,
    );
  });

  testWidgets('a 200-character name at text scale 2.0 wraps without overflow', (
    tester,
  ) async {
    await pumpForm(tester, textScale: 2.0);
    final String long = List.filled(200, 'W').join();
    await type(tester, FirstRunScreen.nameKey, long);
    await type(tester, FirstRunScreen.fatherKey, long);
    await type(tester, FirstRunScreen.siblingsKey, '$long\n$long');
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The field shows the whole name on several lines, never cut short.
    final TextField name = tester.widget(find.byKey(FirstRunScreen.nameKey));
    expect(name.maxLines, isNull);
    expect(name.controller!.text, long);
    expect(
      tester.getSize(find.byKey(FirstRunScreen.nameKey)).height,
      greaterThan(48 * 2),
    );
    // No visible text is set to cut off.
    for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.overflow, isNot(TextOverflow.ellipsis));
      expect(t.maxLines, isNull);
    }
  });

  testWidgets('Save cannot double-submit', (tester) async {
    await pumpForm(tester);
    await type(tester, FirstRunScreen.nameKey, 'Me');
    // Two taps with no frame between them.
    await tester.tap(find.byKey(FirstRunScreen.saveKey));
    await tester.tap(find.byKey(FirstRunScreen.saveKey));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect((await tester.runAsync(people))!, hasLength(2));
    expect((await tester.runAsync(houses))!, hasLength(1));
    expect(saved, hasLength(1));
  });

  testWidgets('Save is disabled while saving', (tester) async {
    await pumpForm(tester);
    expect(
      tester.widget<FilledButton>(find.byKey(FirstRunScreen.saveKey)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(FirstRunScreen.saveKey));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(FirstRunScreen.saveKey)).onPressed,
      isNull,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  });

  testWidgets('FirstRunScreen has no counts, scores, streaks or prompts to '
      'fill missing items', (tester) async {
    await pumpForm(tester);
    final RegExp banned = RegExp(
      r'%|complete|streak|remaining|missing|\bfill\b|\d+ of \d+|\d+/\d+',
      caseSensitive: false,
    );
    // Also after interaction, when a counter or hint might appear.
    Future<void> check() async {
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        expect(banned.hasMatch(t.data ?? ''), isFalse, reason: t.data);
      }
      for (final EditableText e in tester.widgetList<EditableText>(
        find.byType(EditableText),
      )) {
        expect(banned.hasMatch(e.controller.text), isFalse);
      }
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }

    await check();
    await type(tester, FirstRunScreen.nameKey, 'Me');
    await tester.tap(find.byKey(FirstRunScreen.fatherUnknownKey));
    await tester.pump();
    await check();
    // Nothing is marked as required.
    expect(find.textContaining('*'), findsNothing);
  });

  testWidgets('a write that fails part-way leaves no rows, and a second Save '
      'creates exactly one family', (tester) async {
    await pumpForm(tester);
    await type(tester, FirstRunScreen.nameKey, 'Me');
    await type(tester, FirstRunScreen.fatherKey, 'Juma');
    builder.failNextPlaceChild = true;
    await save(tester);

    // The error is reported, shown in words, and nothing is left behind.
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(saved, isEmpty);
    expect((await tester.runAsync(people))!, isEmpty);
    expect((await tester.runAsync(houses))!, isEmpty);
    expect((await tester.runAsync(claims))!, isEmpty);
    expect(
      tester.widget<FilledButton>(find.byKey(FirstRunScreen.saveKey)).onPressed,
      isNotNull,
    );

    await save(tester);

    expect(tester.takeException(), isNull);
    expect((await tester.runAsync(people))!, hasLength(2));
    expect((await tester.runAsync(houses))!, hasLength(1));
    expect((await tester.runAsync(claims))!, hasLength(1));
    expect(saved, hasLength(1));
    expect(find.text('Could not save. Please try again.'), findsNothing);
  });

  testWidgets('a remember that throws rolls everything back and the form can '
      'be saved again', (tester) async {
    final List<String> remembered = [];
    bool fail = true;
    await pumpForm(
      tester,
      remember: (String id) async {
        if (fail) {
          throw StateError('remember failed');
        }
        remembered.add(id);
      },
    );
    await type(tester, FirstRunScreen.nameKey, 'Me');
    await save(tester);

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect((await tester.runAsync(people))!, isEmpty);
    expect((await tester.runAsync(houses))!, isEmpty);
    expect((await tester.runAsync(claims))!, isEmpty);
    expect(saved, isEmpty);
    expect(remembered, isEmpty);
    expect(
      tester.widget<FilledButton>(find.byKey(FirstRunScreen.saveKey)).onPressed,
      isNotNull,
    );

    fail = false;
    await save(tester);

    expect(tester.takeException(), isNull);
    expect((await tester.runAsync(people))!, hasLength(2));
    expect(saved, hasLength(1));
    expect(remembered, saved);
  });

  testWidgets('remember runs inside the write, after the family is written', (
    tester,
  ) async {
    int peopleSeen = -1;
    await pumpForm(
      tester,
      remember: (String id) async {
        peopleSeen = (await people()).length;
      },
    );
    await save(tester);
    expect(peopleSeen, 2);
    expect(saved, hasLength(1));
  });

  testWidgets('each text field has its question as its accessible label', (
    tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpForm(tester);

    final questions = {
      FirstRunScreen.nameKey: 'Your name',
      FirstRunScreen.fatherKey: "Your father's name",
      FirstRunScreen.houseKey: 'His house number',
      FirstRunScreen.siblingsKey: 'Brothers and sisters in his house',
    };
    for (final MapEntry(key: field, value: question) in questions.entries) {
      final Finder editable = find.descendant(
        of: find.byKey(field),
        matching: find.byType(EditableText),
      );
      expect(
        tester.getSemantics(editable).label,
        contains(question),
        reason: question,
      );
    }
    // The question is read once: its visible text is not announced again.
    expect(find.bySemanticsLabel('Your name'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the four "I don\'t know" checkboxes are told apart by '
      'assistive technology', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpForm(tester);

    final labels = [
      for (final Key k in [
        FirstRunScreen.nameUnknownKey,
        FirstRunScreen.fatherUnknownKey,
        FirstRunScreen.houseUnknownKey,
        FirstRunScreen.siblingsUnknownKey,
      ])
        tester.getSemantics(find.byKey(k)).label,
    ];
    expect(labels.toSet(), hasLength(4), reason: '$labels');
    for (final String l in labels) {
      expect(l, contains("I don't know"));
    }
    expect(labels[0], contains('Your name'));
    semantics.dispose();
  });
}
