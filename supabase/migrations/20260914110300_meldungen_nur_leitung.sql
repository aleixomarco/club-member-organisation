-- Meldungen nur noch fest verdrahtet und nur im eigenen Verein
-- (Betreiberentscheidung 13.09.2026, Nachrichtenregel):
-- An alle Mitglieder eines Vereins schreiben nur vereinsadmin, organisator und
-- sysadmin, und nur ueber die Vereins-News. Freitext an viele Empfaenger gibt
-- es fuer andere nicht. Zweckgebundene Meldungen bleiben (Chat im eigenen
-- Kanal, Protokolle, Tippspiel-Ergebnis, Meldungen an die Leitung) - mit
-- festen Kategorien und innerhalb des Vereins.
--
-- rollen-01  notify_club und notify_many_ziel nur noch fuer service_role; die
--            App ruft beide nicht mehr auf (Chat: nur noch der Ausloeser
--            chatnachricht_melden; Protokoll: Ausloeser unten). notify_many
--            nimmt von angemeldeten Nutzern nur feste Kategorien an und nur
--            Empfaenger aus der Vereinsleitung desselben Vereins.
-- U1         Vereins-News-Kanal: schreiben nur vereinsadmin, organisator,
--            sysadmin. News-Beitraege: organisator kommt dazu.
-- U16        Neues Protokoll: Meldung nur an die eingetragenen Teilnehmer.
--
-- Alle Rumpfe und Regeln aus PROD (pg_get_functiondef / pg_policies,
-- 14.09.2026, nur lesend). Dass die Einfuege-Regel fuer messages write_roles
-- liest, steht dort: "authorized members write messages" ... and
-- ((cardinality(c.write_roles) = 0) or has_club_role(c.club_id, c.write_roles)).
-- Braucht 20260914110200 (family_links.bestaetigt).

-- ================================================================ rollen-01: Chat
-- Bisher meldete die App jede Nachricht zusaetzlich selbst (notify_many_ziel)
-- - jede Nachricht kam doppelt an, einmal ohne Stummschaltung der Mannschaft.
-- Jetzt meldet nur noch dieser Ausloeser. Neu gegenueber PROD:
-- - Mannschaftskanal: auch Eltern mit BESTAETIGTER Verknuepfung zu einem
--   Mitglied der Mannschaft (sie lesen den Kanal ueber gehoert_zu_mannschaft).
--   Ihre Stummschaltung ist team_benachrichtigungen.aktiv, sonst an.
-- - Vereinsweiter Kanal mit Sichtbarkeitsrollen: nur, wer ihn sehen darf.
-- - Leerer Suchpfad.
create or replace function public.chatnachricht_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_club     uuid;
  v_team     uuid;
  v_sichtbar public.club_role[];
  v_wer      text;
  v_text     text;
begin
  select c.club_id, c.team_id, c.visible_roles into v_club, v_team, v_sichtbar
    from public.channels c where c.id = new.channel_id;
  if v_club is null then return new; end if;

  /* Ueber profile_id UND club_id: Dieselbe Person kann in mehreren Vereinen
     Mitglied sein, und der Name soll der aus DIESEM Verein sein. */
  select m.display_name into v_wer
    from public.club_memberships m
   where m.profile_id = new.author_id and m.club_id = v_club
   order by (m.status = 'active') desc
   limit 1;

  v_text := case when length(new.body) > 90 then left(new.body, 90) || ' …' else new.body end;

  with empfaenger as (
    select m.id, m.profile_id,
           (v_team is not null and exists (
              select 1 from public.team_members tm
               where tm.membership_id = m.id and tm.team_id = v_team)) as im_team,
           (v_team is not null and exists (
              select 1 from public.family_links f
                join public.team_members tk on tk.team_id = v_team
               where f.bestaetigt and f.club_id = v_club
                 and ((f.first_membership_id = m.id and f.first_to_second = 'eltern'
                       and tk.membership_id = f.second_membership_id)
                   or (f.second_membership_id = m.id and f.second_to_first = 'eltern'
                       and tk.membership_id = f.first_membership_id)))) as elternteil
      from public.club_memberships m
     where m.club_id = v_club and m.status = 'active' and m.profile_id is not null
       and m.profile_id is distinct from new.author_id
  )
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct e.profile_id, v_club, 'chat',
         coalesce(v_wer, public.meldungstext('chat.titel', p.language)),
         coalesce(v_wer, public.meldungstext('allg.jemand', p.language)) || ': ' || v_text,
         'chat', new.channel_id
    from empfaenger e
    left join public.profiles p on p.id = e.profile_id
   where (case
            when v_team is null then
              cardinality(coalesce(v_sichtbar, '{}'::public.club_role[])) = 0
              or exists (select 1 from public.membership_roles r
                          where r.membership_id = e.id and r.role = any(v_sichtbar))
            else
              (e.im_team and public.team_meldung_erlaubt(e.id, v_team, 'chat'))
              or (not e.im_team and e.elternteil
                  and coalesce((select tb.aktiv from public.team_benachrichtigungen tb
                                 where tb.membership_id = e.id and tb.team_id = v_team), true))
          end)
     and public.meldung_erlaubt(e.profile_id, 'chat');
  return new;
