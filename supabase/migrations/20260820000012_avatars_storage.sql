-- ---------------------------------------------------------------------------
-- 0012 · Avatar storage
-- See docs/DATABASE.md §9
-- ---------------------------------------------------------------------------

-- A public bucket, deliberately. Avatars are shown to a household partner and
-- rendered by cached_network_image, and signing every request would mean a
-- round trip before a 44px circle can draw. Nothing private lives here.
--
-- "Public" governs reads only. Writes are still policy-controlled below: a
-- user can only write inside a folder named after their own id.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  2097152,  -- 2 MB. A profile photo that needs more is a photo we should have
            -- resized on the client, and an unbounded bucket is a bill.
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Object paths are '<user_id>/avatar.<ext>'. storage.foldername() returns the
-- path segments, so element 1 is the owning user's id. Every write policy
-- checks it, which is what stops one user overwriting another's face.
do $$ begin
  create policy "avatars are readable by anyone"
    on storage.objects for select
    using (bucket_id = 'avatars');
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "a user writes only their own avatar"
    on storage.objects for insert to authenticated
    with check (
      bucket_id = 'avatars'
      and (storage.foldername(name))[1] = auth.uid()::text
    );
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "a user replaces only their own avatar"
    on storage.objects for update to authenticated
    using (
      bucket_id = 'avatars'
      and (storage.foldername(name))[1] = auth.uid()::text
    );
exception when duplicate_object then null; end $$;

do $$ begin
  create policy "a user deletes only their own avatar"
    on storage.objects for delete to authenticated
    using (
      bucket_id = 'avatars'
      and (storage.foldername(name))[1] = auth.uid()::text
    );
exception when duplicate_object then null; end $$;
