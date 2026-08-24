-- 0014_bill_status_with_details.sql
--
-- Adds the bill's own display columns to bill_status, so a list screen needs one
-- query instead of two.
--
-- Without this, showing a list means fetching bills and fetching statuses and
-- joining them on the client — two round trips, two loading states, and a join
-- the database is better at. A read model that carries everything one screen
-- needs is the point of having a view.
--
-- `create or replace view` allows appending columns but not reordering or
-- renaming existing ones, so the original nine keep their positions and the new
-- ones go on the end. No drop, so nothing depending on it breaks.

create or replace view public.bill_status
with (security_invoker = true) as
select
  -- The original columns, unchanged and in order.
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
    when b.archived_at is not null then 'archived'
    when coalesce(sum(p.amount_minor), 0) >= b.amount_minor then 'paid'
    when b.due_on < (now() at time zone pr.time_zone)::date then 'overdue'
    when coalesce(sum(p.amount_minor), 0) > 0 then 'partially_paid'
    when b.due_on <= (now() at time zone pr.time_zone)::date + 3 then 'due_soon'
    else 'upcoming'
  end as status,

  -- Appended: what a list row shows.
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
-- Grouping by the two primary keys is enough: Postgres knows every other column
-- of those tables is functionally dependent on them, so listing them all would be
-- noise that has to be kept in step with the select list.
group by b.id, pr.id;

comment on view public.bill_status is
  'A bill plus its derived status and payment totals — everything a list row needs, in one query. Runs as the caller (security_invoker), so RLS on bills and payments applies.';

revoke all on public.bill_status from anon;
grant select on public.bill_status to authenticated;
