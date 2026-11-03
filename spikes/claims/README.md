# Spike 2: claims and custom sync cost

Throwaway. Question: do append-only claims survive offline edits from three devices, and what would a custom sync cost?

**Answer for the model built here: yes for writes and competing accounts; only partly for merge and undo.** The fuzz ran 200 seeds of 1,000 random operations each across three devices, with random offline periods, random reconnect order, duplicate pushes, mid-push connection drops and one row that keeps failing. Under both the Task 8 text rule and the rule the controller ruled for Task 8:
- A1 (zero lost writes), A2 (competing accounts, never overwrites) and A4 (a failing push does not block) pass on all 200 seeds.
- A3's direct checks pass on every seed: a merge then undo with nothing in between returns the exact pre-merge view on the server and all three devices.
- **A3's counterfactual replay check fails on every seed (Finding 3b).** Every merge later undone is replayed, none skipped: 12,779 pairs under the baseline and 12,822 under the ruled rule.
  - 9,942 (77.8%) and 9,938 (77.5%) give an identical view.
  - 791 and 823 differ only in the status of a merge or undo that touched one of the pair's people and arrived inside the pair's window, and putting those statuses back reproduces the real view. A3 accepts these (Finding 3).
  - 2,046 and 2,061 fail. In every failure, all changed statuses are on merge or undo rows; the first is such an in-window row; at least one lies outside the window or touches other people; and putting all changed statuses back reproduces the real view. No claim's status ever differs.

  The undo does not restore the world in which the merge never happened: a merge refused while the first merge stood stays refused, and that carries forward to later merges and undos. This is a property of the merge rule, not of the sync; the replay uses no sync at all.

`dart test` therefore fails 40 of its 65 tests: the 40 real-server seeds, all on A3 alone. Five deliberately broken variants (four servers and one client) each fail the assertion they target on every seed tried. The answer covers an in-memory fake server and in-memory devices, not Postgres, HTTP or real phones (see "What was NOT tested").

**Recommendation: keep the custom sync.** The sync core (idempotent push, a queue that does not block, resumable pulls) is 190 code lines of fake server (including the broken modes) and 114 of device sync code. It passed A1, A2 and A4 on every seed. By the split estimate below, the larger part of the remaining work, 12 to 23 of 19 to 37 days, exists only because the sync is custom; that part includes revocation, which section 9 lists as a custom-sync cost. The work needed whichever sync is used (the contest rule under concurrency, the visibility filter, auth, migration) is the smaller part, 7 to 14 days. Both are estimates, not measurements. The merge and undo finding (3b) needs a design decision whichever sync is used.

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
- **A3 merge then undo returns the pre-merge view.** (a) Epilogue 1: render the view on the server and all three devices, merge on `d1`, sync, check the view changed, undo on `d2`, sync; all four views must equal the view before the merge. (b) Epilogue 2: merge on `d0`; while merged, `d1` asserts a claim and `d2` edits the name of the kept person; undo on `d0`. (c) Every merge later undone during the whole run (the epilogues included) is replayed; none is skipped. A fresh server receives every row in the same arrival order minus that merge and its undo. If its view equals the real one, the pair is `identical`. If not, the per-row statuses of that replay are compared with a replay of the whole log. The pair is `acceptedInterfering` only when both of these hold (Finding 3):
- every changed status is on a merge or undo row that touches at least one of the two people in the replayed merge and arrived after the merge and before its undo;
- putting those rows' real statuses back into the replay reproduces the real view exactly.

Anything else fails, including a view difference with no status difference. Failures that have only merge and undo status changes, start with an interfering row inside the window, and are fully explained once every changed status is put back are counted as `undoPairsFailedCascade`. This counter is a diagnostic; those pairs still fail (Finding 3b). A replay of the whole log must reproduce the server's view, or the check fails.
- **A4 a failing push does not block later pushes.** After phase 1, the poison is not on the server, it is the only row left in `d0`'s outbox, and every row `d0` wrote after it is on the server.

## Results

Final run of `dart test -r expanded -j 1` (fix round 2):

```
00:53 +25 -40: Some tests failed.
dart test -r expanded -j 1  54.85s user 1.16s system 102% cpu 54.427 total
```

