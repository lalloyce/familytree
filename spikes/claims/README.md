# Spike 2: claims and custom sync cost

Throwaway. Question: do append-only claims survive offline edits from three devices, and what would a custom sync cost?

**Answer for the model built here: yes for writes and competing accounts; yes for merge then undo, with one design gap.** The fuzz ran 200 seeds of 1,000 random operations each across three devices, with random offline periods, random reconnect order, duplicate pushes, mid-push connection drops and one row that keeps failing. The fake server was run under both the Task 8 text rule and the rule the controller ruled for Task 8.

- **All four assertions pass on every seed under both rules.** `dart test` is green, 65 of 65.
- **A3's direct checks pass on every seed.** A merge then undo with nothing in between returns the exact pre-merge view on the server and all three devices.
- **A3's replay check fails on any pair that is not explained.** Every merge later undone is replayed, none skipped.
  - **Raw figure: 2,837 of 12,779 replayed pairs (baseline) and 2,884 of 12,822 (ruled) give a view that differs at all from the merge-never-happened replay.**
  - Of those that differ, 791 (baseline) and 823 (ruled) are explained by merges or undos refused inside the pair's window (Finding 3).
  - 2,046 (72.1%) and 2,061 (71.5%) are **cascade** pairs (Finding 3b), under a causal definition computed from the arrival log.
  - **0** are non-cascade, so no failure fell outside the known class.
- **What a cascade pair means: a merge refused while another merge stood is never retried when that merge is undone.** Its absence changes later merges and undos. Claim statuses are never affected. The replay uses no sync, so this is a property of the merge rule, not of the sync. It is a design question for M5: re-evaluate refused merges on undo, or treat everything after a refused merge as a review task.
- **Five deliberately broken variants** (four servers and one client) each fail the assertion they target on every seed tried. The A3 control fails through non-cascade pairs.

The answer covers an in-memory fake server and in-memory devices, not Postgres, HTTP or real phones (see "What was NOT tested").

**Recommendation: keep the custom sync.** The sync core (idempotent push, a queue that does not block, resumable pulls) is 190 code lines of fake server (including the broken modes) and 114 of device sync code, and it passed every seed. By the split estimate below, most of the remaining work, 12 to 23 of 19 to 37 days, exists only because the sync is custom. That part includes revocation, which section 9 lists as a custom-sync cost. The work needed whichever sync is used is the smaller part, 7 to 14 days: the contest rule under concurrency, the visibility filter, auth and migration. Both figures are estimates, not measurements. Finding 3b needs a design decision whichever sync is used.

## What was built

All under `spikes/claims/`, a plain Dart package. Pinned in `pubspec.lock`: drift 2.35.3, sqlite3 3.8.0, test 1.33.0. Dart SDK 3.13.7.

| File | What it is |
|---|---|
| `lib/model.dart` | `ClaimRow`, `PushResult`, `PullResult`, `SyncTransport`, the errors, `contestKey`, and `renderView` (the view a person would see, as a canonical string). |
| `lib/fake_server.dart` | The fake server, plain Dart, in memory. Idempotent push by id, arrival order, the contest rule, names, merge and undo, paged pull. Also the broken variants used as negative controls. |
| `lib/fake_network.dart` | The simulated network between one device and the server. Injects offline, mid-push drops, duplicate pushes and lost pull responses. |
| `lib/device.dart` | One phone: an in-memory Drift database (no generated code, as in spike 1), an outbox, push and pull. |
| `lib/fuzz.dart` | The seeded fuzz and the four assertions. |
| `test/fuzz_test.dart` | 20 seeds under each of two contest rules, plus the negative controls. |
| `bin/fuzz.dart` | Runs or replays any seed from the command line. |

## Run

```sh
source scripts/env.sh            # from the repository root
cd spikes/claims
dart pub get
dart test -r expanded -j 1       # 2 x 20 seeds + 25 negative-control runs
SEEDS=1,2,3 dart test            # choose seeds
dart run bin/fuzz.dart --seed 7  # replay one seed; repeat --seed for more
dart run bin/fuzz.dart --seed 7 --mode overwriteOnConflict   # a broken server
dart run bin/fuzz.dart --seed 7 --blocking                   # the blocking client
dart run bin/fuzz.dart --seed 7 --mode supersedeOwnUnderContest  # the ruled rule
```

A failing seed prints `REPLAY: dart run bin/fuzz.dart --seed N ...`. Every random choice, including UUIDs and fault injection, comes from one `Random(seed)`, so a seed replays exactly.

