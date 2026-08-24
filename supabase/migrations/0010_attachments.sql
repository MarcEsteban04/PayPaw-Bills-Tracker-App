-- 0010_attachments.sql
--
-- Metadata for receipt files. The files themselves live in Supabase Storage.

create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,

  bill_id    uuid references public.bills (id) on delete cascade,
  payment_id uuid references public.payments (id) on delete cascade,

  -- The path in the storage bucket, unique so the same object cannot be recorded
  -- twice.
  storage_path text not null unique,

  -- What the user recognises. The storage path is a uuid, which is unhelpful in a
  -- list of three receipts.
  file_name text not null check (char_length(file_name) between 1 and 255),
  mime_type text not null check (char_length(mime_type) <= 120),

  -- 25 MB. A receipt is a photo, not a video; a cap here is cheaper than
  -- discovering the storage bill later.
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 26214400),

  created_at timestamptz not null default now(),

  -- Attached to something. A row pointing at neither is orphaned metadata for a
  -- file nothing can reach.
  constraint attachments_has_target
    check (num_nonnulls(bill_id, payment_id) >= 1),

  -- The path convention, enforced rather than documented.
  --
  -- Storage RLS matches on the first path segment, so a path that does not begin
  -- with the owner's id cannot be secured — and the failure is silent: the row
  -- looks fine and the file is readable by the wrong person. A CHECK is the only
  -- place this can be guaranteed.
  --
  --   {user_id}/bills/{bill_id}/{uuid}.{ext}
  constraint attachments_path_is_owner_scoped
    check (storage_path like user_id::text || '/%')
);

comment on table public.attachments is
  'Metadata only. Files live in Supabase Storage; deleting a row does NOT delete the object.';

-- Deleting a row leaves the Storage object behind. That is not an oversight —
-- Postgres cannot reach into Storage — but it does mean the app must delete the
-- object first and the row second, so a failure leaves a reachable file rather
-- than an unreachable one. A scheduled sweep for orphans belongs with the
-- attachments feature in Sprints 57-59.

create index if not exists attachments_bill_idx on public.attachments (bill_id);
create index if not exists attachments_payment_idx
  on public.attachments (payment_id);

alter table public.attachments enable row level security;

drop policy if exists "attachments belong to their owner" on public.attachments;
create policy "attachments belong to their owner"
  on public.attachments for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

revoke all on public.attachments from anon;
grant select, insert, update, delete on public.attachments to authenticated;
