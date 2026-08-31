-- Drei Funktionen, die die App ruft und die es nicht gibt.
--
-- Beim Abgleich der App gegen die Migrationen kamen 16 Funktionen zum
-- Vorschein, die nur in der Produktivdatenbank standen. Bei dreien war es
-- schlimmer: Es gibt sie auch dort nicht.
--
--   update_news_post    Eine bestehende News ändern
--   update_club_team    Eine Mannschaft umbenennen
--   archive_club_team   Eine Mannschaft archivieren
--
-- Alle drei Aufrufe laufen ins Leere, und der Nutzer bekommt "Die News konnte
-- nicht geändert werden" bzw. "Die Mannschaft konnte nicht geändert werden" zu
-- sehen — eine Fehlermeldung, die aussieht wie ein vorübergehendes Problem und
-- keines ist. Drei Funktionen der App, die schlicht nichts tun.
--
-- Sie sind den vorhandenen Geschwistern nachgebildet: create_news_post und
-- delete_news_post für die Rechte an News, create_club_team für die an
-- Mannschaften.

/* Eine News ändern.
 *
 * Rückgabe ist der ERSETZTE Bildpfad, falls ein neues Bild hochgeladen wurde -
 * die App löscht die alte Datei danach aus dem Speicher. Wird kein neues Bild
 * mitgegeben, bleibt das alte stehen und es kommt null zurück. */
create or replace function public.update_news_post(
  target_post uuid,
  new_title text,
  new_body text,
  new_image_path text default null
)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  post_club uuid;
  altes_bild text;
begin
  select club_id, image_path into post_club, altes_bild
    from public.news_posts where id = target_post;

  if post_club is null then raise exception 'Post not found'; end if;
  if auth.uid() is null or not public.has_club_role(
    post_club,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]
  ) then raise exception 'Not authorized'; end if;

  if nullif(trim(new_title), '') is null or nullif(trim(new_body), '') is null then
    raise exception 'Title and body are required';
  end if;
  -- Derselbe Riegel wie beim Anlegen: Der Bildpfad muss im Ordner dieses
  -- Vereins liegen, sonst liesse sich ein fremdes Bild einhaengen.
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

/* Eine Mannschaft umbenennen.
 *
 * Die Meldung "already exists" ist woertlich gemeint: Die Oberflaeche sucht
 * genau danach, um "Diese Mannschaft ist bereits vorhanden" anzuzeigen statt
 * einer Datenbankmeldung. */
create or replace function public.update_club_team(
  target_club uuid,
  target_team uuid,
  new_name text,
  new_category text default null
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  sauber text := nullif(trim(new_name), '');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.has_club_role(target_club, array['sysadmin','vereinsadmin']::public.club_role[]) then
    raise exception 'Club administrator role required';
  end if;
  if sauber is null then raise exception 'Team name required'; end if;
  if char_length(sauber) > 80 then raise exception 'Team name too long'; end if;
  if not exists (select 1 from public.teams t where t.id = target_team and t.club_id = target_club) then
    raise exception 'Team not found';
  end if;
  if exists (select 1 from public.teams t
              where t.club_id = target_club and t.name = sauber and t.id <> target_team) then
    raise exception 'Team already exists';
  end if;

  update public.teams
     set name = sauber, category = nullif(trim(new_category), '')
   where id = target_team and club_id = target_club;
end;
$$;

/* Eine Mannschaft archivieren.
 *
 * Nicht loeschen: Termine, Aufgaben und Strafen haengen daran, und die
 * Vergangenheit eines Vereins soll nicht verschwinden, weil eine Mannschaft
 * aufgeloest wird. Archiviert heisst: aus allen Auswahllisten heraus
 * (teams.active = false), Historie bleibt. */
create or replace function public.archive_club_team(target_club uuid, target_team uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.has_club_role(target_club, array['sysadmin','vereinsadmin']::public.club_role[]) then
    raise exception 'Club administrator role required';
  end if;
  if not exists (select 1 from public.teams t where t.id = target_team and t.club_id = target_club) then
    raise exception 'Team not found';
  end if;

  update public.teams set active = false where id = target_team and club_id = target_club;
end;
$$;

revoke all on function public.update_news_post(uuid, text, text, text) from public;
revoke all on function public.update_club_team(uuid, uuid, text, text) from public;
revoke all on function public.archive_club_team(uuid, uuid) from public;
grant execute on function public.update_news_post(uuid, text, text, text) to authenticated;
grant execute on function public.update_club_team(uuid, uuid, text, text) to authenticated;
grant execute on function public.archive_club_team(uuid, uuid) to authenticated;
