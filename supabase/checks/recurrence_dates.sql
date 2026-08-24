-- recurrence_dates.sql
--
-- Run this after applying 0016_generate_recurring_bills.sql. It either prints a
-- pass count and succeeds, or raises with every disagreement.
--
-- ## Why this file exists
--
-- The recurrence arithmetic is implemented twice: `Recurrence.occurrenceAfter`
-- in Dart drives the "next three dates" preview, and `next_recurrence_date` here
-- drives generation. Nothing in either language can enforce that they agree, and
-- when they stop agreeing the symptom is bills appearing on dates the preview
-- never promised — which reads as the app inventing due dates.
--
-- **The cases below are the same cases as
-- `test/features/recurring/domain/entities/recurrence_generation_test.dart`.**
-- Change one list and the other has to change with it; that is the whole point,
-- and it is why they are written out rather than generated.
--
-- Written to FAIL rather than to report, like the other checks in this folder: a
-- correctness check whose output has to be read carefully is one that gets
-- skimmed.

do $$
declare
  v_case     record;
  v_actual   date;
  v_failures text[] := '{}';
  v_checked  int := 0;
begin
  for v_case in
    select *
    from (
      values
        -- Weekly steps whole weeks, so the weekday survives without being
        -- consulted at all.
        ('weekly',    1,  null::int, date '2026-01-05', date '2026-01-12'),
        ('weekly',    2,  null::int, date '2026-01-05', date '2026-01-19'),
        ('weekly',    2,  null::int, date '2026-12-30', date '2027-01-13'),

        -- Monthly, plain.
        ('monthly',   1,  15,        date '2026-01-15', date '2026-02-15'),
        ('monthly',   1,  15,        date '2026-12-15', date '2027-01-15'),
        ('monthly',   3,  15,        date '2026-01-15', date '2026-04-15'),

        -- Month ends. The second of these is the whole reason the day is
        -- resolved afresh: carrying 28 February forward would give 28 March, and
        -- every February would ratchet the schedule earlier until it stuck.
        ('monthly',   1,  31,        date '2026-01-31', date '2026-02-28'),
        ('monthly',   1,  31,        date '2026-02-28', date '2026-03-31'),
        ('monthly',   1,  30,        date '2026-01-30', date '2026-02-28'),
        ('monthly',   1,  -1,        date '2026-01-31', date '2026-02-28'),
        ('monthly',   1,  -1,        date '2026-02-28', date '2026-03-31'),

        -- Leap years, and the century rule that catches naive implementations.
        ('monthly',   1,  31,        date '2028-01-31', date '2028-02-29'),
        ('monthly',   1,  31,        date '2100-01-31', date '2100-02-28'),

        -- Quarterly, crossing a year and a short month at once.
        ('quarterly', 1,  10,        date '2026-02-10', date '2026-05-10'),
        ('quarterly', 1,  31,        date '2026-11-30', date '2027-02-28'),

        -- Yearly. The second recovers the 29th in the next leap year, which is
        -- only possible because the rule is stored rather than the last date
        -- used.
        ('yearly',    1,  15,        date '2026-03-15', date '2027-03-15'),
        ('yearly',    1,  29,        date '2027-02-28', date '2028-02-29'),

        -- The largest interval the column allows.
        ('monthly',   60, 5,         date '2026-01-05', date '2031-01-05')
    ) as t(frequency, interval_count, day_of_month, current_on, expected)
  loop
    v_checked := v_checked + 1;

    v_actual := public.next_recurrence_date(
      v_case.frequency,
      v_case.interval_count,
      v_case.day_of_month,
      v_case.current_on
    );

    if v_actual is distinct from v_case.expected then
      v_failures := v_failures || format(
        '%s every %s, day %s, from %s: expected %s, got %s',
        v_case.frequency,
        v_case.interval_count,
        coalesce(v_case.day_of_month::text, '-'),
        v_case.current_on,
        v_case.expected,
        coalesce(v_actual::text, 'null')
      );
    end if;
  end loop;

  if array_length(v_failures, 1) > 0 then
    raise exception
      E'next_recurrence_date disagrees with the Flutter app:\n%',
      array_to_string(v_failures, E'\n');
  end if;

  raise notice 'next_recurrence_date: % cases agree with the app', v_checked;
