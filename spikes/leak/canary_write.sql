-- CANARY, deliberately leaky. Never use outside the canary test.
-- A plausible bug: a "helpful" pre-check on share that reads claim directly
-- and raises its own message before the generic mapping. A hidden claim then
-- falls through to the generic "rejected", while a missing claim raises
-- "claim not found". The two cases become distinguishable.

set search_path = spike, pg_temp;

create or replace function submit(op jsonb) returns jsonb
language plpgsql
security definer
set search_path = spike, pg_temp
as $$
begin
  if op->>'op' = 'share'
     and not exists (select 1 from claim where id = (op->>'claim_id')::uuid) then
    raise exception 'claim not found';
  end if;
  begin
    perform submit_inner(current_viewer(), op);
  exception when others then
    return '{"ok": false, "code": "rejected"}'::jsonb;
  end;
  return '{"ok": true}'::jsonb;
end;
$$;
