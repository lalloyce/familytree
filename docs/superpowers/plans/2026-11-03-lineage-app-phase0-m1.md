# Lineage App: Phase 0 and Milestone 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the risky design assumptions with five throwaway spikes and a paper test, then build Milestone 1: a local, offline Flutter app that records a family as houses and claims and shows it as a read-only spoken chain and house view at 3,000-person scale.

**Architecture:** A Flutter app (`app/`) holds an encrypted-later Drift/SQLite store. Facts are rows (`person`, `house`) plus append-only `claim` rows. Pure-Dart domain modules (`claims`, `tree`) read the store and produce display lines. The UI only displays what the domain returns. Spikes live in `spikes/` and are deleted or promoted once their result is recorded.

**Tech Stack:** Flutter (Android first, then iOS and web), Dart, Drift on SQLite, `flutter_test`, Postgres 16 and Docker for spikes 1 and 2.

**Spec:** `docs/2026-11-03-lineage-app-design.md` (approved by the founder on 2026-11-03). Executors read both.

**Scope of this plan.** The design's milestones M2 to M6 depend on what spikes 1, 2, 3 and 5 find (sync choice, leak rules, encryption setup). They are planned after the results are recorded in Task 6, not now. M1 touches none of those results, except that spike 4 tests the spoken-chain assumption it builds on.

## Global Constraints

- Flutter, targeting Android, iOS and web. The pilot is Android only.
- English only for the first release.
- Local store: Drift on SQLite. Server (later milestones): Postgres, Supabase a candidate.
- IDs are client-generated UUIDs. No sequences in any key that syncs. A name is never an identity.
- The client holds no visibility logic. It displays what the server sent.
- The app never shows "step" or "half".
- Basis is always a word ("born to", "joined", "married"), never colour or line style alone.
- Names wrap and are never truncated. Use the system font scale. No blur, shadow or animation.
- Body text contrast at least 4.5:1, large text at least 3:1. A 48dp touch target is the designer's figure and is unverified: treat it as a default, not a rule.
- Placeholder reads "someone we forgot", dashed outline. Empty house reads "not known yet", plain grey, no button.
- No completeness scores, streaks, nudges or prompts to fill in what the family does not say.
- Sign-in is email and password (M2 onward). Not used in this plan.
- Sub-agent calls set `model` explicitly (`sonnet` default, `haiku` for mechanical work, `opus` for hard debugging). Never `fable`. Re-read and re-run anything a sub-agent reports before repeating it.
- Commit only when the founder asks. Each task ends with a proposed commit message, not a commit. One commit is one complete task.
- Claude does not remember earlier sessions. Keep `docs/NOTES.md` current (Task 0) so a fresh session can continue.

## Review Focus

Failure modes the spec implies but a straight reading of the tasks would not test. Each has a test in the owning task.

1. A woman who is a daughter in one house and a wife in two others (husbands who are brothers): she appears in all three, tagged "same person", and no chain or ancestor query counts her twice or loops. (Tasks 10, 11, 13)
2. Two placeholders, or two people with the same name (two Winyos): never conflated; the chain tells them apart by father. (Tasks 9, 12)
3. A cycle in the lineage (a person is their own ancestor) arriving from bad or merged data: queries terminate and the chain stops with "accounts differ", no hang. (Task 11)
4. Names with apostrophes, non-ASCII characters, or 200 characters ("Atieno Nyang'or"): round-trip through SQLite and wrap on screen at 2x font scale without overflow. (Tasks 7, 13)
5. Missing data: no name, no sex, no father, no house number, empty database on first run. Each has a defined line of text and none crashes. (Tasks 12, 13)
6. The device clock set backwards between two edits: ordering never depends on `createdAt`. (Task 8)

## File Structure

```
related/
  app/                          Flutter app, package name `related`
    lib/data/                   Drift tables and AppDatabase
    lib/claims/                 claim kinds, ClaimService, HouseholdBuilder
    lib/tree/                   ancestorsOf, spokenChain, siblingsOf
    lib/ui/                     screens and widgets
    test/                       mirrors lib/; test/fixtures/ has family builders
  spikes/                       throwaway, one folder per spike
  docs/
    2026-11-03-lineage-app-design.md
    NOTES.md                    state of the project for a fresh session
    paper-test.md               script and results (Task 1)
    spike-results.md            pass/fail and the decisions (Task 6)
    superpowers/plans/          this file
```

## Plan decisions to confirm

