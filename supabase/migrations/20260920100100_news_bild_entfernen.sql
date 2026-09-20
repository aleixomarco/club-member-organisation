-- Entwurf. Zielname im Repo: supabase/migrations/20260920120000_news_bild_entfernen.sql
-- NICHT eingespielt - dieser Lauf aendert weder Repo noch Datenbank.
--
-- Bild aus einem News-Beitrag entfernen (Befund (5) der Pruefung vom 20.09.2026).
--
-- WARUM
-- update_news_post kennt heute nur zwei Faelle: "Bild behalten"
-- (new_image_path is null) und "Bild austauschen". Einen Wert fuer "Bild weg"
-- gibt es nicht, weil NULL schon "behalten" bedeutet. Ein versehentlich
-- hochgeladenes Foto - etwa von einer Person, die widerspricht - liess sich
-- deshalb nur loswerden, indem der ganze Beitrag geloescht und neu
-- geschrieben wurde; Kommentare und Verlauf gingen mit. Fuer eine
-- Loeschbitte nach DSGVO ist das die falsche Antwort.
--
-- WAS SICH AENDERT
-- Neuer Parameter bild_entfernen boolean default false. Ist er gesetzt, wird
-- image_path auf NULL gesetzt und der alte Pfad zurueckgegeben - genau wie
-- beim Austauschen, damit die App das Objekt danach aus dem Eimer
-- news-images raeumt. Neues Bild UND Entfernen zugleich ist ein Widerspruch
-- und wird abgewiesen, statt still ein frisch hochgeladenes Objekt verwaist
-- liegen zu lassen. Titel und Text bleiben unberuehrt, die Vorlagenregel
-- ebenfalls: Nur eine Aenderung an Titel oder Text loest die Vorlage.
--
-- NACHWEIS DES RUMPFS
-- Der Rumpf ist der aus PROD (pg_get_functiondef, 20.09.2026, gelesen ueber
-- `supabase db query --linked`). Er stimmt Zeile fuer Zeile mit
-- supabase/migrations/20260916100000_uebersetzung_stufe_a.sql (Zeilen 579-622)
-- ueberein; der einzige Unterschied ist eine abschliessende Leerzeile.
-- Nachweis: diff-update_news_post.txt neben dieser Datei, dazu
-- prod-update_news_post.sql und repo-update_news_post.sql.
-- Geaendert sind ausschliesslich image_path und der Rueckgabewert.
--
-- WARUM EIN DROP
-- Weil ein Parameter dazukommt, entstuende sonst eine zweite Funktion mit
-- gleichem Namen - dieselbe Lage wie bei create_recurring_events in
-- 20260914110100, wo die alte Signatur ebenfalls faellt. Aeltere Apps aus dem
-- Store rufen ohne bild_entfernen auf; PostgREST findet die Funktion
-- weiterhin, weil der neue Parameter einen Vorgabewert hat. Den
-- Schema-Zwischenspeicher zieht der DDL-Wachhund von Supabase nach - so lief
-- schon der Austausch von create_recurring_events.
--
-- RECHTE
-- Ein Drop nimmt die Rechte mit. Stand in PROD am 20.09.2026:
--   postgres=X/postgres | authenticated=X/postgres | service_role=X/postgres
-- also public und anon ohne. Genau so wird es unten wieder gesetzt.
--
-- BESTAND
-- news_posts in PROD am 20.09.2026: 18 Beitraege, davon 0 mit Bild. Die
-- Aenderung beruehrt keine vorhandenen Daten. Auf news_posts liegt nur ein
-- AFTER-INSERT-Ausloeser (news_posts_melden) - ein UPDATE erzeugt keine
-- Meldung in der Glocke.
--
-- Vorher scripts/sicherung-vor-migration.sh ausfuehren.

drop function if exists public.update_news_post(uuid, text, text, text);

create or replace function public.update_news_post(
  target_post uuid, new_title text, new_body text,
  new_image_path text default null, bild_entfernen boolean default false)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  post_club uuid;
  altes_bild text;
  -- Der Aufrufer darf den Schalter weglassen; NULL heisst "nicht entfernen".
  weg boolean := coalesce(bild_entfernen, false);
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
  /* Austauschen und Entfernen zugleich ergibt keinen Sinn - und liesse das
     gerade hochgeladene Objekt verwaist im Eimer liegen, weil der
     Rueckgabewert nur EINEN Pfad tragen kann. Die App schliesst das aus (ein
     neu gewaehltes Bild setzt den Merker zurueck); die Sperre steht hier
     trotzdem, weil die Funktion jedem angemeldeten Konto offensteht. */
  if weg and new_image_path is not null then
    raise exception 'Cannot replace and remove the image at once';
  end if;

  update public.news_posts
     set title = trim(new_title),
         body = trim(new_body),
         /* Drei Faelle statt zwei: entfernen (NULL), austauschen (neuer
            Pfad), behalten (kein Pfad angegeben). */
         image_path = case when weg then null else coalesce(new_image_path, image_path) end,
         /* Wer Titel oder Text eines Vorlagen-Beitrags (Willkommen) aendert,
            macht daraus einen normalen Beitrag - sonst zeigte die App weiter
            die uebersetzte Vorlage statt des geaenderten Textes. Nur ein
            neues Bild laesst die Vorlage stehen - und ein entferntes ebenso. */
         vorlage = case when trim(new_title) is distinct from title
                          or trim(new_body) is distinct from body then null else vorlage end,
         werte = case when trim(new_title) is distinct from title
                        or trim(new_body) is distinct from body then null else werte end
   where id = target_post;

  /* Zurueck kommt der Pfad, den niemand mehr braucht - beim Austauschen wie
     beim Entfernen. Die App loescht das Objekt danach aus news-images; ohne
     diesen Rueckgabewert bliebe es fuer immer im Speicher liegen. */
  return case
    when weg then altes_bild
    when new_image_path is not null and altes_bild is distinct from new_image_path then altes_bild
  end;
end;
$$;

revoke all on function public.update_news_post(uuid, text, text, text, boolean) from public, anon;
grant execute on function public.update_news_post(uuid, text, text, text, boolean) to authenticated, service_role;