The 65 tests are 20 seeds under `correct`, 20 under `supersedeOwnUnderContest`, and 25 negative-control runs. All 25 negative-control tests pass. All 40 real-server seed tests fail, each on A3 alone, and every A3 violation is a replay pair counted in `undoPairsFailedCascade`. No A3 violation came from an epilogue or from the whole-log replay. Seed 1 from that run, baseline then ruled rule (first violations shortened):

```
seed 1 mode=correct: FAIL
  pass  A1 zero lost writes
  pass  A2 contested facts kept as competing accounts, never overwritten
  FAIL  A3 merge then undo returns the pre-merge view (9 violations; first: merge 8a1a8ab7-b7cf-4863-a689-27862a2b55fb plus undo (seq 102..194) left a trace (2 status changes, 0 on claims, interfering only: false, explained: false; changed: merge@126[in,touches] conflicted->effective merge@973[out,touches] effective->conflicted): ...)
  pass  A4 a failing push does not block later pushes
  stats: {d0RowsAfterPoison: 302, ops: {editName: 196, assertClaim: 464, addPerson: 148, undo (none visible, asserted a claim instead): 3, merge: 93, undoMerge: 96}, rows: 1016, claims: 468, superseded: 23, lateBase: 1, lateBaseViaInactive: 0, lateArrivalsChecked: 1, staleBase: 27, ownReplaceKeptByContest: 119, contestedKeys: 36, selfDifferKeys: 71, conflictedMerges: 14, undoPairsReplayed: 68, undoPairsIdentical: 57, undoPairsAcceptedInterfering: 2, undoPairsFailed: 9, undoPairsFailedCascade: 9, syncs: 211, toggles: 93, midPushDrops: 31, duplicatePushes: 20, pullDrops: 25, duplicateAcks: 205, poisonFailures: 56, ms: 1557}
seed 1 mode=supersedeOwnUnderContest: FAIL
  pass  A1 zero lost writes
  pass  A2 contested facts kept as competing accounts, never overwritten
  FAIL  A3 merge then undo returns the pre-merge view (9 violations; first: merge d7203496-8f13-48c7-9bd3-a9a3664df63f plus undo (seq 34..90) left a trace (7 status changes, 0 on claims, interfering only: false, explained: false; changed: merge@86[in,touches] conflicted->effective merge@308[out,touches] effective->conflicted unmerge@314[out,touches] effective->conflicted merge@623[out,touches] effective->conflicted unmerge@805[out,touches] effective->conflicted merge@868[out,touches] effective->conflicted unmerge@962[out,touches] effective->conflicted): ...)
  pass  A4 a failing push does not block later pushes
  stats: {d0RowsAfterPoison: 316, ops: {editName: 208, assertClaim: 423, addPerson: 160, undo (none visible, asserted a claim instead): 10, merge: 104, undoMerge: 95}, rows: 1016, claims: 434, superseded: 143, lateBase: 1, lateBaseViaInactive: 0, lateArrivalsChecked: 1, staleBase: 158, ownReplaceKeptByContest: 0, contestedKeys: 32, selfDifferKeys: 59, conflictedMerges: 16, undoPairsReplayed: 71, undoPairsIdentical: 58, undoPairsAcceptedInterfering: 4, undoPairsFailed: 9, undoPairsFailedCascade: 9, syncs: 232, toggles: 109, midPushDrops: 33, duplicatePushes: 28, pullDrops: 23, duplicateAcks: 221, poisonFailures: 91, ms: 839}
```

Each `changed` entry gives the row's kind and `seq`, whether it is inside the merge-to-undo window, whether it touches the pair's people, and its status in the real run followed by its status in the replay.

| Seeds | Mode | A1 | A2 | A3 | A4 |
|---|---|---|---|---|---|
| 1 to 20 (`dart test`) | `supersedeOwnUnderContest` (ruled rule) | pass on all 20 | pass on all 20 | **fail on all 20** (replay only; direct checks pass) | pass on all 20 |
| 1 to 20 (`dart test`) | `correct` (Task 8 text, baseline) | pass on all 20 | pass on all 20 | **fail on all 20** (replay only; direct checks pass) | pass on all 20 |
| 1 to 200 (`bin/fuzz.dart`, extra sweep) | `supersedeOwnUnderContest` | pass on all 200 | pass on all 200 | **fail on all 200** (replay only; direct checks pass) | pass on all 200 |
| 1 to 200 (`bin/fuzz.dart`, extra sweep) | `correct` | pass on all 200 | pass on all 200 | **fail on all 200** (replay only; direct checks pass) | pass on all 200 |

