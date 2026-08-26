-- 0018_avatar_storage.sql
--
-- The bucket profile pictures go in, and the policies that keep them private.
--
-- ## Private, not public
--
-- Profile pictures are public in most apps because most apps show them to other
-- people. PayPaw shows yours to you. A public bucket would put a photograph of
-- somebody's face behind a guessable URL for no benefit at all, so this follows
-- migration 0013's stance: private, read by policy, reached through a signed URL
-- the app mints when it needs one.
--
-- The cost is that `profiles.avatar_url` holds a **path**, not a URL. A stored
-- URL would carry an expiring token, which is a value that stops working while
-- sitting in a column. The name is 0002's and is left alone rather than churning
-- a migration over it.
--
-- ## One object per account
--
-- The path is `{user_id}/avatar` with no extension. Uploading with `upsert`
-- replaces it, so changing a picture never leaves the old one behind and there
-- is nothing to garbage-collect. The MIME type is carried by the object's
-- content type, which is what `allowed_mime_types` checks — an extension would
-- be decoration that could disagree with it.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,                                  -- private. Access is by policy only.
  -- 2 MB. The client downscales to 512px before uploading, which lands well
  -- under this; the limit is here to stop a bug or a hand-crafted request
  -- filling the bucket, not to constrain the feature.
  2097152,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public             = false,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Policies
--
-- Same shape as 0013's: `storage.foldername(name)[1]` is the first path segment,
-- and our convention puts the owner's id there. That is what makes "only the
-- owner may touch this object" expressible at all.
--
-- `to authenticated` on every one. Without it a policy also applies to the anon
-- role, where auth.uid() is null and the comparison fails by accident rather
-- than by design.
-- ---------------------------------------------------------------------------

drop policy if exists "avatars: read own" on storage.objects;
create policy "avatars: read own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars: upload own" on storage.objects;
create policy "avatars: upload own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Needed as well as insert: an upsert over an object that already exists is an
-- update, and without this a second upload fails where the first succeeded.
drop policy if exists "avatars: replace own" on storage.objects;
create policy "avatars: replace own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars: delete own" on storage.objects;
create policy "avatars: delete own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
