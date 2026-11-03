# Family Lineage App: Design

Status: approved by the founder on 2026-11-03 (chat reply "Approve design").
Date: 2026-11-03 (the founder's answers to the open decisions are included)

How to read this document: **Founder decided** marks what the founder said. **My call** marks choices I made that the founder has not agreed to. Section 12 lists what is still open, section 13 lists my calls to check, and section 14 lists what was verified against a source and what was not.

## 1. Intent

The founder and their father were tracing their lineage and got stuck on who was who and who came before whom. They had no way to learn whether another relative already knew the missing piece. The app lets relatives pool what they were told, so that gaps in one person's memory can be filled by someone else's.

The app records lineage as the family holds it. It does not claim blood descent.

## 2. Goals, non-goals, anti-goals

**Goals**
- Let a person record their own family from what they were told, including the parts they do not know.
- Let them invite relatives they personally know, who add their own households. The tree grows sideways first, then deeper.
- Surface who might know a missing piece.
- Show the lineage the way the family says it aloud.

**Non-goals (for the MVP)**
- Public trees or public search.
- DNA or ancestry percentages.
- Photos, voice notes, printing or export, push notifications, search across trees.

**Anti-goals** (the app has failed even if it works technically)
- Duplicates: the same person recorded twice.
- A tree that is unrecognizable, meaning it does not look like the family as they would say it.
- A quiet fact (see section 4) reaching someone it was not shared with.
- The most persistent person's version of a disputed fact winning by volume.
- Pressure on anyone to fill in what their family does not say.

## 3. Constraints

**Founder decided**
- Runs on all platforms. Framework: Flutter (Android, iOS, web).
- Offline-first. Relatives will use it in villages with poor connectivity.
- Invites go only to people the inviter knows, and every person has a direct, recorded link to whoever vouched for them.
- Each person on the system is unique: one account per real person.
- One shared set of facts. Each person sees only what they are allowed to see. Per-household views may come later.
- The person who runs the server can read everything, including quiet links, for the MVP. Access is logged and users are told plainly.
- A data-protection and legal review comes before the pilot.
- The first release is in English only.
- The founder and Claude build it. No date or budget has been given.

**Implications (mine)**
- Claude does not remember earlier sessions. The project's documents and tests must carry what a new session needs to know.
- Sign-in is email and password for the MVP (founder decision, 2026-11-03). One account per person means one email address per account, and an email address cannot be shared between two accounts. People without an email address can be recorded by a relative, with attribution and consent, and get an account later.

**Unconfirmed**
- Most devices are low-end Android phones with 1 to 2 GB of RAM.
- Users may include older relatives.

## 4. How the family is modelled

**Founder decided**
- The unit is husband, then house (a wife, numbered by order), then children. Full sibling and same-father sibling follow from sharing a house. The app never shows "step" or "half".
- Mothers and daughters are named people. A woman is a child in her father's house and a wife in her husband's house. A father's sister is therefore an aunt and also the mother of cousins, and appears in both places.
- A woman can head several houses under different husbands, who may be brothers or cousins of each other.
- In wife inheritance the child belongs to the dead husband's house. The biological sire is a separate optional link, drawn as a dotted line.
- Placeholders ("someone we forgot") and empty houses are normal and shown.
- Duplicates are merged only with evidence (for example mother of X, daughter of Y, wife of Z) and confirmation from both families. Several husbands for one woman counts against nothing.
- Disagreeing accounts are both kept. Nearest relatives are brought in to respond.
- A person can switch on a standing setting, "hide all quiet details about me". It works whether or not any quiet note about them exists.

**Founder's worked example.** The founder is son of Juma, son of Manyi, son of Winyo, son of Ochieng, son of Winyo (the elder), son of someone forgotten. Winyo (Manyi's father) had four wives. Manyi was in house 2 with a full brother, Wade. House 4 had one son, Owala. Houses 1 and 3 are unknown. Winyo's brother Obuolo shares his mother. Olembo shares his father but not his mother. Manyi's mother is Atieno Nyang'or.