**A3 coverage per seed, seeds 1 to 20** (from the `dart test` run; replayed = identical + accepted + failed; in every row the failed pairs all have the cascade shape):

| Seed | Ruled: replayed | identical | accepted | failed | Baseline: replayed | identical | accepted | failed |
|---|---|---|---|---|---|---|---|---|
| 1 | 71 | 58 | 4 | 9 | 68 | 57 | 2 | 9 |
| 2 | 69 | 57 | 2 | 10 | 63 | 53 | 3 | 7 |
| 3 | 68 | 53 | 6 | 9 | 62 | 53 | 2 | 7 |
| 4 | 62 | 46 | 4 | 12 | 63 | 48 | 6 | 9 |
| 5 | 67 | 49 | 3 | 15 | 63 | 42 | 6 | 15 |
| 6 | 73 | 54 | 6 | 13 | 77 | 59 | 4 | 14 |
| 7 | 59 | 42 | 5 | 12 | 65 | 53 | 2 | 10 |
| 8 | 58 | 45 | 7 | 6 | 65 | 59 | 1 | 5 |
| 9 | 66 | 50 | 4 | 12 | 51 | 42 | 1 | 8 |
| 10 | 55 | 37 | 3 | 15 | 64 | 49 | 2 | 13 |
| 11 | 59 | 46 | 3 | 10 | 67 | 56 | 3 | 8 |
| 12 | 61 | 46 | 4 | 11 | 68 | 50 | 6 | 12 |
| 13 | 68 | 51 | 7 | 10 | 60 | 44 | 4 | 12 |
| 14 | 65 | 53 | 3 | 9 | 65 | 54 | 4 | 7 |
| 15 | 68 | 57 | 1 | 10 | 66 | 53 | 2 | 11 |
| 16 | 67 | 46 | 8 | 13 | 73 | 52 | 5 | 16 |
| 17 | 58 | 44 | 3 | 11 | 61 | 49 | 4 | 8 |
| 18 | 66 | 55 | 4 | 7 | 65 | 57 | 1 | 7 |
| 19 | 67 | 44 | 9 | 14 | 68 | 55 | 3 | 10 |
| 20 | 60 | 43 | 5 | 12 | 62 | 46 | 5 | 11 |

**Other counters, per seed, minimum to maximum** (the 200-seed sweeps were re-run in fix round 2):

| Counter | Ruled, seeds 1-20 | Baseline, seeds 1-20 | Ruled, 200 seeds | Baseline, 200 seeds |
|---|---|---|---|---|
| `staleBase` (base on the server but not active) | 147 to 186 | 21 to 49 | 131 to 198 | 18 to 49 |
| claims superseded | 134 to 167 | 19 to 40 | 114 to 174 | 16 to 44 |
| own replacement kept active by the "exactly one" rule | 0 | 119 to 149 | 0 | 104 to 165 |
| late-base rule fired (`lateBase`) | 1 on every seed (20 of 20) | 1 on every seed (20 of 20) | 1 on every seed (200 of 200) | 0 to 1 (fired on 199 of 200) |
| of which the naming row was itself already superseded (`lateBaseViaInactive`) | 0 | 0 | 0 to 1 (4 in total) | 0 |
| late arrivals checked by A2 (`lateArrivalsChecked`), all superseded | 1 | 1 | 1 (200 in total) | 0 to 1 (199 in total) |
| A3 pairs replayed | 55 to 73 | 51 to 77 | 43 to 83 (12,822) | 49 to 80 (12,779) |
| A3 pairs identical | 37 to 58 | 42 to 59 | 31 to 67 (9,938) | 35 to 64 (9,942) |
| A3 pairs accepted as interfering | 1 to 9 | 1 to 6 | 0 to 11 (823) | 0 to 10 (791) |
| A3 pairs failed (all with the cascade shape) | 6 to 15 | 5 to 16 | 1 to 18 (2,061) | 4 to 18 (2,046) |

In the 200-seed baseline sweep, also per seed: 416 to 499 claims; 25 to 47 contest keys with active claims from both accounts; 23 to 64 mid-push drops; 9 to 39 duplicate pushes; 12 to 43 lost pull responses; 114 to 351 duplicate acknowledgements; 7 to 44 conflicted merges; 282 to 371 `d0` rows written after the poison row, all delivered while it was failing.

