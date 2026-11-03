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
- `app/lib/data/database.g.dart` is generated and committed, so a fresh checkout compiles without running codegen. Regenerate it after any change to a Drift table.
- `flutter config --android-sdk` was not needed: Flutter finds the SDK through `ANDROID_HOME`.
- Weakest test phone: not yet named. Needed for every awaiting-phone measurement (see Next and [spike-results.md](spike-results.md)).

## Decisions

Plan decisions A to H fill gaps in the design. Task 7 wrote decisions A to G into the design document (section 13) and Task 13b wrote H, so the founder can accept or change them.

- **A.** `person` gets a nullable `sex` ("son of" versus "daughter of"; unknown reads "child of"). The design's table sketch has no such field.
- **B.** `house` gets a nullable `ordinal` (house 2). A house can exist with a known number and an unknown wife ("houses 1 and 3 are unknown").
- **C.** A wife's membership is a `wifeOfHouse` claim (displayed "married"). `belongsToHouse` carries only the basis `bornTo` or `joined`. This keeps "child of one house" single-valued and "wife of several houses" multi-valued.
- **D.** One account replacing another account's claim never supersedes it: both stay active and show "Accounts differ". `baseClaimId` supersedes the claim it names only when that claim is active, of the same kind, asserted by the same account, and on the same contest key or about the same subject. Any other base is stale: nothing is superseded and no error is raised. The same-subject rule lets one account move a wife from one house to another (a wife claim contests by house). "Competing" means active claims on one contest key hold more than one distinct content (subject, object, basis, body); accounts that agree on all four are not a dispute. This follows the anti-goal that persistence must not win by volume.
- **E.** When a person's parentage is disputed or cyclic, the chain stops at that person with "accounts differ".
- **F.** In M1 a `joined` basis displays as the neutral "belongs to". Showing the word "joined" waits for audience rules in M4. This settles the design's "known tension" for M1 only.
- **G.** `person_name(person_id, name, kind)` holds spelling variants and extra names (design edge case 12). `person.name_key` is the primary display name.
- **H.** In M1 the person who is "me" is kept in a local, never-synced `app_settings` row (Drift table `AppSettings`); from M2 it comes from the link between the account and its person.

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
| PostgreSQL (spike 1) | 16.15, Homebrew `postgresql@16` | `spikes/leak/README.md`, read from the tools on 2026-11-03 |
| sqlite3 (spikes 1, 2 and 5) | 3.8.0 | `spikes/leak/README.md`, `spikes/claims/README.md`, `spikes/crypto/README.md` (`pubspec.lock`) |
| flutter_secure_storage (spike 5) | 11.2.0 | `spikes/crypto/README.md` (`pubspec.lock`) |
| SQLite3MultipleCiphers, SQLite (spike 5) | 2.6.1, 3.54.0 | `spikes/crypto/README.md`, observed from the linked library |
| CMake (Android SDK) | 3.22.1, installed by Gradle during `flutter build apk --debug` in spike 5 | `spikes/crypto/README.md`; NDK 28.2.13676358 was already present |

`flutter doctor` on 2026-11-03:

- Flutter: clean.
- Android toolchain: clean. All licences accepted.
- Chrome: clean.
- Xcode: one warning, "iOS 27.2 Simulator not installed". Xcode 27.2 and CocoaPods 1.17.0 are present. Not needed until iOS work starts.

## Scale check (Task 14)

`app/test/tree/scale_test.dart` builds a synthetic tree of exactly 3,000 people through `HouseholdBuilder` (`app/test/fixtures/synthetic_tree.dart`, same shape as `spikes/tree/lib/gen.dart`) and runs the real readers over it. The generator is test code and is not shipped.

