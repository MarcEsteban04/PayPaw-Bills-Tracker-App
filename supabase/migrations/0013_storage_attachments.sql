-- 0013_storage_attachments.sql
--
-- The bucket receipts go in, and the policies that keep them private.
--
-- Ahead of Sprint 57, which builds the attachments feature, and deliberately: the
-- attachments table already exists with a CHECK enforcing the owner-scoped path,
-- and the bucket that path is designed for should exist with correct policies
-- before anyone creates one by hand. A bucket created in the dashboard defaults to
-- the settings whoever clicked chose.

-- `on conflict do update` rather than `do nothing`, so re-running this file
-- re-asserts the settings. If the bucket is ever flipped to public by hand, this
-- puts it back.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  false,                                  -- private. Access is by policy only.
  26214400,                               -- 25 MB, matching attachments.size_bytes
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'application/pdf'
  ]
)
on conflict (id) do update set
  public             = false,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Policies
--
-- storage.foldername(name) splits the object path into segments, so [1] is the
-- first folder. Our convention puts the owner's id there:
--
--   {user_id}/bills/{bill_id}/{uuid}.{ext}
--
-- which is what makes "only the owner may touch this object" expressible at all.
-- The matching CHECK on public.attachments (0010) is what stops a row ever
-- recording a path that these policies could not protect.
-- ---------------------------------------------------------------------------

drop policy if exists "attachments: read own" on storage.objects;
create policy "attachments: read own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "attachments: upload own" on storage.objects;
create policy "attachments: upload own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "attachments: replace own" on storage.objects;
create policy "attachments: replace own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "attachments: delete own" on storage.objects;
create policy "attachments: delete own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- `to authenticated` on every one of them. Without it a policy also applies to
-- the anon role, and an anonymous caller whose auth.uid() is null would be
-- compared against a path segment — which fails, but only by accident rather than
-- by design.
