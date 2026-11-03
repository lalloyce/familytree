// Dart simulation of the airplane-mode matrix (spike 3, step 5).
// These tests simulate the logic only. They do not prove anything on a phone.
// See matrix.md for the on-device procedure and the (empty) device results.
import 'package:invite_spike/invite_spike.dart';
import 'package:test/test.dart';

const claim = Claim(
  vouchedPersonId: 'p-akinyi',
  namedRelativeId: 'p-otieno',
  text: 'cousin of Otieno through his father',
);

void main() {
  late FakeInviteNetwork net;
  late Inviter inviter;
  late Redeemer redeemer;

  setUp(() {
    net = FakeInviteNetwork(
      treeByInviter: {
        'inviter-1': ['Winyo', 'Manyi', 'Otieno'],
      },
    )..registerInviter('inviter-1', 'Achieng');
    inviter = Inviter(id: 'inviter-1', pool: TokenPool('inviter-1'));
    redeemer = Redeemer(id: 'redeemer-1');
  });

  group('Row 1: empty token pool at invite time', () {
    test(
      'offline with an empty pool: no code, no link, claim not bound',
      () async {
        net.online = false;
        expect(inviter.pool.isEmpty, isTrue);

        final result = inviter.bindClaim(claim);

        expect(result, isA<BindPoolEmpty>());
        expect(BindPoolEmpty.message, contains('Connect to the internet'));
        expect(inviter.outbox, isEmpty);
        expect(net.callsServed, 0);
      },
    );

    test(
      'after signal returns the pool fills and the same claim binds',
      () async {
        net.online = false;
        expect(inviter.bindClaim(claim), isA<BindPoolEmpty>());

        net.online = true;
        expect(await inviter.sync(net), isTrue);
        expect(inviter.pool.size, 20);

        net.online = false; // back offline, the pool now serves the invite
        final result = inviter.bindClaim(claim);
        expect(result, isA<BindOk>());
        expect(isValidInviteCode((result as BindOk).code), isTrue);
      },
    );

    test('a pool that runs dry is reported, not reused', () async {
      await inviter.pool.refill(net);
      final codes = <String>{};
      for (var i = 0; i < 20; i++) {
        codes.add((inviter.bindClaim(claim) as BindOk).code);
      }
      expect(codes.length, 20, reason: 'every token is single use');
      expect(inviter.bindClaim(claim), isA<BindPoolEmpty>());
    });
  });

  group('Row 2: redeem with no signal', () {
    test('shows only the saved message and nothing else', () async {
      await inviter.pool.refill(net);
      final ok = inviter.bindClaim(claim) as BindOk;
      await inviter.sync(net);

      net.online = false;
      final entry = redeemer.enterCode(ok.formattedCode);
      expect(entry, isA<EntrySaved>());
      expect((entry as EntrySaved).message, savedMessage);
      expect(await redeemer.sync(net), isFalse);

      final screen = redeemer.screen;
      expect(screen.message, 'saved, we will connect when you have signal');
      expect(screen.inviterName, isNull);
      expect(screen.claimText, isNull);
      expect(screen.tree, isEmpty);
      expect(redeemer.queue.single.state, SavedState.saved);
    });
  });

  group('Row 3: app installed from a link with a missing install referrer', () {
    test(
      'awaiting phone',
      () {},
      skip:
          'awaiting phone: needs an Android install from a link. '
          'Cannot be simulated in Dart. See matrix.md.',
    );
  });

  group('Row 4: typed code with one wrong symbol', () {
    test('rejected at entry, offline, and stored nowhere', () async {
      await inviter.pool.refill(net);
      final ok = inviter.bindClaim(claim) as BindOk;
      net.online = false;
      final callsBefore = net.callsServed;

      // Replace one symbol with a different alphabet symbol, every position.
      var rejected = 0;
      for (var pos = 0; pos < inviteCodeLength; pos++) {
        final wrong =
            inviteAlphabet[(inviteAlphabet.indexOf(ok.code[pos]) + 1) %
                inviteAlphabet.length];
        final typed =
            ok.code.substring(0, pos) + wrong + ok.code.substring(pos + 1);
        final result = redeemer.enterCode(typed);
        expect(result, isA<EntryRejected>(), reason: 'position $pos');
        expect((result as EntryRejected).message, typoMessage);
        rejected++;
      }
      expect(rejected, 9);
      expect(redeemer.queue, isEmpty);
      expect(redeemer.screen.message, isEmpty);
      expect(
        net.callsServed,
        callsBefore,
        reason: 'no network needed to reject',
      );
    });
  });

  group('Row 5: right symbols, then signal returns', () {
    test(
      'redemption completes and the redeemer sees no tree until confirmed',
      () async {
        await inviter.pool.refill(net);
        final ok = inviter.bindClaim(claim) as BindOk;
        await inviter.sync(net); // inviter uploads the binding when online

        net.online = false;
        expect(
          redeemer.enterCode(ok.formattedCode.toLowerCase()),
          isA<EntrySaved>(),
        );
        expect(await redeemer.sync(net), isFalse);
        expect(redeemer.screen.message, savedMessage);

        net.online = true;
        expect(await redeemer.sync(net), isTrue);
        expect(redeemer.queue.single.state, SavedState.redeemed);

        var screen = redeemer.screen;
        expect(screen.tree, isEmpty, reason: 'redeemed is not confirmed');
        expect(screen.message, awaitingConfirmationMessage);

        // The redeemer cannot confirm themselves, a stranger cannot either.
        expect(
          net.confirm(ok.token, byPersonId: 'redeemer-1'),
          ConfirmOutcome.notAuthorised,
        );
        expect(
          net.confirm(ok.token, byPersonId: 'p-stranger'),
          ConfirmOutcome.notAuthorised,
        );
        await redeemer.sync(net);
        expect(redeemer.screen.tree, isEmpty);

        // The named relative confirms.
        expect(
          net.confirm(ok.token, byPersonId: 'p-otieno'),
          ConfirmOutcome.confirmed,
        );
        await redeemer.sync(net);
        screen = redeemer.screen;
        expect(screen.tree, ['Winyo', 'Manyi', 'Otieno']);
      },
    );

    test(
      'redeemed before the inviter has uploaded the binding: still nothing',
      () async {
        await inviter.pool.refill(net);
        final ok = inviter.bindClaim(claim) as BindOk;
        // Inviter stays offline and never uploads. The redeemer has signal.
        redeemer.enterCode(ok.code);
        await redeemer.sync(net);

        expect(redeemer.queue.single.state, SavedState.redeemed);
        expect(redeemer.screen.message, savedMessage);
        expect(redeemer.screen.inviterName, isNull);
        expect(redeemer.screen.tree, isEmpty);

        await inviter.sync(net);
        await redeemer.sync(net);
        expect(redeemer.screen.message, awaitingConfirmationMessage);
        expect(redeemer.screen.tree, isEmpty);

        expect(
          net.confirm(ok.token, byPersonId: 'inviter-1'),
          ConfirmOutcome.confirmed,
        );
        await redeemer.sync(net);
        expect(redeemer.screen.tree, isNotEmpty);
      },
    );
  });
}
