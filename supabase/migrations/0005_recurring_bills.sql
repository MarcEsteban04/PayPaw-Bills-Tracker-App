-- 0005_recurring_bills.sql
--
-- The template for an obligation that repeats. Individual occurrences are rows in
-- `bills`, generated from this.

create table if not exists public.recurring_bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  -- set null, not cascade: deleting a category must never delete the bills filed
  -- under it.
  category_id uuid references public.categories (id) on delete set null,

  -- A subscription IS a recurring obligation — same recurrence, same amount, same
  -- generation. A separate table would mean a second copy of all of that, and the
  -- day the two drift is the day monthly bills work and monthly subscriptions do
  -- not. Subscription-only fields live in the extension table (0006).
  kind text not null default 'bill' check (kind in ('bill', 'subscription')),

  name  text not null check (char_length(name) between 1 and 120),
  payee text check (char_length(payee) <= 120),

  amount_minor bigint not null check (amount_minor >= 0),
  currency char(3) not null default 'PHP' check (currency ~ '^[A-Z]{3}$'),

  -- Structured columns, not an iCal RRULE string. RRULE handles every case
  -- imaginable; PayPaw's UI will offer about six, so the flexibility buys nothing
  -- and costs a parser. If a genuinely custom rule is ever needed, an `rrule`
  -- column can sit beside these and take precedence.
  frequency text not null
    check (frequency in ('weekly', 'monthly', 'quarterly', 'yearly')),

  -- "every 2 months", "every 3 weeks".
  interval_count int not null default 1 check (interval_count between 1 and 60),

  -- -1 means the last day of the month, rather than storing 31 and hoping.
  -- February exists.
  day_of_month  int check (day_of_month = -1 or day_of_month between 1 and 31),
  weekday       int check (weekday between 1 and 7),
  month_of_year int check (month_of_year between 1 and 12),

  starts_on date not null,
  ends_on   date check (ends_on is null or ends_on >= starts_on),

  -- The bookmark that makes generation idempotent: whichever occurrence is
  -- created next, and never twice.
  next_due_on date not null,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- The recurrence fields a frequency actually needs must be present. Without
  -- this, a "monthly" template with no day_of_month is storable, and the bug
  -- surfaces later as an occurrence that never generates.
  constraint recurring_bills_recurrence_shape check (
    case frequency
      when 'weekly'    then weekday is not null
      when 'monthly'   then day_of_month is not null
      when 'quarterly' then day_of_month is not null
      when 'yearly'    then day_of_month is not null and month_of_year is not null
    end
  )
);

comment on table public.recurring_bills is
  'Template for a repeating obligation. Occurrences are rows in bills.';

create index if not exists recurring_bills_owner_active_idx
  on public.recurring_bills (user_id, is_active, next_due_on);

drop trigger if exists recurring_bills_set_updated_at on public.recurring_bills;
create trigger recurring_bills_set_updated_at
  before update on public.recurring_bills
  for each row execute function public.set_updated_at();

alter table public.recurring_bills enable row level security;

drop policy if exists "recurring bills belong to their owner"
  on public.recurring_bills;
create policy "recurring bills belong to their owner"
  on public.recurring_bills for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.recurring_bills from anon;
grant select, insert, update, delete on public.recurring_bills to authenticated;
