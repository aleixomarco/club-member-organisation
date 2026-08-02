-- Vereinslogos: öffentliche Anzeige, Upload nur durch Vereinsadmin oder Sysadmin.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'club-logos',
  'club-logos',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "public reads club logos" on storage.objects
for select using (bucket_id = 'club-logos');

create policy "club admins upload club logos" on storage.objects
for insert to authenticated with check (
  bucket_id = 'club-logos'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin']::public.club_role[]
  )
);

create policy "club admins update club logos" on storage.objects
for update to authenticated using (
  bucket_id = 'club-logos'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin']::public.club_role[]
  )
) with check (
  bucket_id = 'club-logos'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin']::public.club_role[]
  )
);

create policy "club admins delete club logos" on storage.objects
for delete to authenticated using (
  bucket_id = 'club-logos'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin']::public.club_role[]
  )
);

create policy "club admins update club profile" on public.clubs
for update to authenticated using (
  public.has_club_role(id, array['sysadmin','vereinsadmin']::public.club_role[])
) with check (
  public.has_club_role(id, array['sysadmin','vereinsadmin']::public.club_role[])
);
