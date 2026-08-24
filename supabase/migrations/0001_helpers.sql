-- 0001_helpers.sql
--
-- Shared building blocks every later migration depends on. Nothing user-facing.

-- ---------------------------------------------------------------------------
-- set_updated_at
--
-- Keeps updated_at honest. Every table with an updated_at column gets a trigger
-- calling this, because a client that forgets to set it produces audit data that
-- is quietly wrong — and the one time you need it is after something has gone
-- missing.
--
-- `set search_path = ''` is not decoration. Without it a function can be made to
-- resolve an unqualified name against a schema an attacker controls, so every
-- function in this schema pins it and fully qualifies what it touches. (now() is
-- in pg_catalog, which is always searched first.)
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Trigger function: sets updated_at to now() on every UPDATE.';
