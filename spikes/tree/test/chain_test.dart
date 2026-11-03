import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_spike/chain.dart';
import 'package:tree_spike/gen.dart';

Widget host(Widget child, {double scale = 1.0, double width = 360}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a 200 character name wraps without overflow at text scale 2.0',
      (tester) async {
    final name = List.filled(25, 'Okello').join(' ').padRight(200, 'x');
    expect(name.length, 200);
    final text = '$name, son of Winyo, house 2';
    await tester.pumpWidget(host(ChainLine(text: text), scale: 2.0));
    expect(tester.takeException(), isNull);

    final widget = tester.widget<Text>(find.byType(Text));
    expect(widget.data, text, reason: 'full text, nothing cut');
    expect(widget.maxLines, isNull);
    expect(widget.overflow, isNot(TextOverflow.ellipsis));

    final para = tester.renderObject<RenderParagraph>(find.byType(Text));
    expect(para.didExceedMaxLines, isFalse);
    final lineHeight = 16 * 2.0 * 1.3;
    expect(para.size.height, greaterThan(lineHeight * 3),
        reason: 'wrapped onto several lines');
    expect(tester.getSize(find.byType(ChainLine)).width, 360);
  });

  testWidgets('a wrapped name stays inside a narrow screen at scale 2.0',
      (tester) async {
    final name = 'A' * 200; // one unbroken word
    await tester.pumpWidget(
        host(ChainLine(text: name), scale: 2.0, width: 320));
    expect(tester.takeException(), isNull);
    final para = tester.renderObject<RenderParagraph>(find.byType(Text));
    expect(para.size.width, lessThanOrEqualTo(320 - 32));
    expect(para.size.height, greaterThan(16 * 2.0 * 1.3 * 3));
  });

  test('the spoken line reads like speech', () {
    final d = generate(seed: 1);
    final p = d.people.firstWhere((p) => p.fatherHouse != null && !p.isFemale);
    final t = chainText(d, p.id);
    final house = d.houses[p.fatherHouse!];
    expect(t, startsWith('${p.name}, son of ${d.people[house.husbandId].name}'));
    expect(t, endsWith('house ${house.order}'));
  });

  testWidgets('the 3,000 row chain builds lazily', (tester) async {
    final d = generate(seed: 1);
    final c = ScrollController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChainList(data: d, controller: c, onSelect: (_) {}))));
    expect(tester.takeException(), isNull);
    expect(find.byType(ChainLine).evaluate().length, lessThan(40));
    c.jumpTo(c.position.maxScrollExtent);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