end;
$$;

-- ---------------------------------------------------------------------------
-- The day resolver on its own
-- ---------------------------------------------------------------------------
--
-- Exercised by every case above, but worth pinning directly: -1 is the sentinel
-- for the last day, and anything longer than the month is clamped rather than
-- rolling into the next one. A `+ interval '31 days'` implementation would pass
-- the January cases and quietly move February into March.
do $$
declare
  v_failures text[] := '{}';
begin
  if public.resolve_day_in_month(date '2026-02-01', -1) <> date '2026-02-28' then
    v_failures := v_failures || 'last day of Feb 2026';
  end if;
  if public.resolve_day_in_month(date '2028-02-01', -1) <> date '2028-02-29' then
    v_failures := v_failures || 'last day of Feb 2028 (leap)';
  end if;
  if public.resolve_day_in_month(date '2026-02-01', 31) <> date '2026-02-28' then
    v_failures := v_failures || '31st clamped into Feb 2026';
  end if;
  if public.resolve_day_in_month(date '2026-01-01', 31) <> date '2026-01-31' then
    v_failures := v_failures || '31st of a 31-day month';
  end if;
  -- Mid-month, from a date that is not the first: the function takes the month
  -- of what it is given, not the day.
  if public.resolve_day_in_month(date '2026-03-17', 5) <> date '2026-03-05' then
    v_failures := v_failures || '5th from mid-March';
  end if;

  if array_length(v_failures, 1) > 0 then
    raise exception E'resolve_day_in_month is wrong for:\n%',
      array_to_string(v_failures, E'\n');
  end if;

  raise notice 'resolve_day_in_month: 5 cases pass';
end;
$$;

-- ---------------------------------------------------------------------------
-- Time zones
-- ---------------------------------------------------------------------------
--
-- Generation measures its horizon in the *owner's* zone, the same way
-- `bill_status` computes `today`. A cron job running in UTC and a user in Manila
-- must not disagree about which day it is — the failure would be a bill
-- generated, or skipped, a day early for anyone far enough east.
--
-- Asserted as a property rather than against a fixed date, because the answer
-- depends on when this is run.
do $$
declare
  v_manila date := (now() at time zone 'Asia/Manila')::date;
  v_utc    date := (now() at time zone 'UTC')::date;
  v_la     date := (now() at time zone 'America/Los_Angeles')::date;
begin
  -- Manila is ahead of UTC, which is ahead of Los Angeles. Never behind.
  if v_manila < v_utc then
    raise exception 'Asia/Manila (%) is behind UTC (%)', v_manila, v_utc;
  end if;
  if v_utc < v_la then
    raise exception 'UTC (%) is behind America/Los_Angeles (%)', v_utc, v_la;
  end if;

  -- And the spread is at most a day, or a timezone name has stopped resolving
  -- and `at time zone` is silently returning something else.
  if v_manila - v_la > 1 then
    raise exception
      'timezone spread is % days, which means a zone name is not resolving',
      v_manila - v_la;
  end if;

  raise notice
    'time zones: Manila %, UTC %, Los Angeles % — ordered and within a day',
    v_manila, v_utc, v_la;
end;
$$;

-- ---------------------------------------------------------------------------
-- Duplicate generation
-- ---------------------------------------------------------------------------
--
-- The index is the whole of duplicate prevention, so its absence is worth
-- failing on rather than discovering when a bill appears twice.
do $$
begin
  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'bills'
      and indexname = 'bills_occurrence_key'
  ) then
    raise exception
      'bills_occurrence_key is missing; generation is no longer idempotent';
  end if;

  if not exists (
    select 1
    from pg_index i
    join pg_class c on c.oid = i.indexrelid
    where c.relname = 'bills_occurrence_key'
      and i.indisunique
  ) then
    raise exception 'bills_occurrence_key exists but is not unique';
  end if;

  raise notice 'duplicate generation: bills_occurrence_key is present and unique';
end;
$$;
