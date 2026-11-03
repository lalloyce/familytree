-- Spike 1 schema: person, account, claim, claim_audience, claim_access,
-- privacy_setting, plus the derived-access refresh and the single write entry
-- point. Loaded into a fresh schema "spike" for every world the test builds.
--
-- Rules this file enforces (design section 8):
--   * Every key is a client-generated UUID. No sequences, no serial columns.
--   * claim_access is the single source of truth for visibility. The row
--     rules on claim read only claim_access; pull_view (pull_view.sql) reads
--     the same table.
--   * One write entry point, submit(op jsonb), maps every failure to the same
--     generic response.
--   * A person row is visible only if a visible claim references it (or the
--     viewer created it, or it is the viewer's own person).

set search_path = spike, pg_temp;

-- The viewer identity. In M2 this becomes auth.uid(); here the test sets it
-- per session with set_config('app.viewer', <uuid>, false).
create function current_viewer() returns uuid
language sql stable
as $$ select nullif(current_setting('app.viewer', true), '')::uuid $$;

-- A client-generated id is bound to its writer: id = first 16 bytes of
-- sha256(account || ':' || nonce). The client picks a random nonce. The server
-- recomputes the id, so a writer can never insert a row whose id collides with
-- someone else's row, and an insert with a forged id is refused before any
-- table is read. That removes the insert-collision existence oracle.
create function derive_id(account uuid, nonce text) returns uuid
language sql immutable strict
as $$
  select encode(substring(sha256(convert_to(account::text || ':' || nonce, 'UTF8')) from 1 for 16), 'hex')::uuid
$$;

create table person (
  id             uuid primary key,
  is_placeholder boolean not null default false,
  name_key       text not null,
  created_by     uuid not null,
  deleted_at     timestamptz
);

-- Spike-only: an account and the person it belongs to. Not in the design's
-- sketch, needed to resolve "my own privacy setting" and the account audience.
create table account (
  id        uuid primary key,
  person_id uuid not null unique references person(id)
);

create table claim (
  id            uuid primary key,
  kind          text not null check (kind in
                  ('child_of', 'belongs_to_house', 'wife_of_house',
                   'sire', 'joined_via', 'origin_note', 'same_person')),
  subject_id    uuid not null references person(id),
  object_id     uuid references person(id),
  body          text,
  asserted_by   uuid not null references account(id),
  basis         text,
  base_claim_id uuid references claim(id),
  status        text not null default 'active',
  scope         text not null check (scope in ('family', 'audience')),
  created_at    timestamptz not null,
  -- Quiet kinds have no "whole family" scope.
  check (kind not in ('sire', 'joined_via', 'origin_note') or scope = 'audience')
);

-- Snapshot of who may see an audience-scoped claim, taken when shared.
create table claim_audience (
  claim_id   uuid not null references claim(id),
  account_id uuid not null references account(id),
  primary key (claim_id, account_id)
);

-- Derived. Single source of truth for visibility.
-- active  = the account may see the claim now.
-- version = per-account change counter. It moves only when this account's own
--           access changes, so it carries no information about anyone else's
--           claims. It is not a key and not a sequence object.
create table claim_access (
  account_id uuid not null references account(id),
  claim_id   uuid not null references claim(id),
  active     boolean not null,
  version    bigint not null,
  primary key (account_id, claim_id)
);

create table privacy_setting (
  person_id          uuid primary key references person(id),
  hide_quiet_details boolean not null
);

create function is_quiet(kind text) returns boolean
language sql immutable
as $$ select kind in ('sire', 'joined_via', 'origin_note') $$;

-- Persons account v may see. Reads claim only through claim_access.
-- Internal: not callable by app_viewer (revoked below), because it would let
-- a viewer ask about another account.
create function visible_person_ids_for(v uuid) returns setof uuid
language sql stable
as $$
  select c.subject_id
    from claim_access a join claim c on c.id = a.claim_id
   where a.account_id = v and a.active
  union
  select c.object_id
    from claim_access a join claim c on c.id = a.claim_id
   where a.account_id = v and a.active and c.object_id is not null
  union
  select p.id from person p where p.created_by = v
  union
  select ac.person_id from account ac where ac.id = v
$$;

-- The same set for the current viewer only. Security definer so the person
-- row rule can call it without recursing into itself (the set reads person).
-- It takes no argument, so a viewer can ask only about themselves.
create function my_visible_person_ids() returns setof uuid
language sql stable
security definer
set search_path = spike, pg_temp
as $$
  select * from visible_person_ids_for(current_viewer())
$$;

-- Recompute claim_access from claims, audiences and privacy settings, and
-- write only the differences. Each changed (account, claim) pair gets that
-- account's next version number.
--   family scope   -> every account (spike: all accounts are connected by invites)
--   audience scope -> the audience snapshot, plus the asserter
--   quiet claim about a person (subject or object) whose hide_quiet_details is
--   on -> the asserter only
create function refresh_claim_access() returns void
language plpgsql
as $$
begin
  with desired as (
    select ac.id as account_id, c.id as claim_id
      from claim c cross join account ac
     where c.scope = 'family'
    union
    select au.account_id, au.claim_id from claim_audience au
    union
    select c.asserted_by, c.id from claim c
  ),
  hidden as (
    select c.id as claim_id, c.asserted_by
      from claim c
     where is_quiet(c.kind)
       and exists (select 1 from privacy_setting ps
                    where ps.hide_quiet_details
                      and ps.person_id in (c.subject_id, c.object_id))
  ),
  wanted as (
    select d.* from desired d
     where not exists (select 1 from hidden h
                        where h.claim_id = d.claim_id
                          and h.asserted_by <> d.account_id)
  ),
  changes as (
    select w.account_id, w.claim_id, true as active
      from wanted w
      left join claim_access a using (account_id, claim_id)
     where a.account_id is null or not a.active
    union all
    select a.account_id, a.claim_id, false
      from claim_access a
     where a.active
       and not exists (select 1 from wanted w
                        where w.account_id = a.account_id and w.claim_id = a.claim_id)
  ),
  numbered as (
    select ch.account_id, ch.claim_id, ch.active,
           coalesce((select max(x.version) from claim_access x
                      where x.account_id = ch.account_id), 0)
           + row_number() over (partition by ch.account_id order by ch.claim_id) as version
      from changes ch
  )
  insert into claim_access (account_id, claim_id, active, version)
  select account_id, claim_id, active, version from numbered
  on conflict (account_id, claim_id)
  do update set active = excluded.active, version = excluded.version;
end;
$$;

-- The write logic. Every refusal raises; submit() turns every raise into the
-- same generic response. Order of checks does not depend on hidden rows: a
-- check that reads a table reads it only through what the writer can see.
create function submit_inner(v uuid, op jsonb) returns void
language plpgsql
as $$
declare
  kind text;
  cid uuid;
  sid uuid;
  oid_ uuid;
  base uuid;
begin
  if v is null or not exists (select 1 from account where id = v) then
    raise exception 'rejected';
  end if;

  case op->>'op'
  when 'person' then
    if (op->>'id')::uuid is distinct from derive_id(v, op->>'nonce') then
      raise exception 'rejected';
    end if;
    insert into person (id, is_placeholder, name_key, created_by)
    values ((op->>'id')::uuid, coalesce((op->>'is_placeholder')::boolean, false),
            op->>'name_key', v)
    on conflict (id) do nothing;   -- id is bound to v: a conflict is v's own retry

  when 'claim' then
    cid := (op->>'id')::uuid;
    if cid is distinct from derive_id(v, op->>'nonce') then
      raise exception 'rejected';
    end if;
    kind := op->>'kind';
    sid := (op->>'subject_id')::uuid;
    oid_ := (op->>'object_id')::uuid;
    base := (op->>'base_claim_id')::uuid;
    if sid is null or sid not in (select visible_person_ids_for(v)) then
      raise exception 'rejected';
    end if;
    if oid_ is not null and oid_ not in (select visible_person_ids_for(v)) then
      raise exception 'rejected';
    end if;
    if base is not null and not exists (
         select 1 from claim_access a
          where a.account_id = v and a.claim_id = base and a.active) then
      raise exception 'rejected';
    end if;
    insert into claim (id, kind, subject_id, object_id, body, asserted_by, basis,
                       base_claim_id, scope, created_at)
    values (cid, kind, sid, oid_, op->>'body', v, op->>'basis', base,
            coalesce(op->>'scope', 'family'), (op->>'created_at')::timestamptz);
    if op ? 'audience' then
      insert into claim_audience (claim_id, account_id)
      select cid, (x)::uuid from jsonb_array_elements_text(op->'audience') x;
    end if;

  when 'share' then
    -- Replace the audience snapshot. Only the asserter may do this. The lookup
    -- filters on asserted_by = v, so a hidden claim and a missing claim are the
    -- same "no row" to every other writer.
    cid := (op->>'claim_id')::uuid;
    if not exists (select 1 from claim c
                    where c.id = cid and c.asserted_by = v and c.scope = 'audience') then
      raise exception 'rejected';
    end if;
    delete from claim_audience where claim_id = cid;
    insert into claim_audience (claim_id, account_id)
    select cid, (x)::uuid from jsonb_array_elements_text(op->'audience') x;

  when 'privacy' then
    insert into privacy_setting (person_id, hide_quiet_details)
    select ac.person_id, (op->>'hide_quiet_details')::boolean
      from account ac where ac.id = v
    on conflict (person_id) do update set hide_quiet_details = excluded.hide_quiet_details;

  else
    raise exception 'rejected';
  end case;

  perform refresh_claim_access();
end;
$$;

-- The single write entry point. Every database error, of any kind, becomes
-- {"ok": false, "code": "rejected"}. The exception block runs the write in a
-- subtransaction, so a refused write leaves no partial rows.
create function submit(op jsonb) returns jsonb
language plpgsql
security definer
set search_path = spike, pg_temp
as $$
begin
  begin
    perform submit_inner(current_viewer(), op);
  exception when others then
    return '{"ok": false, "code": "rejected"}'::jsonb;
  end;
  return '{"ok": true}'::jsonb;
end;
$$;

-- Row security. app_viewer is not the table owner, so policies apply to it.
alter table person          enable row level security;
alter table account         enable row level security;
alter table claim           enable row level security;
alter table claim_audience  enable row level security;
alter table claim_access    enable row level security;
alter table privacy_setting enable row level security;

-- claim: reads claim_access only.
create policy claim_read on claim for select to app_viewer
  using (exists (select 1 from claim_access a
                  where a.claim_id = claim.id
                    and a.account_id = current_viewer()
                    and a.active));

create policy claim_access_read on claim_access for select to app_viewer
  using (account_id = current_viewer());

-- Only the asserter sees an audience (design flow 7: "see exactly who will see
-- it"). An audience member must not learn of a claim the hide setting removed.
create policy claim_audience_read on claim_audience for select to app_viewer
  using (exists (select 1 from claim c
                  where c.id = claim_audience.claim_id
                    and c.asserted_by = current_viewer()));

create policy person_read on person for select to app_viewer
  using (id in (select my_visible_person_ids()));

create policy account_read on account for select to app_viewer
  using (id = current_viewer());

create policy privacy_read on privacy_setting for select to app_viewer
  using (person_id = (select person_id from account where id = current_viewer()));

grant usage on schema spike to app_viewer;
grant select on person, account, claim, claim_audience, claim_access, privacy_setting
  to app_viewer;
-- No insert, update or delete grants: writes go through submit() only.
revoke all on function submit_inner(uuid, jsonb) from public;
revoke all on function visible_person_ids_for(uuid) from public;
revoke all on function refresh_claim_access() from public;
grant execute on function submit(jsonb) to app_viewer;
