# Spike 1: leak and revocation

Throwaway. The question: can a viewer who lacks a quiet claim learn that it exists?

**Answer for the server model built here: no, through every app endpoint tested.** Viewer B's pull payload bytes, wire bytes, Drift table contents, Drift file image, forged-write responses and row counts are identical between a world with a quiet claim (shared to X only) and a world without it. The standing hide setting and revocation behave as the design requires. All 28 tests pass against the real server, and three deliberately leaky canary servers are each caught by the same checks.

Two findings sit outside the app endpoints and need decisions for M2 (see Findings): catalog statistics leak row counts to any raw SQL session, and SQLite's default leaves revoked rows' bytes in the device file.

## What was built

| File | Purpose |
|---|---|
| `pg.sh` | Private Postgres 16 cluster in `.pgdata/` (gitignored), `127.0.0.1:55432` only. `start`, `stop`, `reset`. |
| `schema.sql` | Tables `person`, `account`, `claim`, `claim_audience`, `claim_access`, `privacy_setting`; `refresh_claim_access()`; the write entry point `submit(op jsonb)`; row security. |
| `pull_view.sql` | `pull_view(viewer uuid, since text)`, the viewer's whole payload as one jsonb value. |
| `canary_pull.sql`, `canary_write.sql`, `canary_rls.sql` | Deliberately leaky variants, loaded on top of the real server only by the canary tests. |
| `lib/harness.dart` | Fresh schema per world, viewer sessions under row security, a TCP relay that records every server-to-viewer byte, and the viewer's device as a Drift database. |
| `leak_test.dart` | The scenarios and checks. |

Server model:

- Every key is a client-generated UUID. No sequences, no serial columns.
- `claim_access(account_id, claim_id, active, version)` is derived and is the single source of truth for visibility. The row rule on `claim` reads only `claim_access`. `pull_view` reaches every claim row by joining from the viewer's own `claim_access` rows, and runs as the caller, so the row rules apply as well.
- One write entry point, `submit(op jsonb)`, security definer. Every refusal and every database error inside it returns the same `{"ok": false, "code": "rejected"}`. The write runs in a subtransaction, so a refused write leaves nothing.
- A person row is visible only if a visible claim names it, the viewer created it, or it is the viewer's own person.
- A writer may name only persons and base claims it can see. These checks read through the writer's own visibility, so a hidden row and a missing row look the same.
- **Ids are bound to their writer.** A client-generated id must equal `first 16 bytes of sha256(account || ':' || nonce)`, with the nonce chosen by the client. The server recomputes it before reading any table. Without this, inserting a row with a hidden claim's id would fail with a key collision while a fresh id would succeed, which is an existence oracle for anyone who knows the id. With it, a forged id is refused before any lookup, and two writers can never collide.
- The viewer identity is the session setting `app.viewer` (stands in for `auth.uid()` in M2). Viewers run as role `app_viewer`, which has `select` on the tables (under row security) and `execute` on `submit` and `pull_view` only.

The device is an in-memory Drift database (no generated code; tables made with `customStatement`). It applies each payload as a sync client would: upsert claims, delete `removed_claims`, replace the person table with the payload's person set, store the cursor and the viewer's own hide flag. It holds no visibility logic.

## How to run

```sh
cd <repo-root>
source scripts/env.sh
cd spikes/leak
dart pub get
./pg.sh start
dart test leak_test.dart -r expanded
./pg.sh stop
```

Run the main, hide and revocation assertions against a canary instead of the real server (they should fail):

```sh
LEAK_CANARY=canary_pull dart test leak_test.dart -r expanded
LEAK_CANARY=canary_write dart test leak_test.dart -r expanded
LEAK_CANARY=canary_rls dart test leak_test.dart -r expanded
```

`./pg.sh reset` deletes `.pgdata/` and starts a fresh cluster. The script never uses `brew services`, the default port 5432, or any other cluster. On macOS it sets `LC_ALL=C` because the postmaster otherwise aborts with "postmaster became multithreaded during startup".

Versions, read from the tools on 2026-11-03: PostgreSQL 16.15 (Homebrew `postgresql@16`), Dart 3.13.7. Packages from `pubspec.lock`: `postgres` 3.5.20, `drift` 2.35.3, `sqlite3` 3.8.0, `crypto` 3.0.8, `test` 1.33.0.

