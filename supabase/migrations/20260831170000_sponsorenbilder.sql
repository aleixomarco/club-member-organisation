-- Bilder für Vereinssponsoren.
--
-- Eigener Eimer, nicht der der Vereinslogos: Logos darf nur der Vereinsadmin
-- austauschen, Sponsorenbilder auch der Sponsorenmanager. Läge beides
-- zusammen, müsste eine der beiden Rollen mehr dürfen, als sie soll.
--
-- Öffentlich lesbar, weil die Bilder ohnehin jedem Mitglied angezeigt werden
-- und ein signierter Link bei jedem Laden neu erzeugt werden müsste. Der
-- Dateiname enthält die Vereins-Kennung als Ordner — daran hängen die Rechte.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'sponsor-bilder',
  'sponsor-bilder',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "public reads sponsor images" on storage.objects
for select using (bucket_id = 'sponsor-bilder');

create policy "sponsor managers upload sponsor images" on storage.objects
for insert to authenticated with check (
  bucket_id = 'sponsor-bilder'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin','geschaeftsfuehrung','vorstand','sponsorenmanager']::public.club_role[]
  )
);

create policy "sponsor managers replace sponsor images" on storage.objects
for update to authenticated using (
  bucket_id = 'sponsor-bilder'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin','geschaeftsfuehrung','vorstand','sponsorenmanager']::public.club_role[]
  )
) with check (
  bucket_id = 'sponsor-bilder'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin','geschaeftsfuehrung','vorstand','sponsorenmanager']::public.club_role[]
  )
);

create policy "sponsor managers delete sponsor images" on storage.objects
for delete to authenticated using (
  bucket_id = 'sponsor-bilder'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['sysadmin','vereinsadmin','geschaeftsfuehrung','vorstand','sponsorenmanager']::public.club_role[]
  )
);