These fill gaps in the design. Task 7 writes all of them into the design document (section 13, "My calls") so the founder can accept or change them.

- **A.** `person` gets a nullable `sex` ("son of" versus "daughter of"; unknown reads "child of"). The design's table sketch has no such field.
- **B.** `house` gets a nullable `ordinal` (house 2). A house can exist with a known number and an unknown wife ("houses 1 and 3 are unknown").
- **C.** A wife's membership is a `wifeOfHouse` claim (displayed "married"). `belongsToHouse` carries only the basis `bornTo` or `joined`. This keeps "child of one house" single-valued and "wife of several houses" multi-valued.
- **D.** One person replacing another person's claim never supersedes it. Both stay active and show "Accounts differ". An asserter replacing their own active claim, where `baseClaimId` equals that claim's id, supersedes it even when other accounts' claims on the same contest key are active; the other accounts' claims stay active. This holds when the replacement has the same contest key or the same subject as the claim it replaces, of the same kind (so a wife moved from one house to another by the same account replaces the earlier claim). Replacing another account's claim never supersedes it. This follows the anti-goal that persistence must not win by volume.
- **E.** When a person's parentage is disputed or cyclic, the chain stops at that person with "accounts differ".
- **F.** In M1 a `joined` basis displays as the neutral "belongs to". Showing the word "joined" waits for audience rules in M4. This settles the design's "known tension" for M1 only.
- **G.** `person_name(person_id, name, kind)` holds spelling variants and extra names (design edge case 12). `person.name_key` is the primary display name.

---

## Phase 0: Setup, paper test and spikes

### Task 0: Toolchain, repository, notes

Flutter, Dart and the Android SDK are not installed on this machine (checked 2026-11-03: `flutter` and `adb` not found). Postgres 16 and Docker are.

**Files:**
- Create: `docs/NOTES.md`, `.gitignore`, `app/` (via `flutter create`)

**Interfaces:**
- Produces: a buildable empty app at `app/`, and `docs/NOTES.md` with sections "How to run", "Decisions", "Versions", "Next".

- [ ] **Step 1: Install Flutter stable and the Android SDK; run `flutter doctor`.** Expected: no error under "Flutter" and "Android toolchain". Record the Flutter, Dart and Android SDK versions in `docs/NOTES.md` under "Versions".
- [ ] **Step 2: Ask the founder which physical Android phone is the weakest they can lend, and whether they want `git init`.** Do not initialise a repository without the answer. Record the phone model and RAM in NOTES.
- [ ] **Step 3: `flutter create --org ke.related --platforms=android,ios,web app`** from the repo root. Run `cd app && flutter test`. Expected: the template test passes.
- [ ] **Step 4: Add the Drift packages** (`drift`, `drift_flutter`, `uuid`, dev: `drift_dev`, `build_runner`). Pin by committing `pubspec.lock`. Run `dart run build_runner build` once with an empty schema to confirm codegen works.
- [ ] **Step 5: Write `docs/NOTES.md`** with the design link, this plan's link, the decision list above, and the rule "commit only when asked".
- [ ] **Step 6: Propose commit** `chore: scaffold flutter app and project notes`.

### Task 1: Paper test with relatives (the founder runs it)

Design section 10: before any build, read the spoken chain aloud to three to five relatives, older and younger, in English.

**Files:**
- Create: `docs/paper-test.md`

**Interfaces:**
- Produces: a written result that decides whether the spoken chain stays the default view (design section 7). Task 12 and Task 13 build on it.

- [ ] **Step 1: Write the script in `docs/paper-test.md`.** Part A: read the founder's chain aloud ("Manyi, son of Winyo, house 2" and so on). Ask "is that how you say it?" and record every correction word for word. Part B: show Winyo's four houses on paper and ask "who is Manyi's full brother?" and "who is only a brother through the father?" Record the answer and the time taken. Part C: ask whether any relative in the pilot lacks an email address they can open on their phone (the sign-in assumption in design section 14).
- [ ] **Step 2: Founder runs it with three to five relatives**, noting age band and phone use for each. Claude does not simulate this.
- [ ] **Step 3: Fill in results and a decision line:** "spoken chain stays default" or "change to: ___". If relatives correct the wording, record the wording; Task 12's line formats change to match before it starts.
- [ ] **Step 4: Propose commit** `docs: paper test script and results`.

### Task 2: Spike 1, leak and revocation

Throwaway. Question: can a viewer who lacks a quiet claim learn it exists?