**My call**
- "Born into one house" becomes "belongs to a house, with a basis": born to, joined the household, or married. A family that joined the clan, like the founder's uncle's family descended from a herder who was given land, did not start in the house they belong to. The UX Architect raised this and I agree.
- **Quiet links** are the sire of a child born through wife inheritance, how a family joined the clan, and origin notes. They are optional, hidden by default, and visible only to the people the recorder chooses. "Not said" is a normal state. The app never prompts anyone to fill these in. The founder called the topic sensitive and was unsure how to handle it, so this approach is my proposal.
- A viewer who cannot see a quiet link must not be able to tell that it exists. No lock icons, no hidden counts, no gaps, no differing error messages. The standing "hide all quiet details about me" setting follows the same rule. The author of a hidden note sees only that their own note is hidden, not who asked.
- Sharing a quiet link is permanent in practice. Revoking stops future sync but cannot recall data already on a device. The app says so before sharing.

## 5. MVP scope

Small enough to test with one extended family.

**Must have**
1. Household builder: husband, numbered houses, wives, children, placeholders, "not said".
2. Per-link basis (born to, joined, married).
3. Open questions on placeholders ("who was Winyo's father?") shown to invitees. This is the pooling the founder wanted.
4. Invites that carry a relationship claim, by link and by typed code, created offline.
5. Offline-first store with visible sync state.
6. Merge suggestions with evidence, two-sided confirmation and undo.
7. Competing accounts shown with who recorded each and on what basis. Invited relatives each record their own response, and "unresolved" is a permitted end state.
8. The tree labelled "X, son of Y", plus a house view.
9. Quiet links in minimal form, plus the standing "hide all quiet details about me" setting.
10. A way to hide your own entry and to request removal of a living person's entry.

**Later:** voice notes from elders, photos, more languages, print or export, push notifications, search across trees, per-household views, an in-app discussion thread.

**Never:** public trees, DNA or ancestry percentages, "step" or "half" labels, completeness scores or streaks or nudges, votes or counts that decide disputes, automatic merging, leaderboards, selling data.

## 6. Core flows

Each flow has a happy path, an offline path and a failure path. The UX Architect's detailed version is the starting point for the plan.

1. **First run.** Name yourself, your father (a placeholder is allowed), his house number, siblings in that house. Every slot has "don't know". No account is needed until first sync or invite.
2. **Add a person with partial facts.** A name (or "unnamed") plus one link is enough. Search-before-create shows candidates only when there is evidence, never on a name alone.
3. **Invite a relative.** Choose a person you vouch for and the claim ("cousin of X through this parent"). Produces a link and a short typed code.
4. **Receive an invite.** See who invited you and the claim. Nothing of the tree is visible until the inviter or the named relative confirms.
5. **Merge suggestion.** Evidence from links both sides can see. Confirm, not the same, or not sure. Both households must confirm.
6. **Dispute.** Both accounts side by side with recorder and basis. The nearest relatives who are not parties to the dispute are invited to respond. Each records their own response in the app, or after speaking outside it. There is no thread and no vote count. (My call: no single person records the outcome. The dispute shows "agreed" only when every invited respondent selects the same account. Otherwise it stays "unresolved", which is a permitted end state. The founder did not say who has authority to record the outcome, so this default avoids needing one.)
7. **Share a quiet link.** Choose people, see exactly who will see it, confirm.
8. **Undo a merge.** Replays anything built on the merge, or lists what will change.

## 7. Screens and look

**Tabs:** Family (tree and house view), Questions (open placeholders), Inbox (merge suggestions, disputes, invites), Invite, Me (my household, visibility, sync, privacy).

**Default view is the spoken chain**, a plain list that reads "Manyi, son of Winyo, house 2". The diagram is one tap away and is remembered. The UI Designer's reasoning: the family says lineage aloud, so the default reads like speech. This rests on an assumption that users think in chains, not charts, and the first test of it is in section 10.

Display rules:
- Basis is always a word ("born to", "joined", "married"), never colour or line style alone.
- A woman who appears in two houses shows a text tag "same person" in each place.
- Disputed links read "Accounts differ", never an icon alone.
- Placeholder: dashed outline and the words "someone we forgot". Empty house: "not known yet" in plain grey, with no button.
- The diagram draws only the focused house plus one generation each way.
- Use the system font scale, wrap names and never truncate them, and avoid blur, shadow and animation on weak phones.

Constraints: body text contrast of at least 4.5:1 and large text at least 3:1 (WCAG, verified). A touch-target minimum of 48dp is the designer's figure and is unverified. Kinship terms that may not translate one to one between English, Swahili and Dholuo need a native-speaker review before a second language is added.

## 8. Data design

