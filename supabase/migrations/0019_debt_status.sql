-- 0019_debt_status.sql
--
-- A debt plus what has been repaid against it, in one query.
--
-- The sibling of `bill_status`, and it exists for the same reason: nothing
-- stores how much of a debt is left. `payments` holds the repayments and the
-- remainder is a subtraction, so any client computing it would be a second
-- definition of "outstanding" — and the day the two disagree is the day
-- somebody is told they still owe money they have already paid back.
--
-- ## Why a view and not a column
--
-- A stored balance has to be maintained by every write that touches a payment,
-- including the ones that have not been written yet. A view is derived on read
-- and cannot go stale. `bills` made this choice in 0012 and nothing since has
-- regretted it.
--
-- ## What it deliberately does not do
--
-- **It does not settle a debt.** `settled_at` stays something the user sets,
-- even when the payments already sum to the principal. Utang is not arithmetic:
-- somebody may round the last hundred pesos off, or agree the rest is a gift,
-- or accept a repayment in kind — and a view that flipped the flag on its own
-- would overrule all three. `is_fully_repaid` says what the numbers say; the
-- flag says what the two people agreed. Both are exposed, and they can disagree.

create or replace view public.debt_status
with (security_invoker = true) as
select
  d.id      as debt_id,
  d.user_id,
  d.direction,
  d.counterparty_name,
  d.counterparty_contact,
  d.principal_minor,
  d.currency,
  coalesce(sum(p.amount_minor), 0)::bigint as repaid_minor,
  -- Clamped at zero. An overpayment is a real thing — somebody hands over a
  -- round number and waves off the change — and a negative remainder would
  -- render as "-₱50 left", which is not a sentence anybody can act on.
  greatest(d.principal_minor - coalesce(sum(p.amount_minor), 0), 0)::bigint
    as outstanding_minor,
  max(p.paid_at) as last_paid_at,
  count(p.id)::int as payment_count,

  -- The arithmetic answer, distinct from `settled_at`. See the note above.
  (coalesce(sum(p.amount_minor), 0) >= d.principal_minor) as is_fully_repaid,

  -- Today in the owner's own zone, so a client never has to decide what "today"
  -- means for somebody else's timezone. Same as `bill_status`.
  (now() at time zone pr.time_zone)::date as today,

  d.incurred_on,
  d.due_on,
  d.notes,
  d.settled_at,
  d.created_at,
  d.updated_at

from public.debts d
join public.profiles pr on pr.id = d.user_id
left join public.payments p on p.debt_id = d.id
-- Grouping by the two primary keys is enough: Postgres knows every other column
-- of those tables is functionally dependent on them, so listing them all would
-- be noise that has to be kept in step with the select list.
group by d.id, pr.id;

comment on view public.debt_status is
  'A debt plus its repayment totals — everything a list row needs, in one query. Runs as the caller (security_invoker), so RLS on debts and payments applies. Does not settle anything: settled_at stays the user''s to set.';

revoke all on public.debt_status from anon;
grant select on public.debt_status to authenticated;
