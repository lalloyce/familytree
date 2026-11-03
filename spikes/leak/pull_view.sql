-- Spike 1 pull function. Loaded after schema.sql.
--
-- pull_view(viewer, since) returns the viewer's whole payload as one jsonb
-- value. It is driven from claim_access: every claim row it emits is reached
-- by joining from the viewer's own claim_access rows, never by querying claim
-- with a filter of its own. It runs as the caller (security invoker), so the
-- row rules on claim, person and privacy_setting apply as well; both layers
-- read the same claim_access.
--
-- Payload shape (keys and arrays in a fixed order, so equal content gives
-- equal bytes):
--   cursor          text, the highest claim_access.version for this viewer
--                   (or `since` when the viewer has no rows). Moves only when
--                   this viewer's own access changes.
--   claims          claims whose access row for this viewer changed after
--                   `since` and is active, ordered by id
--   removed_claims  claim ids whose access row changed after `since` and is no
--                   longer active (revocation), ordered by id
--   persons         the full set of persons the viewer may see now, ordered by
--                   id. The client replaces its person table with this set, so
--                   a person referenced only by a revoked claim disappears.
--   me              the viewer's own privacy setting, never anyone else's
--
-- Timestamps are rendered explicitly in UTC so the session TimeZone setting
-- cannot change the bytes.

set search_path = spike, pg_temp;

create function pull_view(viewer uuid, since text) returns jsonb
language plpgsql
stable
security invoker
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
  )
  select jsonb_build_object(
    'cursor', (select coalesce(max(m.version), s)::text from mine m),
    'claims', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id,
               'kind', c.kind,
               'subject_id', c.subject_id,
               'object_id', c.object_id,
               'body', c.body,
               'asserted_by', c.asserted_by,
               'basis', c.basis,
               -- A base the viewer cannot see is withheld, not named.
               'base_claim_id', case when exists (
                                  select 1 from mine b
                                   where b.claim_id = c.base_claim_id and b.active)
                                then c.base_claim_id end,
               'status', c.status,
               'scope', c.scope,
               'created_at', to_char(c.created_at at time zone 'UTC',
                                     'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
             order by c.id)
        from changed ch
        join claim c on c.id = ch.claim_id
       where ch.active), '[]'::jsonb),
    'removed_claims', coalesce((
      select jsonb_agg(ch.claim_id order by ch.claim_id)
        from changed ch
       where not ch.active), '[]'::jsonb),
    'persons', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id,
               'is_placeholder', p.is_placeholder,
               'name_key', p.name_key,
               'created_by', p.created_by,
               'deleted_at', p.deleted_at)
             order by p.id)
        from person p
       where p.id in (select my_visible_person_ids())), '[]'::jsonb),
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

grant execute on function pull_view(uuid, text) to app_viewer;
