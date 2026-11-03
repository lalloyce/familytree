-- CANARY, deliberately leaky. Never use outside the canary test.
-- A plausible bug: pull_view runs as owner (security definer, so row rules are
-- bypassed) and "helpfully" adds every person named by any claim about a
-- person the viewer can see. That pulls in the sire named only by the hidden
-- quiet claim.

set search_path = spike, pg_temp;

create or replace function pull_view(viewer uuid, since text) returns jsonb
language plpgsql
stable
security definer
set search_path = spike, pg_temp
as $$
declare
  s bigint;
  result jsonb;
begin
  if viewer is null or viewer is distinct from current_viewer() then
    raise exception 'rejected';
  end if;
  s := coalesce(nullif(since, '')::bigint, 0);

  with mine as (
    select a.claim_id, a.active, a.version
      from claim_access a
     where a.account_id = viewer
  ),
  changed as (
    select * from mine where version > s
  ),
  seen as (
    select visible_person_ids_for(viewer) as id
  ),
  leaky_persons as (
    select id from seen
    union
    select c.object_id from claim c                -- reads claim directly: the bug
     where c.subject_id in (select id from seen) and c.object_id is not null
  )
  select jsonb_build_object(
    'cursor', (select coalesce(max(m.version), s)::text from mine m),
    'claims', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'kind', c.kind, 'subject_id', c.subject_id,
               'object_id', c.object_id, 'body', c.body,
               'asserted_by', c.asserted_by, 'basis', c.basis,
               'base_claim_id', case when exists (
                                  select 1 from mine b
                                   where b.claim_id = c.base_claim_id and b.active)
                                then c.base_claim_id end,
               'status', c.status, 'scope', c.scope,
               'created_at', to_char(c.created_at at time zone 'UTC',
                                     'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
             order by c.id)
        from changed ch join claim c on c.id = ch.claim_id
       where ch.active), '[]'::jsonb),
    'removed_claims', coalesce((
      select jsonb_agg(ch.claim_id order by ch.claim_id)
        from changed ch where not ch.active), '[]'::jsonb),
    'persons', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'is_placeholder', p.is_placeholder,
               'name_key', p.name_key, 'created_by', p.created_by,
               'deleted_at', p.deleted_at)
             order by p.id)
        from person p
       where p.id in (select id from leaky_persons)), '[]'::jsonb),
    'me', (
      select jsonb_build_object('hide_quiet_details',
                                coalesce(ps.hide_quiet_details, false))
        from account ac
        left join privacy_setting ps on ps.person_id = ac.person_id
       where ac.id = viewer)
  ) into result;

  return result;
end;
$$;
