-- 0016_generate_recurring_bills.sql
--
-- Turns recurring templates into actual bills.
--
-- ## Why this runs in the database and not in the app
--
-- The point of a bills tracker is being reminded before something is due. A
-- generator that only runs when the app is opened cannot do that: a user who has
-- not opened PayPaw in three weeks has no bills to be reminded about, which is
-- exactly the user who needed reminding. Generation has to happen whether or not
-- anyone is looking.
--
-- It also makes the writer single. Two devices opening the app at once would
-- otherwise race to create the same occurrence — survivable, because of the
-- unique index below, but only by accident.
--
-- The client still calls `generate_my_recurring_bills` on open. Not as the
-- mechanism, as a safety net and a courtesy: a template created a moment ago
-- should produce its bills now rather than after tonight's run.
--
-- ## Idempotence comes from the index, not from careful code
--
-- `bills_occurrence_key` (migration 0007) is a unique index on
-- `(recurring_bill_id, due_on)`. A template can produce one occurrence per due
-- date and no more, so `on conflict do nothing` makes every path here safe to
-- run twice — the cron job, the client call, and a retry after a timeout.
--
-- ## The date arithmetic exists twice, and that is a real cost
--
-- `Recurrence.occurrenceAfter` in Dart drives the preview; `next_recurrence_date`
-- below drives generation. They have to agree, and nothing enforces it. The rule
-- both implement:
--
--   * weekly steps whole weeks, so the weekday is preserved for free;
--   * everything else steps whole months from the *month* of the current
--     occurrence, then resolves `day_of_month` against that month afresh.
--
-- Resolving afresh is what keeps 31 January → 28 February → 31 March. Carrying
-- the previous occurrence's day forward instead would give 28 March, and every
-- February would ratchet the schedule earlier until it stuck.

-- ---------------------------------------------------------------------------
-- Resolving a day of month
-- ---------------------------------------------------------------------------

-- The occurrence in the month containing p_month_start.
--
-- -1 means the last day, rather than storing 31 and hoping. Anything else is
-- clamped to the month's length, so the 31st is the 28th in February and the 31st
-- again in March.
create or replace function public.resolve_day_in_month(
  p_month_start date,
  p_day int
) returns date
language sql
immutable
set search_path = pg_catalog, pg_temp
as $$
  select case
    when p_day = -1 then
      (date_trunc('month', p_month_start) + interval '1 month' - interval '1 day')::date
    else
      (date_trunc('month', p_month_start))::date
      + least(
          p_day,
          extract(
            day from
              (date_trunc('month', p_month_start) + interval '1 month' - interval '1 day')
          )::int
        )
      - 1
  end;
$$;

comment on function public.resolve_day_in_month(date, int) is
  'The day-of-month an occurrence falls on within a given month. -1 is the last day; anything longer than the month is clamped.';

-- ---------------------------------------------------------------------------
-- Stepping to the next occurrence
-- ---------------------------------------------------------------------------

-- The occurrence after p_current, for a rule with these columns.
--
-- Takes the *current occurrence* rather than a bookmark, which is safe only
-- because the month case re-resolves `day_of_month` instead of carrying
-- p_current's own day forward. See the note at the top of this file.
--
-- `month_of_year` is not a parameter: stepping 12 months from an occurrence keeps
-- the month by construction, so passing it would be a chance to disagree with the
-- date already stored.
create or replace function public.next_recurrence_date(
  p_frequency text,
  p_interval int,
  p_day_of_month int,
  p_current date
) returns date
language sql
immutable
set search_path = public, pg_catalog, pg_temp
as $$
  select case p_frequency
    when 'weekly' then p_current + (p_interval * 7)
    else public.resolve_day_in_month(
      (
        date_trunc('month', p_current)
        + make_interval(
            months => p_interval * case p_frequency
              when 'monthly'   then 1
              when 'quarterly' then 3
              when 'yearly'    then 12
            end
          )
      )::date,
      p_day_of_month
    )
  end;
$$;

comment on function public.next_recurrence_date(text, int, int, date) is
  'The occurrence following p_current. Must agree with Recurrence.occurrenceAfter in the Flutter app.';

-- ---------------------------------------------------------------------------
-- Generation
-- ---------------------------------------------------------------------------

-- Materialises every occurrence due within p_lead_days, for one user or for all.
--
-- **Future bills, not just overdue ones.** A lead window is what makes the
-- feature visible: a monthly template created today has its first occurrence
-- weeks away, and a generator that only caught up on the past would create
-- nothing and look broken. 45 days shows next month's bill without filling the
-- list with a year of noise.
--
-- `security definer` because pg_cron runs as the job's owner and has no
-- `auth.uid()`. It is revoked from `authenticated` and `anon` — users reach it
-- only through `generate_my_recurring_bills`, which pins the id to their own.
--
-- Returns how many bills were created, so a caller can tell "nothing was due"
-- from "it did not run".
create or replace function public.generate_recurring_bills(
  p_user_id uuid default null,
  p_lead_days int default 45
) returns int
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_template public.recurring_bills%rowtype;
  v_due     date;
  v_horizon date;
  v_created int := 0;
  v_steps   int;