## Rules the fake server applies

- **Idempotent by id.** A row id seen before is acknowledged as `duplicate` and changes nothing. Same id with different content is refused (`failed`, "id conflict"); it never overwrites.
- **Arrival order is the only clock.** Each new row gets the next `seq`. Device clocks are carried for display and never read. The fuzz gives the three devices skewed clocks (one runs backwards) and checks that the view is unchanged when every device time is set to zero.
- **Claims (plan Task 8 and decision D).** Contest key: `belongsToHouse` by subject, `wifeOfHouse` by house. Two modes are tested:
  - `supersedeOwnUnderContest`, **the rule the controller ruled Task 8 will use and the one this README recommends**: if the new claim's base is an active claim on the key asserted by the same account, that claim becomes `superseded`, whatever other accounts' claims also stand.
  - `correct`, **the Task 8 text, kept as the compared baseline and the server default for every other test** (the 200-seed sweep, the negative controls, `bin/fuzz.dart` without `--mode`): the same, but only when that claim is the only active claim on the key.

  In both, every other case stores the new claim `active` next to the others: a stale base (on the server but no longer active; counted as `staleBase`), a base that is another account's claim, or no base all produce a competing account. One account never supersedes another's claim.
- **Late base (added in this spike, see Finding 2).** If any claim by the same account on the same key, whatever its status, already names the arriving claim as its base, the arriving claim is stored `superseded`.
- **Names (low-stakes).** Every edit is a row and is kept. The current name is the latest by arrival.
- **Merge** (`person_alias` plus `merge_event`). Merge(a, b) aliases b to a if neither is an alias and nothing is aliased to b; otherwise it is stored `conflicted`. No row is rewritten.
- **Undo.** Deletes the alias of an effective, unreversed merge and is stored as a reversing event. Claims made while merged stay on the person id they name.
- **Pull.** Rows by change version, in pages of 50. A status change (for example `superseded`) gives the row a new version, so devices receive it again.

## The transport interface

```dart
abstract interface class SyncTransport {
  Future<PushResult> push(List<ClaimRow> rows); // throws NetworkError or ServerError
  Future<PullResult> pull(String? cursor);      // throws NetworkError
}
```

- `ClaimRow`: `id` (client UUID), `kind` (`person`, `belongsToHouse`, `wifeOfHouse`, `nameEdit`, `merge`, `unmerge`), `subjectId`, `objectId`, `body`, `assertedBy`, `basis`, `baseClaimId`, `deviceId`, `deviceTime` (display only), and the server-set `status`, `seq` (arrival order) and `version` (change counter). Every synced write is a `ClaimRow`, so person creation, name edits, merges and undos use the same pipe as claims. The field use per kind is documented on the class.
- `PushResult`: one `ItemResult(id, accepted | duplicate | failed, reason)` per row sent, in order.
- `PullResult`: `rows` (each in its current state), `nextCursor` (opaque; the device stores it in the same Drift transaction as the rows), `hasMore`.
- `NetworkError` means the connection dropped and the request may or may not have been applied. `ServerError` means the server refused the whole request.

## How the device pushes

Rows are written to the local `row` table and the `outbox` in one transaction, and work offline. A push sends the outbox in batches of 20 in the order the user wrote them. A row that has failed with a server error twice becomes a suspect. Suspects are sent alone, oldest first, before anything newer. A suspect that fails again stays queued and newer rows go past it. Only a genuinely stuck row is ever overtaken; every other row keeps its order. A network error stops the round without counting against any row.

## The fuzz

Three devices: `d0` and `d2` are two phones of one account (A), `d1` is account B. Twelve fixed houses. Ten people are created and synced first. Then, until 1,000 user operations are done, each step is one of: toggle a device online or offline (6%), sync a random online device (20%), or a user operation on a random device (74%), whether online or not.

User operations: add a person (15%), assert a house claim (45%: `belongsToHouse` with basis `bornTo` or `joined`, or `wifeOfHouse` with basis `married`; half the time on the key of one of the eight most recent claims on the device, otherwise on a random person or house; the base is the device's own standing claim half the time, someone else's a quarter of the time, otherwise none), edit a name (20%), merge two people (10%), undo a merge the device sees as effective (10%; when none is visible, a claim is asserted instead and counted separately).

