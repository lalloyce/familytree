import 'package:invite_spike/invite_spike.dart';
import 'package:test/test.dart';

const claim = Claim(
  vouchedPersonId: 'p-akinyi',
  namedRelativeId: 'p-otieno',
  text: 'cousin of Otieno through his father',
);

void main() {
  late FakeInviteNetwork net;

  setUp(() {
    net = FakeInviteNetwork()..registerInviter('inviter-1', 'Achieng');
  });

  group('TokenPool', () {
    test('take on an empty pool returns null', () {
      expect(TokenPool('inviter-1').take(), isNull);
    });

    test('refill adds a batch, take spends one at a time', () async {
      final pool = TokenPool('inviter-1', batchSize: 3);
      expect(await pool.refill(net), 3);
      expect(pool.size, 3);
      final a = pool.take()!;
      final b = pool.take()!;
      expect(a, isNot(b));
      expect(pool.size, 1);
    });

    test('refill offline throws and leaves the pool unchanged', () async {
      final pool = TokenPool('inviter-1');
      net.online = false;
      await expectLater(pool.refill(net), throwsA(isA<NetworkUnavailable>()));
      expect(pool.size, 0);
    });

    test('refillIfLow returns false offline and does not throw', () async {
      final pool = TokenPool('inviter-1');
      net.online = false;
      expect(await pool.refillIfLow(net), isFalse);
      net.online = true;
      expect(await pool.refillIfLow(net), isTrue);
      expect(pool.size, 20);
      expect(await pool.refillIfLow(net), isTrue);
      expect(pool.size, 20, reason: 'above the low-water mark, no fetch');
    });

    test(
      'issued tokens are canonical, so each code is unique to its token',
      () async {
        final pool = TokenPool('inviter-1', batchSize: 200);
        await pool.refill(net);
        final codes = <String>{};
        while (!pool.isEmpty) {
          final t = pool.take()!;
          expect(isCanonicalToken5(t), isTrue);
          final code = encodeInviteCode(t);
          expect(decodeInviteCode(code), t);
          codes.add(code);
        }
        expect(codes.length, 200);
      },
    );
  });

  group('Inviter.bindClaim', () {
    test('consumes one token and queues the binding', () async {
      final inviter = Inviter(
        id: 'inviter-1',
        pool: TokenPool('inviter-1', batchSize: 2),
      );
      await inviter.pool.refill(net);
      net.online = false;
      final ok = inviter.bindClaim(claim) as BindOk;
      expect(inviter.pool.size, 1);
      expect(inviter.outbox.single.token, ok.token);
      expect(inviter.outbox.single.claim, same(claim));
      expect(isValidInviteCode(ok.code), isTrue);
      expect(ok.formattedCode, formatInviteCode(ok.code));
    });

    test('the link carries only the token, never the relationship', () async {
      final inviter = Inviter(id: 'inviter-1', pool: TokenPool('inviter-1'));
      await inviter.pool.refill(net);
      final ok = inviter.bindClaim(claim) as BindOk;

      expect(ok.link, '$defaultLinkBase/i/${ok.code}');
      expect(ok.link.replaceFirst(ok.code, ''), '$defaultLinkBase/i/');
      for (final secret in [
        claim.text,
        claim.vouchedPersonId,
        claim.namedRelativeId,
        'Otieno',
        'cousin',
        'inviter-1',
        'Achieng',
      ]) {
        expect(ok.link.contains(secret), isFalse, reason: secret);
        expect(ok.formattedCode.contains(secret), isFalse, reason: secret);
      }
      expect(Uri.parse(ok.link).hasQuery, isFalse);
      expect(codeFromInviteLink(ok.link), ok.code);
    });

    test('codeFromInviteLink rejects foreign links and typo links', () {
      expect(
        codeFromInviteLink('https://elsewhere.example/i/222222222'),
        isNull,
      );
      expect(codeFromInviteLink('$defaultLinkBase/i/222222223'), isNull);
    });

    test(
      'sync uploads the outbox once online, offline keeps it queued',
      () async {
        final inviter = Inviter(id: 'inviter-1', pool: TokenPool('inviter-1'));
        await inviter.pool.refill(net);
        inviter.bindClaim(claim);
        net.online = false;
        expect(await inviter.sync(net), isFalse);
        expect(inviter.outbox, hasLength(1));
        net.online = true;
        expect(await inviter.sync(net), isTrue);
        expect(inviter.outbox, isEmpty);
      },
    );
  });

  group('Redeemer', () {
    test('a code is queued once however often it is entered', () {
      final r = Redeemer(id: 'r1');
      final code = encodeInviteCode(token5FromValue(42));
      r.enterCode(code);
      r.enterCode(formatInviteCode(code));
      r.enterCode(code.toLowerCase());
      expect(r.queue, hasLength(1));
    });

    test('a token is single use: a second redeemer is refused', () async {
      final inviter = Inviter(id: 'inviter-1', pool: TokenPool('inviter-1'));
      await inviter.pool.refill(net);
      final ok = inviter.bindClaim(claim) as BindOk;
      await inviter.sync(net);

      final first = Redeemer(id: 'r1')..enterCode(ok.code);
      final second = Redeemer(id: 'r2')..enterCode(ok.code);
      await first.sync(net);
      await second.sync(net);

      expect(first.queue.single.state, SavedState.redeemed);
      expect(second.queue.single.state, SavedState.rejected);
      expect(second.screen.message, rejectedMessage);
      expect(second.screen.tree, isEmpty);
    });

    test(
      'a valid code that was never issued is refused by the server',
      () async {
        final r = Redeemer(id: 'r1')
          ..enterCode(encodeInviteCode(token5FromValue(7)));
        await r.sync(net);
        expect(r.queue.single.state, SavedState.rejected);
      },
    );

    test('redeem is idempotent for the same redeemer', () async {
      final inviter = Inviter(id: 'inviter-1', pool: TokenPool('inviter-1'));
      await inviter.pool.refill(net);
      final ok = inviter.bindClaim(claim) as BindOk;
      final a = await net.redeem('r1', ok.token);
      final b = await net.redeem('r1', ok.token);
      expect(a.status, RedeemStatus.accepted);
      expect(b.status, RedeemStatus.accepted);
    });

    test('confirm with nothing redeemed has nothing to confirm', () async {
      final inviter = Inviter(id: 'inviter-1', pool: TokenPool('inviter-1'));
      await inviter.pool.refill(net);
      final ok = inviter.bindClaim(claim) as BindOk;
      await inviter.sync(net);
      expect(
        net.confirm(ok.token, byPersonId: 'inviter-1'),
        ConfirmOutcome.nothingToConfirm,
      );
    });
  });
}