Reading of "20 women who appear in two houses" (the plan's wording is ambiguous, so both readings are built): 10 women are the wife of two houses under two different husbands who are brothers, and 10 other women are a daughter in one house and the wife of another. The second set is a subset of ordinary married women in this model, picked so a test can name them.

Every number below is **host proxy, Apple M4 class, in-memory SQLite** (chip read from `sysctl -n machdep.cpu.brand_string`: "Apple M4"), from `flutter test test/tree/scale_test.dart` on 2026-11-03. It is NOT a weak-phone result and is not compared with any phone threshold. The 100 ms bound is the plan's own number, not the design's.

| Measure (host proxy, in-memory SQLite) | Result |
|---|---|
| `spokenChain` for the deepest person (15 lines), 20 timed calls after 3 warmups, median | 5.65 to 6.04 ms (5 runs) |
| Same, 95th percentile (nearest rank) | 6.27 to 6.56 ms |
| `ancestorsOf` for all 3,000 people, total (about 5.7 ms a call), longest chain 14 steps | 16.8 to 17.2 s (5 runs) |
| Building the 3,000 people (people, houses and all claims, one transaction) | 8.9 to 10.2 s (5 runs) |

- No index was needed: the median is far under 100 ms, so no Drift index on `Claims(kind, subjectId, status)` was added and there is no before-and-after figure. `ancestorsOf` still reads every active `belongsToHouse` claim and every house per call; that cost is visible in the 17 s loop and grows with the family.
- Generation through the builder fitted in 60 s, the threshold the Task 14 plan resolutions set for falling back to direct Drift inserts, so the fallback was not used. The generator does not reproduce the spike's very-long-name branch (names of 80 or more characters).
- The test also seeds one cycle and one disputed person into the same tree, with the extra claims rolled back, and checks that `ancestorsOf` and `spokenChain` stop at them.
- Not measured: `buildHouseViewModel` and `siblingsOf` at 3,000 people, and any widget build or frame time. The app shows one chain (about 15 lines here) and the father's houses; it has no 3,000-row list (spike 4 scrolled one).

Phone run of the 3,000-person tree (founder work). Status: **awaiting phone.**

| Phone | Cold start to chain visible | Chain and house view smoothness | Out-of-memory event |
|---|---|---|---|
| (not named) | awaiting phone | awaiting phone | awaiting phone |

Procedure. There is no clean way to load the tree into the app without adding production code, and none was added. Proposal, not built: a dev-only script `app/tool/seed_synthetic.dart`, outside `lib/` so it is never in the app, that opens a file with `NativeDatabase(File('related.sqlite'))`, calls `buildSyntheticTree(db, accountId: 'local')`, calls `db.setSelfPersonId(tree.deepestPersonId)` and closes. A throwaway script of that shape was run on this host with `dart run` and wrote a 3,000-person file (about 1.4 MB) in about 11 s; it was then deleted. The script must pass `accountId: 'local'` (the app's own account id, `localAccountId` in `app/lib/app.dart`); the generator's default is `'synthetic'`, and claims under that id would read as another account's, so they would show "accounts differ" against the phone's own edits (decision D). None of the adb, profile-build and `run-as` steps below has been run on a device; they are untested. To use it on the phone:

1. Install a debug build (`flutter run -d <device>`), then stop it. Debug is needed because `adb run-as` works only on debuggable builds.
2. `adb push related.sqlite /data/local/tmp/`, then `adb shell run-as ke.related.app cp /data/local/tmp/related.sqlite app_flutter/related.sqlite`. The file name `related.sqlite` comes from `drift_flutter` and `main.dart`; the directory `app_flutter` is the usual Android documents directory and is inferred, not checked on a device. Delete any `related.sqlite-wal` and `-shm` next to it.
3. Cold start numbers need a profile build (debug numbers mean nothing): `flutter build apk --profile`, then `adb install -r` to keep the app's data (not tested). Force-stop the app, then `adb shell am start -W -n ke.related.app/.MainActivity` and record `TotalTime`, three runs, battery above 50 percent and nothing else open (as in `spikes/tree/README.md`).
4. Open the Family tab, switch between the chain and the houses, and note any stutter. Watch `adb logcat` for an out-of-memory event or a killed process (design section 14 notes an Android out-of-memory caveat for complex Drift queries).

## Next

State at the end of M1 (2026-11-03), all local commits, nothing pushed:

- Built: spikes 1 to 5 (`spikes/`, results in [spike-results.md](spike-results.md)); the Drift schema, claims, household builder, ancestor query, sibling groups, spoken chain, theme, chain and house views, first-run screen, family tab, app root and the local self-person setting (Tasks 7 to 13); the 3,000-person scale check (Task 14). `flutter test` and `flutter analyze` in `app/` are clean.
- Not done: nothing has been run on a phone or emulator. Every phone cell in `docs/spike-results.md` and in the scale check above reads "awaiting phone". The host-machine numbers are a proxy, not a weak-phone result.

Awaiting the founder:

1. Review `docs/spike-results.md` and answer its three proposals and seven open questions.
2. Task 1: paper test with relatives. The founder runs it. The script is `docs/paper-test.md`. No interviews are recorded yet.
3. Name the weakest test phone and record its model, RAM and Android version above. It unlocks the spike 3 on-device matrix, the spike 4 layout and frame timing, and the spike 5 cold start, update survival and backup and restore. Procedures are in each spike's README.
4. Task 13 step 5: run the app on the weakest phone and enter your own first-run household by hand, then note anything awkward here. The app is prepared (`cd app && flutter run`); this has not been done.

   Warning before you do. `app/lib/main.dart` opens an unencrypted database (encryption is a later milestone). `app/android/app/src/main/AndroidManifest.xml` sets no `android:allowBackup` attribute (read on 2026-11-03), so the app keeps Android's default for it, which is to allow backup; I did not change the manifest. The household names you type may therefore be included in Android's cloud backup. What you type is M1 data: M2 will have to move or reset it.
5. Task 14 step 5: the 3,000-person run on the phone (see Scale check above).
6. Open questions on choices made in M1. Answer each, or accept it as it is:
   1. Decision E has no stated reason in the plan. Supply one, or accept it as it is.
   2. When two accounts name the same house but differ only on basis (joined versus born to), the chain stops with "accounts differ". Keep that, or treat the two as agreeing for ancestry?
   3. The app shows wording the design did not specify: "wife not known yet", "born to this house", "belongs to this house", and ", same person, accounts differ" for a contested placement. Accept it or change it?
   4. "20 women who appear in two houses" can be read two ways. Both readings were built (see Scale check above). Which did you mean?
   5. When the father is not known at first run, he shows as a dashed "someone we forgot" in both the chain and the houses view. Is that what you want?

Next: the founder reviews `docs/spike-results.md` and answers its open questions, then M2 to M6 are planned from it. The M2 to M6 plan is not written yet; the plan says it is written only after that review.

M2 must do first: M1 claims are written with `assertedBy = 'local'` (`localAccountId` in `app/lib/app.dart`), and people and houses with `createdBy = 'local'`. Before the first edit or sync, M2 must, in one transaction, rewrite `'local'` to the real account id in `persons.createdBy`, `houses.createdBy`, `claims.assertedBy` and `field_edits.assertedBy`, and link the account to its person. Otherwise a user's own M1 claims read as another account's (decision D) and would show "accounts differ" against themselves. The id `'local'` must never be uploaded. M2 must also move or reset the unencrypted M1 database file, and bump the Drift schema version with a migration, because once the app has run on a device it will have written a database at schema version 1.

## Known limits at M1 exit

- `localSeq` is local to each device, so "earliest by arrival" can differ between devices after M2 sync.
- The houses of the aunt's husbands are not reachable from the app in M1: the family tab shows only the father's houses. The case is covered at model and widget level.
- A chain longer than the 60-step cap ends with a last line that reads "son of someone we forgot". This is known and unlikely.
- The dashed outline around "someone we forgot" is laid out separately from the text. With the phone's bold-text or text-spacing accessibility settings on, the outline can sit slightly off the words (reasoned from Flutter's source and one probe; the label and text are unaffected). Child lines for a placeholder child are not outlined.
