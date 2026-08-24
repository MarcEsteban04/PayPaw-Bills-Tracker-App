-- 0011_bill_reminders.sql
--
-- Per-bill reminder overrides. The defaults live in reminder_preferences (0003);
-- this table exists only for the bills that differ, so the common case stores
-- nothing at all.

create table if not exists public.bill_reminders (
  -- One override per bill, so the bill id is the key.
  bill_id uuid primary key references public.bills (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,

  -- Every column nullable, and NULL means inherit. That is the whole point: an
  -- override that had to restate every setting would drift from the defaults the
  -- moment the defaults changed.
  days_before int[] check (array_length(days_before, 1) between 1 and 5),
  time_of_day time,
  is_enabled  boolean,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- A row overriding nothing is a row that should not exist.
  constraint bill_reminders_overrides_something
    check (num_nonnulls(days_before, time_of_day, is_enabled) >= 1)
);

comment on table public.bill_reminders is
  'Per-bill reminder overrides. NULL in any column means inherit from reminder_preferences.';

create index if not exists bill_reminders_owner_idx
  on public.bill_reminders (user_id);

drop trigger if exists bill_reminders_set_updated_at on public.bill_reminders;
create trigger bill_reminders_set_updated_at
  before update on public.bill_reminders
  for each row execute function public.set_updated_at();

alter table public.bill_reminders enable row level security;

drop policy if exists "bill reminders belong to their owner" on public.bill_reminders;
create policy "bill reminders belong to their owner"
  on public.bill_reminders for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.bill_reminders from anon;
grant select, insert, update, delete on public.bill_reminders to authenticated;
