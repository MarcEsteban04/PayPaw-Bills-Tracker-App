-- 0009_payments.sql
--
-- Every payment, full or partial, against a bill or a debt.

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- restrict, not cascade. This constraint is what makes "archive, do not delete"
  -- real: a bill with payments cannot be removed, so the record of what was
  -- actually paid cannot vanish with it. A bill with no payments deletes fine —
  -- that is a mistake being corrected.
  bill_id uuid references public.bills (id) on delete restrict,

  -- restrict here too, for the same reason. The design document originally said
  -- cascade for debts; that was inconsistent — a repayment is history whether the
  -- thing repaid was a bill or a loan from a cousin.
  debt_id uuid references public.debts (id) on delete restrict,

  amount_minor bigint not null check (amount_minor > 0),
  currency char(3) not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),

  -- A timestamptz, unlike a due date. This genuinely happened at a moment.
  paid_at timestamptz not null default now(),

  -- Free text with a documented vocabulary rather than an enum: payment methods
  -- in the Philippines are a moving target, and an enum change is a migration.
  -- Lowercase is enforced so 'GCash' and 'gcash' cannot both accumulate.
  -- Vocabulary: gcash, maya, bank_transfer, card, cash, auto_debit, other.
  method text
    check (method is null or (method = lower(method) and char_length(method) <= 40)),

  -- The reference number from the receipt. The thing you need when a payment is
  -- disputed, and the thing nobody can find later.
  reference text check (char_length(reference) <= 120),
  note      text check (char_length(note) <= 500),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Exactly one target. Two real foreign keys plus this check, rather than a
  -- polymorphic target_type/target_id pair: text-keyed polymorphism gives up
  -- foreign keys entirely, so nothing would stop a payment pointing at a row that
  -- no longer exists, and the RLS policy stops being expressible simply.
  constraint payments_single_target check (num_nonnulls(bill_id, debt_id) = 1)
);

comment on table public.payments is
  'Payments against a bill or a debt. Partial payments need no special handling: they are simply payments that sum to less than the amount due.';

-- No is_partial column. Partial is a comparison between the sum of payments and
-- the amount due, which the bill_status view already computes — a stored flag
-- would be one more derived value waiting to go stale.

create index if not exists payments_bill_idx on public.payments (bill_id);
create index if not exists payments_debt_idx on public.payments (debt_id);

-- Payment history, newest first — the query the history screen will make.
create index if not exists payments_owner_recent_idx
  on public.payments (user_id, paid_at desc);

drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

alter table public.payments enable row level security;

drop policy if exists "payments belong to their owner" on public.payments;
create policy "payments belong to their owner"
  on public.payments for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.payments from anon;
grant select, insert, update, delete on public.payments to authenticated;
