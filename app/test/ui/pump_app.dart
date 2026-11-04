import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:related/ui/theme.dart';

/// Shows [child] under the app theme on a 360dp wide phone at [textScale].
/// A tall [height] keeps every row of a long list built.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  double textScale = 1.0,
  double height = 640,
}) async {
  tester.view.physicalSize = Size(360 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, page) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: page!,
      ),
      home: Scaffold(body: child),
    ),
  );
  expectTextScale(tester, textScale);
}

/// Fails unless the pumped page really runs at [scale], so a test of large
/// text cannot silently run at 1.0.
void expectTextScale(WidgetTester tester, double scale) {
  final BuildContext context = tester.element(find.byType(Scaffold));
  expect(MediaQuery.textScalerOf(context).scale(10), 10 * scale);
}

/// Lets real database work finish, then draws the result. Drift runs on real
/// time, outside the test's fake clock, so a plain pump would not wait for it.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
}