begin
  if p_lead_days < 0 or p_lead_days > 400 then
    raise exception 'p_lead_days must be between 0 and 400';
  end if;

  for v_template in
    select *
      from public.recurring_bills
     where is_active
       and (p_user_id is null or user_id = p_user_id)
     order by id
  loop
    -- The horizon is measured in the owner's own zone, the same way bill_status
    -- computes `today`. A user in Manila and a cron job in UTC must not disagree
    -- about which day it is.
    select ((now() at time zone coalesce(pr.time_zone, 'UTC'))::date + p_lead_days)
      into v_horizon
      from public.profiles pr
     where pr.id = v_template.user_id;

    -- No profile means no timezone and no way to be sure what "today" is there.
    -- Skipping is better than guessing UTC and generating a bill on the wrong
    -- day; the profile is created at sign-up, so this is a broken row, not a
    -- normal one.
    if v_horizon is null then
      continue;
    end if;

    v_due   := v_template.next_due_on;
    v_steps := 0;

    while v_due <= v_horizon
      and (v_template.ends_on is null or v_due <= v_template.ends_on)
      -- A bound rather than `while true`. A weekly rule over 400 days is 58
      -- occurrences; 500 is far beyond anything legitimate and stops a bad row
      -- from spinning forever.
      and v_steps < 500
    loop
      insert into public.bills (
        user_id, category_id, recurring_bill_id,
        name, payee, amount_minor, currency, due_on
      ) values (
        v_template.user_id, v_template.category_id, v_template.id,
        v_template.name, v_template.payee,
        v_template.amount_minor, v_template.currency, v_due
      )
      -- Inferring `bills_occurrence_key`, which is partial, so the predicate is
      -- part of the conflict target. This is the whole of duplicate prevention.
      on conflict (recurring_bill_id, due_on)
        where recurring_bill_id is not null
        do nothing;

      if found then
        v_created := v_created + 1;
      end if;

      v_due := public.next_recurrence_date(
        v_template.frequency,
        v_template.interval_count,
        v_template.day_of_month,
        v_due
      );
      v_steps := v_steps + 1;
    end loop;

    -- Advance the bookmark to the first occurrence *not* yet generated. Writing
    -- it once at the end rather than inside the loop keeps the whole template's
    -- work in one statement's worth of contention.
    --
    -- Past ends_on is how a finished template records that it is finished; that
    -- is what `RecurringBill.isFinished` reads.
    if v_due is distinct from v_template.next_due_on then
      update public.recurring_bills
         set next_due_on = v_due
       where id = v_template.id;
    end if;
  end loop;

  return v_created;
end;
$$;

comment on function public.generate_recurring_bills(uuid, int) is
  'Creates bills for every recurring template occurrence falling within p_lead_days. Idempotent, by bills_occurrence_key.';

-- The only door users get. Pins generation to the caller's own rows, so the
-- SECURITY DEFINER above can never be aimed at somebody else's.
create or replace function public.generate_my_recurring_bills(
  p_lead_days int default 45
) returns int
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    -- Not an authorisation check that matters — the definer function would
    -- generate for everyone, which leaks nothing and helps nobody. It is here so
    -- an unauthenticated call fails loudly instead of doing something enormous.
    raise exception 'generate_my_recurring_bills requires a signed-in user';
  end if;

  return public.generate_recurring_bills(v_user, p_lead_days);
end;
$$;

comment on function public.generate_my_recurring_bills(int) is
  'Generates the calling user''s due recurring bills. Safe to call on every app open.';

revoke all on function public.resolve_day_in_month(date, int) from anon;
revoke all on function public.next_recurrence_date(text, int, int, date) from anon;

-- The unrestricted form is for the scheduler, not for clients.
revoke all on function public.generate_recurring_bills(uuid, int) from anon, authenticated;

revoke all on function public.generate_my_recurring_bills(int) from anon;
grant execute on function public.generate_my_recurring_bills(int) to authenticated;

-- ---------------------------------------------------------------------------
-- The daily run
-- ---------------------------------------------------------------------------
--
-- Guarded, because pg_cron is an extension that has to be enabled first
-- (Supabase dashboard → Database → Extensions → pg_cron). Without it this
-- migration still applies and generation still works — it just only happens when
-- somebody opens the app, which is the thing this file exists to avoid.
--
-- **If the block below is skipped, reminders will be late for anyone who does not
-- open PayPaw regularly.** Enable pg_cron and re-run this migration.
--
-- 17:00 UTC is 01:00 in Manila: after the day has turned for the users this is
-- built for, and off the peak for everyone else.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('paypaw-generate-recurring-bills')
      where exists (
        select 1 from cron.job where jobname = 'paypaw-generate-recurring-bills'
      );

    perform cron.schedule(
      'paypaw-generate-recurring-bills',
      '0 17 * * *',
      $job$select public.generate_recurring_bills(null, 45);$job$
    );
  else
    raise notice
      'pg_cron is not enabled; recurring bills will only be generated when the app is opened.';
  end if;
end;
$$;