The "recent claim" choice was added in fix round 1, and it changes every seed's numbers compared with the first commit. What was observed while building the stale-base control:
- Before the choice was added, with the control built on the Task 8 text rule, the control found 1 violation on seed 1 and none on seed 2, so its `dart test` run for seed 2 failed.
- With the choice added and the control still built on the Task 8 text rule, it did not fail on seeds 3, 7 and 8.
- With the control built on the ruled rule as well, it failed on all 12 seeds tried.
- Seed 1 under the baseline counted `staleBase` 32 before the choice and 27 after it.

So the choice did not measurably raise stale bases, and the control built on the ruled rule was never run without it. Whether the choice is needed is [NEEDS SOURCE].

Faults, per request: mid-push drop 15% (the server stores a random prefix of the batch, then the connection drops), duplicate push 15% (the same batch reaches the server twice), lost pull response 10%. The poison row is `d0`'s fifth claim: while it is in a batch the server stores the rows before it and then answers with an internal error.

Then: phase 1, everyone online and no injected faults, with the poison still failing; check A4. Phase 2, the poison is fixed and everything drains. Two epilogues run merge then undo through the sync on purpose. Then A1 to A3 are checked.

### The assertions

- **A1 zero lost writes.** Every row any device wrote is on the server. Every device's outbox is empty. Every device holds exactly the server's rows, with the same content, status and `seq`.
- **A2 contested facts kept as competing accounts, never overwritten.** No row's fixed fields changed anywhere (server compared with the author's copy; each device checks every row it pulls against its own copy). Every superseded claim has a replacement by the same account that names it as base. On every contest key, every account that ever asserted there still has at least one active claim. A claim that arrives after a claim of its own asserter already named it as base must be superseded, so one person never competes with themselves through late arrival (`lateArrivalsChecked`). The view does not change when device clocks are zeroed.
- **A3 merge then undo returns the pre-merge view.**
  - (a) Epilogue 1: render the view on the server and all three devices, merge on `d1`, sync, check the view changed, undo on `d2`, sync. All four views must equal the view before the merge.
  - (b) Epilogue 2: merge on `d0`; while merged, `d1` asserts a claim and `d2` edits the name of the kept person; undo on `d0`.
  - (c) Every merge m later undone by u during the whole run (the epilogues included) is replayed; none is skipped. A fresh server receives every row in the same arrival order minus m and u. A replay of the whole log must reproduce the server's view, or A3 fails. Each pair is classified, and only non-cascade pairs fail A3:
    - **identical**: the replay's view equals the real one.
    - **accepted-interfering** (Finding 3): every row whose status differs between the replay and the whole-log replay is a merge or undo row that touches one of m's two people and arrived strictly between m and u, and putting those rows' real statuses back into the replay reproduces the real view exactly.
    - **cascade** (Finding 3b): not accepted, but every row whose status differs is in the pair's taint set, and putting all differing statuses back reproduces the real view exactly. The taint set is computed from the real arrival log:
      - Seeds are merge or undo rows that the server stored as `conflicted` while m stood (arriving strictly between m and u) and that touch one of m's people.
      - Closure: in arrival order after the first seed, a merge or undo row is tainted if it touches a person of an already-tainted row, or if it undoes a tainted merge.
      - A claim row is never tainted, so a claim-status difference is never cascade.
    - **non-cascade**: anything else, including a view difference with no row-status difference.

  The same definition is in the code comment above the A3 block in `lib/fuzz.dart`.
- **A4 a failing push does not block later pushes.** After phase 1, the poison is not on the server, it is the only row left in `d0`'s outbox, and every row `d0` wrote after it is on the server.

## Results

Final run of `dart test -r expanded -j 1` (fix round 3):

```
00:55 +65: All tests passed!
dart test -r expanded -j 1  56.64s user 0.78s system 102% cpu 55.815 total
```

The 65 tests are 20 seeds under `correct`, 20 under `supersedeOwnUnderContest`, and 25 negative-control runs. Seed 1 from that run, baseline then ruled rule:

```
seed 1 mode=correct: PASS
  pass  A1 zero lost writes
  pass  A2 contested facts kept as competing accounts, never overwritten
  pass  A3 merge then undo returns the pre-merge view
  pass  A4 a failing push does not block later pushes
  stats: {d0RowsAfterPoison: 302, ops: {editName: 196, assertClaim: 464, addPerson: 148, undo (none visible, asserted a claim instead): 3, merge: 93, undoMerge: 96}, rows: 1016, claims: 468, superseded: 23, lateBase: 1, lateBaseViaInactive: 0, lateArrivalsChecked: 1, staleBase: 27, ownReplaceKeptByContest: 119, contestedKeys: 36, selfDifferKeys: 71, conflictedMerges: 14, undoPairsReplayed: 68, undoPairsIdentical: 57, undoPairsAcceptedInterfering: 2, undoPairsCascade: 9, undoPairsNonCascade: 0, syncs: 211, toggles: 93, midPushDrops: 31, duplicatePushes: 20, pullDrops: 25, duplicateAcks: 205, poisonFailures: 56, ms: 1192}
seed 1 mode=supersedeOwnUnderContest: PASS
  pass  A1 zero lost writes
  pass  A2 contested facts kept as competing accounts, never overwritten
  pass  A3 merge then undo returns the pre-merge view
  pass  A4 a failing push does not block later pushes
  stats: {d0RowsAfterPoison: 316, ops: {editName: 208, assertClaim: 423, addPerson: 160, undo (none visible, asserted a claim instead): 10, merge: 104, undoMerge: 95}, rows: 1016, claims: 434, superseded: 143, lateBase: 1, lateBaseViaInactive: 0, lateArrivalsChecked: 1, staleBase: 158, ownReplaceKeptByContest: 0, contestedKeys: 32, selfDifferKeys: 59, conflictedMerges: 16, undoPairsReplayed: 71, undoPairsIdentical: 58, undoPairsAcceptedInterfering: 4, undoPairsCascade: 9, undoPairsNonCascade: 0, syncs: 232, toggles: 109, midPushDrops: 33, duplicatePushes: 28, pullDrops: 23, duplicateAcks: 221, poisonFailures: 91, ms: 829}
```

| Seeds | Mode | A1 | A2 | A3 | A4 |
|---|---|---|---|---|---|
| 1 to 20 (`dart test`) | `supersedeOwnUnderContest` (ruled rule) | pass on all 20 | pass on all 20 | pass on all 20 (0 non-cascade) | pass on all 20 |
| 1 to 20 (`dart test`) | `correct` (Task 8 text, baseline) | pass on all 20 | pass on all 20 | pass on all 20 (0 non-cascade) | pass on all 20 |
| 1 to 200 (`bin/fuzz.dart`, extra sweep) | `supersedeOwnUnderContest` | pass on all 200 | pass on all 200 | pass on all 200 (0 non-cascade) | pass on all 200 |
| 1 to 200 (`bin/fuzz.dart`, extra sweep) | `correct` | pass on all 200 | pass on all 200 | pass on all 200 (0 non-cascade) | pass on all 200 |

**Undo replay, whole sweeps** (200 seeds each):

| | Replayed | Identical | Differ at all | Accepted-interfering | Cascade (share of differing) | Non-cascade |
|---|---|---|---|---|---|---|
| Baseline (`correct`) | 12,779 | 9,942 | 2,837 | 791 | 2,046 (72.1%) | 0 |
| Ruled (`supersedeOwnUnderContest`) | 12,822 | 9,938 | 2,884 | 823 | 2,061 (71.5%) | 0 |

**Undo replay per seed, seeds 1 to 20** (from the `dart test` run; replayed = identical + accepted + cascade + non-cascade):

| Seed | Ruled: replayed | identical | accepted | cascade | non-cascade | Baseline: replayed | identical | accepted | cascade | non-cascade |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 71 | 58 | 4 | 9 | 0 | 68 | 57 | 2 | 9 | 0 |
| 2 | 69 | 57 | 2 | 10 | 0 | 63 | 53 | 3 | 7 | 0 |
| 3 | 68 | 53 | 6 | 9 | 0 | 62 | 53 | 2 | 7 | 0 |
| 4 | 62 | 46 | 4 | 12 | 0 | 63 | 48 | 6 | 9 | 0 |
| 5 | 67 | 49 | 3 | 15 | 0 | 63 | 42 | 6 | 15 | 0 |
| 6 | 73 | 54 | 6 | 13 | 0 | 77 | 59 | 4 | 14 | 0 |
| 7 | 59 | 42 | 5 | 12 | 0 | 65 | 53 | 2 | 10 | 0 |
| 8 | 58 | 45 | 7 | 6 | 0 | 65 | 59 | 1 | 5 | 0 |
| 9 | 66 | 50 | 4 | 12 | 0 | 51 | 42 | 1 | 8 | 0 |
| 10 | 55 | 37 | 3 | 15 | 0 | 64 | 49 | 2 | 13 | 0 |
| 11 | 59 | 46 | 3 | 10 | 0 | 67 | 56 | 3 | 8 | 0 |
| 12 | 61 | 46 | 4 | 11 | 0 | 68 | 50 | 6 | 12 | 0 |
| 13 | 68 | 51 | 7 | 10 | 0 | 60 | 44 | 4 | 12 | 0 |
| 14 | 65 | 53 | 3 | 9 | 0 | 65 | 54 | 4 | 7 | 0 |
| 15 | 68 | 57 | 1 | 10 | 0 | 66 | 53 | 2 | 11 | 0 |
| 16 | 67 | 46 | 8 | 13 | 0 | 73 | 52 | 5 | 16 | 0 |
| 17 | 58 | 44 | 3 | 11 | 0 | 61 | 49 | 4 | 8 | 0 |
| 18 | 66 | 55 | 4 | 7 | 0 | 65 | 57 | 1 | 7 | 0 |
| 19 | 67 | 44 | 9 | 14 | 0 | 68 | 55 | 3 | 10 | 0 |
| 20 | 60 | 43 | 5 | 12 | 0 | 62 | 46 | 5 | 11 | 0 |

