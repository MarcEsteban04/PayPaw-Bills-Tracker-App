-- rls_audit.sql
--
-- Run this after any migration. It either prints nothing and succeeds, or raises
-- with a list of problems.
--
-- Written to FAIL rather than to report, because a security check whose output
-- has to be read carefully is a security check that gets skimmed.

do $$
declare
  unprotected  text;
  policyless   text;
  leaky_views  text;
begin
  -- 1. Any table in public without row level security.
  --
  -- The most important line in the whole project: the publishable key is public,
  -- so a table in this schema without RLS is readable by anybody who has the key
  -- — which is anybody who has the app.
  select string_agg(c.relname, ', ' order by c.relname)
  into unprotected
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and not c.relrowsecurity;

  if unprotected is not null then
    raise exception 'Tables in public with RLS DISABLED: %', unprotected;
  end if;

  -- 2. RLS enabled but no policies at all.
  --
  -- Not dangerous — no policy means deny everything — but it means the table is
  -- unreachable, which is almost never what was intended and usually a migration
  -- that half applied.
  select string_agg(c.relname, ', ' order by c.relname)
  into policyless
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'r'
    and c.relrowsecurity
    and not exists (
      select 1 from pg_policy p where p.polrelid = c.oid
    );

  if policyless is not null then
    raise exception
      'Tables with RLS on but NO policies (unreachable): %', policyless;
  end if;

  -- 3. Views that do not run as their caller.
  --
  -- A view defaults to its definer's privileges, which means it bypasses RLS on
  -- everything underneath and cheerfully returns other users' rows while looking
  -- like it works. security_invoker=true is what stops that.
  select string_agg(c.relname, ', ' order by c.relname)
  into leaky_views
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind = 'v'
    and coalesce(
      array_to_string(c.reloptions, ','), ''
    ) not like '%security_invoker=true%';

  if leaky_views is not null then
    raise exception
      'Views without security_invoker=true (these BYPASS RLS): %', leaky_views;
  end if;

  raise notice 'RLS audit passed: every public table is protected and every view runs as its caller.';
end $$;
