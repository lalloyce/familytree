# Project notes

State of the project for a fresh session. Claude does not remember earlier sessions, so read this first and keep it current.

- Design: [2026-11-03-lineage-app-design.md](2026-11-03-lineage-app-design.md)
- Plan (Phase 0 and M1): [superpowers/plans/2026-11-03-lineage-app-phase0-m1.md](superpowers/plans/2026-11-03-lineage-app-phase0-m1.md)
- Rule: commit only when asked. One commit is one complete task. Never push without being asked.

## How to run

Every session must source the environment file first. It sets `JAVA_HOME`, `ANDROID_HOME` and `PATH` for that shell only. No shell profile is edited.

```sh
cd /Users/lawrencejuma/Dev/related
source scripts/env.sh
flutter doctor        # Flutter and Android toolchain lines should be clean
cd app
flutter pub get
dart run build_runner build   # regenerates lib/**/*.g.dart
flutter test
```

- The Dart package is `related`; the Android application ID is `ke.related.app` (from `flutter create --org ke.related ... app`).
- `app/lib/data/app_database.g.dart` is generated and committed, so a fresh checkout compiles without running codegen. Regenerate it after any change to a Drift table.
- `flutter config --android-sdk` was not needed: Flutter finds the SDK through `ANDROID_HOME`.
- Weakest test phone: not yet named. Needed before Task 4 step 5.

## Decisions

Plan decisions A to G fill gaps in the design. Task 7 writes them into the design document (section 13) so the founder can accept or change them.

- **A.** `person` gets a nullable `sex` ("son of" versus "daughter of"; unknown reads "child of"). The design's table sketch has no such field.
- **B.** `house` gets a nullable `ordinal` (house 2). A house can exist with a known number and an unknown wife ("houses 1 and 3 are unknown").
- **C.** A wife's membership is a `wifeOfHouse` claim (displayed "married"). `belongsToHouse` carries only the basis `bornTo` or `joined`. This keeps "child of one house" single-valued and "wife of several houses" multi-valued.
- **D.** One person replacing another person's claim never supersedes it. Both stay active and show "Accounts differ". Only the same asserter, with the current claim as their base, supersedes their own claim. This follows the anti-goal that persistence must not win by volume.
- **E.** When a person's parentage is disputed or cyclic, the chain stops at that person with "accounts differ".
- **F.** In M1 a `joined` basis displays as the neutral "belongs to". Showing the word "joined" waits for audience rules in M4. This settles the design's "known tension" for M1 only.
- **G.** `person_name(person_id, name, kind)` holds spelling variants and extra names (design edge case 12). `person.name_key` is the primary display name.

Setup decisions (Task 0):

- Flutter and the Android command-line tools were installed with Homebrew (casks `flutter` and `android-commandlinetools`). The founder authorised this. No Android Studio and no emulator images.
- The JDK is the existing Homebrew `openjdk@21`. No JDK was installed.
- The environment lives in `scripts/env.sh`, not in `~/.zshrc` or any other profile. The founder did not authorise editing profiles.
- iOS and web are scaffolded but not needed until later. The pilot is Android only.

## Versions

Read from the tools on 2026-11-03.

| Item | Version | Source |
|---|---|---|
| Flutter | 3.47.9, stable channel, revision c197ca5199 | `flutter --version` |
| Dart | 3.13.7 (stable) | `dart --version` |
| DevTools | 2.60.0 | `flutter --version` |
| Android SDK platform | android-36 | `flutter doctor -v` |
| Android build-tools | 36.0.0 | `flutter doctor -v` |
| Android platform-tools (adb) | 37.0.1-15733141 | `adb --version` |
| Android command-line tools | cask 15859902; `sdkmanager --version` prints 22.0 | `brew list --cask --versions`, `sdkmanager` |
| JDK | OpenJDK 21.0.13.0.2 (Homebrew `openjdk@21`) | `java -version` |
| drift | ^2.35.3 | `app/pubspec.yaml` (exact versions in `app/pubspec.lock`) |
| drift_flutter | ^0.3.1 | `app/pubspec.yaml` |
| uuid | ^4.6.0 | `app/pubspec.yaml` |
| drift_dev (dev) | ^2.35.2 | `app/pubspec.yaml` |
| build_runner (dev) | ^2.17.1 | `app/pubspec.yaml` |

`flutter doctor` on 2026-11-03:

- Flutter: clean.
- Android toolchain: clean. All licences accepted.
- Chrome: clean.
- Xcode: one warning, "iOS 27.2 Simulator not installed". Xcode 27.2 and CocoaPods 1.17.0 are present. Not needed until iOS work starts.

## Next

1. Task 1: paper test with relatives. The founder runs it. Script goes in `docs/paper-test.md`.
2. Name the weakest test phone and record its model and RAM above. Needed before Task 4 step 5.
3. Later tasks add the Drift tables (Task 7). `AppDatabase` in `app/lib/data/app_database.dart` has an empty schema for now.