### Negative controls

Each runs on seeds 1 to 5 inside `dart test`, and the test passes only if the fuzz fails the targeted assertion. All 25 runs failed as required. Seed 1, from the final run. Since fix round 2 every variant also fails A3 through the cascade of Finding 3b, as the real server does:

| Variant | Targets | A1 | A2 | A3 | A4 |
|---|---|---|---|---|---|
| Server overwrites on conflict (a new claim supersedes every active claim on the key) | A2 | pass | **FAIL** (272) | FAIL (9) | pass |
| Server acknowledges a batch but silently drops its second half | A1 | **FAIL** (872) | pass | FAIL (1) | FAIL (1) |
| Server rewrites the merged-away person's claims to the kept person | A3 | pass | FAIL (691) | **FAIL** (47) | pass |
| Stale base supersedes the asserter's current claim (built on the ruled rule) | A2 | pass | **FAIL** (27) | FAIL (8) | pass |
| Client queue stops at the first failing row | A4 | pass | pass | FAIL (9) | **FAIL** (2) |

Numbers in brackets are violations. First violations, quoted from the run:

```
FAIL  A2 ... (272 violations; first: claim 43183859-5d14-44c7-a52d-d77b4ad2cd70 by acct-A superseded without a replacement by the same asserter)
FAIL  A1 zero lost writes (872 violations; first: lost person dc00d9ef-ac46-45fa-81ae-c8b6e3e33846 from d0)
FAIL  A3 ... (47 violations; first: epilogue: server view after undo differs from before merge: line 2310: "   "belongsTo": []," vs "   "belongsTo": [")
FAIL  A2 ... (27 violations; first: claim a16de279-9d49-4ea6-92f1-ddbb9db214c6 by acct-A superseded without a replacement by the same asserter)
FAIL  A4 a failing push does not block later pushes (2 violations; first: 334 d0 rows still queued behind the poison row)
```

**The reference rewrite still fails A3, in ways the real server never does.** On seeds 1 to 5 its A3 violations were as follows:

| Seed | Epilogue failures | Replay pairs failed | Cascade shape | Not cascade shape |
|---|---|---|---|---|
| 1 | 4 | 43 | 0 | 43 |
| 2 | 0 | 39 | 1 | 38 |
| 3 | 4 | 55 | 1 | 54 |
| 4 | 4 | 43 | 1 | 42 |
| 5 | 0 | 46 | 1 | 45 |

The real server has 0 epilogue failures and 0 non-cascade failures on every seed. The non-cascade failures are mostly a view difference with no status difference ("0 status changes, 0 on claims"). The `dart test` control checks only that A3 failed; these splits come from a separate run of the same seeds.

**Why the stale-base control fails A2.** Account A's two phones replace the same claim X offline. The first replacement Q1 arrives and supersedes X. The second, Q2, arrives with base X, which is no longer active. Under the broken rule Q2 supersedes Q1, A's current claim, although Q2 never named it. The check "every superseded claim has a replacement by the same account that names it as base" finds no claim naming Q1 and reports it. The correct servers store Q2 as a competing account instead.

## Findings

1. **Task 8's "exactly one active claim" rule stops people correcting themselves once a fact is contested. Resolved by controller ruling.** Under the Task 8 text, once B disagrees with A, A's correction no longer supersedes A's earlier claim, so A ends up with two standing accounts of their own: 119 to 149 times per seed on seeds 1 to 20 under `correct`. The controller has ruled that Task 8 will use `supersedeOwnUnderContest`: an asserter replacing their own active claim whose id equals `baseClaimId` supersedes it regardless of other accounts' claims; replacing another account's claim never supersedes it. That mode passes A1, A2 and A4 on seeds 1 to 20 in `dart test` and on 200 seeds in the sweep, with 0 own replacements kept active. It fails A3's replay check exactly as the baseline does (Finding 3b), which does not depend on the contest rule.
2. **A row that is overtaken can arrive after its own replacement.** A non-blocking queue means the stuck row reaches the server after newer rows. If the asserter had already replaced it, the plain rule would store it as active and show a spurious "accounts differ" from one person. The fake server checks every claim by the same account on the same key, whatever its status. If any of them already names the arriving claim as its base, the arriving claim is stored as superseded. This covers chains P, Q, R where Q was itself superseded by R before P arrived (seen 4 times in the 200-seed ruled sweep). A2 asserts that no such late claim stands. In the fix-round-2 sweeps the rule fired once on each of the 200 ruled seeds, and once on 199 of the 200 baseline seeds (`lateBase` 0 to 1). `lateArrivalsChecked` has the same counts, and every checked late claim was superseded. The design should state this rule.
3. **A merge or undo refused while a merge stands stays refused after the undo.** A merge or undo that arrives while one of its people is merged away is stored as conflicted, and it stays conflicted after the undo, although without the first merge it might have taken effect. A3 accepts a replayed pair only when every changed status is on a merge or undo row that touches one of the pair's two people and arrived inside the pair's window, and when putting those statuses back reproduces the real view. 823 of 12,822 pairs (ruled sweep) and 791 of 12,779 (baseline) met that. Section 8's "becomes a review task" must cover conflicted merges and undos, not only references to the merged identity.