**Other counters, per seed, minimum to maximum** (200-seed sweeps re-run in fix round 3):

| Counter | Ruled, seeds 1-20 | Baseline, seeds 1-20 | Ruled, 200 seeds | Baseline, 200 seeds |
|---|---|---|---|---|
| `staleBase` (base on the server but not active) | 147 to 186 | 21 to 49 | 131 to 198 | 18 to 49 |
| claims superseded | 134 to 167 | 19 to 40 | 114 to 174 | 16 to 44 |
| own replacement kept active by the "exactly one" rule | 0 | 119 to 149 | 0 | 104 to 165 |
| late-base rule fired (`lateBase`) | 1 on every seed (20 of 20) | 1 on every seed (20 of 20) | 1 on every seed (200 of 200) | 0 to 1 (fired on 199 of 200) |
| of which the naming row was itself already superseded (`lateBaseViaInactive`) | 0 | 0 | 0 to 1 (4 in total) | 0 |
| late arrivals checked by A2 (`lateArrivalsChecked`), all superseded | 1 | 1 | 1 (200 in total) | 0 to 1 (199 in total) |
| A3 pairs replayed | 55 to 73 | 51 to 77 | 43 to 83 | 49 to 80 |
| A3 pairs identical | 37 to 58 | 42 to 59 | 31 to 67 | 35 to 64 |
| A3 pairs accepted-interfering | 1 to 9 | 1 to 6 | 0 to 11 | 0 to 10 |
| A3 pairs cascade | 6 to 15 | 5 to 16 | 1 to 18 | 4 to 18 |
| A3 pairs non-cascade | 0 | 0 | 0 | 0 |

In the 200-seed baseline sweep, also per seed: 416 to 499 claims; 25 to 47 contest keys with active claims from both accounts; 23 to 64 mid-push drops; 9 to 39 duplicate pushes; 12 to 43 lost pull responses; 114 to 351 duplicate acknowledgements; 7 to 44 conflicted merges; 282 to 371 `d0` rows written after the poison row, all delivered while it was failing.

### Negative controls

Each control runs on seeds 1 to 5 inside `dart test`. A control test passes only if the fuzz fails the assertion that control targets. For the A3 control, the test also requires at least one non-cascade pair, because cascade pairs are what the real server produces. All 25 control runs failed as required. Seed 1 results, from the final run:

| Variant | Targets | A1 | A2 | A3 | A4 |
|---|---|---|---|---|---|
| Server overwrites on conflict (a new claim supersedes every active claim on the key) | A2 | pass | **FAIL** (272) | pass | pass |
| Server acknowledges a batch but silently drops its second half | A1 | **FAIL** (872) | pass | pass | FAIL (1) |
| Server rewrites the merged-away person's claims to the kept person | A3 | pass | FAIL (691) | **FAIL** (47) | pass |
| Stale base supersedes the asserter's current claim (built on the ruled rule) | A2 | pass | **FAIL** (27) | pass | pass |
| Client queue stops at the first failing row | A4 | pass | pass | pass | **FAIL** (2) |

Numbers in brackets are violations. First violations, quoted from the run:

```
FAIL  A2 ... (272 violations; first: claim 43183859-5d14-44c7-a52d-d77b4ad2cd70 by acct-A superseded without a replacement by the same asserter)
FAIL  A1 zero lost writes (872 violations; first: lost person dc00d9ef-ac46-45fa-81ae-c8b6e3e33846 from d0)
FAIL  A3 ... (47 violations; first: epilogue: server view after undo differs from before merge: line 2310: "   "belongsTo": []," vs "   "belongsTo": [")
FAIL  A2 ... (27 violations; first: claim a16de279-9d49-4ea6-92f1-ddbb9db214c6 by acct-A superseded without a replacement by the same asserter)
FAIL  A4 a failing push does not block later pushes (2 violations; first: 334 d0 rows still queued behind the poison row)
```

**Undo-replay classification per control, seeds 1 to 5.** Values are cascade / non-cascade pairs. In brackets: epilogue failures, for the rewrite control only.

| Control | Seed 1 | Seed 2 | Seed 3 | Seed 4 | Seed 5 |
|---|---|---|---|---|---|
| Rewrites references on merge (targets A3) | 0 / **43** (+4) | 1 / **38** (+0) | 1 / **54** (+4) | 1 / **42** (+4) | 1 / **45** (+0) |
| Overwrites on conflict | 9 / 0 | 8 / 0 | 12 / 0 | 13 / 0 | 12 / 0 |
| Drops batch tail | 1 / 0 | 1 / 0 | 3 / 0 | 4 / 0 | 6 / 0 |
| Stale base supersedes head | 8 / 0 | 10 / 0 | 13 / 0 | 14 / 0 | 13 / 0 |
| Blocking client queue | 9 / 0 | 6 / 0 | 8 / 0 | 7 / 0 | 11 / 0 |

- **The A3 control fails through non-cascade pairs on every seed**, 38 to 54 per seed. Most are a view difference with no status difference ("0 status changes, 0 on claims"). On 3 of the 5 seeds it also fails the epilogue. So it still proves the check has teeth.
- **The other four controls have no non-cascade pairs and pass A3.** They target A1, A2 and A4, and they break nothing about merges.

**Why the stale-base control fails A2.** Account A's two phones replace the same claim X offline. The first replacement Q1 arrives and supersedes X. The second, Q2, arrives with base X, which is no longer active. Under the broken rule Q2 supersedes Q1, A's current claim, although Q2 never named it. The check "every superseded claim has a replacement by the same account that names it as base" finds no claim naming Q1 and reports it. The correct servers store Q2 as a competing account instead.

## Findings

1. **Task 8's "exactly one active claim" rule stops people correcting themselves once a fact is contested. Resolved by controller ruling.** Under the Task 8 text, once B disagrees with A, A's correction no longer supersedes A's earlier claim, so A ends up with two standing accounts of their own: 119 to 149 times per seed on seeds 1 to 20 under `correct`. The controller has ruled that Task 8 will use `supersedeOwnUnderContest`: an asserter replacing their own active claim whose id equals `baseClaimId` supersedes it regardless of other accounts' claims; replacing another account's claim never supersedes it. That mode passes all four assertions on seeds 1 to 20 in `dart test` and on 200 seeds in the sweep, with 0 own replacements kept active. It has cascade pairs at the same rate as the baseline (Finding 3b), which does not depend on the contest rule, and no non-cascade pairs.
2. **A row that is overtaken can arrive after its own replacement.** A non-blocking queue means the stuck row reaches the server after newer rows. If the asserter had already replaced it, the plain rule would store it as active and show a spurious "accounts differ" from one person. The fake server checks every claim by the same account on the same key, whatever its status. If any of them already names the arriving claim as its base, the arriving claim is stored as superseded. This covers chains P, Q, R where Q was itself superseded by R before P arrived (seen 4 times in the 200-seed ruled sweep). A2 asserts that no such late claim stands. In the fix-round-3 sweeps the rule fired once on each of the 200 ruled seeds, and once on 199 of the 200 baseline seeds (`lateBase` 0 to 1). `lateArrivalsChecked` has the same counts, and every checked late claim was superseded. The design should state this rule.
3. **A merge or undo refused while a merge stands stays refused after the undo.** A merge or undo that arrives while one of its people is merged away is stored as conflicted, and it stays conflicted after the undo, although without the first merge it might have taken effect. Pairs whose only difference is such in-window rows, and whose view difference those rows fully explain, are accepted-interfering: 791 (baseline) and 823 (ruled) in the 200-seed sweeps. Section 8's "becomes a review task" must cover conflicted merges and undos, not only references to the merged identity.

3b. **A merge refused while another merge stood is never retried when that merge is undone, and the effect spreads.** This is the cascade class (definition in A3 above). The refused merge's absence changes later merges and undos, after the undo and sometimes on other people linked through them.

Raw and explained figures over the 200-seed sweeps:

| Rule | Replayed pairs | Differ at all | Cascade | Accepted-interfering | Non-cascade |
|---|---|---|---|---|---|
| Baseline | 12,779 | 2,837 | 2,046 | 791 | 0 |
| Ruled | 12,822 | 2,884 | 2,061 | 823 | 0 |

Every cascade pair changes only merge and undo statuses, all in the taint set, and putting them back reproduces the real view exactly. No claim status differs in any pair.

Examples, both from seed 1:
- Baseline: pair merge `8a1a8ab7-b7cf-4863-a689-27862a2b55fb`, seq 102 to 194. Merge @126 inside the window was refused in the real run and takes effect in the replay. Merge @973 then takes effect in the real run and is refused in the replay.
- Ruled rule: pair merge `d7203496-8f13-48c7-9bd3-a9a3664df63f`, seq 34 to 90. One refused merge @86 changes six later merges and undos, out to seq 962.

The direct requirement, that a merge followed by undo returns the pre-merge view, holds on every seed (the epilogues). The design question for M5 has two options:
- re-evaluate refused merges and undos when a merge is undone, which can change outcomes people have already seen;
- keep the current rule and make every refused merge or undo, and everything decided after it on the same people, a review task.

The suite reports cascade pairs per seed and fails only on non-cascade pairs. A non-cascade pair on the real server would be recorded here as Finding 3c; none occurred. The replay uses no sync, so the choice of sync does not affect this.

4. **Spike 1's pull cursor must also move on status changes** (inferred from reading `spikes/leak/README.md`, not tested together). Spike 1's per-account version moves only when an account's access changes. A claim being superseded changes its status, not its access, so a device on spike 1's cursor would never learn of it. M2 must give the status change a new version for every account that can see the claim.
5. **The fake server's cursor would leak in production.** It is a position in one global change log, so its value counts every write, including hidden ones. Spike 1's per-account version does not have this problem; M2 should use that, not this.
6. **A permanently failing row needs a visible state.** The spike retries the poison every round until the server is fixed. Production needs a cap, a dead-letter state, and a way for the user to see that one item has not been sent.

## What was NOT tested

- Postgres, Supabase, HTTP, TLS, timeouts, auth, and the visibility filter (`claim_access`). The server is single-threaded Dart, so concurrent transactions racing on one contest key were not tested.
- Revocation in this spike's sync. Spike 1 covers revocation on its own Postgres model.
- A crash between applying a pull page and storing its cursor. Both are in one Drift transaction, but no crash was injected inside it.
- The poison as a person, name edit, merge or undo row. Only a claim was poisoned.
- Merge evidence, confirmation by both families, and the review tasks.
- Device-side display of unsent merges (the view counts confirmed rows only).
- Scale beyond about 1,000 rows, more than two accounts, schema migration, back-pressure, and real devices.
- Contest-key rules for kinds other than the two house kinds (sire, joined-via, origin note, "same person").
- Undo chains: a merge into a person who is already a merge target is stored as conflicted, so chains never form.
- The id-conflict path (same id, different content): the server refuses it, but the fuzz never sends one, so the path never ran.
- Outbox persistence across an app restart. Each device database is in memory and lives for one run.
- Display of pending claims and pending name edits. The view counts confirmed rows only.
- Contest keys that ignore merged identity. Keys use the raw person id, so while a and b are merged their `belongsToHouse` claims sit on separate keys and never supersede each other, yet the merged view lists them together and can show "accounts differ" across them.

## Effort

**(a) My elapsed time.** Measured with `date` on 2026-11-03. First commit: 14:30:00 to 14:47:19 EAT, about 17 minutes and about 52 tool calls. Fix round 1: 14:54:42 to about 15:13 EAT, about 19 minutes and about 21 tool calls. Fix round 2: 15:16:46 to 15:28:47 EAT, about 12 minutes and about 21 tool calls. Fix round 3: 15:30:14 to 15:42 EAT, about 12 minutes and about 12 tool calls. Total about 60 minutes and about 106 tool calls. This is the time of an AI session that does not tire or switch context, and it is not a measure of the founder's working days.

**(b) Lines of Dart** (`wc -l`; in brackets, lines that are neither blank nor comments):

