# Spike 2: claims and custom sync cost

Throwaway. Question: do append-only claims survive offline edits from three devices, and what would a custom sync cost?

**Answer for the model built here: yes.** On 200 seeds of 1,000 random operations each across three devices, with random offline periods, random reconnect order, duplicate pushes, mid-push connection drops and one row that keeps failing, all four required assertions pass against the fake server, under both the Task 8 text rule and the rule the controller ruled for Task 8. Every merge that was later undone is replayed, none skipped: 12,779 pairs in the 200-seed baseline sweep and 12,822 under the ruled rule. 78% of the pairs under each rule give an identical view; the rest differ only in the status of a later merge or undo that touched the same people (Finding 3); none fails. Five deliberately broken variants (four servers and one client) each fail the assertion they target, on every seed tried. The answer covers an in-memory fake server and in-memory devices, not Postgres, HTTP or real phones (see "What was NOT tested").

**Recommendation: keep the custom sync.** The sync core (idempotent push, a queue that does not block, resumable pulls) is 190 code lines of fake server (including the broken modes) and 114 of device sync code and passed every seed. The costly work that remains is mostly server-side visibility, revocation and the contest rule under concurrency, which section 9 says must be written whichever sync is used. The production estimate below is an estimate, not a measurement.

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

The "recent claim" choice was added in fix round 1. Without it, account A's two phones almost never edited the same key while both were offline, so stale bases from one account were too rare for the stale-base control to fail on every seed. It changes every seed's numbers compared with the first commit.

Faults, per request: mid-push drop 15% (the server stores a random prefix of the batch, then the connection drops), duplicate push 15% (the same batch reaches the server twice), lost pull response 10%. The poison row is `d0`'s fifth claim: while it is in a batch the server stores the rows before it and then answers with an internal error.

Then: phase 1, everyone online and no injected faults, with the poison still failing; check A4. Phase 2, the poison is fixed and everything drains. Two epilogues run merge then undo through the sync on purpose. Then A1 to A3 are checked.

### The assertions

- **A1 zero lost writes.** Every row any device wrote is on the server. Every device's outbox is empty. Every device holds exactly the server's rows, with the same content, status and `seq`.
- **A2 contested facts kept as competing accounts, never overwritten.** No row's fixed fields changed anywhere (server compared with the author's copy; each device checks every row it pulls against its own copy). Every superseded claim has a replacement by the same account that names it as base. On every contest key, every account that ever asserted there still has at least one active claim. A claim that arrives after a claim of its own asserter already named it as base must be superseded, so one person never competes with themselves through late arrival (`lateArrivalsChecked`). The view does not change when device clocks are zeroed.
- **A3 merge then undo returns the pre-merge view.** (a) Epilogue 1: render the view on the server and all three devices, merge on `d1`, sync, check the view changed, undo on `d2`, sync; all four views must equal the view before the merge. (b) Epilogue 2: merge on `d0`; while merged, `d1` asserts a claim and `d2` edits the name of the kept person; undo on `d0`. (c) Every merge later undone during the whole run (the epilogues included) is replayed; none is skipped. A fresh server receives every row in the same arrival order minus that merge and its undo. If its view equals the real one, the pair is `identical`. If not, the per-row statuses of that replay are compared with a replay of the whole log: the pair is `acceptedInterfering` only when every changed status is on a merge or undo row that arrived after the merge (Finding 3); anything else fails, including a view difference with no status difference. A replay of the whole log must reproduce the server's view, or the check fails.
- **A4 a failing push does not block later pushes.** After phase 1, the poison is not on the server, it is the only row left in `d0`'s outbox, and every row `d0` wrote after it is on the server.

## Results

Final run of `dart test -r expanded -j 1` (fix round 1):

```
00:50 +65: All tests passed!
dart test -r expanded -j 1  51.65s user 0.74s system 102% cpu 51.209 total
```

65 tests: 20 seeds under `correct`, 20 under `supersedeOwnUnderContest`, and 25 negative-control runs. Seed 1 under the ruled rule, from that run:

```
seed 1 mode=supersedeOwnUnderContest: PASS
  pass  A1 zero lost writes
  pass  A2 contested facts kept as competing accounts, never overwritten
  pass  A3 merge then undo returns the pre-merge view
  pass  A4 a failing push does not block later pushes
```

| Seeds | Mode | A1 | A2 | A3 | A4 |
|---|---|---|---|---|---|
| 1 to 20 (`dart test`) | `supersedeOwnUnderContest` (ruled rule) | pass on all 20 | pass on all 20 | pass on all 20 | pass on all 20 |
| 1 to 20 (`dart test`) | `correct` (Task 8 text, baseline) | pass on all 20 | pass on all 20 | pass on all 20 | pass on all 20 |
| 1 to 200 (`bin/fuzz.dart`, extra sweep) | `supersedeOwnUnderContest` | pass on all 200 | pass on all 200 | pass on all 200 | pass on all 200 |
| 1 to 200 (`bin/fuzz.dart`, extra sweep) | `correct` | pass on all 200 | pass on all 200 | pass on all 200 | pass on all 200 |

