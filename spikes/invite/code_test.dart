import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'code.dart';

/// Fixed token for the exhaustive checks: bytes 0x12 0x34 0x56 0x78 0x9A.
final fixedToken = Uint8List.fromList([0x12, 0x34, 0x56, 0x78, 0x9A]);

void main() {
  const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  test('alphabet is 31 symbols: digits 2-9, letters A-Z without I, L, O', () {
    expect(inviteAlphabet, alphabet);
    expect(inviteAlphabet.length, 31);
    for (final banned in ['0', '1', 'I', 'L', 'O']) {
      expect(inviteAlphabet.contains(banned), isFalse);
    }
  });

  test('encodeInviteCode gives 9 symbols from the alphabet', () {
    final code = encodeInviteCode(fixedToken);
    expect(code.length, 9);
    for (final ch in code.split('')) {
      expect(alphabet.contains(ch), isTrue, reason: 'symbol $ch');
    }
  });

  test('isValidInviteCode accepts an encoded code', () {
    expect(isValidInviteCode(encodeInviteCode(fixedToken)), isTrue);
  });

  test('check symbol follows the formula on a hand-computed example', () {
    // All-zero token: eight symbols at index 0 ('2'), sum 0, check index 0.
    expect(encodeInviteCode(Uint8List(5)), '222222222');
    // Value 1: last token symbol has index 1 at position 7 (weight 8),
    // so sum = 8 and the check symbol is alphabet[8] = 'A'.
    expect(encodeInviteCode(Uint8List.fromList([0, 0, 0, 0, 1])), '22222223A');
  });

  test('every single-symbol substitution is rejected (9 positions x 30)', () {
    final code = encodeInviteCode(fixedToken);
    var tried = 0;
    for (var pos = 0; pos < 9; pos++) {
      for (final sym in alphabet.split('')) {
        if (sym == code[pos]) continue;
        final mutated = code.substring(0, pos) + sym + code.substring(pos + 1);
        expect(
          isValidInviteCode(mutated),
          isFalse,
          reason: 'pos $pos -> $sym in $code',
        );
        tried++;
      }
    }
    expect(tried, 270);
  });

  test('every adjacent swap of different symbols is rejected', () {
    final code = encodeInviteCode(fixedToken);
    var tried = 0;
    for (var pos = 0; pos < 8; pos++) {
      if (code[pos] == code[pos + 1]) continue;
      final chars = code.split('');
      final tmp = chars[pos];
      chars[pos] = chars[pos + 1];
      chars[pos + 1] = tmp;
      expect(
        isValidInviteCode(chars.join()),
        isFalse,
        reason: 'swap at $pos in $code',
      );
      tried++;
    }
    expect(tried, 8);
  });

  test('substitution and adjacent swap are caught over many tokens', () {
    var subs = 0;
    var swaps = 0;
    // 500 tokens drawn with a fixed seed: eight random base-31 digits each, so
    // values are spread uniformly over [0, 31^8) and are reproducible.
    final rng = Random(20261103);
    final codes = <String>[];
    for (var i = 0; i < 500; i++) {
      var value = 0;
      for (var d = 0; d < 8; d++) {
        value = value * 31 + rng.nextInt(31);
      }
      codes.add(encodeInviteCode(token5FromValue(value)));
    }
    // Guard against a silent regression to a narrow range: with a uniform
    // spread, the 31 x 31 = 961 possible two-symbol prefixes are mostly hit.
    expect(
      codes.map((c) => c.substring(0, 2)).toSet().length,
      greaterThan(100),
    );
    var expectedSwaps = 0;
    for (final code in codes) {
      for (var pos = 0; pos < 8; pos++) {
        if (code[pos] != code[pos + 1]) expectedSwaps++;
      }
    }
    for (final code in codes) {
      expect(isValidInviteCode(code), isTrue);
      for (var pos = 0; pos < 9; pos++) {
        for (final sym in alphabet.split('')) {
          if (sym == code[pos]) continue;
          final m = code.substring(0, pos) + sym + code.substring(pos + 1);
          expect(isValidInviteCode(m), isFalse);
          subs++;
        }
      }
      for (var pos = 0; pos < 8; pos++) {
        if (code[pos] == code[pos + 1]) continue;
        final c = code.split('');
        final t = c[pos];
        c[pos] = c[pos + 1];
        c[pos + 1] = t;
        expect(isValidInviteCode(c.join()), isFalse);
        swaps++;
      }
    }
    expect(subs, 500 * 270);
    expect(swaps, expectedSwaps);
    expect(swaps, greaterThan(0));
    // ignore: avoid_print
    print('swap test: $subs substitutions, $swaps swaps, all rejected');
  });

  test('every adjacent swap of every different symbol pair is rejected', () {
    // Token positions 0..6 swap with their right neighbour, all 31 x 30
    // ordered pairs each, other symbols fixed at index 5. Position 7 is
    // covered with the check symbol by the tests above.
    var tried = 0;
    for (var pos = 0; pos < 7; pos++) {
      for (var a = 0; a < 31; a++) {
        for (var b = 0; b < 31; b++) {
          if (a == b) continue;
          final idx = List<int>.filled(8, 5);
          idx[pos] = a;
          idx[pos + 1] = b;
          var value = 0;
          for (final k in idx) {
            value = value * 31 + k;
          }
          final code = encodeInviteCode(token5FromValue(value));
          expect(code[pos], alphabet[a]);
          expect(code[pos + 1], alphabet[b]);
          final c = code.split('');
          c[pos] = alphabet[b];
          c[pos + 1] = alphabet[a];
          expect(
            isValidInviteCode(c.join()),
            isFalse,
            reason: 'swap at $pos of ${alphabet[a]}${alphabet[b]}',
          );
          tried++;
        }
      }
    }
    expect(tried, 7 * 31 * 30);
  });

  test('lowercase input is accepted after normalisation', () {
    final code = encodeInviteCode(fixedToken);
    expect(isValidInviteCode(code.toLowerCase()), isTrue);
  });

  test('spaces or hyphens every four symbols are accepted', () {
    final code = encodeInviteCode(fixedToken);
    final grouped =
        '${code.substring(0, 4)}-${code.substring(4, 8)}-${code[8]}';
    final spaced = '${code.substring(0, 4)} ${code.substring(4, 8)} ${code[8]}';
    expect(isValidInviteCode(grouped), isTrue);
    expect(isValidInviteCode(spaced), isTrue);
    expect(isValidInviteCode(grouped.toLowerCase()), isTrue);
    expect(normaliseInviteCode(grouped), code);
    expect(formatInviteCode(code), grouped);
  });

  test('wrong length and out-of-alphabet symbols are rejected', () {
    final code = encodeInviteCode(fixedToken);
    expect(isValidInviteCode(''), isFalse);
    expect(isValidInviteCode(code.substring(0, 8)), isFalse);
    expect(isValidInviteCode('${code}2'), isFalse);
    for (final bad in ['0', '1', 'I', 'L', 'O', '!']) {
      expect(isValidInviteCode(bad + code.substring(1)), isFalse);
    }
  });

  test(
    'decodeInviteCode round-trips canonical tokens and rejects bad codes',
    () {
      final token = token5FromValue(123456789012);
      final code = encodeInviteCode(token);
      expect(decodeInviteCode(code), token);
      expect(decodeInviteCode(formatInviteCode(code.toLowerCase())), token);
      expect(decodeInviteCode('${code.substring(0, 8)}2'), isNull);
    },
  );

  test('encodeInviteCode rejects a token that is not 5 bytes', () {
    expect(() => encodeInviteCode(Uint8List(4)), throwsArgumentError);
    expect(() => encodeInviteCode(Uint8List(6)), throwsArgumentError);
  });

  test(
    'a token above 31^8 is reduced modulo 31^8 (documented, not injective)',
    () {
      // 40 bits hold more values than eight base-31 symbols (31^8 < 2^40).
      final big = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
      expect(isCanonicalToken5(big), isFalse);
      expect(isValidInviteCode(encodeInviteCode(big)), isTrue);
      expect(isCanonicalToken5(token5FromValue(31 * 31 * 31 * 31)), isTrue);
    },
  );
}
