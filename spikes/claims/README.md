# Spike 2: claims and custom sync cost

Throwaway. Question: do append-only claims survive offline edits from three devices, and what would a custom sync cost?

**Answer for the model built here: yes.** On 200 seeds of 1,000 random operations each across three devices, with random offline periods, random reconnect order, duplicate pushes, mid-push connection drops and one row that keeps failing, all four required assertions pass against the fake server. Four deliberately broken variants (three servers and one client) each fail the assertion they target, on every seed tried. The answer covers an in-memory fake server and in-memory devices, not Postgres, HTTP or real phones (see "What was NOT tested").

**Recommendation: keep the custom sync.** The sync core (idempotent push, a queue that does not block, resumable pulls) is 167 lines of fake server and 114 lines of device sync code and passed every seed. The costly work that remains is mostly server-side visibility, revocation and the contest rule under concurrency, which section 9 says must be written whichever sync is used. The production estimate below is an estimate, not a measurement.

## What was built

All under `spikes/claims/`, a plain Dart package. Pinned in `pubspec.lock`: drift 2.35.3, sqlite3 3.8.0, test 1.33.0. Dart SDK 3.13.7.

| File | What it is |
|---|---|
| `lib/model.dart` | `ClaimRow`, `PushResult`, `PullResult`, `SyncTransport`, the errors, `contestKey`, and `renderView` (the view a person would see, as a canonical string). |
| `lib/fake_server.dart` | The fake server, plain Dart, in memory. Idempotent push by id, arrival order, the contest rule, names, merge and undo, paged pull. Also the broken variants used as negative controls. |
| `lib/fake_network.dart` | The simulated network between one device and the server. Injects offline, mid-push drops, duplicate pushes and lost pull responses. |
| `lib/device.dart` | One phone: an in-memory Drift database (no generated code, as in spike 1), an outbox, push and pull. |
| `lib/fuzz.dart` | The seeded fuzz and the four assertions. |
| `test/fuzz_test.dart` | 20 seeds against the real fake server, plus the negative controls. |
| `bin/fuzz.dart` | Runs or replays any seed from the command line. |

## Run

```sh
source scripts/env.sh            # from the repository root
cd spikes/claims
dart pub get
dart test -r expanded -j 1       # 20 seeds + 20 negative-control runs
SEEDS=1,2,3 dart test            # choose seeds
dart run bin/fuzz.dart --seed 7  # replay one seed; repeat --seed for more
dart run bin/fuzz.dart --seed 7 --mode overwriteOnConflict   # a broken server
dart run bin/fuzz.dart --seed 7 --blocking                   # the blocking client
dart run bin/fuzz.dart --seed 7 --mode supersedeOwnUnderContest  # Finding 1
```

A failing seed prints `REPLAY: dart run bin/fuzz.dart --seed N ...`. Every random choice, including UUIDs and fault injection, comes from one `Random(seed)`, so a seed replays exactly.

## Rules the fake server applies

- **Idempotent by id.** A row id seen before is acknowledged as `duplicate` and changes nothing. Same id with different content is refused (`failed`, "id conflict"); it never overwrites.
- **Arrival order is the only clock.** Each new row gets the next `seq`. Device clocks are carried for display and never read. The fuzz gives the three devices skewed clocks (one runs backwards) and checks that the view is unchanged when every device time is set to zero.
- **Claims (plan Task 8 and decision D).** Contest key: `belongsToHouse` by subject, `wifeOfHouse` by house. On arrival, if exactly one claim is active on the key, it was asserted by the same account, and the new claim names it as base, it becomes `superseded`. In every other case the new claim is stored `active` next to the others: a stale base, a base that is another account's claim, or no base all produce a competing account.
- **Late base (added in this spike, see Finding 2).** If an active claim by the same account on the same key already names the arriving claim as its base, the arriving claim is stored `superseded`.
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

User operations: add a person (15%), assert a house claim (45%: `belongsToHouse` with basis `bornTo` or `joined`, or `wifeOfHouse` with basis `married`; the base is the device's own standing claim half the time, someone else's a quarter of the time, otherwise none), edit a name (20%), merge two people (10%), undo a merge the device sees as effective (10%; when none is visible, a claim is asserted instead and counted separately).

Faults, per request: mid-push drop 15% (the server stores a random prefix of the batch, then the connection drops), duplicate push 15% (the same batch reaches the server twice), lost pull response 10%. The poison row is `d0`'s fifth claim: while it is in a batch the server stores the rows before it and then answers with an internal error.