Stack: Postgres on the server (Supabase is a candidate), SQLite on the phone via Drift.

**Two kinds of fields**
- Low-stakes fields follow last write wins: name spelling, nickname, life notes, a household's private notes. Every overwrite is kept in an edit history, so nothing is lost.
- Contested facts are append-only claims: which house a person belongs to, who the wife of a house is, sire, joined-via, origin note, and "same person". Nothing is overwritten. Each claim records who asserted it, the basis, and the claim version it was based on. If the server has moved on since that version, the new claim is stored as a competing account.

**Tables (sketch)**
```
person(id, is_placeholder, name_key, sex, created_by, deleted_at)
person_name(id, person_id, name, kind)     -- spelling variants and extra names
house(id, husband_id, ordinal, created_by, deleted_at)
claim(id, kind, subject_id, object_id, body, asserted_by, basis,
      base_claim_id, status, scope, created_at)
claim_audience(claim_id, account_id)       -- snapshot of who may see it, taken when shared
claim_access(account_id, claim_id)         -- derived, single source of truth for visibility
invite(id, inviter_id, invitee_id, claimed_relation, depth)
person_alias(alias_id, canonical_id)       -- merges
merge_event(id, a, b, evidence, confirmed_by_a, confirmed_by_b, reverses_event_id)
dispute_response(id, subject_id, kind, respondent_id, chosen_claim_id, created_at)
privacy_setting(person_id, hide_quiet_details)
operator_access_log(id, operator, table_name, at)
```
- IDs are client-generated UUIDs. A name is never an identity.
- Every non-root person has an inviter. The invite depth is recorded so that a cap can be switched on later.
- Unknown parentage: a fresh placeholder husband and a fresh house per person. Never one shared "unknown" house, which would make every orphan a full sibling.
- Unknown wife: a house with no accepted wife claim. Ancestor queries follow the father's line, so they never touch wives.
- Several husbands: several houses with the same wife. There is no uniqueness on the wife.

**Visibility.** An audience is an explicit set of accounts, snapshotted when a claim is shared. "My household" is a shortcut in the sharing screen: it expands to the accounts of the people in the houses I belong to (as a child and as a wife or husband) at that moment. People without accounts, such as the dead, children and placeholders, are never in an audience. Later joiners and merges never widen an existing audience; someone new is added by choosing them. Quiet claims have no "whole family" scope. Ordinary, non-quiet claims are visible to every account connected through invites at the time. The derived `claim_access` table is the single source of truth. Both the server's row rules and the sync filter read it, because the two can otherwise drift apart.

**Leak rules.** The only unique keys are client-generated UUIDs. No sequences. Every write goes through one entry point that maps all database errors to a generic code. A person row syncs only if a visible claim or invite references it. A cycle in the lineage found only on hidden data is flagged internally and never shown to the submitter.

**Operator access.** The server holds quiet links in readable form. Anyone with database access can read them. Every operator read is recorded in `operator_access_log`, and the app tells users plainly. End-to-end encryption of quiet links is out of scope because it would break server-built views and merge evidence.

**Merge evidence** uses only claims visible to both sponsoring accounts, and only the kinds "belongs to house" and "wife of house". Score is the number of distinct evidence types, with at least two required. Different husbands never subtract. Quiet kinds never enter evidence.

**Undo** deletes the alias and appends a reversing event. No foreign key is rewritten. Claims made while merged stay on the record they reference. Anything that referenced the merged identity becomes a review task for both families.

**Quality gates:** search-before-create over visible people only, with the candidates shown logged. The invite creates the invitee's person record first, and the invitee claims it instead of creating a second. A cycle check runs before accepting a house or sire claim.

**Known tension to resolve in planning.** "Joined the household" is both a basis for belonging and a quiet link. The membership claim itself is visible, but the word "joined" must display as a neutral "belongs to" unless the audience allows the detail. The Database Optimizer's design assumed membership claims are never quiet. That needs reconciling.

## 9. Client and sync