**Files:**
- Create: `spikes/leak/schema.sql`, `spikes/leak/pull_view.sql`, `spikes/leak/leak_test.dart`, `spikes/leak/README.md`

**Interfaces:**
- Produces: a pass/fail result and the final shape of `claim_access` and the pull function, reused by M2.

- [ ] **Step 1: Run Postgres 16 in Docker** and write `schema.sql` for `person`, `claim`, `claim_audience`, `claim_access`, `privacy_setting` per design section 8, with row security on `claim` reading `claim_access` only. Add a `pull_view(viewer uuid, since text)` function that builds the viewer's rows from `claim_access`, never from `claim` directly. Both the row rules and `pull_view` must read the same `claim_access`.
- [ ] **Step 2: Write the test `leak_test.dart`.** Build world A: viewers X and B, one quiet sire claim shared to X only, plus a person row referenced only by that claim. Build world B: identical but with no quiet claim. Assert, for viewer B in A versus B: the pull payload bytes are identical; the viewer's local Drift file (after applying the payload to an in-memory Drift DB) has identical table contents; the error text from a forged write to the quiet claim's id equals the error text from a write to a random id; row counts from every endpoint are identical.
- [ ] **Step 3: Add the standing hide case.** Person P turns on `hide_quiet_details` with no quiet notes existing. Assert B's payloads before and after a later quiet note about P is added and shared to X are identical.
- [ ] **Step 4: Add the revocation case.** Remove B from an audience that included B; assert the next pull for B returns a removal for those claim ids and, after applying it, B's Drift file holds none of the rows. Record that data already on a device before revocation cannot be recalled (design section 4).
- [ ] **Step 5: Run it.** Pass means every assertion above holds. Write the outcome and any leak found into `spikes/leak/README.md`.

### Task 3: Spike 2, claims and custom sync cost

Throwaway. Question: do append-only claims survive offline edits from three devices, and what does a custom sync cost?

**Files:**
- Create: `spikes/claims/` (Dart package with `fake_server.dart`, `device.dart`, `fuzz_test.dart`), `spikes/claims/README.md`

**Interfaces:**
- Produces: the `SyncTransport` interface shape (`push(List<ClaimRow>) -> PushResult`, `pull(String? cursor) -> PullResult`) and a measured effort in working days.

- [ ] **Step 1: Write `fake_server.dart`** accepting claim pushes idempotently by UUID, assigning an arrival sequence, and applying decision D and the base-claim rule from design section 8.
- [ ] **Step 2: Write `device.dart`**: an in-memory Drift database plus an outbox, able to go offline, queue operations, and push and pull.
- [ ] **Step 3: Write `fuzz_test.dart`.** Three devices, 1,000 randomised offline operations (add person, assert house claim, edit a name, merge, undo merge), with random reconnect order and random duplicate pushes. Assert: zero lost writes (every pushed claim id exists on the server and on all devices after final sync); contested facts appear as competing accounts and never as overwrites; merge followed by undo returns a view identical to the pre-merge view; a failing push does not block later ones (design edge case 13).
- [ ] **Step 4: Record elapsed working days** spent on this spike and on what a production version of retries, resumable pulls and revocation would still need. This is the evidence for the "few weeks" test in design section 9.

### Task 4: Spike 3, offline invite

Throwaway except the code checksum, which graduates to M3.

**Files:**
- Create: `spikes/invite/code.dart`, `spikes/invite/code_test.dart`, `spikes/invite/matrix.md`, plus a minimal Android app in `spikes/invite/app/`

**Interfaces:**
- Produces: `String encodeInviteCode(Uint8List token5)` and `bool isValidInviteCode(String code)`.

- [ ] **Step 1: Write the failing test `code_test.dart`.** Alphabet is 31 symbols: digits 2 to 9 and letters A to Z without I, L and O. A code is 8 token symbols plus one check symbol. Check = (sum over positions i from 0 of symbolIndex(i) × (i+1)) mod 31. Tests: `encodeInviteCode` output is 9 symbols from the alphabet; `isValidInviteCode` accepts it; for one fixed code, every single-symbol substitution (8 positions × 30 other symbols, check symbol included) is rejected; every swap of two adjacent different symbols is rejected; lowercase input and input with spaces or hyphens every four symbols are accepted after normalisation.
- [ ] **Step 2: Run to see it fail.** Run: `dart test spikes/invite/code_test.dart`. Expected: FAIL, `encodeInviteCode` undefined.
- [ ] **Step 3: Implement both functions in `code.dart`.** Prime modulus 31 is why single substitutions and adjacent swaps are always caught; keep the comment.
- [ ] **Step 4: Run to see it pass.** Expected: PASS.
- [ ] **Step 5: Run the airplane-mode matrix on the physical phone** and record each row in `matrix.md` with pass/fail: empty token pool at invite time; redeem with no signal (shows only "saved, we will connect when you have signal"); app installed from a link where the install referrer is missing; typed code with one wrong symbol (rejected at the keyboard, offline); typed code with the right symbols, then signal returns (redemption completes and the redeemer still sees nothing until confirmed).

