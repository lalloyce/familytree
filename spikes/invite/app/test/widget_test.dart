import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_spike_app/main.dart';

void main() {
  testWidgets('offline: create, type a bad code, then a good code', (t) async {
    await t.pumpWidget(const InviteSpikeApp());

    // Online once to fill the pool.
    await t.tap(find.byKey(const Key('inviter-sync')));
    await t.pumpAndSettle();
    expect(find.text('Tokens in pool: 20'), findsOneWidget);

    // Airplane mode, then create an invite from the pool.
    await t.tap(find.byKey(const Key('signal-switch')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('create-invite')));
    await t.pumpAndSettle();
    final code =
        (t.widget(find.byKey(const Key('typed-code'))) as SelectableText).data!;

    await t.tap(find.text('Enter code'));
    await t.pumpAndSettle();

    // One wrong symbol is rejected at the keyboard.
    final wrong = code.replaceFirst(code[0], code[0] == '2' ? '3' : '2');
    await t.enterText(find.byKey(const Key('code-field')), wrong);
    await t.tap(find.byKey(const Key('submit-code')));
    await t.pumpAndSettle();
    expect(
      find.text('That code has a typo. Check it and try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('status')), findsNothing);

    // The right code is saved, and that is all the screen says.
    await t.enterText(find.byKey(const Key('code-field')), code);
    await t.tap(find.byKey(const Key('submit-code')));
    await t.pumpAndSettle();
    expect(
      find.text('saved, we will connect when you have signal'),
      findsOneWidget,
    );
    expect(find.text('Rafa'), findsNothing);
  });
}
