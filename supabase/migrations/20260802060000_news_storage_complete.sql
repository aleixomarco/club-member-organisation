-- Vereins-News in der Datenbank, Bilder privat in Supabase Storage.

create table if not exists public.news_posts (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 180),
  body text not null check (char_length(trim(body)) between 1 and 5000),
  image_path text,
  author_id uuid not null references public.profiles(id) on delete restrict,
  author_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (image_path is null or image_path <> '')
);

create index if not exists news_posts_club_created_idx on public.news_posts(club_id, created_at desc);
alter table public.news_posts enable row level security;

create policy "club members read news posts" on public.news_posts
for select to authenticated using (public.is_club_member(club_id));

create policy "news editors create posts" on public.news_posts
for insert to authenticated with check (
  author_id = auth.uid() and public.has_club_role(
    club_id,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]
  )
);

create policy "news editors delete posts" on public.news_posts
for delete to authenticated using (
  public.has_club_role(
    club_id,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'news-images', 'news-images', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "club members read news images" on storage.objects
for select to authenticated using (
  bucket_id = 'news-images'
  and public.is_club_member(((storage.foldername(name))[1])::uuid)
);

create policy "news editors upload images" on storage.objects
for insert to authenticated with check (
  bucket_id = 'news-images'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]
  )
);

create policy "news editors delete images" on storage.objects
for delete to authenticated using (
  bucket_id = 'news-images'
  and public.has_club_role(
    ((storage.foldername(name))[1])::uuid,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]
  )
);

create or replace function public.create_news_post(
  target_club uuid,
  post_title text,
  post_body text,
  post_image_path text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  result_id uuid;
  resolved_author text;
begin
  if auth.uid() is null or not public.has_club_role(
    target_club,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]
  ) then raise exception 'Not authorized'; end if;
  if nullif(trim(post_title), '') is null or nullif(trim(post_body), '') is null then
    raise exception 'Title and body are required';
  end if;
  if post_image_path is not null and post_image_path not like target_club::text || '/%' then
    raise exception 'Invalid image path';
  end if;

  select display_name into resolved_author
  from public.club_memberships
  where club_id = target_club and profile_id = auth.uid() and status = 'active'
  limit 1;
  if resolved_author is null then raise exception 'Membership not found'; end if;

  insert into public.news_posts (club_id, title, body, image_path, author_id, author_name)
  values (target_club, trim(post_title), trim(post_body), post_image_path, auth.uid(), resolved_author)
  returning id into result_id;
  return result_id;
end;
$$;

create or replace function public.delete_news_post(target_post uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  post_club uuid;
  stored_image_path text;
begin
  select club_id, image_path into post_club, stored_image_path
  from public.news_posts where id = target_post;
  if post_club is null or auth.uid() is null or not public.has_club_role(
    post_club,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]
  ) then raise exception 'Not authorized'; end if;

  delete from public.news_posts where id = target_post;
  return stored_image_path;
end;
$$;

revoke all on function public.create_news_post(uuid, text, text, text) from public;
revoke all on function public.delete_news_post(uuid) from public;
grant execute on function public.create_news_post(uuid, text, text, text) to authenticated;
grant execute on function public.delete_news_post(uuid) to authenticated;
