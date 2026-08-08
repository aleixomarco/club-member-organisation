-- "App kennenlernen": kuratierte Kurzvideos, die zeigen, wie man bestimmte
-- Aktionen in der App ausführt. Öffentlich lesbar (Anzeige wird pro Nutzer
-- clientseitig nach Rolle gefiltert); Uploads erfolgen nicht durch Endnutzer,
-- daher keine insert/update/delete-Policy für authenticated/anon.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'howto-videos',
  'howto-videos',
  true,
  52428800,
  array['video/mp4']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "public reads howto videos" on storage.objects
for select using (bucket_id = 'howto-videos');
