-- 0002_profiles.sql
--
-- The app's own row per account.
--
-- auth.users belongs to Supabase and should not be extended directly: its columns
-- can change under us, and it is not in a schema the app should be writing to.
-- profiles is where PayPaw's own per-user data lives, keyed by the same id.

create table if not exists public.profiles (
  -- Not a fresh uuid. The profile IS the user, so it shares the id and there is
  -- never a question of which profile belongs to which account.
  id uuid primary key references auth.users (id) on delete cascade,

  display_name text check (char_length(display_name) <= 80),
  avatar_url   text,

  -- Defaults for new bills. Philippines-first, but stored rather than assumed so
  -- a user abroad is a settings change and not a migration.
  currency  char(3) not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),
  locale    text    not null default 'en_PH',

  -- Load-bearing, not decoration: "due today" and a reminder fired at 9am both
  -- depend on which day it is for THIS user, and that cannot be inferred from the
  -- device at the moment a notification is scheduled.
  time_zone text not null default 'Asia/Manila',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'PayPaw''s own per-account row. Shares its id with auth.users.';

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- A profile always exists
--
-- Created by a trigger rather than by the app. Doing it from the client means a
-- crash, a lost connection or a closed app between sign-up and profile creation
-- leaves an account with no profile — and every screen afterwards has to cope
-- with a user who half exists.
--
-- security definer because the trigger runs in the context of the sign-up, which
-- has no rights to write to public.profiles. That is exactly the case the
-- attribute is for, and it is why search_path is pinned and every name is
-- qualified.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    -- A usable starting name rather than an empty screen. The user can change it.
    nullif(split_part(coalesce(new.email, ''), '@', 1), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: accounts that were created before this migration existed. Without
-- this, anyone who signed up during Phase 3 has no profile.
insert into public.profiles (id, display_name)
select u.id, nullif(split_part(coalesce(u.email, ''), '@', 1), '')
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id);

-- ---------------------------------------------------------------------------
-- Row Level Security
--
-- In the same migration that creates the table, deliberately. The publishable
-- key is public, so a table that exists without RLS is a public table — and the
-- gap between two migrations is a window where anyone can read it.
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles are readable by their owner" on public.profiles;
create policy "profiles are readable by their owner"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles are editable by their owner" on public.profiles;
create policy "profiles are editable by their owner"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- No insert policy, and no delete policy, on purpose:
--   * inserts happen through the trigger above, so a client never needs to
--   * deleting a profile means deleting the account, which is Supabase's job
--     (the cascade from auth.users handles the row)

-- Explicit privileges rather than relying on the project's default grants. RLS
-- decides which rows; these decide whether the role may reach the table at all,
-- and being explicit means this migration behaves the same on a fresh project.
revoke all on public.profiles from anon;
grant select, update on public.profiles to authenticated;