- Modules: data (Drift), claims, sync, invite, auth, crypto, tree. The client holds no visibility logic. It displays what the server sent. Hiding on the client would mean the data is already on the phone.
- The phone may hold the viewer's server-built view, their own unsent claims, and a pool of pre-fetched invite tokens. It never holds quiet links the viewer is not entitled to.
- **Sync approach (my call): a small custom sync behind an interface**, with PowerSync swappable in. Reason: claims are append-only, so writes are plain inserts, and the visibility filter must live on the server either way. Cost: we write retries, idempotency, resumable pulls and revocation. The founder and Claude maintain it, so the sync code, its tests and its notes must be clear enough for a session that remembers nothing. What would change this: spike 2 shows the custom sync costs more than a few weeks, or PowerSync passes the leak spike. Spike result (2026-11-03, host run, see [spike-results.md](spike-results.md)): the custom sync passed the spike's four assertions on 200 fuzzed seeds against an in-memory fake server. The production estimate is 4 to 7 working weeks in all, 12 to 23 days of it only because the sync is custom [ESTIMATE, not measured]. Neither trigger is shown: this document does not say how many weeks "a few" is, and PowerSync was not run through the leak spike. The choice stays open as a proposal in spike-results.md.
- **Offline invite.** The inviter's phone pre-fetches single-use tokens. Offline, it binds the claim locally and shares a short code with a checksum. The link carries only the token, never the relationship. The invitee can type the code offline, and the app shows only "saved, we will connect when you have signal". Redemption happens when signal returns. Spike 3 (simulated in Dart, not run on a phone; see [spike-results.md](spike-results.md)): the code is 8 token symbols plus 1 check symbol from a 31-symbol alphabet. 31^8 is about 39.6 bits, so a 40-bit token cannot map one-to-one onto 8 symbols, and the server must issue 8-symbol values directly. The token pool and the outbox must be persisted atomically.
- **Redeeming an invite (my call).** Holding a code is not enough. A redeemer sees nothing of the tree until the inviter or the named relative confirms. Open (spike 3): flow 4 shows the redeemer the inviter and the claim before confirmation, and the claim text can name a person in the tree. This sentence and flow 4 disagree until the founder chooses; see [spike-results.md](spike-results.md).
- **Sign-in and recovery.** Email and password (founder decision). The email address is the unique identifier and must be verified before the account can see any tree, so a typo or a borrowed address cannot attach one person's account to another's place in the tree. Password reset goes through the verified email. Add rate limiting on sign-in and reset, and a minimum password length. First sign-in needs signal; after that the app works offline on the stored session. Recovery means signing in again and re-syncing from the server. Unsynced work on a lost phone is lost, and the app says so at install.
- **Why this matters for quiet links (my call).** An account holds access to quiet links, so taking over an account exposes them. Email plus password is weaker than a phone code against password reuse and a shared email inbox. The MVP accepts this, with two mitigations: sign-out of other devices on password change, and a notification email on every reset. Two-step sign-in and passkeys are later.
- **Shared inboxes (my call).** Relatives who share one email address cannot both have accounts. The sign-up screen says so plainly and does not offer a workaround. Whether this blocks real users in the village is a question for the paper test.
- **Encryption.** The local database is encrypted from the first install, with a random key held in the platform's secure storage. This protects a lost or stolen phone, not an unlocked one. Quiet-link secrecy comes from not sending the data. Spike 5 (host run on a Mac only, no phone; see [spike-results.md](spike-results.md)): SQLite3MultipleCiphers through the `sqlite3` build hook works with Drift's `NativeDatabase`, and the file held no plaintext. A missing or rejected key sets the old file aside and does not delete it. Spike 1 found that SQLite's default leaves the bytes of revoked rows in the device file and that `PRAGMA secure_delete = ON` removed them in the test (rollback journal mode; WAL not tested), so the device database should set it.
- **Backups.** A restored database without its key is unreadable, so a restore means a re-sync, and unsynced items are lost. Warn users. Spike 5 simulated this on a Mac: a database file restored without its key could not be opened, and the app fell back to a clean database and kept the old file. Android backup and restore were not run, and the backup settings recommended in `spikes/crypto/README.md` are untested.

## 10. Build order

Nothing is built until the founder approves this document.

**Throwaway spikes first** (thresholds are mine):
1. Leak and revocation: two viewers, one quiet link, plus the standing hide setting. Viewer B's database file, wire traffic, error text and row counts must match a world with no quiet link, and revoked rows must be gone after sync.
2. Claims: three devices, 1,000 randomized offline operations. Zero lost writes, contested facts kept as competing accounts, and merge then undo returns an identical view.
3. Offline invite: airplane-mode matrix (empty token pool, no-signal redeem, missing install referrer, typo).
4. Tree: 3,000 synthetic nodes on the weakest phone available. Layout under 1 second off the main thread and 95th-percentile frame time under 16 ms.
5. Cold start with an encrypted database: under 3 seconds, key survives an app update, restore does not expose data.