Then: phase 1, everyone online and no injected faults, with the poison still failing; check A4. Phase 2, the poison is fixed and everything drains. Two epilogues run merge then undo through the sync on purpose. Then A1 to A3 are checked.

### The assertions

- **A1 zero lost writes.** Every row any device wrote is on the server. Every device's outbox is empty. Every device holds exactly the server's rows, with the same content, status and `seq`.
- **A2 contested facts kept as competing accounts, never overwritten.** No row's fixed fields changed anywhere (server compared with the author's copy; each device checks every row it pulls against its own copy). Every superseded claim has a replacement by the same account that names it as base. On every contest key, every account that ever asserted there still has at least one active claim. The view does not change when device clocks are zeroed.
- **A3 merge then undo returns the pre-merge view.** (a) Epilogue 1: render the view on the server and all three devices, merge on `d1`, sync, check the view changed, undo on `d2`, sync; all four views must equal the view before the merge. (b) Epilogue 2: merge on `d0`; while merged, `d1` asserts a claim and `d2` edits the name of the kept person; undo on `d0`. (c) For every merge later undone during the whole run (the epilogues included), a fresh server receives every row in the same arrival order minus that merge and its undo; its view must equal the real one. Pairs with another merge or undo touching the same people between them are skipped and counted (Finding 3). A replay of the whole log must reproduce the server's view, or the check fails.
- **A4 a failing push does not block later pushes.** After phase 1, the poison is not on the server, it is the only row left in `d0`'s outbox, and every row `d0` wrote after it is on the server.

## Results

Final run of `dart test -r expanded -j 1`:

```
00:13 +40: All tests passed!
dart test -r expanded -j 1  14.20s user 0.36s system 107% cpu 13.557 total
```

Seed 1 from that run:

```
seed 1 mode=correct: PASS
  pass  A1 zero lost writes
  pass  A2 contested facts kept as competing accounts, never overwritten
  pass  A3 merge then undo returns the pre-merge view
  pass  A4 a failing push does not block later pushes
  stats: {d0RowsAfterPoison: 316, ops: {editName: 205, assertClaim: 451, addPerson: 150, merge: 99, undo (none visible, asserted a claim instead): 12, undoMerge: 83}, rows: 1016, claims: 464, superseded: 30, lateBase: 0, ownReplaceKeptByContest: 126, contestedKeys: 51, selfDifferKeys: 85, conflictedMerges: 24, undoPairsChecked: 34, undoPairsSkipped: 29, syncs: 242, toggles: 76, midPushDrops: 39, duplicatePushes: 21, pullDrops: 31, duplicateAcks: 200, poisonFailures: 76, ms: 885}
```

| Seeds | A1 | A2 | A3 | A4 |
|---|---|---|---|---|
| 1 to 20 (`dart test`) | pass on all 20 | pass on all 20 | pass on all 20 | pass on all 20 |
| 1 to 200 (`bin/fuzz.dart`, extra sweep) | pass on all 200 | pass on all 200 | pass on all 200 | pass on all 200 |

What the 200-seed sweep exercised (per seed, minimum to maximum): 419 to 506 claims; 42 to 67 contest keys with active claims from both accounts; 21 to 64 mid-push drops; 13 to 42 duplicate pushes; 13 to 41 lost pull responses; 137 to 380 duplicate acknowledgements; 10 to 39 conflicted merges; 17 to 55 merge and undo pairs checked by replay (7,439 in total) and 12 to 43 skipped; 284 to 361 `d0` rows written after the poison row, all delivered while it was failing. The late-base rule fired in 144 of the 200 seeds.

### Negative controls

Each runs on seeds 1 to 5 inside `dart test`, and the test passes only if the fuzz fails the targeted assertion. All 20 runs failed as required. Seed 1:

| Variant | Targets | A1 | A2 | A3 | A4 |
|---|---|---|---|---|---|
| Server overwrites on conflict (a new claim supersedes every active claim on the key) | A2 | pass | **FAIL** (300) | pass | pass |
| Server acknowledges a batch but silently drops its second half | A1 | **FAIL** (868) | pass | pass | FAIL (1) |
| Server rewrites the merged-away person's claims to the kept person | A3 | pass | FAIL (724) | **FAIL** (40) | pass |
| Client queue stops at the first failing row | A4 | pass | pass | pass | **FAIL** (2) |

Numbers in brackets are violations. First violations, quoted from the run:

```
FAIL  A2 ... (300 violations; first: claim d5182877-4b23-41fa-ad4c-dc2d7abceead by acct-B superseded without a replacement by the same asserter)
FAIL  A1 zero lost writes (868 violations; first: lost person dc00d9ef-ac46-45fa-81ae-c8b6e3e33846 from d0)
FAIL  A3 ... (40 violations; first: epilogue: server view after undo differs from before merge: line 1864: "   "belongsTo": [" vs "   "belongsTo": [],")
FAIL  A4 a failing push does not block later pushes (2 violations; first: 311 d0 rows still queued behind the poison row)
```