end;
$$;
-- create or replace behaelt den Ausloeser messages_melden.
-- Chat-Abstimmungen: chat_abstimmung_anlegen schreibt eine Nachricht mit
-- poll_id in messages - die meldet dieser Ausloeser; umfrage_melden laesst
-- Kanal-Abstimmungen bewusst aus. Einen zweiten Weg gibt es nicht mehr.

-- ================================================================ rollen-01: Freitext
-- Kein Aufrufer mehr in app/, lib/, app/api/ oder supabase/functions (grep
-- 14.09.2026). Zeitplan und Datenbankfunktionen laufen als Eigentuemer und
-- sind nicht betroffen.
revoke execute on function public.notify_club(uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.notify_club(uuid, text, text, text, uuid) to service_role;
revoke execute on function public.notify_many_ziel(uuid[], text, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.notify_many_ziel(uuid[], text, text, text, text, uuid) to service_role;

-- notify_many bleibt fuer notifyClubAdmins (Fahrzeugbuchung eines Mitglieds,
-- Sperren/Beenden/Entfernen durch die Leitung) - aber nur noch als "Meldung
-- an die Leitung":
--   a) feste Kategorie: 'vehicle' oder 'membership' (NOTIFICATION_OPTIONS);
--   b) der Aufrufer ist aktives Mitglied des Vereins, und jeder Empfaenger ist
--      aktiv in DEMSELBEN Verein;
--   c) jeder Empfaenger gehoert zur Leitung (vereinsadmin, sysadmin,
--      organisator) - auch wenn die Leitung selbst schreibt: Meldungen an alle
--      gehen nur ueber die Vereins-News.
-- Sonst 42501. Ohne Anmeldung (service_role) wie bisher.
-- Bisher (PROD): fremde Kennungen still uebergangen, jede Kategorie, jeder
-- Empfaenger im selben Verein.
create or replace function public.notify_many(target_memberships uuid[], p_notif_type text, p_title text, p_body text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  ziel    uuid;
  v_ziele uuid[];
  v_club  uuid;
begin
  select coalesce(array_agg(distinct z), array[]::uuid[]) into v_ziele
    from unnest(coalesce(target_memberships, array[]::uuid[])) z where z is not null;

  if auth.uid() is null then
    foreach ziel in array v_ziele loop
      perform public.notify(ziel, p_notif_type, p_title, p_body);
    end loop;
    return;
  end if;

  if p_notif_type is null or p_notif_type not in ('vehicle', 'membership') then
    raise exception 'Diese Meldungsart ist nicht erlaubt' using errcode = '42501';
  end if;
  if cardinality(v_ziele) = 0 then return; end if;

  select min(m.club_id::text)::uuid into v_club
    from public.club_memberships m where m.id = v_ziele[1];
  if v_club is null or not public.is_club_member(v_club) then
    raise exception 'Nicht im Verein' using errcode = '42501';
  end if;
  if exists (
    select 1 from unnest(v_ziele) z
     where not exists (
       select 1 from public.club_memberships m
         join public.membership_roles r on r.membership_id = m.id
        where m.id = z and m.club_id = v_club and m.status = 'active'
          and r.role in ('vereinsadmin', 'sysadmin', 'organisator'))
  ) then
    raise exception 'Empfaenger muessen zur Vereinsleitung desselben Vereins gehoeren' using errcode = '42501';
  end if;

  foreach ziel in array v_ziele loop
    perform public.notify(ziel, p_notif_type, left(p_title, 200), left(p_body, 1000));
  end loop;
end;
$$;
revoke all on function public.notify_many(uuid[], text, text, text) from public, anon;
grant execute on function public.notify_many(uuid[], text, text, text) to authenticated, service_role;

-- ================================================================ U1: Vereins-News-Kanal
-- PROD (14.09.2026): zwei vereinsweite Kanaele, beide "Vereins-News", mit
-- write_roles {redakteur,vorstand,geschaeftsfuehrung,vereinsadmin,sysadmin}.
-- Vereinsweit heisst team_id is null - nicht der Name.
update public.channels
   set write_roles = array['vereinsadmin','organisator','sysadmin']::public.club_role[]
 where team_id is null
   and write_roles is distinct from array['vereinsadmin','organisator','sysadmin']::public.club_role[];

-- Rumpf aus PROD; neu nur die Schreibrollen.
create or replace function public.kanal_fuer_neuen_verein()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.channels (club_id, name, emoji, team_id, write_roles, visible_roles)
  values (new.id, 'Vereins-News', '📣', null,
          array['vereinsadmin','organisator','sysadmin']::public.club_role[],
          '{}'::public.club_role[])
  on conflict do nothing;
  return new;
end;
$$;

-- ================================================================ U1: News-Beitraege
-- In jeder Liste kommt organisator dazu; redakteur bleibt (offene Frage an den
-- Betreiber, siehe Befundliste). Die abgeschafften Rollen stehen weiter drin
-- und sind niemandem zugewiesen (rollen-12 raeumt sie zusammen auf).
-- Bisher: "news editors create posts" INSERT to authenticated
--   with check ((author_id = auth.uid()) and has_club_role(club_id,
--     ARRAY['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']))
drop policy if exists "news editors create posts" on public.news_posts;
create policy "news editors create posts" on public.news_posts
  for insert to authenticated
  with check (author_id = (select auth.uid())
              and public.has_club_role(club_id, array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]));