**Paper test before any build:** read the spoken chain aloud to three to five relatives, older and younger, in English (Luo is a later test, since the first release is English only), and ask "is that how you say it?" Then show Winyo's four houses and ask for Manyi's full brother.

**Milestones:** M1 local data and claims with a read-only tree at scale. M2 auth, server view, sync for one family. M3 invites with typed-code fallback. M4 quiet links and the hide setting. M5 merge, undo, disputes with responses. **Gate: the data-protection and legal review, before any real family data beyond the founder's own family.** M6 village pilot on real devices. Web last.

**Pilot platform (my call).** The pilot is Android only. iOS and web follow, since Flutter keeps them cheap to add. How the pilot app is distributed (Play Store, or an installed file) is unknown. An installed file has no install referrer, so the typed code is the primary invite path and links are a convenience.

## 11. Edge cases and failure modes

The UX Architect and the engineering reports produced these. They are reasoning, not sourced findings. Ranked by severity.

1. **Lineage records used as evidence in land, inheritance or clan-membership disputes.** Mitigation: no export in the MVP, no public output, no "verified" badge. When export is added it must say "as told, by whom". Any legal effect is [NEEDS SOURCE].
2. **A living person added without consent, with sensitive facts.** Mitigation: non-household viewers see minimal fields, and a person can hide their entry, use the standing hide setting, or request removal. Data-protection obligations are [NEEDS SOURCE].
3. **A quiet link leaks through a derived feature:** merge hints, dispute prompts, notification text, shared phones, error messages, or the sync filter drifting from the row rules. Mitigation: a visibility check in every derived feature, generic notifications, parity testing between the two rule sets, and spike 1.
4. **The persistent voice wins a dispute.** Mitigation: one response per person per claim, no counts or recency weighting, parties excluded, "agreed" only when all respondents agree.
5. **Fake or imposter relatives.** Mitigation: a named person confirms each invite, redemption needs confirmation, invites are limited and revocable.
6. **Children's data.** Draft: a child's name is visible only to their own household until they have an account. The age of consent is [NEEDS SOURCE].
7. **Wrong merges caused by repeated names.** Mitigation: evidence from relationships only, two-sided confirmation, undo that replays dependents.
8. **Elders' knowledge lost, or never entered because elders do not use phones.** Mitigation: assisted entry by a relative with the elder's consent and attribution, and the Questions tab leads with elders' knowledge.
9. **A family splits or a branch wants out.** Mitigation: leaving turns the person into a placeholder but keeps the shape of the links. Open question: does a house belong to the wife who heads it, the husband, or the person?
10. **A branch objects to how the tree grows.** Deferred: per-household views come later.
11. **Data custody:** a lost phone holds quiet links offline, and the operator can read everything. Mitigation: encrypted local store, an access log, plain disclosure. Registration and breach duties in Kenya are [NEEDS SOURCE].
12. **Cultural mismatch:** multiple names, naming by circumstance, nicknames, not speaking the dead's names, clan versus lineage. Mitigation: several names per person and spelling variants. Needs input from the founder's family before release.
13. **Sync bugs:** an upload that keeps failing blocks the queue, a stale offline edit conflicts, a merge is undone after children were added. Mitigation: spikes 2 and 3, and the merge, add-children, undo test.

## 12. Decisions

**Decided by the founder on 2026-11-03**
1. The server operator can read everything for the MVP, with an audit log and plain disclosure.
2. A standing "hide all quiet details about me" setting.
3. One shared set of facts, each person sees what they may see, per-household views later.
4. Disputes: discussion inside the app, or outside it with each invited person responding.
5. Each person on the system is unique, with one account per person.
6. A data-protection and legal review comes before the pilot.
7. The founder and Claude build it.
8. English for the first release.
9. Sign-in is email and password for the MVP.

**Read from a short reply, to confirm**
- **Invite policy.** The founder replied "keep this for now". I read that as keeping the current plan: a named living person confirms each invite, open invites are limited per person, only confirmed adults invite, and a chain of invites can be revoked. The invite depth is recorded so a degree cap can be switched on later. If the founder meant keeping the third-degree cap, the plan changes.
- **Disputes.** I turned "inside the app, or outside with each invited person responding" into the response mechanism in section 6. It is smaller than a discussion thread. Who has authority to record an outcome was not answered, and my default (all respondents agree, otherwise unresolved) avoids needing one.