## Findings

1. **Task 8's "exactly one active claim" rule stops people correcting themselves once a fact is contested.** Decision D says the same asserter, with their current claim as base, supersedes it. Task 8 adds that it must be the only active claim on the key. Once B disagrees with A, A's correction no longer supersedes A's earlier claim, so A ends up with two standing accounts of their own. On seeds 1 to 20 this happened 95 to 131 times per seed (`ownReplaceKeptByContest`). The alternative rule (supersede your own named base whatever else stands; mode `supersedeOwnUnderContest`) passes all four assertions on seeds 1 to 20, and those runs supersede 116 to 159 claims per seed against 18 to 34 under Task 8's rule. Decision for the founder before Task 8 is built: I recommend the alternative rule, because it still never lets one account replace another's claim.
2. **A row that is overtaken can arrive after its own replacement.** A non-blocking queue means the stuck row reaches the server after newer rows. If the asserter had already replaced it, the plain rule would store it as active and show a spurious "accounts differ" from one person. The fake server stores it as superseded instead (fired in 144 of 200 seeds). The design should state this rule.
3. **Merge and undo are only exactly reversible when nothing else touched the same people in between.** A merge that arrives while one of its people is merged away is stored as conflicted, and stays conflicted after the undo. 5,225 of 12,664 undone merges in the sweep had such an event in between and were skipped by check A3(c). Section 8's "becomes a review task" must cover conflicted merges, not only references to the merged identity.
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

## Effort

**(a) My elapsed time.** Measured with `date`: started 14:30:00 EAT on 2026-11-03; the README was written at 14:45:47 EAT, about 16 minutes later. About 52 tool calls up to and including the commit. This is the time of an AI session that does not tire or switch context, and it is not a measure of the founder's working days.

**(b) Lines of Dart** (`wc -l`; in brackets, lines that are neither blank nor comments):

| File | Lines | Code |
|---|---|---|
| `lib/fake_server.dart` (server, including 3 broken modes and the comparison mode) | 224 | 167 |
| `lib/device.dart`, whole file (schema, local writes, queries, sync) | 355 | 285 |
| `lib/device.dart`, the sync section alone (outbox, push, pull) | 135 | 114 |
| `lib/model.dart` (row, results, interface, contest key, view) | 291 | 228 |
| `lib/fake_network.dart` (fault injection, test only) | 69 | 52 |
| `lib/fuzz.dart` (fuzz and assertions, test only) | 529 | 473 |

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

**(d) Production estimate. [ESTIMATE, not measured]** About 4 to 7 working weeks for the founder and Claude together. Reasoning, in focused working days per item: Postgres push with idempotency, the contest rule under concurrency, and merge/undo, 3 to 5; a safe per-account cursor that also carries status changes, 2 to 4; the visibility filter and revocation joined to this sync, 4 to 8 (spike 1 has a working model, which narrows this); auth wiring and row-rule parity, 2 to 3; the client's HTTP transport, retry timing and dead-letter display, 3 to 5; schema migration, 1 to 2; back-pressure limits, 1 to 2; observability, 1 to 3; porting the fuzz to the real server, 2 to 4. Total 19 to 36 days. The spike itself took minutes of session time, which says the core logic is small and testable, not that the rest will go as fast; most of the remaining days are integration with Postgres and Supabase, which the spike did not touch.

## The design's triggers (section 9)

Section 9 says the sync choice changes if "spike 2 shows the custom sync costs more than a few weeks, or PowerSync passes the leak spike."

- **Custom sync costs more than a few weeks: not shown.** Nothing in this spike measures weeks. The estimate above (4 to 7 weeks) sits at or above "a few", but it is an estimate, and the design does not say how many weeks "a few" means. Most of that estimate is server-side visibility, revocation and the contest rule, which section 9 says must live on the server either way. Whether PowerSync would remove any of those items was not checked here [UNVERIFIED]. If the founder reads "a few" as three weeks or fewer, this trigger is borderline and deserves a decision rather than a default.
- **PowerSync passes the leak spike: did not fire.** Spike 1 tested a custom Postgres model only; PowerSync was not run through it.

**Recommendation: keep the custom sync behind `SyncTransport`.** Evidence: its core passed 200 fuzzed seeds with every injected fault, every assertion has a negative control that fails, and the work it leaves is mostly work either choice would need.
