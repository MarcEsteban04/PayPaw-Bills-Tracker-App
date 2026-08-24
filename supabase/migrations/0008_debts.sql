-- 0008_debts.sql
--
-- Utang, in both directions. Created before payments because payments reference
-- it.

create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- One table with a direction rather than two tables. The fields are identical
  -- and every query is the same shape; two tables would mean writing every debt
  -- feature twice.
  direction text not null check (direction in ('i_owe', 'owed_to_me')),

  -- Text, not a reference to a user. The person you owe money to is usually not a
  -- PayPaw user, and requiring them to be would make the feature useless.
  counterparty_name text not null
    check (char_length(counterparty_name) between 1 and 120),
  counterparty_contact text check (char_length(counterparty_contact) <= 120),

  principal_minor bigint not null check (principal_minor > 0),
  currency char(3) not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),

  incurred_on date not null,

  -- Nullable, unlike a bill's due date. Plenty of utang has no agreed date, and
  -- forcing one would mean inventing a deadline the user never agreed to.
  due_on date check (due_on is null or due_on >= incurred_on),

  notes text check (char_length(notes) <= 2000),

  -- Settled rather than deleted, the same reasoning as archiving a bill: the
  -- payments made against it are history.
  settled_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.debts is
  'Money owed, in either direction. Settled rather than deleted once repaid.';

create index if not exists debts_owner_open_idx
  on public.debts (user_id, due_on)
  where settled_at is null;

create index if not exists debts_owner_direction_idx
  on public.debts (user_id, direction, settled_at);

drop trigger if exists debts_set_updated_at on public.debts;
create trigger debts_set_updated_at
  before update on public.debts
  for each row execute function public.set_updated_at();

alter table public.debts enable row level security;

drop policy if exists "debts belong to their owner" on public.debts;
create policy "debts belong to their owner"
  on public.debts for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.debts from anon;
grant select, insert, update, delete on public.debts to authenticated;