3b. **The effect does not stay inside the window, so A3's replay check fails on every seed.** In every failing pair, a merge refused inside the window (`conflicted` in the real run, `effective` in the replay) changes what happens to later merges and undos, after the undo and sometimes on other people. 2,061 of 12,822 pairs (ruled sweep) and 2,046 of 12,779 (baseline) fail this way. Every one has the cascade shape:
- only merge and undo statuses change;
- the earliest change is an in-window row touching the pair;
- putting all changed statuses back reproduces the real view exactly;
- no claim status changes in any pair.

Example, seed 1, baseline: pair merge `8a1a8ab7-b7cf-4863-a689-27862a2b55fb` (seq 102) and its undo (seq 194). Merge @126 inside the window was refused in the real run and takes effect in the replay; merge @973 then takes effect in the real run and is refused in the replay. Example, seed 1, ruled rule: pair merge `d7203496-8f13-48c7-9bd3-a9a3664df63f` (seq 34 to 90). One refused merge @86 changes six later merges and undos, out to seq 962. Replay any seed with `dart run bin/fuzz.dart --seed N [--mode supersedeOwnUnderContest]`.

The direct requirement, that a merge followed by undo returns the pre-merge view, holds on every seed (epilogues). What fails is the stronger counterfactual: undo does not give the world in which the merge never happened. This is a design question for M5, not a sync bug. Either re-evaluate refused merges and undos when a merge is undone (which can change outcomes people have already seen), or keep the current rule and make every refused merge and undo, and everything decided after it on the same people, a review task. The replay uses no sync, so the choice of sync does not affect this.
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

**(a) My elapsed time.** Measured with `date` on 2026-11-03. First commit: 14:30:00 to 14:47:19 EAT, about 17 minutes and about 52 tool calls. Fix round 1: 14:54:42 to about 15:13 EAT, about 19 minutes and about 21 tool calls. Fix round 2: 15:16:46 to 15:28:47 EAT, about 12 minutes and about 21 tool calls. Total about 48 minutes and about 94 tool calls. This is the time of an AI session that does not tire or switch context, and it is not a measure of the founder's working days.

**(b) Lines of Dart** (`wc -l`; in brackets, lines that are neither blank nor comments):

| File | Lines | Code |
|---|---|---|
| `lib/fake_server.dart` (server, including 4 broken modes and the ruled-rule mode) | 256 | 190 |
| `lib/device.dart`, whole file (schema, local writes, queries, sync) | 363 | 290 |
| `lib/device.dart`, the sync section alone (outbox, push, pull) | 135 | 114 |
| `lib/model.dart` (row, results, interface, contest key, view) | 291 | 228 |
| `lib/fake_network.dart` (fault injection, test only) | 69 | 52 |
| `lib/fuzz.dart` (fuzz and assertions, test only) | 635 | 562 |
| `bin/fuzz.dart` (command line, test only) | 39 | 33 |
| `test/fuzz_test.dart` (test groups, test only) | 92 | 76 |

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

**Recommendation: keep the custom sync behind `SyncTransport`, with `supersedeOwnUnderContest` as the contest rule.** Evidence: across 200 fuzzed seeds under each contest rule, with every injected fault, the sync passed A1, A2 and A4. Every assertion has a negative control that fails. The custom-sync-only work is estimated at 2.5 to 4.5 weeks [ESTIMATE, not measured]. The A3 replay failure (Finding 3b) comes from the merge rule, not the sync, and needs a design decision before M5.
