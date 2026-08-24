-- 0003_reminder_preferences.sql
--
-- How far ahead a user wants to be warned, and at what time of day.
--
-- Notifications are *delivered* on the device by flutter_local_notifications.
-- These are the rules behind them, in the database, so they survive a reinstall
-- and follow the user to a second device. A reminder that exists only in one
-- device's scheduler is a reminder that silently disappears.

create table if not exists public.reminder_preferences (
  -- One row per user, so the user id IS the key.
  user_id uuid primary key references auth.users (id) on delete cascade,

  -- Days before the due date to warn. {3,1,0} means three days out, the day
  -- before, and on the day. An array rather than three boolean columns because
  -- "which offsets" is a set, and a set in columns cannot grow without a
  -- migration.
  days_before int[] not null default '{3,1,0}'::int[]
    check (array_length(days_before, 1) between 1 and 5),

  -- A plain `time`, interpreted in profiles.time_zone. Storing it as timestamptz
  -- would be nonsense: 9am is not an instant, it is a time of day that recurs.
  time_of_day time not null default '09:00',

  is_enabled boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.reminder_preferences is
  'Per-user reminder defaults. A missing row means the column defaults apply.';

comment on column public.reminder_preferences.days_before is
  'Offsets in days before the due date. Values must be 0-60, enforced by the app: a CHECK constraint cannot contain the subquery that validating array elements would need.';

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------
drop trigger if exists reminder_preferences_set_updated_at
  on public.reminder_preferences;
create trigger reminder_preferences_set_updated_at
  before update on public.reminder_preferences
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- No row is created up front, and that is the design
--
-- Unlike profiles, there is no trigger seeding this table. A user who has never
-- opened reminder settings has no row, and the app reads that absence as "use the
-- defaults" — which are the column defaults above, in one place.
--
-- The alternative, seeding a row per signup, means a table full of rows identical
-- to their own defaults, and two places that define what the default is.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.reminder_preferences enable row level security;

drop policy if exists "reminder preferences belong to their owner"
  on public.reminder_preferences;
create policy "reminder preferences belong to their owner"
  on public.reminder_preferences for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- `for all` here, unlike profiles: the client legitimately inserts this row the
-- first time the user changes a setting. `with check` is what stops it inserting
-- one that belongs to somebody else — `using` alone would allow writing a row and
-- then losing sight of it.

revoke all on public.reminder_preferences from anon;
grant select, insert, update, delete on public.reminder_preferences to authenticated;
