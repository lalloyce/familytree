// Spike 5: where the database key lives.
//
// Pure Dart (no Flutter import), so the cold-start benchmark can run it in a
// plain `dart` process. The platform implementation is in
// secure_key_store.dart.

import 'dart:io';
import 'dart:math';

/// Thrown by [KeyStore.readKey] when the store could not be read (a platform
/// failure). This is NOT "no key": the key may still be there, so callers
/// must not delete data or write a new key in response.
class KeyReadException implements Exception {
  KeyReadException(this.cause);

  final Object cause;

  @override
  String toString() => 'KeyReadException: $cause';
}

/// Holds the one database key for this install.
abstract class KeyStore {
  /// The stored key, or null only when no key is stored.
  /// Throws [KeyReadException] when the store could not be read.
  Future<String?> readKey();

  Future<void> writeKey(String key);

  Future<void> deleteKey();
}

/// Generates a new random key: 32 bytes from [Random.secure], as 64
/// lowercase hex characters.
String generateKey([Random? random]) {
  final r = random ?? Random.secure();
  final sb = StringBuffer();
  for (var i = 0; i < 32; i++) {
    sb.write(r.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// True for a key in the form [generateKey] produces.
bool isWellFormedKey(String key) => RegExp(r'^[0-9a-f]{64}$').hasMatch(key);

/// In-memory fake for host tests. Forgets everything when dropped.
class MemoryKeyStore implements KeyStore {
  String? _key;

  @override
  Future<String?> readKey() async => _key;

  @override
  Future<void> writeKey(String key) async => _key = key;

  @override
  Future<void> deleteKey() async => _key = null;
}

/// TEST AND BENCHMARK ONLY. Keeps the key in a plain file so a second,
/// separate process can read it (the simulated app update and the cold-start
/// benchmark). It is not secure storage and must never ship.
class PlainFileKeyStoreForTests implements KeyStore {
  PlainFileKeyStoreForTests(this.file);

  final File file;

  @override
  Future<String?> readKey() async =>
      await file.exists() ? (await file.readAsString()).trim() : null;

  @override
  Future<void> writeKey(String key) => file.writeAsString(key, flush: true);

  @override
  Future<void> deleteKey() async {
    if (await file.exists()) await file.delete();
  }
}
