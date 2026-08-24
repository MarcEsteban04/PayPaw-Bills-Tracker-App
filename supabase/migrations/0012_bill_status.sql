-- 0012_bill_status.sql
--
-- Bill status, computed rather than stored.
--
-- Sprint 18's checklist called for a "bill statuses" table. There is none, on
-- purpose. upcoming / due soon / overdue / partially paid / paid are all functions
-- of the due date and the payments recorded against a bill. Stored, they are wrong
-- every midnight with no write to trigger an update, and the fix is always a
-- nightly job to repair rows that a query could have derived correctly.
--
-- What IS stored is archived_at, on bills: a decision the user made, not a
-- consequence of dates.

-- ---------------------------------------------------------------------------
-- security_invoker is the whole ballgame
--
-- A Postgres view runs with its *definer's* privileges by default, which means it
-- BYPASSES row level security on the tables underneath. Without the setting
-- below, this view would happily return every user's bills to any authenticated
-- caller — and it would look like it was working perfectly.
--
-- With security_invoker, the view runs as the caller and the RLS policies on
-- bills, payments and profiles all apply.
-- ---------------------------------------------------------------------------
create or replace view public.bill_status
with (security_invoker = true) as
select
  b.id      as bill_id,
  b.user_id,
  b.due_on,
  b.amount_minor,

  coalesce(sum(p.amount_minor), 0)::bigint as paid_minor,

  -- greatest(..., 0) because overpaying is possible and negative outstanding is
  -- not a thing a user should be shown.
  greatest(b.amount_minor - coalesce(sum(p.amount_minor), 0), 0)::bigint
    as outstanding_minor,

  max(p.paid_at) as last_paid_at,

  -- "Today" in the *user's* timezone, not the server's. This is what
  -- profiles.time_zone is for: a bill due on the 1st must not read as overdue at
  -- 4pm on the 31st for someone in Manila being served by a UTC database.
  (now() at time zone pr.time_zone)::date as today,

  case
    -- Archived first: an archived bill has no urgency, whatever its date says.
    when b.archived_at is not null then 'archived'

    -- Settled, including overpaid.
    when coalesce(sum(p.amount_minor), 0) >= b.amount_minor then 'paid'

    -- Overdue outranks partially paid deliberately. A bill part-paid after its
    -- date is still money owed past the date; the partial payment is visible in
    -- paid_minor and outstanding_minor, so the UI can show both — "Overdue,
    -- ₱500 of ₱1,200 paid" — without the status having to say two things at once.
    when b.due_on < (now() at time zone pr.time_zone)::date then 'overdue'

    when coalesce(sum(p.amount_minor), 0) > 0 then 'partially_paid'

    -- The three-day "due soon" window lives HERE and only here. The client reads
    -- status from this view rather than recomputing it, so there is no second
    -- definition to drift.
    when b.due_on <= (now() at time zone pr.time_zone)::date + 3 then 'due_soon'

    else 'upcoming'
  end as status

from public.bills b
-- inner join, not left: profiles is guaranteed by the trigger in 0002, and a bill
-- whose owner has no profile would be a bug worth noticing rather than papering
-- over with a default timezone.
join public.profiles pr on pr.id = b.user_id
left join public.payments p on p.bill_id = b.id
group by b.id, b.user_id, b.due_on, b.amount_minor, b.archived_at, pr.time_zone;

comment on view public.bill_status is
  'Derived bill status and payment totals. Runs as the caller (security_invoker), so RLS on bills and payments applies.';

revoke all on public.bill_status from anon;
grant select on public.bill_status to authenticated;