## Scenarios

**Main (brief step 2).** Accounts R (recorder), X, B, P, each with their own person. R records Rafa and Kito; each account asserts its own person as a child of Rafa. World A adds a person "QUIET-SIRE-NAME" and a quiet `sire` claim (Kito to that person) shared to X only. World B is identical without those two rows. Both worlds also hold a quiet note R shared to X and B (so B's payload exercises the audience path), a claim by X based on one of R's claims, and B's own person and claim. B pulls once at the start and after every step (in world B the quiet steps are skipped but B still pulls), then a full pull, then forged writes, then a delta and a full pull again.

**Standing hide (brief step 3).** P turns on `hide_quiet_details` when no quiet note exists. Then R adds a quiet `joined_via` note about P, naming a new person, shared to X. B's and X's payloads, counts and rows are captured before the setting, after it, and after the note.

**Revocation (brief step 4).** R shares a quiet `origin_note`, naming a person referenced by nothing else, to X and B. B pulls and applies it. R reshares to X only. B pulls the delta and applies it. A control world never had the note.

## Results against the real server

Final run output is quoted in the task report. All 28 tests passed.

| # | Assertion | Result |
|---|---|---|
| M1 | Non-vacuity: X receives the quiet claim and its sire in A, not in B | PASS |
| M2 | B's pull payload bytes identical, all 18 pulls | PASS |
| M2b | `pull_view` called by B with X's id is refused with the generic error, identically in both worlds | PASS |
| M3 | Server-to-B wire bytes identical after the handshake | PASS |
| M4 | B's Drift table contents identical (all tables, rowid order, schema) | PASS |
| M5 | B's Drift file image (VACUUM INTO) byte-identical | PASS |
| M6 | No quiet text or id in B's payloads, wire bytes, device tables, device image or table rows | PASS |
| M7 | Forged writes: quiet id = random id (world A) = same id in world B, for six probes; all `{"ok": false, "code": "rejected"}` | PASS |
| M8 | Row counts from every endpoint identical (6 tables, full pull and delta pull sections) | PASS |
| M9 | Rows visible from every table identical (sorted by row text) | PASS |
| M9b | Rows visible from every table identical in the server's natural order (no ORDER BY): physical row order does not differ in this scenario | PASS |
| H1 | Non-vacuity: R holds the hidden note; an unhidden note does reach X | PASS |
| H2 | B: full payload bytes identical before the setting, after it, after the note | PASS |
| H3 | B: delta payload bytes identical at the same points | PASS |
| H4 | B: row counts and visible rows identical | PASS |
| H5 | X (in the note's audience) also sees no change: the setting withholds the note | PASS |
| R1 | Non-vacuity: before revocation B holds the claim and its person | PASS |
| R2 | Next pull lists the claim id in `removed_claims` and drops its person | PASS |
| R3 | After applying, no table on B's device holds the claim, its person, or their text | PASS |
| R4 | After applying, B's claim and person contents equal a world where it was never shared | PASS |
| R5 | X keeps the claim (revocation is per viewer) | PASS |
| R6 | Forged writes after revocation: revoked id = random id | PASS |
| R7 | Device file with `PRAGMA secure_delete = ON` keeps no bytes of the revoked rows | PASS |
| R7b | Control for R7: the same steps with the SQLite default (`secure_delete=0`) do leave the revoked bytes in the file | PASS |
| C1-C3 | Canaries detected (below) | PASS |

The six forged-write probes, each aimed at the target id and at an id that exists nowhere: change the target claim's audience; a new claim based on the target claim; a new claim reusing the target claim's id; a new claim naming the target person as object; the same as subject; a new person reusing the target person's id.

## Canary result

Each canary is loaded on top of the real server and the same check functions are run. A check that cannot fail would show as a failing canary test. All three canaries were detected.

| Canary | Bug | Checks that caught it |
|---|---|---|
| `canary_pull` | `pull_view` runs as owner and adds every person named by any claim about a visible person, which pulls in the quiet sire | payload bytes (9 of 18 pulls differ), wire bytes (44271 vs 42313), device tables (person 9 vs 8 rows), device image, quiet-text search, counts (`pull_full:persons` 9 vs 8) |
| `canary_write` | a pre-check on `share` raises "claim not found" for a missing claim, while a hidden claim falls through to "rejected" | forged-write comparison, wire bytes |
| `canary_rls` | the person row rule opened to everyone | table counts (`person` 9 vs 8), table rows (sorted and natural order), quiet-text search, wire bytes |

Running the main group with `LEAK_CANARY=<canary>` turns it red: 6 failures for `canary_pull`, 2 for `canary_write`, 5 for `canary_rls`. The natural-order check (M9b) fails only for `canary_rls`; the other two canaries do not change what the table endpoints return, so it has nothing to catch there. With `LEAK_CANARY=canary_pull` the hide group fails 3 tests and the revocation group fails 4.

## What was normalised

- **Payload bytes (M2, H2, H3): nothing.** The server adds no timestamps. `created_at` is client-supplied and fixed in the test, and `pull_view` renders it in UTC so the session time zone cannot change it. Arrays are ordered by id inside `pull_view`. The cursor is a per-account counter that moves only when that account's own access changes.
- **Wire bytes (M3): the connection handshake is excluded,** meaning everything up to and including the first ReadyForQuery message. It carries BackendKeyData, a process id and random cancel key that differ on every connection and carry no data. Everything after it (row descriptions, data rows, command tags, the session's `set role` and `set_config` responses) is compared byte for byte.
- **Device tables and image (M4, M5): nothing.** Rows are compared in rowid order with the rowid included. The image is the output of `VACUUM INTO`, which is a compacted copy, so it does not show free pages (see the secure_delete finding).
- **Table endpoint rows (M9): sorted by row text.** `tableRows()` orders each table's rows by `row_to_json(x)::text`, so M9 compares the set of rows, not their order. Justification: sorting isolates content from order, so a content difference is reported as such. Because physical row order could itself be a channel, M9b compares the same reads with no ORDER BY, in the order the server returned them, with nothing normalised. Both pass.
- **Revocation comparison with a never-shared world (R4): rowid stripped, rows sorted, and `sync_state` excluded.** B did hold the row, so later rows got different rowids, and B's cursor moved twice (grant and revoke). After the rowid is removed, the remaining rows are sorted by their text, because insertion order also shifted when the revoked row was inserted among them. All three reflect what B legitimately saw; none reveals anything B was not entitled to.
- Identity: both worlds use the same fixed UUIDs for everything except the quiet claim and its sire. Ids made through `submit` are derived from fixed (account, nonce) pairs, so they match too.

## Findings

1. **Catalog statistics leak to a raw SQL session (outside the app endpoints).** As role `app_viewer`, B can read `pg_stat_user_tables`, which every role can read. After the writers disconnect, world A shows `claim 7`, `person 4`, `claim_audience 3`, `claim_access 25` inserted rows; world B shows 6, 3, 2, 23. That reveals a hidden claim exists. The test records this as a measurement, not a pass/fail assertion, because a viewer in the design never holds a SQL session; the app endpoints (pull, submit, tables under row security) show no difference. **M2 must guarantee viewers reach the database only through the RPC and table endpoints** and that no exposed endpoint returns catalog or statistics data. In Supabase terms: confirm the exposed schemas exclude `pg_catalog` and that viewers cannot open direct database connections. [NEEDS SOURCE] for how Supabase's PostgREST exposes schemas; not checked here.
2. **Revoked rows stay in the device file's free pages by default.** With SQLite's default (`secure_delete=0`, `journal_mode=delete`, measured), the revoked note's body, its person's name and both ids remain as bytes in the database file after the rows are deleted. With `PRAGMA secure_delete = ON` none remain (R7, with R7b as its control). M2's device database should set `secure_delete = ON`. The design's local encryption protects this at rest but not on an unlocked phone. WAL mode was not tested and may hold old pages in the `-wal` file until a checkpoint.
3. **Insert-collision oracle closed by binding ids to their writer.** Without it, a writer who knows a hidden claim's id can tell it exists. Knowing the id needs a prior leak or earlier access, so the risk is narrow, but the binding removes it at the cost of one hash on each write. This is a proposed decision for M2, not yet agreed.
4. **Base claims the viewer cannot see are withheld.** If a visible claim's `base_claim_id` points at a claim the viewer cannot see, `pull_view` sends `null` instead of the id. Not exercised by a test in this spike.
5. **Revocation cannot recall data already on a device** (design section 4). B held the note and its person before revocation; nothing on the server can remove what B copied, screenshotted or backed up. The next pull removes the rows from the app's own database, and with `secure_delete` on, from its file.

## What was NOT tested

- **Timing.** Response times were not measured. A hidden claim could change how long `pull_view`, `submit` or `refresh_claim_access` take.
- The raw transport of M2 (HTTPS to PostgREST or an edge function, TLS record lengths). Wire bytes here are the Postgres protocol over local TCP.
- Supabase itself, `auth.uid()`, JWTs, and PostgREST's schema exposure.
- WAL journal mode on the device, and SQLCipher encryption.
- Concurrency: simultaneous writes, and a pull racing a revocation.
- Scale. `refresh_claim_access()` recomputes all access on every write, which is fine for a spike and not for a family of thousands.
- Invites. All accounts are treated as connected; no `invite` table.
- Houses. Membership is a simple `child_of` claim between persons; there is no `house` table.
- Merge evidence, aliases, disputes, cycle detection on hidden data, operator access logging.
- "The author of a hidden note sees only that their own note is hidden": the author sees their note but no "hidden" marker exists.
- Edits to person rows (name changes) and how they reach viewers. Persons are sent as a full set on every pull.
- Other raw-SQL channels in the same class as the `pg_stat_user_tables` finding: `pg_class.reltuples` and `relpages`, `EXPLAIN` row estimates, `pg_relation_size`, the `xmin` and `ctid` system columns, transaction-id functions, and `pg_locks`. `pg_stats` was checked only by reading its definition in this cluster (PostgreSQL 16.15): it filters out tables where row security is active (`(c.relrowsecurity = false) OR (NOT row_security_active(c.oid))`). Not tested as a channel.
- PostgREST planned or estimated counts, and whether it exposes system columns. [UNVERIFIED]
- Server logs, WAL and replication, backups and point-in-time recovery.
- Device-side operating-system backups of the SQLite file, and leftovers of deleted rollback-journal files.
- The hide setting turned on after a quiet note about that person was already shared. The audience would then receive a removal, which may tell them about the setting.
- Competing-account status logic. The spike uses only `status = 'active'`.
- Errors that escape the generic mapping. PL/pgSQL `exception when others` does not catch `QUERY_CANCELED` or `ASSERT_FAILURE`. A `statement_timeout` firing inside `refresh_claim_access()` would escape `submit()` with a different error, turning a timing channel into an error-text channel. M2 must account for it.

## Final shape for M2

`claim_access`, derived, the single source of truth:

```sql
create table claim_access (
  account_id uuid not null references account(id),
  claim_id   uuid not null references claim(id),
  active     boolean not null,  -- may see it now
  version    bigint not null,   -- per-account change counter; moves only on this account's own access changes
  primary key (account_id, claim_id)
);
```

Derivation (`refresh_claim_access()` in `schema.sql`): family-scope claims go to every connected account; audience-scope claims go to the audience snapshot plus the asserter; a quiet claim whose subject or object has `hide_quiet_details` on goes to the asserter only. Only differences are written. A grant sets `active = true`, a revocation sets `active = false`, and each change takes that account's next version. Rows are never deleted, so a revocation stays visible to the pull as a removal.

Row rule on `claim`, reading only `claim_access`:

```sql
create policy claim_read on claim for select to app_viewer
  using (exists (select 1 from claim_access a
                  where a.claim_id = claim.id
                    and a.account_id = current_viewer()
                    and a.active));
```

`pull_view(viewer uuid, since text) returns jsonb` (full text in `pull_view.sql`), security invoker, refuses unless `viewer` is the session's viewer:

```
{ "cursor":         max(version) of the viewer's claim_access rows, as text,
  "claims":         claims whose access row changed after `since` and is active, by id,
  "removed_claims": claim ids whose access row changed after `since` and is inactive, by id,
  "persons":        the full set of persons the viewer may see now, by id,
  "me":             { "hide_quiet_details": the viewer's own setting } }
```

`since = '0'` gives a full pull. The client replaces its person table with `persons`, so a person named only by a revoked claim disappears. For M2, consider tracking person visibility in its own derived table so persons can be sent as a delta too.

Write entry point `submit(op jsonb) returns jsonb`, ops `person`, `claim`, `share`, `privacy`; ids bound to the writer by `derive_id(account, nonce)`; every failure returns `{"ok": false, "code": "rejected"}`.