**Still open, with my defaults for planning**
- Who counts as "both families" for a merge: the household heads of the two people being merged.
- Who breaks a deadlock between feuding relatives: with the response mechanism it stays "unresolved".
- How long a merge can be undone: to be set in planning.
- Children: at what age they control their own entry, defaulting to the visibility rule in section 11.
- Who inherits an account when its owner dies.
- Date and budget.

## 13. My calls (not agreed by the founder)

- The belongs-to-house change (section 4).
- Quiet-link behaviour and its defaults (section 4).
- Last write wins for low-stakes fields only, with an edit history. The two engineering reports disagree on ordering those edits. The Database Optimizer wants device clocks, clamped against server arrival time. The Mobile App Builder wants server arrival order, with device clocks for display only. I recommend arrival order. It matches the founder's own proposal of server time as the clock, and the history means no overwrite is lost.
- Merge screens show each viewer their own data plus the shared evidence only. Scoring uses links visible to both.
- Custom sync over PowerSync for the MVP.
- Audiences as snapshotted sets of accounts, with no whole-family scope for quiet claims.
- Redeeming an invite needs confirmation; recovery is re-sync.
- The dispute response mechanism and its "agreed only if all agree" rule.
- No export in the MVP.
- Android-only pilot, with the typed code as the primary invite path.
- Search-before-create, the checksum on typed invite codes and the spike thresholds.
- The file location of this document.

**Decisions made while planning Milestone 1.** These fill gaps in the design. The founder can accept or change any of them.
- **A. `person.sex` is nullable.** The reason: "son of" versus "daughter of" needs it, and an unknown sex reads "child of". The table sketch in section 8 had no such field.
- **B. `house.ordinal` is nullable.** The reason: a house can exist with a known number and an unknown wife, as in "houses 1 and 3 are unknown".
- **C. A wife's membership is a `wifeOfHouse` claim, displayed "married".** `belongsToHouse` carries only the basis `bornTo` or `joined`. The reason: this keeps "child of one house" single-valued and "wife of several houses" multi-valued.
- **D. One person replacing another person's claim never supersedes it.** Both stay active and show "Accounts differ". An asserter replacing their own active claim, where `baseClaimId` equals that claim's id, supersedes it, even when other accounts' claims on the same contest key are active. The other accounts' claims stay active. The reason: this follows the anti-goal that persistence must not win by volume.
- **E. When a person's parentage is disputed or cyclic, the chain stops at that person with "accounts differ".**
- **F. In M1 a `joined` basis displays as the neutral "belongs to".** Showing the word "joined" waits for the audience rules in M4. This settles the "known tension" in section 8 for M1 only.
- **G. `person_name(person_id, name, kind)` holds spelling variants and extra names** (edge case 12). `person.name_key` is the primary display name.

## 14. Verification status

