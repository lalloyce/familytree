// Spike 5: the platform secure-storage KeyStore.
//
// Android options are the flutter_secure_storage 11.2.0 defaults
// (`AndroidOptions()`). Per its README and lib/options/android_options.dart,
// that default wraps an AES-GCM storage key with RSA/ECB/OAEPWithSHA-256AndMGF1
// in the Android KeyStore, and `resetOnError` defaults to true (on a
// decryption error the plugin erases its stored data). This was read from the
// package, not tested on a phone.
//
// macOS: `usesDataProtectionKeychain: false` uses the legacy keychain, which
// the README says avoids the keychain-access-groups entitlement and its
// provisioning profile. Only used for the host proxy run.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_store.dart';

class SecureKeyStore implements KeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            // Read only on macOS.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  static const _name = 'db_key_v1';
  final FlutterSecureStorage _storage;

  /// A store that cannot be decrypted (the flutter_secure_storage README
  /// names `InvalidKeyException: Failed to unwrap key` after an Android
  /// backup restore) is treated as "no key", so coldStart() falls back to a
  /// clean database instead of throwing. Not tested on a phone.
  @override
  Future<String?> readKey() async {
    try {
      return await _storage.read(key: _name);
    } on PlatformException catch (e) {
      debugPrint('SecureKeyStore.readKey failed, treating as no key: $e');
      return null;
    }
  }

  @override
  Future<void> writeKey(String key) async {
    try {
      await _storage.write(key: _name, value: key);
    } on PlatformException catch (e) {
      debugPrint('SecureKeyStore.writeKey failed, clearing store once: $e');
      await _storage.deleteAll();
      await _storage.write(key: _name, value: key);
    }
  }

  @override
  Future<void> deleteKey() => _storage.delete(key: _name);
}