-- Bisher: "news editors delete posts" DELETE to authenticated using (has_club_role(club_id, dieselbe Liste))
drop policy if exists "news editors delete posts" on public.news_posts;
create policy "news editors delete posts" on public.news_posts
  for delete to authenticated
  using (public.has_club_role(club_id, array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]));

-- Bisher: "news editors upload images" INSERT / "news editors delete images"
-- DELETE auf storage.objects, bucket news-images, Ordner = club_id, dieselbe Liste.
drop policy if exists "news editors upload images" on storage.objects;
create policy "news editors upload images" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'news-images'
              and public.has_club_role(((storage.foldername(name))[1])::uuid,
                    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]));

drop policy if exists "news editors delete images" on storage.objects;
create policy "news editors delete images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'news-images'
         and public.has_club_role(((storage.foldername(name))[1])::uuid,
               array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]));

-- Rumpfe aus PROD; neu nur organisator in der Rollenliste.
create or replace function public.create_news_post(target_club uuid, post_title text, post_body text, post_image_path text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  result_id uuid;
  resolved_author text;
begin
  if auth.uid() is null or not public.has_club_role(
    target_club,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]
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

create or replace function public.update_news_post(target_post uuid, new_title text, new_body text, new_image_path text default null)
returns text language plpgsql security definer set search_path = '' as $$
declare
  post_club uuid;
  altes_bild text;
begin
  select club_id, image_path into post_club, altes_bild
    from public.news_posts where id = target_post;

  if post_club is null then raise exception 'Post not found'; end if;
  if auth.uid() is null or not public.has_club_role(
    post_club,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]
  ) then raise exception 'Not authorized'; end if;

  if nullif(trim(new_title), '') is null or nullif(trim(new_body), '') is null then
    raise exception 'Title and body are required';
  end if;
  if new_image_path is not null and new_image_path not like post_club::text || '/%' then
    raise exception 'Invalid image path';
  end if;

  update public.news_posts
     set title = trim(new_title),
         body = trim(new_body),
         image_path = coalesce(new_image_path, image_path)
   where id = target_post;

  return case when new_image_path is not null and altes_bild is distinct from new_image_path
              then altes_bild end;
end;
$$;

