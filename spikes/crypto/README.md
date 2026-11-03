# Spike 5: encrypted database and cold start

Throwaway. Design section 10, spike 5: "Cold start with an encrypted database: under 3 seconds, key survives an app update, restore does not expose data." Design section 9: the local database is encrypted from the first install with a random key held in the platform's secure storage, and a restored database without its key means a re-sync.

**Status: written and tested on the founder's Mac only. No phone and no emulator exist, so none of the three phone checks (cold start, update, backup and restore) has been run. Weak-phone result: awaiting phone. Nothing in this file declares the 3-second threshold passed.**

## What was built

- `lib/database.dart`: a Drift database (`SpikeDb`, one table `people`) and `openEncryptedDatabase(file, key)`. The key is applied with `PRAGMA key` in Drift's `setup` callback. Before that, `setup` checks `PRAGMA cipher` and throws `CipherMissingError` if SQLite3MultipleCiphers is not linked, so a build mistake can never create a plain database. After the key, `setup` reads `sqlite_master`, because SQLite3MultipleCiphers' `PRAGMA key` "return[s] `ok` even if the provided key isn't correct" (its pragma docs). `isNotADatabase(error)` recognises SQLITE_NOTADB (code 26) through Drift's isolate wrapper.
- Two key forms, both tested: `KeyForm.passphrase` (`PRAGMA key = '<64 hex>'`, the Drift docs' form) and `KeyForm.raw` (`PRAGMA key = 'raw:<64 hex>'`, which the SQLite3MultipleCiphers docs describe as "converted directly to 32 bytes (256 bits) of key data"). The default is `passphrase`.
- `lib/key_store.dart`: the `KeyStore` interface, `generateKey()` (32 bytes from `Random.secure()`, 64 hex characters), `MemoryKeyStore` (fake for host tests) and `PlainFileKeyStoreForTests` (a plain file, so a second process can read the key; test and benchmark only, never shipped).
- `lib/secure_key_store.dart`: `SecureKeyStore`, backed by flutter_secure_storage with `AndroidOptions()` (the package default) and, for the Mac run only, `MacOsOptions(usesDataProtectionKeychain: false)`. A `PlatformException` on read is treated as "no key"; on write the store is cleared once and the write retried.
- `lib/cold_start.dart`: `coldStart(keys, dbFile)`, the first-run versus returning-run flow:

  | Key stored? | Database file? | Outcome |
  |---|---|---|
  | no | no | `firstRun`: generate key, store it, create empty encrypted database |
  | yes | yes, key opens it | `returning` |
  | no | yes | `resyncNeeded` (`keyMissing`): delete the unreadable file, new key, clean database |
  | yes | yes, key rejected | `resyncNeeded` (`keyRejected`): same fallback |
  | yes | no | `resyncNeeded` (`databaseMissing`): clean database with the stored key |

  The unreadable-data cases never throw to the caller. Any other error (disk full, a bug) is rethrown so it is not hidden.
- `lib/main.dart`: the Flutter app. Opens the database before `runApp`, shows the state (the `resyncNeeded` text says to sign in and download the family again and that unsent work is lost), and after the first frame prints one `COLD_START_RESULT` line. On a first run (or after a fallback) it adds 3,000 synthetic people after the first frame, so later starts open a realistic database. With `--dart-define=AUTORUN=true` it also writes the line to `<application support dir>/cold_start_result.txt` and exits. On Linux and Android it adds `process_to_first_frame_ms`, read from `/proc/self/stat` and `/proc/uptime` (assumes 100 clock ticks per second; not checked on a phone).
- `bin/cold_start_child.dart`: one cold start in a fresh `dart` process. `bin/cold_start_bench.dart`: runs the compiled child 40 times per key form.
- `test/crypto_test.dart`: 15 host tests, listed below.

Not built: PowerSync, any sync, sign-in, iOS, and the real app's schema.

## Encryption approach and why

**SQLite3MultipleCiphers, bundled by the `sqlite3` package's build hook, with `package:drift/native.dart` unchanged.** This is what the Drift documentation recommends today: "For new apps, we recommend using a NativeDatabase with encrypted databases." The setup is one pubspec entry:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

The same page says `sqlcipher_flutter_libs` "is no longer necessary after upgrading to drift 2.32.0 and can be removed". The alternative it describes, `encrypted_drift` (a git dependency wrapping `sqflite_sqlcipher`), needs extra Android and iOS setup such as ProGuard rules and was not used.

The `sqlite3` package's hook document says the published binaries come from GitHub releases, are "compiled directly from upstream sources in GitHub actions", and are checked against sha256 hashes in the pub.dev package; three builds exist per platform (upstream SQLite, SQLite3MultipleCiphers, SQLCipher). It also notes that SQLite3MultipleCiphers has its own licence (not reviewed here).

Observed in this run: `PRAGMA cipher` returns `chacha20`; `sqlite3mc_version()` returns `SQLite3 Multiple Ciphers 2.6.1`; `sqlite_version()` returns `3.54.0`. The SQLite3MultipleCiphers docs say ChaCha20-Poly1305 is its default cipher, with PBKDF2-SHA256 key derivation and a default `kdf_iter` of 64007. The macOS build bundles `sqlite3mc.framework` (seen in the app bundle); the debug APK contains `libsqlite3mc.so` for arm64-v8a, armeabi-v7a and x86_64 (seen with `unzip -l`).

Versions, from `pubspec.lock`: drift 2.35.3, drift_dev 2.35.2, sqlite3 3.8.0, flutter_secure_storage 11.2.0 (flutter_secure_storage_darwin 0.4.3, platform_interface 2.1.1), path_provider 2.1.6, path_provider_android 2.3.1, hooks 2.2.0, code_assets 2.1.0, build_runner 2.17.1. Flutter 3.47.9, Dart 3.13.7. No `sqlite3_flutter_libs` or `sqlcipher_flutter_libs` in the lock file.

### Sources read (2026-11-03)

- Drift, Encryption: https://drift.simonbinder.eu/platforms/encryption/
- sqlite3 3.8.0 `doc/hook.md` (in the pub cache; same text on the repository's main branch): https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md, and https://pub.dev/packages/sqlite3
- SQLite3MultipleCiphers, SQL pragmas: https://utelle.github.io/SQLite3MultipleCiphers/docs/configuration/config_sql_pragmas/
- SQLite3MultipleCiphers, ChaCha20 cipher: https://utelle.github.io/SQLite3MultipleCiphers/docs/ciphers/cipher_chacha20/
- flutter_secure_storage 11.2.0 README and `lib/options/android_options.dart`, `lib/options/macos_options.dart`, Android `FlutterSecureStorageConfig.java` (pub cache), and https://pub.dev/packages/flutter_secure_storage
- path_provider_android 2.3.1 `lib/src/path_provider_android_real.dart` (pub cache)
- Android, Auto Backup: https://developer.android.com/identity/data/autobackup
- Android, Test backup and restore: https://developer.android.com/identity/data/testingbackup
- Android 12 behaviour changes (backup and `adb backup`): https://developer.android.com/about/versions/12/behavior-changes-12

## Android secure storage default (design "not verified" item): read from docs, NOT tested

From flutter_secure_storage 11.2.0's README and source:

- `AndroidOptions()` is the default. Key cipher `RSA/ECB/OAEPWithSHA-256AndMGF1Padding`, storage cipher `AES/GCM/NoPadding`, no biometrics. The README calls it "Standard secure storage with RSA OAEP key wrapping". Version 10 replaced the Jetpack `encryptedSharedPreferences`, which it says "is no longer recommended". Minimum Android SDK 23.
- Values are stored in SharedPreferences (default name `FlutterSecureStorage`, from `FlutterSecureStorageConfig.java`); the wrapping key is in the Android KeyStore.
- `resetOnError` defaults to `true`. The source comment: "When an error is detected, automatically reset all data ... it will PERMANENTLY erase the data when an error occurs."
- The README warns: "By default Android backups data on Google Drive. It can cause exception `java.security.InvalidKeyException: Failed to unwrap key`," and tells you to disable auto backup or exclude the plugin's shared preferences. Inferred, not read: the KeyStore key is not part of the backup, so restored preferences cannot be decrypted.

None of this was run on Android. Whether a read after a restore returns null (after the reset) or throws is not known; `SecureKeyStore` handles both by treating them as "no key".

## Run

```
source scripts/env.sh
cd spikes/crypto
flutter pub get
dart run build_runner build          # regenerates lib/database.g.dart (committed)
flutter analyze
flutter test                         # 15 tests

# host-proxy cold start, compiled child in a fresh process per run
dart build cli -t bin/cold_start_child.dart
dart run bin/cold_start_bench.dart --exe build/cli/macos_arm64/bundle/bin/cold_start_child --runs 40

# macOS app with the real keychain-backed KeyStore
flutter build macos --profile --dart-define=AUTORUN=true
open -n build/macos/Build/Products/Profile/crypto_spike.app
# result: ~/Library/Containers/spike.crypto.cryptoSpike/Data/Library/Application Support/spike.crypto.cryptoSpike/cold_start_result.txt

flutter build apk --debug            # built, not run on a device
```

## Host proof results

`flutter test`, 15 of 15 passed (output quoted in the task report). What each proves, with the real SQLite3MultipleCiphers library:

1. The linked SQLite is SQLite3MultipleCiphers (`PRAGMA cipher` returns `chacha20`).
2. `generateKey` gives 64 hex characters and differs per call.
3. **Control:** a database opened without a key DOES start with `SQLite format 3\0` and DOES contain the marker string. This shows the byte search below would catch plaintext.
4. For each key form (passphrase, raw): after writing 200 rows that include the marker `PLAINTEXT_MARKER_Akinyi_Odhiambo_7f3c19`, every file SQLite left (`lineage.db`; no `-journal` or `-wal` remained after close) contains no marker, no row value (`Person 1`), no `CREATE TABLE`, and does not start with the SQLite header.
5. For each key form: opening the file without a key fails with SQLITE_NOTADB (26).
6. For each key form: opening with a different random key fails; the error arrives as `DriftRemoteException` wrapping `SqliteException(26): ... file is not a database`, and `isNotADatabase` recognises it.
7. An independent SQLite (the `python3` sqlite3 module, version 3.54.0) cannot read the file: `sqlite3.DatabaseError: file is not a database`.
8. First run creates and stores a key; a returning run reads the same key and sees the rows.
9. **Simulated app update:** process 1 (the test) does a first run, writes 25 rows and stores the key in a plain file; process 2 (`dart run bin/cold_start_child.dart`, a new OS process) reads the key and reports `state=returning people=25`. This simulates only key persistence across process death. It does not simulate an Android package update, where the question is whether the KeyStore entry and the SharedPreferences survive `adb install -r`.
10. **Restore without the key:** the database file is copied to a new directory with an empty key store. The copy contains no marker. `coldStart` returns `resyncNeeded` / `keyMissing` with 0 people and a new stored key, without throwing.
11. Restore onto a store holding a different key: `resyncNeeded` / `keyRejected`, clean database, no exception; the next start is `returning` with the new data.
12. Key present but database gone: `resyncNeeded` / `databaseMissing`.

Also checked by hand on the Mac app (profile build, real keychain through `SecureKeyStore`):

- The app's `lineage.db` (348,160 bytes, 3,000 people) starts with bytes `4e52 150a 5d6d 4812 ...`, not the SQLite header; `grep -a -c "Person 1"` gives 0; python3's sqlite3 says "file is not a database".
- The key is in the login keychain (`security find-generic-password -a db_key_v1` shows service `flutter_secure_storage_service`; the secret was not printed).
- After deleting that keychain item (`security delete-generic-password`), the next launch reported `state=resyncNeeded reason=keyMissing people=0`, and the launch after that `state=returning people=3000`. Done twice, once per build.

## Host-proxy cold-start numbers (NOT a weak-phone result)

Machine, as read from tools: Apple M4 (`sysctl machdep.cpu.brand_string`), 10 logical CPUs (`hw.ncpu`), 17,179,869,184 bytes memory (`hw.memsize`), macOS 27.2 build 26B123 (`sw_vers`). Flutter 3.47.9, Dart 3.13.7. Database of 3,000 people, 348,160 bytes. The OS file cache was warm after the first run; it was not cleared. Percentiles are nearest-rank. All times in milliseconds.

### A. Compiled `dart` child, 40 fresh processes per key form

`inner` is from the start of `coldStart()` (key read from a file, Drift background isolate start, library load, key derivation, first query) to the first query result. `outer` is from the parent's `Process.run` to the child's exit, so it includes process start-up and shutdown. `plain-control` is the same Drift path with no key on an unencrypted file.

| Form | Measure | Run 1: min / median / p95 / max | Run 2: min / median / p95 / max |
|---|---|---|---|
| passphrase | inner | 15.8 / 16.2 / 16.4 / 400.9 | 16.3 / 16.7 / 17.8 / 22.9 |
| passphrase | outer | 28.8 / 29.6 / 34.2 / 858.4 | 29.3 / 30.1 / 32.7 / 55.4 |
| raw | inner | 1.8 / 1.9 / 2.1 / 2.1 | 1.9 / 2.1 / 2.2 / 2.4 |
| raw | outer | 13.7 / 14.7 / 15.1 / 15.4 | 14.7 / 15.5 / 15.9 / 16.1 |
| plain-control | inner | 1.5 / 1.5 / 1.7 / 1.7 | 1.6 / 1.8 / 2.0 / 2.1 |
| plain-control | outer | 13.3 / 14.1 / 14.5 / 14.8 | 14.6 / 15.4 / 17.5 / 18.1 |

The 400.9 ms and 858.4 ms maxima in run 1 are the very first launch of a freshly built executable; the p95 of that set is 16.4 ms inner. The cause was not investigated.

Finding: on this Mac the passphrase form costs about 14 to 15 ms more per open than the raw form, which costs 0.3 to 0.4 ms more than no encryption (median against median). Inferred, not documented on the pages read: the raw form skips the PBKDF2 derivation (64,007 iterations by default). A weak phone's CPU will make that difference larger by an unmeasured factor. Since the key is already 256 random bits, derivation adds nothing to security for this design; switching to `KeyForm.raw` is a one-line change. Decision left to the founder after the phone numbers.

### B. The Flutter app (macOS profile build, real keychain), 32 launches with `open -n`

Each launch was a returning start (`state=returning people=3000`, passphrase form). `launch_to_first_frame` is from a timestamp taken just before `open -n` to the epoch time recorded in the first post-frame callback, so it includes macOS LaunchServices, process start and engine start-up.

| Measure | Build 1: min / median / p95 / max | Build 2 (final code): min / median / p95 / max |
|---|---|---|
| key read (keychain) | 7.8 / 10.2 / 21.8 / 28.0 | 7.7 / 11.1 / 40.1 / 56.1 |
| `coldStart` (key read to first query result) | 25.7 / 29.3 / 45.8 / 48.1 | 25.7 / 30.8 / 73.6 / 116.9 |
| `main()` to database ready | 42.0 / 47.9 / 65.2 / 71.0 | 35.4 / 49.4 / 107.1 / 131.7 |
| `main()` to first frame | 44.4 / 50.5 / 67.8 / 73.8 | 38.1 / 52.3 / 109.8 / 140.9 |
| launch to first frame | 257.6 / 288.7 / 314.3 / 314.9 | 237.3 / 283.0 / 341.8 / 1102.3 |

Build 2 differs from build 1 only in `SecureKeyStore` error handling and the `/proc` reading (which returns nothing on macOS). One first-run launch (build 1, empty keychain and no database): key read 32.0, `coldStart` 88.8, `main()` to first frame 135.5.

**Weak-phone result: awaiting phone.**

## Phone procedures (founder, when a phone is available)

Package `spike.crypto.crypto_spike`, activity `.MainActivity`. Run from the repository root after `source scripts/env.sh`, then `cd spikes/crypto`. Both installs in the update test must be signed with the same key, so build both versions with the same command on the same Mac (`android/app/build.gradle.kts` signs the release build type with the debug key; the profile build's signing was not checked). If `adb install -r` reports a signature mismatch, the test is invalid; do not uninstall in between, since that deletes the data and the key. Record the phone model, RAM and Android version (`adb shell getprop ro.build.version.release`, `adb shell getprop ro.product.model`).

The founder's Android version is not known [NEEDS SOURCE]. The cloud-backup procedure needs Android 6 or later; the device-to-device procedure needs Android 12 or later (Android test-backup page).

### 1. Update test (key survives an app update)

```
flutter build apk --profile --build-number=1
adb install -r build/app/outputs/flutter-apk/app-profile.apk
adb shell dumpsys package spike.crypto.crypto_spike | grep versionCode     # expect versionCode=1
adb logcat -c
adb shell am start -W -n spike.crypto.crypto_spike/.MainActivity
adb logcat -d | grep COLD_START_RESULT        # expect state=firstRun
# wait about 10 s for the 3,000-person seed, then:
adb shell am force-stop spike.crypto.crypto_spike
adb logcat -c; adb shell am start -W -n spike.crypto.crypto_spike/.MainActivity
adb logcat -d | grep COLD_START_RESULT        # expect state=returning people=3000

flutter build apk --profile --build-number=2
adb install -r build/app/outputs/flutter-apk/app-profile.apk
adb shell dumpsys package spike.crypto.crypto_spike | grep versionCode     # expect versionCode=2
adb logcat -c; adb shell am start -W -n spike.crypto.crypto_spike/.MainActivity
adb logcat -d | grep COLD_START_RESULT
```

Pass: the last line says `state=returning people=3000`. Fail: `state=resyncNeeded` (the key or the file was lost on update). `--build-number` sets the Android versionCode (Flutter's pubspec template comment).

### 2. Backup and restore test (restore without the key does not expose data)

The spike keeps Flutter's default manifest, which does not set `android:allowBackup`; the Android docs say the default is `true`. This is deliberate, so the restore actually brings the encrypted file back and the fallback is exercised. Use the debug APK so `run-as` can read the app's files.

1. `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`, launch once, wait about 10 s for the seed, relaunch and confirm `state=returning people=3000`.
2. Confirm where the database is: `adb shell run-as spike.crypto.crypto_spike ls -l files/` should list `lineage.db` (path_provider_android 2.3.1 maps the application support directory to `Context.getFilesDir()`, which Auto Backup includes by default).
3. Run the cloud-backup script from https://developer.android.com/identity/data/testingbackup (`test_cloud_backup.sh spike.crypto.crypto_spike`). It enables the backup manager, selects the local transport, runs `adb shell bmgr backupnow spike.crypto.crypto_spike`, uninstalls with `adb shell pm uninstall --user 0` and reinstalls with `adb install-multiple -t --user 0`, which triggers the restore. The device must be signed in to a Google account set as the backup account.
4. Before launching the app, capture the restored file: `adb shell run-as spike.crypto.crypto_spike ls -l files/ shared_prefs/` and `adb exec-out run-as spike.crypto.crypto_spike cat files/lineage.db > restored.db`. Check `xxd restored.db | head -1` (must not start `5351 4c69 7465` = "SQLite") and `grep -a -c "Person 1" restored.db` (must be 0).
5. Launch: `adb logcat -c; adb shell am start -W -n spike.crypto.crypto_spike/.MainActivity; adb logcat -d | grep -E "COLD_START_RESULT|SecureKeyStore"`.

Pass: no crash; the line says `state=resyncNeeded` with `reason=keyMissing` (or `keyRejected`) and `people=0`; the screen shows the re-sync text. Record whether `SecureKeyStore` logged a failure (this tells us whether flutter_secure_storage threw or reset silently). If step 4 shows no `lineage.db`, the backup did not include it; record that, since then the test shows nothing about the fallback.

On Android 12 or later, repeat with the D2D script on the same page (`test_d2d.sh`).

`adb backup`: the Android 12 behaviour-change page says that for apps targeting Android 12 or higher, app data is excluded from `adb backup` unless the app is `android:debuggable`. This spike targets SDK 36 (Flutter's default). Whether `adb backup` still works at all on the founder's Android version was not checked; use `bmgr` as above.

### 3. Cold-start measurement

```
flutter build apk --profile
adb install -r build/app/outputs/flutter-apk/app-profile.apk
adb shell am start -W -n spike.crypto.crypto_spike/.MainActivity   # first run seeds 3,000 people; wait 10 s
for i in $(seq 1 30); do
  adb shell am force-stop spike.crypto.crypto_spike; sleep 2
  adb logcat -c
  adb shell am start -W -n spike.crypto.crypto_spike/.MainActivity | grep -E "TotalTime|WaitTime"
  sleep 4
  adb logcat -d | grep COLD_START_RESULT
done
```

Record per run `process_to_first_frame_ms` (process start to first Flutter frame, from `/proc`), `main_to_first_frame_ms`, `cold_start_ms`, `key_read_ms` and `am start -W`'s `TotalTime`. Report min, median, p95 and max. Also do one run after `adb reboot` (cold file cache). The exact meaning of `TotalTime` and the 100-tick assumption behind `process_to_first_frame_ms` were not checked against a source; if they disagree by more than about 100 ms, note it. Then repeat the 30 runs with `KeyForm.raw` (change the default in `lib/database.dart`, reinstall after uninstalling, since a passphrase database will not open with the raw key) to measure the key-derivation cost on the phone.

Threshold (design): cold start to first frame with the database open under 3 seconds. Proposed reading: p95 of `process_to_first_frame_ms` under 3,000 ms, with the reboot run reported separately.

## Recommended backup settings for the real app (recommendation, NOT tested)

Design section 9 says a restore means a re-sync. The encrypted file is useless without the KeyStore key, and restored flutter_secure_storage preferences cause `Failed to unwrap key` (its README). So nothing in the local database or the key store should be backed up or transferred:

1. Keep the database in its own directory, for example `files/db/lineage.db`. Android's rule paths take no wildcards, but a directory rule covers everything below it, which catches `-journal` and `-wal` files.
2. Set `android:allowBackup="false"` (the flutter_secure_storage README's advice).
3. Also set `android:dataExtractionRules="@xml/data_extraction_rules"` (Android 12+) and `android:fullBackupContent="@xml/backup_rules"` (Android 11 and lower). The Android 12 page says that on some manufacturers' devices `allowBackup="false"` disables Google Drive backup but not device-to-device transfer, and that only the new format controls D2D.

`res/xml/data_extraction_rules.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="file" path="db/"/>
    <exclude domain="sharedpref" path="."/>
  </cloud-backup>
  <device-transfer>
    <exclude domain="file" path="db/"/>
    <exclude domain="sharedpref" path="."/>
  </device-transfer>
</data-extraction-rules>
```

`res/xml/backup_rules.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
  <exclude domain="file" path="db/"/>
  <exclude domain="sharedpref" path="."/>
</full-backup-content>
```

Excluding all shared preferences assumes the app keeps nothing there that should survive a restore. With these settings the phone backup test above should show no `lineage.db` after restore and a `firstRun` start; run it again on the real app to confirm. Users must still be told that unsent work is lost on a new phone (design section 9).

Two Android pages disagree on the cloud quota: Auto Backup says 25 MB per app; the testing page says 2 MB for cloud backup. Irrelevant if the database is excluded.

## What was NOT tested

- Anything on Android: cold start, update survival, backup and restore, D2D, the KeyStore, flutter_secure_storage's default ciphers, `resetOnError`, and whether its read throws or returns null after a restore. The debug APK was built (`flutter build apk --debug`, 189,367,254 bytes) but never installed.
- The 3-second threshold. Only host-proxy numbers exist.
- The Android package update. The host test simulates only key persistence across a new process.
- Whether `KeyForm.raw` skips key derivation (inferred from timing, not documented on the pages read).
- Journal or WAL contents during an open transaction (only files left after close were searched). Drift's default journal mode was used; WAL was not enabled.
- PowerSync with an encrypted Drift database (design "not verified" item). Not attempted.
- iOS, web, and the macOS data-protection keychain (the Mac run used the legacy keychain).
- Memory use, database sizes beyond 3,000 short rows, and a cold OS file cache on the Mac.
- The SQLite3MultipleCiphers licence.

## Build side effects

`flutter build apk --debug` made Gradle install CMake 3.22.1 into `/opt/homebrew/share/android-commandlinetools/cmake/3.22.1` (logged: "Install CMake 3.22.1 v.3.22.1 ... finished"). The NDK 28.2.13676358 was already present.
