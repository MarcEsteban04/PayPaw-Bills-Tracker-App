-- 0004_categories.sql
--
-- What kind of thing a bill is. User-owned rows, plus a shared set everyone sees.

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),

  -- The one nullable ownership column in the schema. NULL means a system category
  -- that every user sees; a value means it belongs to that user. The read policy
  -- below is what makes that work, and the write policies are what stop anyone
  -- editing the shared rows.
  user_id uuid references auth.users (id) on delete cascade,

  name text not null check (char_length(name) between 1 and 40),

  -- A Material icon identifier, not an image. The app already ships the icon
  -- font, so a category list costs no network requests and no storage.
  icon_name text not null,

  -- NULL falls back to a palette colour chosen by the app.
  color_hex char(7) check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),

  sort_order int not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.categories is
  'Bill categories. user_id NULL means a system category visible to everyone.';

-- Two partial unique indexes rather than one `unique (user_id, name)`, because
-- SQL treats NULLs as distinct — so a single constraint would let the system rows
-- be duplicated indefinitely. lower(name) so "Water" and "water" collide, which
-- is what a user means by "I already have that one".
create unique index if not exists categories_owner_name_key
  on public.categories (user_id, lower(name))
  where user_id is not null;

create unique index if not exists categories_system_name_key
  on public.categories (lower(name))
  where user_id is null;

create index if not exists categories_owner_sort_idx
  on public.categories (user_id, sort_order);

drop trigger if exists categories_set_updated_at on public.categories;
create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- The shared set
--
-- Seeded here rather than created per user on sign-up. Copying thirteen rows into
-- every account would mean thirteen rows per user that are identical forever, and
-- renaming a default later would reach none of them.
--
-- Chosen for the Philippines: Meralco, Maynilad, Globe/PLDT, and utang are the
-- everyday cases, not "Utilities".
-- ---------------------------------------------------------------------------
insert into public.categories (user_id, name, icon_name, color_hex, sort_order)
select v.user_id, v.name, v.icon_name, v.color_hex, v.sort_order
from (values
  (null::uuid, 'Electricity',  'bolt',              '#F59E0B',  10),
  (null::uuid, 'Water',        'water_drop',        '#3B82F6',  20),
  (null::uuid, 'Internet',     'wifi',              '#6366F1',  30),
  (null::uuid, 'Mobile',       'smartphone',        '#8B5CF6',  40),
  (null::uuid, 'Rent',         'home',              '#16A34A',  50),
  (null::uuid, 'Subscription', 'subscriptions',     '#EC4899',  60),
  (null::uuid, 'Insurance',    'health_and_safety', '#0EA5E9',  70),
  (null::uuid, 'Loan',         'account_balance',   '#EF4444',  80),
  (null::uuid, 'Credit card',  'credit_card',       '#F97316',  90),
  (null::uuid, 'Tuition',      'school',            '#14B8A6', 100),
  (null::uuid, 'Transport',    'directions_bus',    '#64748B', 110),
  (null::uuid, 'Groceries',    'shopping_basket',   '#84CC16', 120),
  (null::uuid, 'Other',        'more_horiz',        '#94A3B8', 999)
) as v(user_id, name, icon_name, color_hex, sort_order)
where not exists (
  select 1 from public.categories c
  where c.user_id is null and lower(c.name) = lower(v.name)
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.categories enable row level security;

drop policy if exists "categories: read own and system" on public.categories;
create policy "categories: read own and system"
  on public.categories for select
  using (user_id is null or user_id = auth.uid());

-- Insert, update and delete are separate policies rather than one `for all`,
-- because the read rule is genuinely different from the write rule. A `for all`
-- policy with `using (user_id is null or ...)` would let anyone edit the shared
-- rows for everybody.
drop policy if exists "categories: create own" on public.categories;
create policy "categories: create own"
  on public.categories for insert
  with check (user_id = auth.uid());

drop policy if exists "categories: edit own" on public.categories;
create policy "categories: edit own"
  on public.categories for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "categories: delete own" on public.categories;
create policy "categories: delete own"
  on public.categories for delete
  using (user_id = auth.uid());

revoke all on public.categories from anon;
grant select, insert, update, delete on public.categories to authenticated;
