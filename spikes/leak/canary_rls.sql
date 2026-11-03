-- CANARY, deliberately leaky. Never use outside the canary test.
-- A plausible bug: the person row rule is loosened to "everyone can read
-- persons". The pull is untouched, so only the direct table read leaks.

set search_path = spike, pg_temp;

drop policy person_read on person;
create policy person_read on person for select to app_viewer using (true);
