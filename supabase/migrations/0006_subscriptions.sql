-- 0006_subscriptions.sql
--
-- The fields that are genuinely subscription-specific. Everything a subscription
-- shares with any other repeating bill — recurrence, amount, category, generation
-- — stays in recurring_bills.

create table if not exists public.subscriptions (
  -- The parent's id is the key: exactly one subscription row per recurring bill,
  -- enforced by the primary key rather than by a unique constraint bolted on.
  recurring_bill_id uuid primary key
    references public.recurring_bills (id) on delete cascade,

  -- Denormalised from the parent, on purpose. The RLS policy below is then a
  -- column comparison instead of a subquery into recurring_bills — which every
  -- read of this table would otherwise pay for, and which makes the policy harder
  -- to read and to be sure of.
  user_id uuid not null references auth.users (id) on delete cascade,

  provider  text not null check (char_length(provider) between 1 and 120),
  plan_name text check (char_length(plan_name) <= 120),

  -- Worth its own column rather than being inferred from starts_on: a trial that
  -- ends is the thing the user wants warning about.
  trial_ends_on date,

  auto_renews boolean not null default true,

  -- Where to go to cancel. Stored because finding it again is the hard part of
  -- cancelling anything.
  cancellation_url text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.subscriptions is
  '1:1 extension of recurring_bills where kind = ''subscription''.';

comment on column public.subscriptions.user_id is
  'Denormalised from recurring_bills so the RLS policy needs no join. The app is the only writer and sets both from the same source.';

create index if not exists subscriptions_owner_trial_idx
  on public.subscriptions (user_id, trial_ends_on);

drop trigger if exists subscriptions_set_updated_at on public.subscriptions;
create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

alter table public.subscriptions enable row level security;

drop policy if exists "subscriptions belong to their owner" on public.subscriptions;
create policy "subscriptions belong to their owner"
  on public.subscriptions for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.subscriptions from anon;
grant select, insert, update, delete on public.subscriptions to authenticated;
