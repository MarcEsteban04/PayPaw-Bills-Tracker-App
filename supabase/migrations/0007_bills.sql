-- 0007_bills.sql
--
-- One dated obligation. The centre of the schema: payments, attachments and
-- reminders all hang off it.

create table if not exists public.bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  category_id uuid references public.categories (id) on delete set null,

  -- set null, not cascade. A generated occurrence is history the moment it is
  -- paid, and deleting the template that produced it must not erase what the user
  -- actually paid last month.
  recurring_bill_id uuid references public.recurring_bills (id) on delete set null,

  name  text not null check (char_length(name) between 1 and 120),
  payee text check (char_length(payee) <= 120),

  amount_minor bigint not null check (amount_minor >= 0),
  currency char(3) not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),

  -- A `date`, not a timestamptz. A bill is due on a day, not at an instant;
  -- stored with a timezone, a bill due on the 1st reads as due on the 31st for
  -- someone who travels.
  due_on date not null,

  notes text check (char_length(notes) <= 2000),

  -- Archived rather than deleted. A bill with payment history cannot be removed
  -- without taking the history with it and quietly changing what the user paid,
  -- so payments hold a restrict constraint (0008) and the UI offers archive
  -- instead. A bill with no payments can still be deleted outright — that is a
  -- mistake being corrected, not history being erased.
  archived_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.bills is
  'One dated obligation. Status is derived, not stored — see the bill_status view.';

-- Generation is idempotent because of this index, not because of careful code. A
-- template can only ever produce one occurrence per due date, so a retry, a
-- double tap or two devices syncing at once cannot create duplicates.
create unique index if not exists bills_occurrence_key
  on public.bills (recurring_bill_id, due_on)
  where recurring_bill_id is not null;

-- user_id-leading, every one of them: RLS adds `user_id = auth.uid()` to every
-- query, so an index that does not start with user_id cannot be used for it.
create index if not exists bills_owner_due_idx
  on public.bills (user_id, due_on);

create index if not exists bills_owner_open_due_idx
  on public.bills (user_id, due_on)
  where archived_at is null;

create index if not exists bills_owner_category_idx
  on public.bills (user_id, category_id);

drop trigger if exists bills_set_updated_at on public.bills;
create trigger bills_set_updated_at
  before update on public.bills
  for each row execute function public.set_updated_at();

alter table public.bills enable row level security;

drop policy if exists "bills belong to their owner" on public.bills;
create policy "bills belong to their owner"
  on public.bills for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Sharing (bill_shares) will need this policy to consult a can_access_bill()
-- helper instead. That is Sprint 75's change, deliberately: owner-only RLS is one
-- obviously correct line, and fifty-five sprints of harder-to-verify policies is a
-- poor price for a feature that does not exist yet.

revoke all on public.bills from anon;
grant select, insert, update, delete on public.bills to authenticated;
