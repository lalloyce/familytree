// Invite code: 8 token symbols plus 1 check symbol, typed by hand offline.
//
// Standalone Dart, no Flutter dependency. This file graduates to M3.
//
// Alphabet: 31 symbols, digits 2-9 and letters A-Z without I, L and O, so no
// symbol can be mistaken for 0 or 1 when read aloud or copied from a message.
//
// Check symbol = (sum over i = 0..7 of symbolIndex(i) * (i + 1)) mod 31.
//
// Why 31 and weights 1..8: 31 is prime, so every weight 1..8 has an inverse
// mod 31. That gives two guarantees, proved here and exercised in
// code_test.dart:
//  * Single substitution. Changing the symbol at token position i by a
//    non-zero amount d changes the sum by d * (i + 1). Because 31 is prime
//    and 0 < d < 31 and 0 < (i + 1) < 31, that product is never 0 mod 31, so
//    the check symbol no longer matches. A wrong check symbol is caught too,
//    because the check must equal the sum.
//  * Adjacent swap. Swapping neighbouring token symbols a and b at weights w
//    and w + 1 changes the sum by (b - a) * w + (a - b) * (w + 1) = a - b,
//    which is non-zero mod 31 when a != b. Swapping the last token symbol with
//    the check symbol is also caught (the check would need token == check).
//
// Token capacity: a 5-byte token holds 40 bits, but eight base-31 symbols hold
// only 31^8 = 852,891,037,441 values (about 39.6 bits), and 2^40 is larger.
// So encodeInviteCode reduces the 40-bit value modulo 31^8. Tokens that the
// server issues must be canonical (value < 31^8, see isCanonicalToken5 and
// token5FromValue) so that encoding is one-to-one and decodeInviteCode returns
// the same bytes. A non-canonical token still encodes, but collides with
// another token, so the server must not issue one.

import 'dart:typed_data';

/// The 31 symbols of an invite code.
const String inviteAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

/// Symbols that carry the token.
const int inviteTokenSymbols = 8;

/// Token symbols plus one check symbol.
const int inviteCodeLength = inviteTokenSymbols + 1;

/// Bytes in a token.
const int inviteTokenBytes = 5;

/// 31^8, the number of distinct token values a code can carry.
const int inviteTokenSpace = 852891037441;

const int _base = 31;

/// Whether the 5-byte token is below 31^8, so its code is unique to it.
bool isCanonicalToken5(Uint8List token5) =>
    token5.length == inviteTokenBytes && _tokenValue(token5) < inviteTokenSpace;

/// Builds a 5-byte token from an integer in [0, 40 bits), big-endian.
Uint8List token5FromValue(int value) {
  if (value < 0 || value >= (1 << 40)) {
    throw RangeError.range(value, 0, (1 << 40) - 1, 'value');
  }
  final out = Uint8List(inviteTokenBytes);
  var v = value;
  for (var i = inviteTokenBytes - 1; i >= 0; i--) {
    out[i] = v & 0xFF;
    v >>= 8;
  }
  return out;
}

int _tokenValue(Uint8List token5) {
  var v = 0;
  for (final b in token5) {
    v = (v << 8) | b;
  }
  return v;
}

int _checkIndex(List<int> tokenIndexes) {
  var sum = 0;
  for (var i = 0; i < inviteTokenSymbols; i++) {
    sum += tokenIndexes[i] * (i + 1);
  }
  return sum % _base;
}

/// Encodes a 5-byte token as 9 symbols: 8 token symbols then the check symbol.
///
/// The token is read as a big-endian 40-bit integer, reduced modulo 31^8 and
/// written as eight base-31 digits, most significant first.
String encodeInviteCode(Uint8List token5) {
  if (token5.length != inviteTokenBytes) {
    throw ArgumentError.value(
      token5.length,
      'token5.length',
      'must be $inviteTokenBytes bytes',
    );
  }
  var v = _tokenValue(token5) % inviteTokenSpace;
  final indexes = List<int>.filled(inviteTokenSymbols, 0);
  for (var i = inviteTokenSymbols - 1; i >= 0; i--) {
    indexes[i] = v % _base;
    v ~/= _base;
  }
  final buf = StringBuffer();
  for (final idx in indexes) {
    buf.write(inviteAlphabet[idx]);
  }
  buf.write(inviteAlphabet[_checkIndex(indexes)]);
  return buf.toString();
}

/// Uppercases and removes spaces and hyphens. Does not validate.
String normaliseInviteCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Splits a normalised code as XXXX-XXXX-X for display.
String formatInviteCode(String code) {
  final c = normaliseInviteCode(code);
  final parts = <String>[];
  for (var i = 0; i < c.length; i += 4) {
    parts.add(c.substring(i, i + 4 > c.length ? c.length : i + 4));
  }
  return parts.join('-');
}

/// Whether [code], after normalisation, is 9 alphabet symbols with a correct
/// check symbol. Works offline, no lookup.
bool isValidInviteCode(String code) => _indexes(code) != null;

/// Returns the 5-byte token for a valid code, or null if the code is invalid.
Uint8List? decodeInviteCode(String code) {
  final idx = _indexes(code);
  if (idx == null) return null;
  var v = 0;
  for (var i = 0; i < inviteTokenSymbols; i++) {
    v = v * _base + idx[i];
  }
  return token5FromValue(v);
}

/// Symbol indexes (9 of them) of a valid code, otherwise null.
List<int>? _indexes(String code) {
  final c = normaliseInviteCode(code);
  if (c.length != inviteCodeLength) return null;
  final idx = <int>[];
  for (var i = 0; i < c.length; i++) {
    final k = inviteAlphabet.indexOf(c[i]);
    if (k < 0) return null;
    idx.add(k);
  }
  if (_checkIndex(idx) != idx[inviteTokenSymbols]) return null;
  return idx;
}