**Checked against a source I read this session**
- PowerSync's default is per-field last write wins, and its backend can customise it: [docs](https://docs.powersync.com/handling-writes/handling-update-conflicts).
- Its replication role bypasses row security, and Sync Streams decide what each client receives: [Supabase guide](https://docs.powersync.com/integration-guides/supabase-+-powersync).
- Sync Streams support subqueries, CTEs and joins on simple equality, selecting columns from one table. The page does not mention recursion: [queries](https://docs.powersync.com/sync/streams/queries).
- The PowerSync Flutter SDK exists and its web support is beta: [SDK](https://docs.powersync.com/client-sdks/reference/flutter).
- Postgres row security is default-deny, superusers and bypass roles skip it, and integrity checks bypass it with a documented risk of covert leaks: [Postgres](https://www.postgresql.org/docs/current/ddl-rowsecurity.html).
- Postgres recursive queries have a CYCLE clause (the page I read describes version 18): [Postgres](https://www.postgresql.org/docs/current/queries-with.html). SQLite supports recursive queries and documents no CYCLE clause; it handles cycles with UNION: [SQLite](https://www.sqlite.org/lang_with.html).
- Supabase advises indexing policy columns, wrapping `auth.uid()` in a select, and `security_invoker` views: [Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security).
- Drift runs on Android, iOS and web, with an Android out-of-memory caveat for complex queries: [Drift](https://drift.simonbinder.eu/platforms/).
- Firebase Dynamic Links was scheduled to shut down on 25 August 2025; the page predates that, so I confirmed the plan, not the event: [FAQ](https://firebase.google.com/support/dynamic-links-faq).
- Firebase phone sign-in is not available in all countries, has an SMS quota, and does not work on emulators: [Firebase](https://firebase.google.com/docs/auth/flutter/phone-auth).
- Android checks App Links against the website at install, and changes can take up to seven days to propagate on Android 15 and later: [Android](https://developer.android.com/training/app-links/verify-android-applinks).
- WCAG 4.5:1 for normal text and 3:1 for large text: [WCAG](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

**Verified by a run on the host machine, not on a phone (2026-11-03).** Details and limits are in [spike-results.md](spike-results.md).
- Spike 1, against a local PostgreSQL 16.15 model (not Supabase): through the app endpoints, viewer B's pull payloads, wire bytes, device tables and row counts were identical between a world with a quiet claim and a world without, and each of three leaky canaries was caught. A raw SQL role could still read row counts from `pg_stat_user_tables`.
- Spike 1: revoked rows left no bytes in the device file only with `PRAGMA secure_delete = ON`.
- Spike 2, against an in-memory fake server: on 200 seeds of 1,000 operations from three devices, no lost writes, competing accounts kept, and a direct merge then undo returned the identical view. The stricter replay differs on 2,884 of 12,822 undone pairs (spike-results.md, Finding 8).
- Spike 3, in a Dart simulation: matrix rows 1, 2, 4 and 5 and the checksum. Row 3 and every on-device cell are not run.
- Spike 5, on a Mac: the SQLite3MultipleCiphers setup with Drift (without PowerSync) produced a file with no plaintext, restore without the key fell back without throwing, and a failed key read changed nothing.

**Not verified**
- That a typical relative in the pilot has an email address they can open on their phone. The sign-in method was chosen by the founder for simplicity, not tested against the device and account mix. Phone sign-in is no longer in the MVP, so the Kenya check on it is dropped.
- That Supabase's email sign-in (verification, reset, rate limits) meets the requirements in section 9, and what it costs at pilot size.
- That PowerSync works with a Drift-managed database, its cost, and its limits on how many sync groups a user can have.
- Whether the 48dp touch target is Android's recommendation (the page I fetched did not say).
- The Android default secure-storage key (read from documentation in spike 5, not run), the `SQLite3MultipleCiphers` setup with PowerSync (not attempted; the setup with Drift alone was run on a Mac, see above), and the backup behaviour reported by the Mobile App Builder (not run on Android).
- Postgres version support for the CYCLE clause on the hosted database we would use.
- Query speed at a few thousand people, tree smoothness on weak phones, and the device mix. Spike 4 produced host proxy numbers on a Mac only; no phone has been measured.
- Everything the UX Architect said about law and data protection in Kenya. It is marked [NEEDS SOURCE] throughout and none of it is stated here as fact.
- The reported last-write-wins behaviour of Firestore, and the state of the `sql_crdt` and Couchbase Flutter packages.

**Not verified, raised by the spikes** (see [spike-results.md](spike-results.md))
- Cold start with the encrypted database on a phone, whether the key survives an Android app update, and what Android backup and restore do to the database and the key. What flutter_secure_storage returns after a restore, and the effect of its `resetOnError` default of `true`.
- The offline invite on a phone (all five matrix rows), and handling of an install referrer. Row 3 needs link handling built first.
- Whether Supabase's exposed schemas hide catalog statistics and system columns from viewers. A raw SQL role read row counts in spike 1 [NEEDS SOURCE for PostgREST exposure].
- Timing differences, concurrent writes racing a revocation, and leftover bytes in WAL mode (not tested in spike 1).
- That an unbound client id gives an existence oracle. Spike 1 reasons it but built no canary for it. The id-derivation rule is a proposal, not approved.
- The production sync estimate of 4 to 7 weeks [ESTIMATE, not measured], whether PowerSync would remove the custom-sync-only work, and the custom sync against real Postgres under concurrent transactions.
- How refused merges behave after an undo (spike 2, Finding 3b). This needs a design decision before M5.
- That the spike 4 generator's reading of "20 women who appear in two houses" is what the founder meant.