create or replace function public.delete_news_post(target_post uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  post_club uuid;
  stored_image_path text;
begin
  select club_id, image_path into post_club, stored_image_path
  from public.news_posts where id = target_post;
  if post_club is null or auth.uid() is null or not public.has_club_role(
    post_club,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]
  ) then raise exception 'Not authorized'; end if;

  delete from public.news_posts where id = target_post;
  return stored_image_path;
end;
$$;

-- ================================================================ U16
-- Die App rief notify_club ohne await auf - postgrest-js schickt erst im
-- then() ab, die Meldung ging also nie raus. Mit await haette sie interne
-- Protokolltitel an den ganzen Verein geschickt. Jetzt: nur die eingetragenen
-- Teilnehmer, die im Verein aktiv sind und ein Konto haben, ohne den
-- Verfasser - fuer interne und oeffentliche Protokolle gleich. Keine Meldung an
-- alle. Ein Sprungziel gibt es nicht: Die App hat keine Protokollansicht, die
-- meldungOeffenbar oeffnen koennte.
create or replace function public.protokoll_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, new.club_id, 'protocols',
         public.meldungstext('protokoll.titel', p.language),
         public.meldungstext('protokoll.text', p.language, jsonb_build_object('titel', new.title))
    from public.club_memberships m
    left join public.profiles p on p.id = m.profile_id
   where m.id = any(coalesce(new.attendee_membership_ids, '{}'::uuid[]))
     and m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
     and m.profile_id is distinct from auth.uid()
     and public.meldung_erlaubt(m.profile_id, 'protocols');
  return new;
exception when others then
  /* Das Protokoll ist wichtiger als die Meldung darueber. */
  raise warning 'Protokollmeldung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$$;
revoke all on function public.protokoll_melden() from public, anon, authenticated;

drop trigger if exists protocols_melden on public.protocols;
create trigger protocols_melden
  after insert on public.protocols
  for each row execute function public.protokoll_melden();

insert into public.meldungstexte (schluessel, sprache, text) values
  ('protokoll.titel', 'de', 'Neues Protokoll'),
  ('protokoll.titel', 'en', 'New minutes'),
  ('protokoll.titel', 'es', 'Nueva acta'),
  ('protokoll.titel', 'pt', 'Nova ata'),
  ('protokoll.titel', 'it', 'Nuovo verbale'),
  ('protokoll.titel', 'tr', 'Yeni tutanak'),
  ('protokoll.titel', 'fr', 'Nouveau procès-verbal'),
  ('protokoll.text', 'de', 'Du stehst auf der Teilnehmerliste: {titel}'),
  ('protokoll.text', 'en', 'You are listed as an attendee: {titel}'),
  ('protokoll.text', 'es', 'Figuras en la lista de asistentes: {titel}'),
  ('protokoll.text', 'pt', 'Estás na lista de participantes: {titel}'),
  ('protokoll.text', 'it', 'Sei nell''elenco dei partecipanti: {titel}'),
  ('protokoll.text', 'tr', 'Katılımcı listesindesin: {titel}'),
  ('protokoll.text', 'fr', 'Tu figures sur la liste des participants : {titel}')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- Erwartet: vereinsweit_club = 0, freitext_offen = false, ziel_offen = false,
-- viele_ausfuehrbar = true, protokoll_ausloeser = 1, texte = 14,
-- news_schreibregel_organisator = true.
select
  (select count(*) from public.channels
    where team_id is null
      and write_roles is distinct from array['vereinsadmin','organisator','sysadmin']::public.club_role[]) as vereinsweit_club,
  has_function_privilege('authenticated', 'public.notify_club(uuid, text, text, text, uuid)', 'execute') as freitext_offen,
  has_function_privilege('authenticated', 'public.notify_many_ziel(uuid[], text, text, text, text, uuid)', 'execute') as ziel_offen,
  has_function_privilege('authenticated', 'public.notify_many(uuid[], text, text, text)', 'execute') as viele_ausfuehrbar,
  (select count(*) from pg_trigger where tgrelid = 'public.protocols'::regclass and tgname = 'protocols_melden') as protokoll_ausloeser,
  (select count(*) from public.meldungstexte where schluessel like 'protokoll.%') as texte,
  (select with_check like '%organisator%' from pg_policies
    where schemaname = 'public' and tablename = 'news_posts' and policyname = 'news editors create posts') as news_schreibregel_organisator;
