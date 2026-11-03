// Spike 5: the platform secure-storage KeyStore.
//
// Android options are the flutter_secure_storage 11.2.0 defaults
// (`AndroidOptions()`). Per its README and lib/options/android_options.dart,
// that default wraps an AES-GCM storage key with RSA/ECB/OAEPWithSHA-256AndMGF1
// in the Android KeyStore, and both `resetOnError` and
// `migrateOnAlgorithmChange` default to true. With `resetOnError` the plugin
// itself erases its stored data on a decryption error (see README, "When the
// app deletes or sets aside local data"). Read from the package, not tested
// on a phone. The defaults are kept here on purpose so the phone restore test
// shows the plugin's real behaviour.
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

  /// Returns null only when the plugin reports no value. A platform failure
  /// becomes [KeyReadException], so coldStart() leaves the data alone.
  @override
  Future<String?> readKey() async {
    try {
      return await _storage.read(key: _name);
    } on PlatformException catch (e) {
      debugPrint('SecureKeyStore.readKey failed: $e');
      throw KeyReadException(e);
    }
  }

  /// On failure, deletes and rewrites only this spike's own key name, never
  /// the rest of the store.
  @override
  Future<void> writeKey(String key) async {
    try {
      await _storage.write(key: _name, value: key);
    } on PlatformException catch (e) {
      debugPrint('SecureKeyStore.writeKey failed, retrying once: $e');
      await _storage.delete(key: _name);
      await _storage.write(key: _name, value: key);
    }
  }

  @override
  Future<void> deleteKey() => _storage.delete(key: _name);
}