### Task 5: Spike 4, tree at scale; Spike 5, encrypted cold start

Two spikes, each a small Flutter app on the weakest phone named in Task 0.

**Files:**
- Create: `spikes/tree/` (Flutter app, `lib/gen.dart`, `lib/layout.dart`), `spikes/crypto/` (Flutter app)

**Interfaces:**
- Produces: measured numbers in `spikes/tree/README.md` and `spikes/crypto/README.md`.

- [ ] **Step 1 (spike 4): Write `gen.dart`** generating 3,000 synthetic people in houses with 1 to 4 wives per husband and 0 to 6 children per house, plus 20 women who appear in two houses.
- [ ] **Step 2: Write `layout.dart`** computing the focused-house-plus-one-generation diagram layout in an isolate, and a scrolling spoken-chain list.
- [ ] **Step 3: Measure on the phone.** Pass: layout finishes in under 1 second off the main thread, and the 95th-percentile frame time while scrolling is under 16 ms. Record the numbers and the device.
- [ ] **Step 4 (spike 5): Open an encrypted Drift database** following the encryption approach in the Drift documentation read at that time (the design's unverified list names SQLite3MultipleCiphers; record which approach actually worked). Key: random, held in platform secure storage.
- [ ] **Step 5: Measure and test on the phone.** Pass: cold start to first frame with the database open under 3 seconds; after an app update (install a higher version code over the old) the data is still readable; after a backup and restore without the key the data is unreadable and the app falls back to a clean re-sync state. Record each.

### Task 6: Spike results and the decisions they unlock

**Files:**
- Create: `docs/spike-results.md`
- Modify: `docs/2026-11-03-lineage-app-design.md` (sections 9 and 14), `docs/NOTES.md`

- [ ] **Step 1: Write `docs/spike-results.md`** with one row per spike: pass or fail against the design's threshold, the measured number, the device, the date, and what was not tested.
- [ ] **Step 2: Record the three decisions:** keep the custom sync or switch to PowerSync (design section 9 gives the two triggers); whether the weakest-phone numbers force changes to the tree diagram; whether the typed code stays the primary invite path.
- [ ] **Step 3: Move verified items** out of "Not verified" in design section 14 and add what the spikes could not settle.
- [ ] **Step 4: Stop and show the founder.** The plan for M2 to M6 is written only after this review.
- [ ] **Step 5: Propose commit** `docs: spike results and decisions`.

---

## Milestone 1: Local data, claims and a read-only tree at scale

Everything in M1 is local. No server, no sign-in, no encryption (spike 5 decides that setup; it is added in M2).

### Task 7: Drift schema

**Files:**
- Create: `app/lib/data/tables.dart`, `app/lib/data/database.dart`
- Test: `app/test/data/database_test.dart`
- Modify: `docs/2026-11-03-lineage-app-design.md` (section 8 table sketch: add `person.sex`, `house.ordinal`, `person_name`; section 13: add decisions A to G from this plan)

**Interfaces:**
- Produces: `AppDatabase(QueryExecutor e)` with tables `Persons(id, isPlaceholder, nameKey?, sex?, createdBy, deletedAt?)`, `Houses(id, husbandId, ordinal?, createdBy, deletedAt?)`, `Claims(localSeq pk auto, id unique, kind, subjectId, objectId?, basis?, body?, assertedBy, baseClaimId?, status, createdAt)`, `PersonNames(id, personId, name, kind)`, `FieldEdits(id, entity, entityId, field, value, assertedBy, localSeq)`. Row classes `PersonRow`, `HouseRow`, `ClaimRow`, `PersonNameRow`. Enums `ClaimKind { belongsToHouse, wifeOfHouse, sire, joinedVia, originNote, samePerson }`, `Basis { bornTo, joined }`, `Sex { male, female }`, stored as text. Status text is `active` or `superseded`.
- Test helper: `AppDatabase.memory()` using an in-memory executor.

- [ ] **Step 1: Write the failing test** `database_test.dart`: `inserts and reads a person with an apostrophe, non-ASCII and a 200-character name` (names `Atieno Nyang'or`, `Ouma Ọkọ̀`, and `'x' * 200` round-trip unchanged); `a person with null name, null sex reads back with nulls`; `inserting two claims with the same id throws`.
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/data/database_test.dart`. Expected: FAIL, `AppDatabase` undefined.
- [ ] **Step 3: Implement the tables and `AppDatabase`** as listed, with `@DataClassName('ClaimRow')` and so on to avoid colliding with domain names. Run `dart run build_runner build`.
- [ ] **Step 4: Run to see it pass.** Expected: PASS (3 tests).
- [ ] **Step 5: Update the design.** Section 8 table sketch gets the three additions. Section 13 gets decisions A to G from "Plan decisions to confirm", each with its reason.
- [ ] **Step 6: Propose commit** `feat(data): drift schema for people, houses and claims`.

### Task 8: ClaimService, append-only claims

**Files:**
- Create: `app/lib/claims/claim_kinds.dart`, `app/lib/claims/claim_service.dart`
- Test: `app/test/claims/claim_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` from Task 7.
- Produces:
  - `String contestKey(ClaimKind kind, String subjectId, String? objectId)`: `belongsToHouse` returns the subject id, `wifeOfHouse` returns the object (house) id, others return `"$kind:$subjectId"`.
  - `class ClaimService { ClaimService(AppDatabase db, {required String accountId, DateTime Function()? now}); Future<ClaimRow> assertClaim({required ClaimKind kind, required String subjectId, String? objectId, Basis? basis, String? body, String? baseClaimId}); Future<List<ClaimView>> activeClaims(ClaimKind kind, {String? subjectId, String? objectId}); }`
  - `class ClaimView { final ClaimRow claim; final bool competing; }`

- [ ] **Step 1: Write the failing tests** (names and assertions):
  - `first claim is active and not competing`.
  - `same asserter replacing own claim with the current claim as base supersedes it`: assert A to house H1, then A to H2 with base = first; `activeClaims` returns only the second; the first row still exists with status `superseded`.
  - `a different asserter replacing a claim never supersedes it` (decision D): asserters A and B, B's base is A's claim; both are active and both have `competing == true`.
  - `own claim is superseded even when another account's claim is active` (decision D): A asserts H1, B asserts H2 with base null (both active), then A asserts H3 with base = A's first claim; A's first is `superseded`, B's H2 and A's H3 are active and competing.
  - `a stale base becomes a competing claim`: A asserts, B asserts with base null; both active, both competing.
  - `wifeOfHouse competes by house`: two different women asserted as wife of the same house are competing; one woman asserted as wife of two houses is not.
  - `ordering ignores the device clock`: `now` returns decreasing timestamps; the second asserted claim is the active head after supersession.
  - `no claim row is ever updated except status`: after five assertions, compare all columns except status for the first row before and after.
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/claims/claim_service_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement `claim_kinds.dart` and `ClaimService`.** `assertClaim` runs in one transaction: find active claims with the same contest key; if one of them was asserted by this account and its id equals `baseClaimId`, mark that one `superseded`; also supersede this account's own active claim of the same kind that `baseClaimId` names when it has the same subject, even if its contest key differs (wifeOfHouse moved between houses); in every other case leave existing active claims alone; then insert the new claim.
- [ ] **Step 4: Run to see it pass.** Expected: PASS (8 tests).
- [ ] **Step 5: Propose commit** `feat(claims): append-only claims with competing accounts`.

### Task 9: HouseholdBuilder and unknown parentage

**Files:**
- Create: `app/lib/claims/household_builder.dart`
- Test: `app/test/claims/household_builder_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ClaimService` (Task 8).
- Produces: `class HouseholdBuilder { HouseholdBuilder(AppDatabase db, ClaimService claims, {required String accountId}); Future<String> addPerson({String? name, Sex? sex}); Future<String> addPlaceholder({Sex? sex}); Future<String> addHouse({required String husbandId, int? ordinal}); Future<void> placeChild({required String personId, required String houseId, Basis basis}); Future<void> addWife({required String wifeId, required String houseId}); Future<String> ensureFatherHouse(String personId); }`. Each returns the new row's UUID.

- [ ] **Step 1: Write the failing tests:**
  - `addPerson with no name creates an unnamed person that is not a placeholder`.
  - `ensureFatherHouse for a person with no parents creates a fresh placeholder husband and a fresh house and places the person in it`.
  - `two orphans get different houses and different husbands` (assert `houseId` differs, and neither is the other's sibling by shared house).
  - `ensureFatherHouse is idempotent` (second call returns the same house id and creates no rows).
  - `addWife creates a wifeOfHouse claim and a woman can be wife of two houses`.
  - `two persons named Winyo get different ids and both are kept`.
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/claims/household_builder_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement `HouseholdBuilder`.** IDs from `Uuid().v4()`. Methods write through `ClaimService` for claims; `addHouse`, `addPerson` and `addPlaceholder` insert rows directly. No shared "unknown" house anywhere.
- [ ] **Step 4: Run to see it pass.** Expected: PASS (6 tests).
- [ ] **Step 5: Propose commit** `feat(claims): household builder with placeholder parentage`.

### Task 10: Ancestor query with cycle protection

**Files:**
- Create: `app/lib/tree/ancestors.dart`
- Test: `app/test/tree/ancestors_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `ClaimService.activeClaims`, `HouseholdBuilder` for fixtures.
- Produces: `Future<List<AncestorStep>> ancestorsOf(AppDatabase db, String personId, {int maxDepth = 60})` and `class AncestorStep { final String personId; final String houseId; final int depth; final bool disputed; }`. The list runs from the person's father upward. It follows only `belongsToHouse` claims and each house's `husbandId`. Never touches wives.

- [ ] **Step 1: Write the failing tests:**
  - `follows the father line through placeholders` (three generations, top is a placeholder).
  - `stops with disputed true when a person has two competing belongsToHouse claims`, and returns no steps beyond that person (decision E).
  - `terminates on a cycle`: a person is made their own great-grandfather through claims; the call returns within the depth cap and flags the repeat with `disputed: true`. Run it with a 2-second timeout.
  - `a woman who is wife of two houses does not appear in anyone's ancestors` through the wife claims.
  - `joined basis is followed like bornTo`.
  - `returns an empty list for a person with no belongsToHouse claim`.
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/tree/ancestors_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement `ancestorsOf`** with a SQLite recursive CTE using `UNION` (not `UNION ALL`) so repeats are dropped, carrying depth, capped at `maxDepth`. Detect competing claims with `ClaimService`'s contest rule rather than re-deriving it.
- [ ] **Step 4: Run to see it pass.** Expected: PASS (6 tests).
- [ ] **Step 5: Propose commit** `feat(tree): ancestor query that terminates on cycles`.

### Task 11: Founder family fixture and sibling groups

**Files:**
- Create: `app/test/fixtures/winyo_family.dart`, `app/lib/tree/siblings.dart`
- Test: `app/test/tree/siblings_test.dart`

**Interfaces:**
- Consumes: `HouseholdBuilder`.
- Produces: `Future<WinyoFamily> buildWinyoFamily(AppDatabase db)` returning ids by name (`me, juma, manyi, wade, owala, winyo, ochieng, atieno, obuolo, olembo, aunt, auntHusbandA, auntHusbandB`), and `Future<SiblingGroups> siblingsOf(AppDatabase db, String personId)` with `class SiblingGroups { final List<String> sameHouse; final List<SiblingHouse> otherHouses; } class SiblingHouse { final String houseId; final int? ordinal; final List<String> personIds; }`.

Fixture per design section 4: Winyo has four houses (ordinals 1 to 4); Manyi and Wade in house 2 with mother Atieno Nyang'or; Owala in house 4; houses 1 and 3 have no wife and no children; Obuolo shares Winyo's mother's house; Olembo shares Winyo's father's other house. The aunt is a daughter in Manyi's house, wife in a house of A, then wife in a house of B, where A and B are brothers.

- [ ] **Step 1: Write the failing tests** against `buildWinyoFamily`:
  - `Wade is in Manyi's sameHouse; Owala is under otherHouses ordinal 4, not sameHouse`.
  - `Obuolo is in Winyo's sameHouse; Olembo is under another house`.
  - `houses 1 and 3 exist with no wife claim and no children`.
  - `the aunt belongs to Manyi's house as a child and is wife of two houses; her children are in each of those houses` (Review Focus 1).
  - `no user-visible string in app/lib/ contains "step" or "half"` (reads the `lib/ui` and `lib/tree` sources and matches string literals, case-insensitive, whole word).
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/tree/siblings_test.dart`. Expected: FAIL.
- [ ] **Step 3: Write the fixture and implement `siblingsOf`.** A full sibling is anyone in the same house; the other houses of the same husband are grouped by house with their ordinal. Return ids only.
- [ ] **Step 4: Run to see it pass.** Expected: PASS (5 tests).
- [ ] **Step 5: Propose commit** `feat(tree): sibling groups and the Winyo family fixture`.

### Task 12: Spoken chain

Task 1's result may change the wording. Read `docs/paper-test.md` first. If relatives corrected the format, the strings below change and the tests change with them.

**Files:**
- Create: `app/lib/tree/spoken_chain.dart`
- Test: `app/test/tree/spoken_chain_test.dart`

**Interfaces:**
- Consumes: `ancestorsOf` (Task 10), `buildWinyoFamily` (Task 11).
- Produces: `Future<List<ChainLine>> spokenChain(AppDatabase db, String personId)` and `class ChainLine { final String personId; final String text; final bool disputed; final bool placeholder; }`. The first line is the person, then each ancestor in order.

Line formats (pending Task 1): `"{name}, son of {father}, house {n}"`; `"daughter of"` for female; `"child of"` when sex is unknown; house suffix omitted when `ordinal` is null; a missing name reads `unnamed`; a placeholder reads `someone we forgot`; a `joined` basis reads `"{name}, belongs to {father}'s house"` (decision F); a disputed or cyclic parentage reads `"{name}, accounts differ"` and ends the list.

- [ ] **Step 1: Write the failing tests** with `buildWinyoFamily`:
  - `Manyi line is "Manyi, son of Winyo, house 2"`.
  - `the chain for me reads me, son of Juma; Juma, son of Manyi; Manyi, son of Winyo, house 2; Winyo, son of Ochieng; Ochieng, son of Winyo; Winyo, son of someone we forgot` (join the `text` fields; no em dashes).
  - `the two Winyos are told apart by their father`.
  - `unknown sex reads "child of"`; `no name reads "unnamed"`; `no ordinal omits the house suffix`.
  - `joined basis never prints the word "joined"`.
  - `a cycle ends with "accounts differ" and the chain has finite length`.
  - `a person with no father reads "son of someone we forgot"` and does not throw.
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/tree/spoken_chain_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement `spokenChain`** using `ancestorsOf`; load names and sexes in one batched query per call, not per line.
- [ ] **Step 4: Run to see it pass.** Expected: PASS (8 tests).
- [ ] **Step 5: Propose commit** `feat(tree): spoken chain lines`.

### Task 13: Screens: spoken chain, house view, first run

**Files:**
- Create: `app/lib/ui/family_tab.dart`, `app/lib/ui/chain_view.dart`, `app/lib/ui/house_view.dart`, `app/lib/ui/first_run.dart`, `app/lib/ui/theme.dart`
- Modify: `app/lib/main.dart`
- Test: `app/test/ui/chain_view_test.dart`, `app/test/ui/house_view_test.dart`, `app/test/ui/first_run_test.dart`

**Interfaces:**
- Consumes: `spokenChain`, `siblingsOf`, `HouseholdBuilder`.
- Produces: `ChainView({required List<ChainLine> lines, VoidCallback? onShowDiagram})`, `HouseView({required HouseViewModel house})` where `HouseViewModel { String husbandName; List<HouseRowModel> houses }` and `HouseRowModel { int? ordinal; String? wifeName; bool wifeSameAsElsewhere; List<String> childLines }`, and `FirstRunScreen({required HouseholdBuilder builder})`.

- [ ] **Step 1: Write the failing widget tests:**
  - `ChainView wraps a 200-character name at text scale 2.0 with no overflow and no ellipsis`.
  - `placeholder line shows dashed outline and the words "someone we forgot"`.
  - `HouseView shows "not known yet" for an empty house and offers no button in it`.
  - `a woman in two houses shows the text "same person" in each place` (Review Focus 1).
  - `basis is shown as a word`: the `married` basis appears as text in the wife row.
  - `FirstRunScreen with an empty database lets the user save with father unknown and creates a fresh placeholder father and house`.
  - `FirstRunScreen has no counts, scores, streaks or prompts to fill missing items` (assert no widget text matches `%`, `complete`, `streak`, `remaining`).
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/ui`. Expected: FAIL.
- [ ] **Step 3: Implement the screens and `theme.dart`.** Theme: body text at least 4.5:1 against its background, large text at least 3:1 (assert both in a `theme_test.dart` by computing the contrast ratio from the theme's colours). No blur, shadow or animation. Interactive targets default to 48dp. `main.dart` opens `AppDatabase` with `drift_flutter`, shows `FirstRunScreen` when the database has no people and `FamilyTab` otherwise. The tab shows the chain by default, with "show diagram" disabled until a later milestone, labelled in plain text.
- [ ] **Step 4: Run to see it pass.** Run: `cd app && flutter test`. Expected: all tests pass.
- [ ] **Step 5: Run the app on the founder's weakest phone** and enter the founder's own first-run household by hand. Record anything awkward in `docs/NOTES.md`.
- [ ] **Step 6: Propose commit** `feat(ui): spoken chain, house view and first run`.

### Task 14: Scale check and M1 exit

**Files:**
- Create: `app/test/fixtures/synthetic_tree.dart`, `app/test/tree/scale_test.dart`
- Modify: `docs/NOTES.md`

**Interfaces:**
- Produces: `Future<SyntheticTree> buildSyntheticTree(AppDatabase db, {int persons = 3000})` returning `deepestPersonId` and `focusHouseId`.

- [ ] **Step 1: Write the failing test** `scale_test.dart`: `spokenChain for the deepest of 3000 people returns in under 100 ms` (threshold is mine, not the design's); `ancestorsOf terminates for every person within the depth cap`; `building 3000 people with 1 to 4 wives per husband and 20 women in two houses completes`.
- [ ] **Step 2: Run to see it fail.** Run: `cd app && flutter test test/tree/scale_test.dart`. Expected: FAIL, `buildSyntheticTree` undefined.
- [ ] **Step 3: Implement the generator** (the same shape as spike 4's `gen.dart`, written against `HouseholdBuilder`).
- [ ] **Step 4: Run to see it pass.** Expected: PASS. If the 100 ms test fails, add an index on `Claims(kind, subjectId, status)` and rerun, and record the before and after in NOTES.
- [ ] **Step 5: Run the 3,000-person fixture on the weakest phone** and record cold start, chain scroll smoothness and any out-of-memory event (design section 14 notes an Android out-of-memory caveat for complex Drift queries).
- [ ] **Step 6: M1 exit.** Run `cd app && flutter test` and `flutter analyze`; both must be clean. Update `docs/NOTES.md` "Next" with: write the M2 to M6 plan from `docs/spike-results.md`.
- [ ] **Step 7: Propose commit** `test(tree): 3000-person scale check and M1 exit notes`.

---

## Milestones after this plan

Written as separate plans after Task 6 and the founder's review of the spike results.

| Milestone | Depends on | What the spikes decide |
|---|---|---|
| M2 auth, server view, sync for one family | M1; spikes 1, 2, 5 | custom sync or PowerSync; encryption setup; email and password through Supabase or not |
| M3 invites with typed-code fallback | M2; spike 3 | typed code stays primary; the checksum from Task 4 graduates |
| M4 quiet links and the hide setting | M2; spike 1 | `claim_access` shape; the word "joined" display rule (decision F) |
| M5 merge, undo, disputes with responses | M2, M4 | none; the open items in design section 12 (undo window, "both families") are set here |
| Gate: data-protection and legal review | before any real family data beyond the founder's own | Kenyan obligations are [NEEDS SOURCE] |
| M6 village pilot on real devices | all above | Android only; web last |

## Self-review

- **Spec coverage.** Section 10's five spikes and the paper test are Tasks 1 to 5. M1 covers must-have items 1, 2, 8 and the display rules of section 7 (items 5 to 7, 9, 10 are M2 to M5). Item 3 (open questions on placeholders) and the Questions tab are not in M1: they need invitees, so they land in M3. Section 4 modelling, section 8 claims and leak rules (spike 1 for the rules, Task 8 for the claim rule), section 9 offline invite and encryption (Tasks 4 and 5, built in M2 and M3).
- **Gaps found and recorded.** The design had no `sex`, `ordinal` or name-variant fields and did not say who supersedes whom; decisions A to G close those and Task 7 writes them into the design.
- **Type consistency.** `ClaimService.activeClaims`, `AncestorStep`, `ChainLine`, `SiblingGroups` and `HouseholdBuilder` names are the same in every task that uses them.
- **Not verified here.** Flutter, Drift and Android tool versions and the encryption package setup are chosen at Task 0 and Task 5; this plan names no versions.