| File | Lines | Code |
|---|---|---|
| `lib/fake_server.dart` (server, including 4 broken modes and the ruled-rule mode) | 256 | 190 |
| `lib/device.dart`, whole file (schema, local writes, queries, sync) | 363 | 290 |
| `lib/device.dart`, the sync section alone (outbox, push, pull) | 135 | 114 |
| `lib/model.dart` (row, results, interface, contest key, view) | 291 | 228 |
| `lib/fake_network.dart` (fault injection, test only) | 69 | 52 |
| `lib/fuzz.dart` (fuzz and assertions, test only) | 647 | 565 |
| `bin/fuzz.dart` (command line, test only) | 39 | 33 |
| `test/fuzz_test.dart` (test groups, test only) | 101 | 83 |

**(c) What a production sync still needs.**

| Item | Status |
|---|---|
| Idempotent push by client UUID | spiked |
| Retries that never block the queue | spiked |
| Duplicate and partially applied batches | spiked |
| Resumable pulls with a persisted cursor | spiked (cursor stored with the page in one Drift transaction; lost responses injected; no crash inside the transaction) |
| A cursor that does not leak write counts (per-account version) | not spiked here; built in spike 1 |
| Contest rule and merge/undo as server rules | spiked in Dart; not in Postgres |
| Contest rule under concurrent server transactions (locking per contest key) | not spiked |
| Status changes reaching viewers through spike 1's per-account cursor (Finding 4) | not spiked |
| Auth (Supabase sessions, binding writes to the account) | not spiked |
| Visibility filter on pull | not spiked here; built in spike 1 |
| Revocation of rows no longer visible | not spiked here; built in spike 1 |
| Dead-letter state and user-visible "not sent" (Finding 6) | not spiked |
| Schema migration of synced rows on device and server | not spiked |
| Back-pressure and batching limits (payload caps, rate limits, server page limits) | not spiked (fixed batch of 20 and page of 50 only) |
| Observability (sync health metrics, error reports from devices) | not spiked (harness counters only) |
| Real transport: HTTP endpoints, timeouts, retry timing on connectivity change | not spiked |
| The fuzz ported to run against the real server | not spiked |

**(d) Production estimate. [ESTIMATE, not measured]** About 4 to 7 working weeks in all for the founder and Claude together, in focused working days, split by whether the work exists only because the sync is custom. Section 9 names the custom-sync costs as "retries, idempotency, resumable pulls and revocation".

*Custom-sync-only work: 12 to 23 days, about 2.5 to 4.5 weeks.*
- client HTTP transport, retry timing and dead-letter display: 3 to 5
- idempotent push endpoint: 1 to 2
- a per-account cursor that also carries status changes: 2 to 4
- revocation delivered through this sync: 2 to 4 (spike 1 has a working model)
- back-pressure limits: 1 to 2
- sync health observability: 1 to 2
- porting the fuzz to the real sync: 2 to 4

*Needed either way: 7 to 14 days.*
- the contest rule and merge/undo in Postgres under concurrent transactions: 2 to 4
- the visibility filter (`claim_access`): 2 to 4
- auth wiring and row-rule parity: 2 to 3
- schema migration: 1 to 2
- general observability: 0 to 1

The spike itself took minutes of session time. That says the core logic is small and testable, not that the rest will go as fast; most of the remaining days are integration with Postgres and Supabase, which the spike did not touch. Whether PowerSync would remove all of the custom-sync-only items was not checked [UNVERIFIED].

## The design's triggers (section 9)

Section 9 says the sync choice changes if "spike 2 shows the custom sync costs more than a few weeks, or PowerSync passes the leak spike."

- **Custom sync costs more than a few weeks: not shown.** Nothing in this spike measures weeks. The custom-sync-only part of the estimate is 2.5 to 4.5 weeks [ESTIMATE, not measured], which straddles "a few"; the design does not say how many weeks "a few" means. The 1.5 to 3 weeks of work needed either way does not count toward this trigger. Whether PowerSync would remove the custom-sync-only items was not checked here [UNVERIFIED]. If the founder reads "a few" as three weeks or fewer, this trigger is borderline and deserves a decision rather than a default.
- **PowerSync passes the leak spike: did not fire.** Spike 1 tested a custom Postgres model only; PowerSync was not run through it.

**Recommendation: keep the custom sync behind `SyncTransport`, with `supersedeOwnUnderContest` as the contest rule.** Evidence: across 200 fuzzed seeds under each contest rule, with every injected fault, the sync passed all four assertions, with 0 non-cascade undo pairs. Every assertion has a negative control that fails. The custom-sync-only work is estimated at 2.5 to 4.5 weeks [ESTIMATE, not measured]. The cascade pairs (Finding 3b) come from the merge rule, not the sync, and need a design decision before M5.
