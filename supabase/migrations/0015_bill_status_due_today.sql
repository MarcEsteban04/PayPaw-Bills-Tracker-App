-- 0015_bill_status_due_today.sql
--
-- Adds 'due_today', and moves partial payment below the dates in the precedence.
--
-- ## Why 'due_today' is its own status
--
-- 'due_soon' covered a three-day window, so a bill due this afternoon and one due
-- on Friday said exactly the same thing. Those are not the same thing: one of them
-- can still be paid on time, and after today it cannot. The list already knew —
-- every row's subtitle read "Due today" off the date — while its badge said
-- "DUE SOON" and it sat in the Due soon group. The row disagreed with itself.
--
-- ## Why partial payment moved down
--
-- The old order put 'partially_paid' above 'due_soon', so a half-paid bill due
-- tomorrow reported 'partially_paid' — it lost its date entirely and the app filed
-- it with the bills nobody has to think about this week. Money still owed
-- tomorrow is urgent whether or not something was paid against it, which is the
-- same argument that already put 'overdue' above 'partially_paid'.
--
-- Nothing is lost by demoting it. The UI does not read partial payment off the
-- status: `BillWithStatus.isPartiallyPaid` compares the paid and outstanding
-- amounts, so the progress bar and the "₱1,000.00 paid of ₱2,450.50" line keep
-- working on a bill that now reports 'due_today'. 'partially_paid' remains the
-- status for the case with no date pressure — paid something, due next month.
--
-- ## Compatibility
--
-- A build that predates this migration parses 'due_today' to null and renders it
-- as "Unknown" rather than crashing, by `BillStatus.tryParse`. A build that
-- postdates it, running against a database that has not been migrated, simply
-- never sees the value. Neither direction breaks.
--
-- `create or replace view` again: same columns, same order, only the case
-- expression changes.

create or replace view public.bill_status
with (security_invoker = true) as
select
  b.id      as bill_id,
  b.user_id,
  b.due_on,
  b.amount_minor,
  coalesce(sum(p.amount_minor), 0)::bigint as paid_minor,
  greatest(b.amount_minor - coalesce(sum(p.amount_minor), 0), 0)::bigint
    as outstanding_minor,
  max(p.paid_at) as last_paid_at,
  (now() at time zone pr.time_zone)::date as today,
  case
    -- Archived first: a bill the user put away has no urgency, whatever its date
    -- says. Settled next: a paid bill is finished even if it was paid late.
    when b.archived_at is not null then 'archived'
    when coalesce(sum(p.amount_minor), 0) >= b.amount_minor then 'paid'

    -- Then the date, most urgent first. These outrank partial payment because a
    -- date is a deadline and a part payment is a fact about the past.
    when b.due_on < (now() at time zone pr.time_zone)::date then 'overdue'
    when b.due_on = (now() at time zone pr.time_zone)::date then 'due_today'
    when b.due_on <= (now() at time zone pr.time_zone)::date + 3 then 'due_soon'

    -- Something paid, and no date pressure.
    when coalesce(sum(p.amount_minor), 0) > 0 then 'partially_paid'

    else 'upcoming'
  end as status,

  b.name,
  b.payee,
  b.category_id,
  b.currency,
  b.recurring_bill_id,
  b.notes,
  b.archived_at,
  b.created_at,
  b.updated_at

from public.bills b
join public.profiles pr on pr.id = b.user_id
left join public.payments p on p.bill_id = b.id
group by b.id, pr.id;

comment on view public.bill_status is
  'A bill plus its derived status and payment totals — everything a list row needs, in one query. Runs as the caller (security_invoker), so RLS on bills and payments applies.';

revoke all on public.bill_status from anon;
grant select on public.bill_status to authenticated;