**A3 coverage per seed, seeds 1 to 20** (from the `dart test` run; replayed = identical + accepted-interfering + failed):

| Seed | Ruled: replayed | identical | accepted-interfering | failed | Baseline: replayed | identical | accepted-interfering | failed |
|---|---|---|---|---|---|---|---|---|
| 1 | 71 | 58 | 13 | 0 | 68 | 57 | 11 | 0 |
| 2 | 69 | 57 | 12 | 0 | 63 | 53 | 10 | 0 |
| 3 | 68 | 53 | 15 | 0 | 62 | 53 | 9 | 0 |
| 4 | 62 | 46 | 16 | 0 | 63 | 48 | 15 | 0 |
| 5 | 67 | 49 | 18 | 0 | 63 | 42 | 21 | 0 |
| 6 | 73 | 54 | 19 | 0 | 77 | 59 | 18 | 0 |
| 7 | 59 | 42 | 17 | 0 | 65 | 53 | 12 | 0 |
| 8 | 58 | 45 | 13 | 0 | 65 | 59 | 6 | 0 |
| 9 | 66 | 50 | 16 | 0 | 51 | 42 | 9 | 0 |
| 10 | 55 | 37 | 18 | 0 | 64 | 49 | 15 | 0 |
| 11 | 59 | 46 | 13 | 0 | 67 | 56 | 11 | 0 |
| 12 | 61 | 46 | 15 | 0 | 68 | 50 | 18 | 0 |
| 13 | 68 | 51 | 17 | 0 | 60 | 44 | 16 | 0 |
| 14 | 65 | 53 | 12 | 0 | 65 | 54 | 11 | 0 |
| 15 | 68 | 57 | 11 | 0 | 66 | 53 | 13 | 0 |
| 16 | 67 | 46 | 21 | 0 | 73 | 52 | 21 | 0 |
| 17 | 58 | 44 | 14 | 0 | 61 | 49 | 12 | 0 |
| 18 | 66 | 55 | 11 | 0 | 65 | 57 | 8 | 0 |
| 19 | 67 | 44 | 23 | 0 | 68 | 55 | 13 | 0 |
| 20 | 60 | 43 | 17 | 0 | 62 | 46 | 16 | 0 |

**Other counters, per seed, minimum to maximum.**

| Counter | Ruled, seeds 1-20 | Baseline, seeds 1-20 | Ruled, 200 seeds | Baseline, 200 seeds |
|---|---|---|---|---|
| `staleBase` (base on the server but not active) | 147 to 186 | 21 to 49 | 131 to 198 | 18 to 49 |
| claims superseded | 134 to 167 | 19 to 40 | 114 to 174 | 16 to 44 |
| own replacement kept active by the "exactly one" rule | 0 | 119 to 149 | 0 | 104 to 165 |
| late-base rule fired (seeds where it fired) | 1 (20 of 20) | 1 (20 of 20) | 0 to 1 (200 of 200) | 0 to 1 (199 of 200) |
| of which the naming row was itself already superseded (chain P, Q, R) | 0 | 0 | 0 to 1 (4 in total) | 0 |
| A3 pairs replayed | 55 to 73 | 51 to 77 | 43 to 83 (12,822) | 49 to 80 (12,779) |
| A3 pairs failed | 0 | 0 | 0 | 0 |

In the 200-seed baseline sweep, also per seed: 416 to 499 claims; 25 to 47 contest keys with active claims from both accounts; 23 to 64 mid-push drops; 9 to 39 duplicate pushes; 12 to 43 lost pull responses; 114 to 351 duplicate acknowledgements; 7 to 44 conflicted merges; 282 to 371 `d0` rows written after the poison row, all delivered while it was failing.

### Negative controls

Each runs on seeds 1 to 5 inside `dart test`, and the test passes only if the fuzz fails the targeted assertion. All 25 runs failed as required. Seed 1, from the final run:

| Variant | Targets | A1 | A2 | A3 | A4 |
|---|---|---|---|---|---|
| Server overwrites on conflict (a new claim supersedes every active claim on the key) | A2 | pass | **FAIL** (272) | pass | pass |
| Server acknowledges a batch but silently drops its second half | A1 | **FAIL** (872) | pass | pass | FAIL (1) |
| Server rewrites the merged-away person's claims to the kept person | A3 | pass | FAIL (691) | **FAIL** (36) | pass |
| Stale base supersedes the asserter's current claim (built on the ruled rule) | A2 | pass | **FAIL** (27) | pass | pass |
| Client queue stops at the first failing row | A4 | pass | pass | pass | **FAIL** (2) |

Numbers in brackets are violations. First violations, quoted from the run:

```
FAIL  A2 ... (272 violations; first: claim 43183859-5d14-44c7-a52d-d77b4ad2cd70 by acct-A superseded without a replacement by the same asserter)
FAIL  A1 zero lost writes (872 violations; first: lost person dc00d9ef-ac46-45fa-81ae-c8b6e3e33846 from d0)
FAIL  A3 ... (36 violations; first: epilogue: server view after undo differs from before merge: line 2310: "   "belongsTo": []," vs "   "belongsTo": [")
FAIL  A2 ... (27 violations; first: claim a16de279-9d49-4ea6-92f1-ddbb9db214c6 by acct-A superseded without a replacement by the same asserter)
FAIL  A4 a failing push does not block later pushes (2 violations; first: 334 d0 rows still queued behind the poison row)
```

**The reference rewrite still fails A3 through the full replay, not only the epilogue.** On seeds 1 to 5 its A3 violations split into epilogue and replay as 4 + 32, 0 + 31, 4 + 45, 4 + 33 and 0 + 34. Most replay failures show a view difference with no status difference ("0 status changes, 0 on claims"), which the new rule rejects.

**Why the stale-base control fails A2.** Account A's two phones replace the same claim X offline. The first replacement Q1 arrives and supersedes X. The second, Q2, arrives with base X, which is no longer active. Under the broken rule Q2 supersedes Q1, A's current claim, although Q2 never named it. The check "every superseded claim has a replacement by the same account that names it as base" finds no claim naming Q1 and reports it. The correct servers store Q2 as a competing account instead.

## Findings

1. **Task 8's "exactly one active claim" rule stops people correcting themselves once a fact is contested. Resolved by controller ruling.** Under the Task 8 text, once B disagrees with A, A's correction no longer supersedes A's earlier claim, so A ends up with two standing accounts of their own: 119 to 149 times per seed on seeds 1 to 20 under `correct`. The controller has ruled that Task 8 will use `supersedeOwnUnderContest`: an asserter replacing their own active claim whose id equals `baseClaimId` supersedes it regardless of other accounts' claims; replacing another account's claim never supersedes it. That mode passes all four assertions on seeds 1 to 20 in `dart test` and on 200 seeds in the sweep, with 0 own replacements kept active.
2. **A row that is overtaken can arrive after its own replacement.** A non-blocking queue means the stuck row reaches the server after newer rows. If the asserter had already replaced it, the plain rule would store it as active and show a spurious "accounts differ" from one person. The fake server checks every claim by the same account on the same key, whatever its status. If any of them already names the arriving claim as its base, the arriving claim is stored as superseded. This covers chains P, Q, R where Q was itself superseded by R before P arrived (seen 4 times in the 200-seed ruled sweep). A2 asserts that no such late claim stands. The rule fired in 200 of 200 ruled seeds and 199 of 200 baseline seeds. The design should state this rule.
3. **Merge and undo are only exactly reversible when nothing else touched the same people in between.** A merge or undo that arrives while one of its people is merged away is stored as conflicted, and stays conflicted after the undo. Without the first merge it might have taken effect. In the 200-seed ruled sweep, 2,884 of 12,822 replayed pairs (22%) differ from their counterfactual in this way, and only in the status of such later merge or undo rows; A3 accepts these and fails anything else (none failed). Section 8's "becomes a review task" must cover conflicted merges and undos, not only references to the merged identity.
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

**(a) My elapsed time.** Measured with `date` on 2026-11-03. First commit: 14:30:00 to 14:47:19 EAT, about 17 minutes and about 52 tool calls. Fix round 1: 14:54:42 to about 15:13 EAT, about 19 minutes and about 21 tool calls. Total about 36 minutes and about 73 tool calls. This is the time of an AI session that does not tire or switch context, and it is not a measure of the founder's working days.

**(b) Lines of Dart** (`wc -l`; in brackets, lines that are neither blank nor comments):

| File | Lines | Code |
|---|---|---|
| `lib/fake_server.dart` (server, including 4 broken modes and the ruled-rule mode) | 256 | 190 |
| `lib/device.dart`, whole file (schema, local writes, queries, sync) | 363 | 290 |
| `lib/device.dart`, the sync section alone (outbox, push, pull) | 135 | 114 |
| `lib/model.dart` (row, results, interface, contest key, view) | 291 | 228 |
| `lib/fake_network.dart` (fault injection, test only) | 69 | 52 |
| `lib/fuzz.dart` (fuzz and assertions, test only) | 577 | 512 |
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

**Recommendation: keep the custom sync behind `SyncTransport`, with `supersedeOwnUnderContest` as the contest rule.** Evidence: its core passed 200 fuzzed seeds under each contest rule with every injected fault, with every undone merge replayed, every assertion has a negative control that fails, and the custom-sync-only work is estimated at 2.5 to 4.5 weeks [ESTIMATE, not measured].
