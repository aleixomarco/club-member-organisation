-- Stufe B: Glocken-Meldungen folgen einem spaeteren Sprachwechsel.
--
-- Jede uebersetzbare Meldung speichert neben title/body ihr Rezept
-- (titel_schluessel, text_schluessel, werte, sprache). meldung_rendern baut den
-- Text beim Schreiben und beim Nachuebersetzen aus demselben Code;
-- sprache_setzen ruft danach glocke_neu_rendern fuer die eigenen Meldungen.
-- Freitext (Betreiber, Chat-Inhalt, Namen) bleibt unveraendert.
--
-- Alle Schreiber sind aus ihrer PROD-Definition vom 16.09.2026 neu angelegt und
-- aendern NUR Rezept und Renderer - title/body beim INSERT bleiben gleich
-- (Gleichheit vorab in ueber 16.000 Faellen in 7 Sprachen lesend belegt).
-- Reihenfolge ist Pflicht: Kern (Spalten, Renderer, notify_uebersetzt,
-- Warteschlange) vor den Schreibern; die Teile pruefen das per DO-Waechter.

-- ================================================================ kern/kern.sql
-- Uebersetzung Stufe B, Teil KERN: Die Glocke folgt einem Sprachwechsel.
--
-- (1) user_notifications: Rezeptspalten titel_schluessel, text_schluessel,
--     werte, sprache (nullable, ohne Default). null = nie neu rendern.
-- (2) public.meldung_rendern(text, text, jsonb): einziger Renderer (beim
--     Schreiben und beim Neu-Rendern), flacht verschachtelte Werte ab und ruft
--     public.meldungstext - fuer reine Text-/Zahlwerte Byte fuer Byte wie heute.
-- (3) meldungstexte: chat.zeile in 7 Sprachen.
-- (4) notify_uebersetzt und warteschlange_in_glocke: Rumpf aus PROD
--     (pg_get_functiondef, 16.09.2026), geaendert NUR das Rezept
--     (Nachweis: diff-notify_uebersetzt.txt, diff-warteschlange_in_glocke.txt).
--     Andere Wege in notification_queue (pg_proc-Suche 16.09.2026): notify()
--     wird direkt nur von anzeige_melden, notify_club, notify_many,
--     notify_many_ziel und notify_uebersetzt aufgerufen; nur notify() schreibt
--     in notification_queue. Ohne data._rezept bleiben die vier Spalten null -
--     Titel, Text und Sprungziel entstehen dort genau wie bisher.
--     app/api/account/delete/route.ts ruft notify_uebersetzt mit benannten
--     Parametern und p_data {} - Signatur unveraendert, weiter kompatibel.
-- (5) public.glocke_neu_rendern(uuid, text, integer): nicht fuer authenticated.
-- (6) sprache_setzen: Rumpf aus PROD, danach glocke_neu_rendern im eigenen
--     Ausnahmeblock (Nachweis: diff-sprache_setzen.txt).
-- (7) Rechte: meldung_rendern wie meldungstext (postgres, service_role);
--     glocke_neu_rendern fuer niemanden ausser dem Eigentuemer.
--
-- Vorher scripts/sicherung-vor-migration.sh ausfuehren.

-- ================================================================ (1) Rezeptspalten
alter table public.user_notifications
  add column if not exists titel_schluessel text,
  add column if not exists text_schluessel  text,
  add column if not exists werte            jsonb,
  add column if not exists sprache          text;

comment on column public.user_notifications.titel_schluessel is
  'meldungstexte-Schluessel des Titels; null = Titel ist Freitext und wird nie neu gerendert (Stufe B).';
comment on column public.user_notifications.text_schluessel is
  'meldungstexte-Schluessel des Textes (ohne Vereinspraefix); null = body wird nie neu gerendert (Stufe B).';
comment on column public.user_notifications.werte is
  'Platzhalterwerte fuer public.meldung_rendern (Text/Zahl, {"t"}, {"s","w"}, {"zeit","uhrzeit"}, {"tag","jahr"}, optional "vor").';
comment on column public.user_notifications.sprache is
  'Sprache, in der title/body gerade stehen; null = kein Rezept.';

-- Lesen: authenticated hat SELECT auf der Tabelle - die neuen Spalten sind fuer
-- die eigenen Zeilen lesbar (Policy "users read own notifications"). UPDATE hat
-- authenticated nur auf read_at (20260914130000) - die Rezeptspalten sind also
-- nicht aenderbar. Kein Index noetig (user_notifications_postfach_idx).

-- ================================================================ (2) meldung_rendern
create or replace function public.meldung_rendern(p_schluessel text, p_sprache text, p_werte jsonb)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $function$
/* Einziger Renderer fuer Meldungstexte (Stufe B) - beim Schreiben UND beim
   Neu-Rendern nach einem Sprachwechsel. Er macht aus p_werte ein flaches
   Objekt aus Texten und gibt es an public.meldungstext weiter. Die
   Reihenfolge der Ersetzung (jsonb-Schluesselreihenfolge) bleibt damit exakt
   die von heute.
   Formen in p_werte:
     "Text" oder Zahl                    -> so, wie meldungstext es heute einsetzt
     {"t": "Rohtext"}                    -> nie uebersetzt
     {"s": "schluessel", "w": {...}}     -> verschachtelt, in p_sprache gerendert
     {"zeit": "ISO", "uhrzeit": true}    -> meldung_datum(timestamptz, p_sprache, uhrzeit)
     {"tag": "YYYY-MM-DD", "jahr": true} -> meldung_datum(date, p_sprache, jahr)
   Jedes Objekt darf "vor" tragen: wird nur vorangestellt, wenn der Wert nicht
   leer ist. Leerer oder fehlender Wert ergibt ''. Ein nicht lesbares Datum
   bleibt als Rohtext stehen (wie in leitung_melden); ein Objekt ohne
   bekannte Form ergibt ''. */
declare
  v_flach jsonb := '{}'::jsonb;
  v_k     text;
  v_v     jsonb;
  v_roh   text;
  v_teil  text;
begin
  if p_schluessel is null then
    return null;                       -- wie meldungstext(null, ...)
  end if;
  if p_werte is null or jsonb_typeof(p_werte) <> 'object' then
    return public.meldungstext(p_schluessel, p_sprache, p_werte);
  end if;

  for v_k, v_v in select e.key, e.value from jsonb_each(p_werte) e loop
    if jsonb_typeof(v_v) <> 'object' then
      /* Text, Zahl, true/false, Liste, null: derselbe Text, den meldungstext
         heute ueber ->> einsetzt (null wird dort zu ''). */
      v_teil := coalesce(v_v #>> '{}', '');
    else
      v_teil := null;
      if v_v ? 's' then
        v_teil := public.meldung_rendern(v_v ->> 's', p_sprache, v_v -> 'w');
      elsif v_v ? 'zeit' then
        v_roh := v_v ->> 'zeit';
        if v_roh is not null and pg_input_is_valid(v_roh, 'timestamp with time zone') then
          v_teil := public.meldung_datum(v_roh::timestamptz, p_sprache,
                      coalesce(v_v ->> 'uhrzeit', '') in ('true', 't', '1'));
        else
          v_teil := v_roh;
        end if;
      elsif v_v ? 'tag' then
        v_roh := v_v ->> 'tag';
        if v_roh is not null and pg_input_is_valid(v_roh, 'date') then
          v_teil := public.meldung_datum(v_roh::date, p_sprache,
                      coalesce(v_v ->> 'jahr', '') in ('true', 't', '1'));
        else
          v_teil := v_roh;
        end if;
      elsif v_v ? 't' then
        v_teil := v_v ->> 't';
      end if;

      if coalesce(v_teil, '') = '' then
        v_teil := '';
      else
        v_teil := coalesce(v_v ->> 'vor', '') || v_teil;
      end if;
    end if;
    v_flach := v_flach || jsonb_build_object(v_k, v_teil);
  end loop;

  return public.meldungstext(p_schluessel, p_sprache, v_flach);
end;
$function$;

-- ================================================================ (3) meldungstexte
-- chat.zeile: Chat-Text bleibt Rohtext ({"t": ...}), nur {wer} kann ein
-- Ersatzwort sein. Heute schreibt chatnachricht_melden "<wer>: <text>" in allen
-- Sprachen; fr bekommt laut Vertrag das franzoesische Leerzeichen vor dem
-- Doppelpunkt (wie termin.grund fr ' Motif : {grund}').
insert into public.meldungstexte (schluessel, sprache, text) values
  ('chat.zeile', 'de', '{wer}: {text}'),
  ('chat.zeile', 'en', '{wer}: {text}'),
  ('chat.zeile', 'es', '{wer}: {text}'),
  ('chat.zeile', 'pt', '{wer}: {text}'),
  ('chat.zeile', 'it', '{wer}: {text}'),
  ('chat.zeile', 'tr', '{wer}: {text}'),
  ('chat.zeile', 'fr', '{wer} : {text}')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- ================================================================ (4) Weg ueber die Warteschlange
-- Rumpfe aus PROD (pg_get_functiondef, 16.09.2026). CREATE OR REPLACE behaelt
-- Rechte (notify_uebersetzt: postgres, service_role; warteschlange_in_glocke:
-- PUBLIC, postgres, authenticated) und den Ausloeser notification_queue_in_glocke.
-- Beide in DIESER Migration, damit data._rezept nie ohne Leser ankommt.

-- ---------------------------------------------------------------- notify_uebersetzt
CREATE OR REPLACE FUNCTION public.notify_uebersetzt(target_membership uuid, p_notif_type text, p_titel_schluessel text, p_text_schluessel text DEFAULT NULL::text, p_werte jsonb DEFAULT '{}'::jsonb, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_sprache text;
begin
  v_sprache := public.sprache_der_mitgliedschaft(target_membership);
  perform public.notify(
    target_membership,
    p_notif_type,
    public.meldung_rendern(p_titel_schluessel, v_sprache, p_werte),
    case when p_text_schluessel is null then null
         else public.meldung_rendern(p_text_schluessel, v_sprache, p_werte) end,
    /* Stufe B: Das Rezept reist in data._rezept mit, warteschlange_in_glocke
       legt es in user_notifications ab. So kann die Glocke nach einem
       Sprachwechsel neu rendern. Nur bei data als Objekt (oder null) - ein
       anderer Typ geht unveraendert weiter wie bisher. */
    case when p_data is null or jsonb_typeof(p_data) = 'object' then
           coalesce(p_data, '{}'::jsonb) || jsonb_build_object('_rezept', jsonb_build_object(
             'titel_schluessel', p_titel_schluessel,
             'text_schluessel',  p_text_schluessel,
             'werte',            p_werte,
             'sprache',          v_sprache))
         else p_data end);
end;
$function$
;

-- ---------------------------------------------------------------- warteschlange_in_glocke
CREATE OR REPLACE FUNCTION public.warteschlange_in_glocke()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_profil uuid; v_sprache text;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null then return new; end if;
  if not public.meldung_erlaubt(v_profil, coalesce(new.notif_type, 'info')) then return new; end if;

  /* Titel und Text kommen hier schon fertig uebersetzt an - notify_uebersetzt
     hat sie gesetzt, bevor die Zeile in die Warteschlange ging. Uebersetzt
     wird nur noch der Ersatztitel fuer den Fall, dass gar keiner mitkam. */
  v_sprache := public.sprache_der_mitgliedschaft(new.membership_id);

  /* Stufe B: data._rezept (von notify_uebersetzt) landet in den vier
     Rezeptspalten - sonst bleiben sie null (Freitext, wird nie neu
     gerendert). In title, body, ziel_art oder ziel_id kommt davon nichts. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  values (v_profil, new.club_id, coalesce(new.notif_type, 'info'),
          coalesce(new.title, public.meldungstext('allg.vereinsmeldung', v_sprache)),
          coalesce(new.body, ''),
          nullif(new.data ->> 'ziel_art', ''),
          case when (new.data ->> 'ziel_id') ~ '^[0-9a-fA-F-]{36}$'
               then (new.data ->> 'ziel_id')::uuid else null end,
          new.data #>> '{_rezept,titel_schluessel}',
          new.data #>> '{_rezept,text_schluessel}',
          nullif(new.data #> '{_rezept,werte}', 'null'::jsonb),
          new.data #>> '{_rezept,sprache}');
  return new;
end;
$function$
;

-- ================================================================ (5) glocke_neu_rendern
create or replace function public.glocke_neu_rendern(p_profil uuid, p_sprache text, p_limit integer default 300)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
/* Rendert die Glocke eines Profils in p_sprache neu (Stufe B). Nur die
   neuesten p_limit Zeilen MIT Rezept; Zeilen ohne Schluessel (Freitext,
   Betreiber, Zeilen von vor Stufe B) bleiben, wie sie sind.
   - title nur bei titel_schluessel, body nur bei text_schluessel.
   - Vereinspraefix wie meldung_vereinsname_voranstellen (BEFORE INSERT, feuert
     bei UPDATE nicht): aktueller Vereinsname der club_id, nur wenn der body
     nicht schon mit "Name:" beginnt. Ein body ohne text_schluessel wird nicht
     angefasst - kein doppeltes Praefix.
   - Waechter: Liefert meldungstext den Schluessel selbst zurueck (Baustein
     fehlt ganz), bleibt der alte Text stehen.
   - read_at wird nicht gesetzt: user_notifications_bleibt_gelesen (BEFORE
     UPDATE OF read_at) feuert nicht, user_notifications_zaehler_gelesen stoesst
     nur bei read_at null -> gesetzt an, user_notifications_push nur bei INSERT.
     Es geht also kein Push hinaus.
   Nicht fuer authenticated freigegeben - Aufruf nur aus sprache_setzen
   (auth.uid()). Rueckgabe: Anzahl neu gerenderter Zeilen. */
declare
  v_anzahl integer;
begin
  if p_profil is null or p_sprache is null then
    return 0;
  end if;

  with ziel as (
    select n.id
      from public.user_notifications n
     where n.profile_id = p_profil
       and (n.titel_schluessel is not null or n.text_schluessel is not null)
     order by n.created_at desc, n.id desc
     limit greatest(coalesce(p_limit, 300), 0)
  ),
  neu as (
    select n.id,
           n.titel_schluessel,
           n.text_schluessel,
           case when n.titel_schluessel is not null
                then public.meldung_rendern(n.titel_schluessel, p_sprache, n.werte) end as neu_titel,
           case when n.text_schluessel is not null
                then public.meldung_rendern(n.text_schluessel, p_sprache, n.werte) end as neu_text,
           c.name as verein
      from ziel z
      join public.user_notifications n on n.id = z.id
      left join public.clubs c on c.id = n.club_id
  )
  update public.user_notifications u
     set title   = case when x.neu_titel is null or x.neu_titel = x.titel_schluessel then u.title
                        else x.neu_titel end,
         body    = case when x.neu_text is null or x.neu_text = x.text_schluessel then u.body
                        when u.club_id is not null
                             and x.verein is not null and x.verein <> ''
                             and position(x.verein || ':' in x.neu_text) <> 1
                          then x.verein || ': ' || x.neu_text
                        else x.neu_text end,
         sprache = p_sprache
    from neu x
   where u.id = x.id;

  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$function$;

-- ================================================================ (6) sprache_setzen
-- Rumpf aus PROD (pg_get_functiondef, 16.09.2026), gleiche Signatur (keine
-- PostgREST-Ueberladung), Rechte bleiben (PUBLIC, authenticated, service_role).
CREATE OR REPLACE FUNCTION public.sprache_setzen(neue_sprache text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if neue_sprache not in ('de','en','es','pt','it','tr','fr') then
    raise exception 'Unsupported language';
  end if;
  update public.profiles set language = neue_sprache where id = auth.uid();
  /* Stufe B: Die eigene Glocke folgt der neuen Sprache (hoechstens die
     neuesten 300 Zeilen mit Rezept). Eigener Block - die Sprachwahl selbst
     darf daran nie scheitern. */
  begin
    perform public.glocke_neu_rendern(auth.uid(), neue_sprache, 300);
  exception when others then
    raise warning 'Glocke nicht neu uebersetzt: %', sqlerrm;
  end;
  return neue_sprache;
end;
$function$
;

-- ================================================================ (7) Rechte
-- meldung_rendern wie meldungstext(text,text,jsonb): {postgres=X, service_role=X}.
-- SECURITY-DEFINER-Funktionen laufen als postgres und brauchen keine Freigabe.
revoke all on function public.meldung_rendern(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.meldung_rendern(text, text, jsonb) to service_role;

-- glocke_neu_rendern: niemand ausser dem Eigentuemer (Aufruf nur aus sprache_setzen).
revoke all on function public.glocke_neu_rendern(uuid, text, integer) from public, anon, authenticated, service_role;

-- ================================================================ gruppe1/neue-texte.sql
-- Uebersetzung Stufe B, Gruppe 1: neue Satzmuster fuer die Rezepte.
-- Muss VOR gruppe1.sql laufen (sonst liefert meldungstext den Schluessel selbst).
--
-- termin.zeile          notify_event_audience (body). In allen Sprachen gleich:
--                       die bisherige Verkettung satz || ' ' || titel || wann || ort || grund.
--                       Platzhalter so benannt, dass Nutzertext (titel, ortzusatz,
--                       grundzusatz) NACH satz/wann ersetzt wird.
-- chat.zeile            chatnachricht_melden (body). fr mit Leerzeichen vor ':'
--                       (Vertrag, fr-Typografie wie in den uebrigen fr-Texten).
--                       Steht identisch auch in kern/kern.sql (3) - doppelt ist
--                       unschaedlich (Upsert), beim Zusammenfuehren eine Stelle behalten.
-- helfer.termin         helferdienst_einteilung_melden: Titel des Termins + Datum.
-- helfer.stationTermin  helferdienst_einteilung_melden: Station + ' – ' Termin.
insert into public.meldungstexte (schluessel, sprache, text) values
  ('termin.zeile', 'de', '{satz} {titel}{wann}{ortzusatz}{grundzusatz}'),
  ('termin.zeile', 'en', '{satz} {titel}{wann}{ortzusatz}{grundzusatz}'),
  ('termin.zeile', 'es', '{satz} {titel}{wann}{ortzusatz}{grundzusatz}'),
  ('termin.zeile', 'pt', '{satz} {titel}{wann}{ortzusatz}{grundzusatz}'),
  ('termin.zeile', 'it', '{satz} {titel}{wann}{ortzusatz}{grundzusatz}'),
  ('termin.zeile', 'tr', '{satz} {titel}{wann}{ortzusatz}{grundzusatz}'),
  ('termin.zeile', 'fr', '{satz} {titel}{wann}{ortzusatz}{grundzusatz}'),
  ('chat.zeile', 'de', '{wer}: {text}'),
  ('chat.zeile', 'en', '{wer}: {text}'),
  ('chat.zeile', 'es', '{wer}: {text}'),
  ('chat.zeile', 'pt', '{wer}: {text}'),
  ('chat.zeile', 'it', '{wer}: {text}'),
  ('chat.zeile', 'tr', '{wer}: {text}'),
  ('chat.zeile', 'fr', '{wer} : {text}'),
  ('helfer.termin', 'de', '{titel}{wann}'),
  ('helfer.termin', 'en', '{titel}{wann}'),
  ('helfer.termin', 'es', '{titel}{wann}'),
  ('helfer.termin', 'pt', '{titel}{wann}'),
  ('helfer.termin', 'it', '{titel}{wann}'),
  ('helfer.termin', 'tr', '{titel}{wann}'),
  ('helfer.termin', 'fr', '{titel}{wann}'),
  ('helfer.stationTermin', 'de', '{station}{terminangabe}'),
  ('helfer.stationTermin', 'en', '{station}{terminangabe}'),
  ('helfer.stationTermin', 'es', '{station}{terminangabe}'),
  ('helfer.stationTermin', 'pt', '{station}{terminangabe}'),
  ('helfer.stationTermin', 'it', '{station}{terminangabe}'),
  ('helfer.stationTermin', 'tr', '{station}{terminangabe}'),
  ('helfer.stationTermin', 'fr', '{station}{terminangabe}')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- ================================================================ gruppe1/gruppe1.sql
-- Uebersetzung Stufe B, Gruppe 1: direkte Schreiber in user_notifications
-- legen ihr Rezept ab (titel_schluessel, text_schluessel, werte, sprache).
--
-- Voraussetzungen (muessen VORHER in derselben oder einer frueheren Migration stehen):
--   * user_notifications.titel_schluessel/text_schluessel/werte/sprache (Kern)
--   * public.meldung_rendern(text, text, jsonb) (Kern)
--   * neue-texte.sql: termin.zeile, chat.zeile, helfer.termin, helfer.stationTermin
--   * notify_uebersetzt rendert mit meldung_rendern (Kern) - ergebnis_melden
--     uebergibt im Tippspiel-Zweig {"s": "allg.begegnung"} als Wert.
--
-- Rumpfe aus PROD (pg_get_functiondef, 16.09.2026, Stand nach Stufe A).
-- Geaendert NUR: meldungstext(...) -> meldung_rendern(...), Ersatzwoerter und
-- Datum als Baustein in werte, vier zusaetzliche Spalten im INSERT.
-- Nachweis je Funktion: diff-<name>.txt. CREATE OR REPLACE behaelt Rechte,
-- Eigentuemer und Ausloeser. title/body beim INSERT sind Zeichen fuer Zeichen
-- dieselben wie bisher (Ausnahme laut Vertrag: chat.zeile fr '{wer} : {text}').
--
-- Reihenfolge fest: notify_event_audience, news_melden, umfrage_melden,
-- chatnachricht_melden, ergebnis_melden, ergebnis_erinnerung_senden,
-- aufgaben_erinnerung_senden, aufgabe_zugewiesen_melden,
-- vereinsaufgabe_zuweisung_melden, helferdienst_einteilung_melden.

-- ---------------------------------------------------------------- notify_event_audience
CREATE OR REPLACE FUNCTION public.notify_event_audience()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_situation  text;   -- angelegt | abgesagt | geaendert
  v_basis      text;   -- z. B. termin.spiel.abgesagt
  v_schluessel text;   -- zugleich kind und Einstellungsschluessel
  v_teamart    text;   -- trainings | spiele | null
  v_grund      text;
  v_werte      jsonb;  -- Rezept fuer das Neu-Rendern (Stufe B)
begin
  v_teamart := case new.type when 'training' then 'trainings' when 'spiel' then 'spiele' else null end;

  /* Ein reiner Ergebniseintrag ist keine Aenderung des Termins - dafuer gibt
     es spielergebnis_melden. Sonst bekaeme der halbe Verein "Das Spiel wurde
     geaendert", sobald jemand 3:2 eintraegt. */
  if tg_op = 'UPDATE'
     and to_jsonb(old) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
       = to_jsonb(new) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
  then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_situation := 'angelegt';
    v_schluessel := case new.type when 'training' then 'training_created'
                                  when 'spiel'    then 'game_created'
                                  else 'events' end;

    /* Eine Serie meldet EINMAL, nicht je Termin.
       create_recurring_events legt alle Termine in einer einzigen
       INSERT-...-SELECT-Anweisung an. Dieser Ausloeser haengt aber an FOR EACH
       ROW - bisher entstand also je Termin und je Empfaenger eine Meldung und
       damit eine Push-Nachricht. In den Daten steht der Beleg: eine Serie mit
       drei Terminen erzeugte neun Meldungen. Die groesste vorhandene Serie hat
       85 Termine.
       Weil alle Zeilen derselben Anweisung dieselbe created_at tragen - now()
       ist innerhalb einer Transaktion konstant -, entscheidet die Kennung den
       Gleichstand. Genau eine Zeile findet keine aeltere vor sich und meldet;
       alle uebrigen steigen hier aus.
       Wird der Serie spaeter ein Termin hinzugefuegt, hat er eine juengere
       created_at und schweigt ebenfalls - richtig so: angekuendigt wurde die
       Serie bereits. */
    if new.series_id is not null then
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and (e.created_at, e.id) < (new.created_at, new.id)
      ) then
        return new;
      end if;
      v_situation := 'serie_angelegt';
    end if;
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_situation := 'abgesagt';
    v_schluessel := case new.type when 'training' then 'training_cancelled'
                                  when 'spiel'    then 'game_cancelled'
                                  else 'events' end;

    /* Dieselbe Ueberlegung wie beim Anlegen, nur umgekehrt: Wer eine ganze
       Reihe absagt, soll EINE Nachricht ausloesen, nicht zwanzig.
       Unterschieden wird an cancelled_at. absage_serie setzt alle Termine in
       EINER Anweisung ab, und now() ist innerhalb einer Transaktion konstant -
       alle abgesagten Zeilen der Reihe tragen deshalb denselben Zeitpunkt auf
       die Mikrosekunde. Findet eine Zeile eine Schwester mit GENAU derselben
       cancelled_at und kleinerer Kennung, war es eine Reihenabsage und sie
       schweigt.
       Wird dagegen ein EINZELNER Termin einer Reihe abgesagt, gibt es keine
       solche Schwester - er meldet ganz normal mit "abgesagt". Genau das
       braucht die Auswahl "nur dieser Termin". */
    if new.series_id is not null and new.cancelled_at is not null then
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and e.status = 'cancelled'
           and e.cancelled_at = new.cancelled_at
           and e.id < new.id
      ) then
        return new;
      end if;
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and e.status = 'cancelled'
           and e.cancelled_at = new.cancelled_at
      ) then
        v_situation := 'serie_abgesagt';
      end if;
    end if;
  elsif tg_op = 'UPDATE' then
    v_situation := 'geaendert';
    v_schluessel := case new.type when 'training' then 'training_changed'
                                  when 'spiel'    then 'game_changed'
                                  else 'events' end;
  else
    return new;
  end if;

  /* Ganze Saetze je Terminart, nicht "Das {art} wurde …" zusammengesetzt:
     Artikel und Geschlecht haengen in den meisten Sprachen am Wort. */
  v_basis := 'termin.' || case new.type when 'training' then 'training'
                                        when 'spiel'    then 'spiel'
                                        else 'event' end
             || '.' || v_situation;

  v_grund := nullif(trim(new.cancel_reason), '');

  /* Stufe B: Der Text entsteht aus Bausteinen, damit ihn glocke_neu_rendern
     spaeter in einer anderen Sprache wiederholen kann. termin.zeile ist
     '{satz} {titel}{wann}{ortzusatz}{grundzusatz}' - Zeichen fuer Zeichen
     dasselbe wie die bisherige Verkettung. Satz, Datum und Grund-Baustein
     folgen der Sprache; Titel, Ort und Grund selbst bleiben Rohtext. */
  v_werte := jsonb_build_object(
    'satz',        jsonb_build_object('s', v_basis || '.text'),
    'titel',       coalesce(new.title, ''),
    'wann',        case when new.starts_at is null then to_jsonb(''::text)
                        else jsonb_build_object('vor', ' · ', 'zeit', new.starts_at, 'uhrzeit', true) end,
    'ortzusatz',   coalesce(' · ' || new.location, ''),
    'grundzusatz', case when v_situation = 'abgesagt' and v_grund is not null
                        then jsonb_build_object('vor', ' ·', 's', 'termin.grund',
                                               'w', jsonb_build_object('grund', v_grund))
                        else to_jsonb(''::text) end);

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, v_schluessel,
         public.meldung_rendern(v_basis || '.titel', coalesce(p.language, 'de'), '{}'::jsonb),
         /* Der Grund steht am ENDE, nicht direkt hinter dem Satz. Vorher las
            sich eine Absage als "Das Spiel wurde abgesagt. Grund: Glatteis
            Herren 1 gegen Herringen · 12.09. · Hemberghalle" - der Grund
            klebte am Spieltitel und man wusste nicht, wo er aufhoert. */
         public.meldung_rendern('termin.zeile', coalesce(p.language, 'de'), v_werte),
         'termin', new.id,
         v_basis || '.titel', 'termin.zeile', v_werte, coalesce(p.language, 'de')
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, new.team_id, v_teamart)
    and public.meldung_erlaubt(m.profile_id, v_schluessel)
    /* Fans sehen keine Trainings (12.09.2026) - also auch keine Meldung
       darueber. Ein Fan ist in keiner Mannschaft, konnte einer aber ueber
       team_benachrichtigungen folgen, und vereinsweite Trainings erreichten
       ohnehin jeden. "Nur Fan" heisst: 'fan' und keine andere Rolle. Seit
       20260911110000 laesst die Datenbank neben 'fan' nichts mehr zu; die
       zweite Bedingung haelt trotzdem fest, was gemeint ist. */
    and not (
      new.type = 'training'
      and exists (select 1 from public.membership_roles r
                   where r.membership_id = m.id and r.role = 'fan')
      and not exists (select 1 from public.membership_roles r
                       where r.membership_id = m.id and r.role <> 'fan')
    );

  return new;
exception when others then
  /* Ein Termin ist wichtiger als die Meldung darueber: Er wird angelegt,
     auch wenn das Melden scheitert. Die Warnung steht im Protokoll. */
  raise warning 'Terminmeldung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$function$

;

-- ---------------------------------------------------------------- news_melden
CREATE OR REPLACE FUNCTION public.news_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  /* Der Willkommensbeitrag bei einer Aufnahme meldet nicht an alle - die
     Aufnahme melden wir der Vereinsleitung eigens (aufnahme_leitung_melden). */
  if coalesce(current_setting('cmo.news_still', true), '') = 'an' then
    return new;
  end if;
  /* Ziel ist der Beitrag selbst: Die App rollt ihn auf der Startseite heran
     oder oeffnet ihn einzeln, wenn er dort nicht mehr steht. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select m.profile_id, new.club_id, 'news',
         public.meldung_rendern('news.titel', coalesce(p.language, 'de'), '{}'::jsonb),
         public.meldung_rendern('news.text', coalesce(p.language, 'de'), '{}'::jsonb),
         'news', new.id,
         'news.titel', 'news.text', '{}'::jsonb, coalesce(p.language, 'de')
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'news');
  return new;
end;
$function$

;

-- ---------------------------------------------------------------- umfrage_melden
CREATE OR REPLACE FUNCTION public.umfrage_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not new.active then return new; end if;
  /* Chat-Abstimmungen melden sich selbst, an die Leute ihres Kanals. */
  if new.channel_id is not null then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select m.profile_id, new.club_id, 'polls',
         public.meldung_rendern('umfrage.titel', coalesce(p.language, 'de'), '{}'::jsonb),
         public.meldung_rendern('umfrage.text', coalesce(p.language, 'de'), '{}'::jsonb),
         'umfrage', new.id,
         'umfrage.titel', 'umfrage.text', '{}'::jsonb, coalesce(p.language, 'de')
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and public.meldung_erlaubt(m.profile_id, 'polls');

  return new;
end;
$function$

;

-- ---------------------------------------------------------------- chatnachricht_melden
CREATE OR REPLACE FUNCTION public.chatnachricht_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_club     uuid;
  v_team     uuid;
  v_sichtbar public.club_role[];
  v_wer      text;
  v_text     text;
  v_werte    jsonb;  -- Rezept fuer das Neu-Rendern (Stufe B)
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

  /* Stufe B: chat.zeile = '{wer}: {text}'. Name und Nachricht bleiben
     Rohtext; nur das Ersatzwort (kein Name) und das Satzmuster folgen der
     Sprache. Titel mit Name: kein titel_schluessel, bleibt wie er ist. */
  v_werte := jsonb_build_object(
    'wer',  case when v_wer is null then jsonb_build_object('s', 'allg.jemand') else to_jsonb(v_wer) end,
    'text', v_text);

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
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct e.profile_id, v_club, 'chat',
         coalesce(v_wer, public.meldung_rendern('chat.titel', coalesce(p.language, 'de'), '{}'::jsonb)),
         public.meldung_rendern('chat.zeile', coalesce(p.language, 'de'), v_werte),
         'chat', new.channel_id,
         case when v_wer is null then 'chat.titel' end, 'chat.zeile', v_werte, coalesce(p.language, 'de')
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
$function$

;

-- ---------------------------------------------------------------- ergebnis_melden
CREATE OR REPLACE FUNCTION public.ergebnis_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_event       record;
  v_vereinsname text;
  v_mannschaft  text;
  v_schluessel  text;
  v_tipper      record;
  v_werte       jsonb;
  v_zeile       jsonb;  -- Rezept der Mannschaftsmeldung (Stufe B)
begin
  if tg_op = 'UPDATE'
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  select e.team_id, e.home_away, e.club_id, e.title, e.type, e.status
    into v_event
    from public.events e
   where e.id = new.event_id;
  if not found then return new; end if;
  if v_event.type is distinct from 'spiel' then return new; end if;
  if v_event.status = 'cancelled' then return new; end if;

  v_werte := public.ergebnis_meldewerte(v_event.home_away, new.heim, new.auswaerts);

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

  /* Tippspiel zuerst - getippt wird auch auf Begegnungen ohne Mannschaft. */
  for v_tipper in
    select m.id
      from public.predictions pr
      join public.club_memberships m
        on m.profile_id = pr.profile_id and m.club_id = new.club_id
     where pr.event_id = new.event_id and m.status = 'active'
  loop
    /* Mit Sprungziel (U8): warteschlange_in_glocke uebernimmt ziel_art und
       ziel_id aus p_data. Die App oeffnet damit das Tippspiel, ohne Abo den
       Termin. */
    perform public.notify_uebersetzt(v_tipper.id, 'tipp',
      'tipp.titel', 'tipp.text',
      jsonb_build_object(
        /* Stufe B: Ersatzwort als Baustein - notify_uebersetzt rendert es in
           der Empfaengersprache und legt das Rezept in data._rezept. */
        'titel', case when v_event.title is null then jsonb_build_object('s', 'allg.begegnung')
                      else to_jsonb(v_event.title) end,
        'heim', v_werte -> 'heim', 'auswaerts', v_werte -> 'auswaerts'),
      jsonb_build_object('ziel_art', 'termin', 'ziel_id', new.event_id));
  end loop;

  if v_mannschaft is null or (v_werte ->> 'ort') is null then return new; end if;

  v_schluessel := 'ergebnis.' || (v_werte ->> 'ort') || '.' || (v_werte ->> 'ausgang');

  /* Stufe B: Der ganze Satz steht im Titel und folgt der Sprache; der body
     bleibt '' (kein text_schluessel, wird nie neu gerendert). */
  v_zeile := jsonb_build_object(
    'verein', case when v_vereinsname is null then jsonb_build_object('s', 'allg.verein')
                   else to_jsonb(v_vereinsname) end,
    'mannschaft', v_mannschaft,
    'heim', v_werte -> 'heim', 'auswaerts', v_werte -> 'auswaerts');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, 'results',
         public.meldung_rendern(v_schluessel, coalesce(p.language, 'de'), v_zeile),
         '',
         'termin', new.event_id,
         v_schluessel, null::text, v_zeile, coalesce(p.language, 'de')
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = v_event.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = v_event.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, v_event.team_id, 'ergebnisse')
    and public.meldung_erlaubt(m.profile_id, 'results');

  return new;
end;
$function$

;

-- ---------------------------------------------------------------- ergebnis_erinnerung_senden
CREATE OR REPLACE FUNCTION public.ergebnis_erinnerung_senden()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select e.id, e.club_id, e.title
    from public.events e
    left join public.event_results r on r.event_id = e.id
    where e.type = 'spiel'
      and e.status is distinct from 'cancelled'
      and e.starts_at < now() - interval '3 hours'
      and e.starts_at > now() - interval '7 days'
      and r.event_id is null
      and e.ergebnis_erinnert_at is null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                           titel_schluessel, text_schluessel, werte, sprache)
    select distinct m.profile_id, f.club_id, 'results',
           public.meldung_rendern('ergebnis.fehlt.titel', coalesce(p.language, 'de'), '{}'::jsonb),
           public.meldung_rendern('ergebnis.fehlt.text', coalesce(p.language, 'de'), jsonb_build_object('titel', f.title)),
           'termin', f.id,
           'ergebnis.fehlt.titel', 'ergebnis.fehlt.text', jsonb_build_object('titel', f.title), coalesce(p.language, 'de')
    from faellig f
    join public.club_memberships m
      on m.club_id = f.club_id and m.status = 'active' and m.profile_id is not null
    left join public.profiles p on p.id = m.profile_id
    where public.darf_ergebnis_eintragen_fuer(m.profile_id, f.club_id, f.id)
      and public.meldung_erlaubt(m.profile_id, 'results')
    returning 1
  )
  update public.events set ergebnis_erinnert_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$function$

;

-- ---------------------------------------------------------------- aufgaben_erinnerung_senden
CREATE OR REPLACE FUNCTION public.aufgaben_erinnerung_senden()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select t.id, t.club_id, t.title, t.event_id, m.profile_id, coalesce(pr.language, 'de') as sprache
    from public.duty_tasks t
    join public.club_memberships m on m.id = t.assignee_membership_id
    left join public.profiles pr on pr.id = m.profile_id
    where t.due_date = (current_date + 1)
      and t.reminded_at is null and t.done is not true
      and m.profile_id is not null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                           titel_schluessel, text_schluessel, werte, sprache)
    select f.profile_id, f.club_id, 'duty',
           public.meldung_rendern('erinnerung.titel', f.sprache, '{}'::jsonb),
           public.meldung_rendern('erinnerung.morgen', f.sprache, jsonb_build_object('titel', f.title)),
           case when f.event_id is not null then 'helferdienst' end, f.event_id,
           'erinnerung.titel', 'erinnerung.morgen', jsonb_build_object('titel', f.title), f.sprache
    from faellig f
    where public.meldung_erlaubt(f.profile_id, 'duty')
    returning 1
  )
  update public.duty_tasks set reminded_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;

  with faellig2 as (
    select t.id, t.club_id, t.team_id, t.title
    from public.club_tasks t
    /* erledigt_am mitpruefen - wer seine Vereinsaufgabe abgehakt hat, soll am
       Vorabend keine Erinnerung mehr bekommen. */
    where t.due_date = (current_date + 1) and t.reminded_at is null
      and t.erledigt_am is null
  ), beteiligte as (
    /* Nur wem die Aufgabe gehoert: verantwortlich eingetragen oder selbst
       eingetragen. Keine Rueckfalls-Empfaenger mehr (ganzer Verein, ganze
       Mannschaft), wenn niemand verantwortlich ist. */
    select a.task_id, a.membership_id from public.club_task_assignees a
     where a.task_id in (select id from faellig2)
    union
    select s.task_id, s.membership_id from public.club_task_signups s
     where s.task_id in (select id from faellig2)
  ), empfaenger as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                           titel_schluessel, text_schluessel, werte, sprache)
    select distinct m.profile_id, f.club_id, 'tasks',
           public.meldung_rendern('erinnerung.titel', coalesce(pr.language, 'de'), '{}'::jsonb),
           public.meldung_rendern('erinnerung.morgen', coalesce(pr.language, 'de'), jsonb_build_object('titel', f.title)),
           'aufgabe', f.id,
           'erinnerung.titel', 'erinnerung.morgen', jsonb_build_object('titel', f.title), coalesce(pr.language, 'de')
    from faellig2 f
    join beteiligte b on b.task_id = f.id
    join public.club_memberships m on m.id = b.membership_id and m.club_id = f.club_id and m.status = 'active'
    left join public.profiles pr on pr.id = m.profile_id
    where m.profile_id is not null
      and public.team_meldung_erlaubt(m.id, f.team_id, 'aufgaben')
      and public.meldung_erlaubt(m.profile_id, 'tasks')
    returning 1
  )
  update public.club_tasks set reminded_at = now() where id in (select id from faellig2);

  return v_anzahl;
end;
$function$

;

-- ---------------------------------------------------------------- aufgabe_zugewiesen_melden
CREATE OR REPLACE FUNCTION public.aufgabe_zugewiesen_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
  v_werte   jsonb;  -- Rezept fuer das Neu-Rendern (Stufe B)
begin
  if new.assignee_membership_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.assignee_membership_id is not distinct from old.assignee_membership_id then
    return new;
  end if;
  select profile_id into v_profil from public.club_memberships where id = new.assignee_membership_id;
  if v_profil is null then return new; end if;
  if v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'duty') then return new; end if;
  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.assignee_membership_id);
  v_werte := jsonb_build_object(
    'wer', case when v_wer is null then jsonb_build_object('s', 'allg.vereinsleitung') else to_jsonb(v_wer) end,
    'titel', coalesce(new.title, ''));
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  values (v_profil, new.club_id, 'duty',
          public.meldung_rendern('aufgabe.zugewiesen.titel', v_sprache, '{}'::jsonb),
          public.meldung_rendern('aufgabe.zugewiesen.textMitTitel', v_sprache, v_werte),
          'helferdienst', new.event_id,
          'aufgabe.zugewiesen.titel', 'aufgabe.zugewiesen.textMitTitel', v_werte, v_sprache);
  return new;
end;
$function$

;

-- ---------------------------------------------------------------- vereinsaufgabe_zuweisung_melden
CREATE OR REPLACE FUNCTION public.vereinsaufgabe_zuweisung_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_profil uuid; v_club uuid; v_titel text; v_wer text; v_sprache text;
        v_werte jsonb;  -- Rezept fuer das Neu-Rendern (Stufe B)
begin
  select t.club_id, t.title into v_club, v_titel from public.club_tasks t where t.id = new.task_id;
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'tasks') then return new; end if;

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = v_club limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.membership_id);
  v_werte := jsonb_build_object(
    'wer', case when v_wer is null then jsonb_build_object('s', 'allg.vereinsleitung') else to_jsonb(v_wer) end,
    'titel', coalesce(v_titel, ''));

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  values (v_profil, v_club, 'tasks',
          public.meldung_rendern('aufgabe.zugewiesen.titel', v_sprache, '{}'::jsonb),
          public.meldung_rendern('aufgabe.zugewiesen.textMitTitel', v_sprache, v_werte),
          'aufgabe', new.task_id,
          'aufgabe.zugewiesen.titel', 'aufgabe.zugewiesen.textMitTitel', v_werte, v_sprache);
  return new;
end;
$function$

;

-- ---------------------------------------------------------------- helferdienst_einteilung_melden
CREATE OR REPLACE FUNCTION public.helferdienst_einteilung_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
  v_termin  jsonb;  -- Stufe B: Baustein statt fertigem Text
  v_werte   jsonb;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'duty') then return new; end if;
  v_sprache := public.sprache_der_mitgliedschaft(new.membership_id);
  /* Bisher nullif(trim(titel || ' · ' || datum), ''). Das Datum endet nie auf
     ein Leerzeichen, trim wirkt also nur vorn: am Titel - oder, ist der Titel
     leer, am Trenner (' · ' -> '· '). helfer.termin = '{titel}{wann}'; ist
     es leer, faellt auch ' – ' weg (vor). Kein Termin: v_termin bleibt null. */
  select jsonb_build_object('vor', ' – ', 's', 'helfer.termin', 'w', jsonb_build_object(
           'titel', case when e.starts_at is null then trim(coalesce(e.title, ''))
                         else ltrim(coalesce(e.title, '')) end,
           'wann',  case when e.starts_at is null then to_jsonb(''::text)
                         else jsonb_build_object(
                                'vor', case when ltrim(coalesce(e.title, '')) = '' then '· ' else ' · ' end,
                                'zeit', e.starts_at, 'uhrzeit', false) end))
    into v_termin from public.events e where e.id = new.event_id;
  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  /* helfer.stationTermin = '{station}{terminangabe}' (Station bleibt Rohtext). */
  v_werte := jsonb_build_object(
    'wer', case when v_wer is null then jsonb_build_object('s', 'allg.vereinsleitung') else to_jsonb(v_wer) end,
    'titel', case when new.station is null then to_jsonb(''::text)  -- bisher null || ... = ''
                  else jsonb_build_object('s', 'helfer.stationTermin', 'w', jsonb_build_object(
                         'station', new.station,
                         'terminangabe', coalesce(v_termin, to_jsonb(''::text)))) end);
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  values (v_profil, new.club_id, 'duty',
          public.meldung_rendern('aufgabe.zugewiesen.titel', v_sprache, '{}'::jsonb),
          public.meldung_rendern('aufgabe.zugewiesen.textMitTitel', v_sprache, v_werte),
          'helferdienst', new.event_id,
          'aufgabe.zugewiesen.titel', 'aufgabe.zugewiesen.textMitTitel', v_werte, v_sprache);
  return new;
end;
$function$

;

-- ================================================================ gruppe2/gruppe2.sql
-- Uebersetzung Stufe B, Gruppe 2: direkte Schreiber in user_notifications
-- speichern ihr Rezept (titel_schluessel, text_schluessel, werte, sprache).
--
-- Betroffen (je Rumpf aus PROD per pg_get_functiondef vom 16.09.2026, nach
-- Stufe A 20260916100000; Nachweis diff-<name>.txt, Rueckweg prod-<name>.sql):
--   protokoll_melden, protokollaufgabe_zuweisung_melden, fahrzeuganfrage_melden,
--   entscheide_fahrzeug_anfrage, beitrittsanfrage_melden, aufnahme_leitung_melden,
--   notify_new_device, notify_family_link_created, leitung_melden.
--
-- Geaendert ist NUR: meldungstext(...) -> meldung_rendern(schluessel, sprache, werte),
-- die vier Rezeptspalten im INSERT, vorgerenderte Ersatzwoerter/Datumswerte als
-- Bausteine ({"s": ...} bzw. {"tag": ..., "jahr": true}). Signaturen, SECURITY
-- DEFINER, search_path, Filter, exception-Bloecke und Rechte bleiben
-- (CREATE OR REPLACE behaelt ACL und Ausloeser). title/body beim INSERT sind
-- Zeichen fuer Zeichen wie bisher (Nachweis pruefung-gleichheit.sql:
-- 3488 Faelle ueber 7 Sprachen + null, 0 Abweichungen).
--
-- Voraussetzung (Waechter unten bricht sonst ab):
--   * Kern M1: Spalten user_notifications.titel_schluessel/text_schluessel/werte/sprache
--     und public.meldung_rendern(text, text, jsonb) returns text.
--   * Kern M2: notify_uebersetzt rendert mit meldung_rendern - notify_family_link_created
--     reicht {"s": "allg.jemand"} an notify_uebersetzt weiter; mit dem alten
--     notify_uebersetzt stuende sonst JSON im Text.
-- Keine neuen meldungstexte (neue-texte.sql ist leer bis auf eine Pruefung).
-- Vorher scripts/sicherung-vor-migration.sh ausfuehren.

-- ================================================================ Waechter
do $$
begin
  if (select count(*) from pg_attribute a
       where a.attrelid = 'public.user_notifications'::regclass and not a.attisdropped
         and (a.attname, format_type(a.atttypid, a.atttypmod)) in
             (('titel_schluessel', 'text'), ('text_schluessel', 'text'), ('werte', 'jsonb'), ('sprache', 'text'))) <> 4 then
    raise exception 'Stufe B Gruppe 2: Rezeptspalten in user_notifications fehlen - zuerst Kern (M1) einspielen';
  end if;
  if not exists (select 1 from pg_proc p
                  where p.pronamespace = 'public'::regnamespace and p.proname = 'meldung_rendern'
                    and p.pronargs >= 3 and p.pronargs - p.pronargdefaults <= 3
                    and p.proargtypes[0] = 'text'::regtype and p.proargtypes[1] = 'text'::regtype
                    and p.proargtypes[2] = 'jsonb'::regtype and p.prorettype = 'text'::regtype) then
    raise exception 'Stufe B Gruppe 2: public.meldung_rendern(text, text, jsonb) fehlt - zuerst Kern (M1) einspielen';
  end if;
  if not exists (select 1 from pg_proc p
                  where p.oid = 'public.notify_uebersetzt(uuid,text,text,text,jsonb,jsonb)'::regprocedure
                    and p.prosrc like '%meldung_rendern%') then
    raise exception 'Stufe B Gruppe 2: notify_uebersetzt rendert noch nicht mit meldung_rendern - zuerst Kern (M2) einspielen';
  end if;
end $$;

-- ---------------------------------------------------------------- protokoll_melden
CREATE OR REPLACE FUNCTION public.protokoll_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_werte jsonb;
begin
  /* Rezept (Stufe B): Schluessel und Werte stehen mit in der Zeile, damit
     glocke_neu_rendern sie nach einem Sprachwechsel neu uebersetzen kann.
     Der Protokolltitel ist Nutzerinhalt und bleibt Rohtext. */
  v_werte := jsonb_build_object('titel', new.title);
  insert into public.user_notifications (profile_id, club_id, kind, title, body,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, 'protocols',
         public.meldung_rendern('protokoll.titel', coalesce(p.language, 'de'), v_werte),
         public.meldung_rendern('protokoll.text', coalesce(p.language, 'de'), v_werte),
         'protokoll.titel', 'protokoll.text', v_werte, coalesce(p.language, 'de')
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
$function$
;

-- ---------------------------------------------------------------- protokollaufgabe_zuweisung_melden
CREATE OR REPLACE FUNCTION public.protokollaufgabe_zuweisung_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
  v_werte   jsonb;
begin
  if new.assignee_membership_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.assignee_membership_id is not distinct from old.assignee_membership_id then
    return new;
  end if;
  select profile_id into v_profil from public.club_memberships where id = new.assignee_membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'tasks') then return new; end if;
  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.assignee_membership_id);
  /* Rezept (Stufe B): Das Ersatzwort steht als Baustein {"s": ...} in werte,
     damit es beim Neu-Rendern mituebersetzt wird. Name und Aufgabentext
     bleiben Rohtext. */
  v_werte := jsonb_build_object(
    'wer', coalesce(to_jsonb(v_wer), jsonb_build_object('s', 'allg.vereinsleitung')),
    'titel', left(coalesce(new.text, ''), 120));
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  values (v_profil, new.club_id, 'tasks',
          public.meldung_rendern('aufgabe.zugewiesen.titel', v_sprache, v_werte),
          public.meldung_rendern('aufgabe.zugewiesen.textMitTitel', v_sprache, v_werte),
          'protokollaufgabe', new.id,
          'aufgabe.zugewiesen.titel', 'aufgabe.zugewiesen.textMitTitel', v_werte, v_sprache);
  return new;
end;
$function$
;

-- ---------------------------------------------------------------- fahrzeuganfrage_melden
CREATE OR REPLACE FUNCTION public.fahrzeuganfrage_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_name  text;
  v_text  text;
  v_werte jsonb;
begin
  /* Nur Anfragen. Wer direkt buchen darf, hat den Status schon auf
     "bestaetigt" - da gibt es nichts zu genehmigen und niemanden zu stoeren. */
  if new.status <> 'angefragt' then return new; end if;

  select display_name into v_name from public.club_memberships where id = new.membership_id;

  /* Rezept (Stufe B): dieselbe Fallunterscheidung wie bisher, nur als
     Schluessel und Werte festgehalten. */
  v_text  := case when v_name is null then 'fahrzeug.anfrage.textOhneName'
                  else 'fahrzeug.anfrage.text' end;
  v_werte := case when v_name is null then '{}'::jsonb
                  else jsonb_build_object('wer', v_name) end;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, 'vehicle',
         public.meldung_rendern('fahrzeug.anfrage.titel', coalesce(p.language, 'de'), v_werte),
         public.meldung_rendern(v_text, coalesce(p.language, 'de'), v_werte),
         'fahrzeug', new.id,
         'fahrzeug.anfrage.titel', v_text, v_werte, coalesce(p.language, 'de')
  from public.membership_roles r
  join public.club_memberships m on m.id = r.membership_id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and public.meldung_erlaubt(m.profile_id, 'vehicle');

  return new;
end;
$function$
;

-- ---------------------------------------------------------------- entscheide_fahrzeug_anfrage
CREATE OR REPLACE FUNCTION public.entscheide_fahrzeug_anfrage(target_booking uuid, annehmen boolean)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_club uuid;
  v_anfrager uuid;
  v_profil uuid;
  v_status text;
  v_mein uuid;
  v_sprache text;
  v_text    text;
begin
  select club_id, membership_id, status into v_club, v_anfrager, v_status
  from public.vehicle_bookings where id = target_booking;
  if v_club is null then raise exception 'Booking not found'; end if;
  if not public.darf_fahrzeug_entscheiden(v_club) then raise exception 'Not authorized'; end if;
  if v_status <> 'angefragt' then return v_status; end if;

  select id into v_mein from public.club_memberships
   where club_id = v_club and profile_id = auth.uid() and status = 'active' limit 1;

  update public.vehicle_bookings
     set status = case when annehmen then 'bestaetigt' else 'abgelehnt' end,
         decided_by = v_mein, decided_at = now()
   where id = target_booking;

  select profile_id into v_profil from public.club_memberships where id = v_anfrager;
  if v_profil is not null and public.meldung_erlaubt(v_profil, 'vehicle') then
    v_sprache := public.sprache_der_mitgliedschaft(v_anfrager);
    v_text := case when annehmen then 'fahrzeug.angenommen' else 'fahrzeug.abgelehnt' end;
    /* Rezept (Stufe B): reine Schluessel, keine Werte. */
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                           titel_schluessel, text_schluessel, werte, sprache)
    values (v_profil, v_club, 'vehicle',
            public.meldung_rendern('fahrzeug.titel', v_sprache, '{}'::jsonb),
            public.meldung_rendern(v_text, v_sprache, '{}'::jsonb),
            'fahrzeug', target_booking,
            'fahrzeug.titel', v_text, '{}'::jsonb, v_sprache);
  end if;

  return case when annehmen then 'bestaetigt' else 'abgelehnt' end;
end;
$function$
;

-- ---------------------------------------------------------------- beitrittsanfrage_melden
CREATE OR REPLACE FUNCTION public.beitrittsanfrage_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_wer   text;
  v_text  text;
  v_werte jsonb;
begin
  if new.status <> 'pending' then return new; end if;
  /* Nur beim UEBERGANG nach pending, nicht bei jeder Aenderung an einer
     bereits wartenden Zeile - sonst meldet jeder Tippfehler im Namen erneut. */
  if tg_op = 'UPDATE' and old.status = 'pending' then return new; end if;

  v_wer := nullif(btrim(coalesce(new.display_name, '')), '');

  /* Rezept (Stufe B): dieselbe Fallunterscheidung wie bisher, nur als
     Schluessel und Werte festgehalten. */
  v_text  := case when v_wer is null then 'beitritt.anfrage.textOhneName'
                  else 'beitritt.anfrage.text' end;
  v_werte := case when v_wer is null then '{}'::jsonb
                  else jsonb_build_object('wer', v_wer) end;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, 'join_requests',
         public.meldung_rendern('beitritt.anfrage.titel', coalesce(p.language, 'de'), v_werte),
         public.meldung_rendern(v_text, coalesce(p.language, 'de'), v_werte),
         'beitritt', new.id,
         'beitritt.anfrage.titel', v_text, v_werte, coalesce(p.language, 'de')
  from public.club_memberships m
  join public.membership_roles r on r.membership_id = m.id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and m.id is distinct from new.id
    and public.meldung_erlaubt(m.profile_id, 'join_requests');

  return new;
end;
$function$
;

-- ---------------------------------------------------------------- aufnahme_leitung_melden
CREATE OR REPLACE FUNCTION public.aufnahme_leitung_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_wer text;
  v_fan boolean;
  v_texte text;
  v_text  text;
  v_werte jsonb;
begin
  if new.status <> 'active' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
  if new.profile_id is null or new.is_managed_profile then return new; end if;

  v_wer := nullif(btrim(coalesce(new.display_name, '')), '');

  /* Ein Fan ist kein "Neues Mitglied". Die Rolle steht schon da:
     beitritt_entscheiden schreibt die Rollen vor dem Status. */
  v_fan := exists (select 1 from public.membership_roles r
                    where r.membership_id = new.id and r.role = 'fan');
  v_texte := case when v_fan then 'beitritt.aufgenommenFan' else 'beitritt.aufgenommen' end;

  /* Rezept (Stufe B): dieselbe Fallunterscheidung wie bisher, nur als
     Schluessel und Werte festgehalten. */
  v_text  := v_texte || case when v_wer is null then '.textOhneName' else '.text' end;
  v_werte := case when v_wer is null then '{}'::jsonb
                  else jsonb_build_object('wer', v_wer) end;

  /* 'mitglied' statt 'beitritt': Die Aufnahme ist erledigt, bei den offenen
     Antraegen steht sie nicht mehr. Die Leitung will das neue Mitglied sehen. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, 'join_requests',
         public.meldung_rendern(v_texte || '.titel', coalesce(p.language, 'de'), v_werte),
         public.meldung_rendern(v_text, coalesce(p.language, 'de'), v_werte),
         'mitglied', new.id,
         v_texte || '.titel', v_text, v_werte, coalesce(p.language, 'de')
  from public.club_memberships m
  join public.membership_roles r on r.membership_id = m.id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and m.id <> new.id
    and m.profile_id is distinct from new.profile_id
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'join_requests');
  return new;
exception when others then
  -- Die Aufnahme gilt, auch wenn die Meldung an die Leitung scheitert.
  raise warning 'Aufnahmemeldung an die Vereinsleitung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$function$
;

-- ---------------------------------------------------------------- notify_new_device
CREATE OR REPLACE FUNCTION public.notify_new_device()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  computed_hash text;
  is_new boolean;
  v_sprache text;
begin
  computed_hash := md5(coalesce(new.user_agent, '') || '|' || coalesce(host(new.ip), ''));
  select not exists (
    select 1 from public.known_devices where profile_id = new.user_id and device_hash = computed_hash
  ) into is_new;
  insert into public.known_devices (profile_id, device_hash, user_agent, last_seen_at)
  values (new.user_id, computed_hash, new.user_agent, now())
  on conflict (profile_id, device_hash) do update set last_seen_at = now();

  if is_new then
    begin
      if exists (select 1 from public.club_memberships where profile_id = new.user_id and status = 'active')
         and public.meldung_erlaubt(new.user_id, 'security') then
        select coalesce(p.language, 'de') into v_sprache from public.profiles p where p.id = new.user_id;
        v_sprache := coalesce(v_sprache, 'de');
        /* 'sicherheit' ohne Kennung: Die App oeffnet Profil > Konto &
           Sicherheit - dort meldet man fremde Geraete ab. */
        /* Rezept (Stufe B): reine Schluessel, keine Werte. */
        insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                               titel_schluessel, text_schluessel, werte, sprache)
        values (new.user_id, null, 'security',
                public.meldung_rendern('geraet.neu.titel', v_sprache, '{}'::jsonb),
                public.meldung_rendern('geraet.neu.text', v_sprache, '{}'::jsonb),
                'sicherheit', null,
                'geraet.neu.titel', 'geraet.neu.text', '{}'::jsonb, v_sprache);
      end if;
    exception when others then
      -- Auch meldung_erlaubt gehoert in diesen Block: Es wandelt die
      -- gespeicherte Einstellung per ::boolean um - ein kaputter Wert wuerde
      -- sonst die Anmeldung selbst abbrechen.
      raise warning 'Geraetemeldung fehlgeschlagen: %', sqlerrm;
    end;
  end if;
  return new;
end;
$function$
;

-- ---------------------------------------------------------------- notify_family_link_created
CREATE OR REPLACE FUNCTION public.notify_family_link_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_andere uuid;
  v_profil uuid;
  v_wer    text;
  v_werte  jsonb;
begin
  if new.bestaetigt then
    perform public.notify_uebersetzt(new.first_membership_id,  'family', 'familie.titel', 'familie.text',
      '{}'::jsonb, jsonb_build_object('ziel_art', 'familie'));
    perform public.notify_uebersetzt(new.second_membership_id, 'family', 'familie.titel', 'familie.text',
      '{}'::jsonb, jsonb_build_object('ziel_art', 'familie'));
    return new;
  end if;

  v_andere := case when new.angefragt_von = new.first_membership_id then new.second_membership_id
                   else new.first_membership_id end;
  select m.profile_id into v_profil from public.club_memberships m where m.id = v_andere;
  select m.display_name into v_wer from public.club_memberships m where m.id = new.angefragt_von;

  /* Rezept (Stufe B): Das Ersatzwort steht als Baustein {"s": ...} in werte
     und wird erst beim Rendern in der Empfaengersprache aufgeloest - in
     notify_uebersetzt ebenso wie beim direkten Schreiben unten. */
  v_werte := jsonb_build_object('wer', coalesce(to_jsonb(v_wer), jsonb_build_object('s', 'allg.jemand')));

  if v_profil is not null then
    perform public.notify_uebersetzt(v_andere, 'family', 'familie.anfrage.titel', 'familie.anfrage.text',
      v_werte,
      jsonb_build_object('ziel_art', 'familie'));
  else
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                           titel_schluessel, text_schluessel, werte, sprache)
    select distinct m.profile_id, new.club_id, 'family',
           public.meldung_rendern('familie.anfrage.titel', coalesce(p.language, 'de'), v_werte),
           public.meldung_rendern('familie.anfrage.text', coalesce(p.language, 'de'), v_werte),
           'mitglied', v_andere,
           'familie.anfrage.titel', 'familie.anfrage.text', v_werte, coalesce(p.language, 'de')
      from public.membership_roles r
      join public.club_memberships m on m.id = r.membership_id
      left join public.profiles p on p.id = m.profile_id
     where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
       and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
       and m.profile_id is distinct from auth.uid()
       and public.meldung_erlaubt(m.profile_id, 'family');
  end if;
  return new;
exception when others then
  raise warning 'Familienmeldung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$function$
;

-- ---------------------------------------------------------------- leitung_melden
CREATE OR REPLACE FUNCTION public.leitung_melden(p_club uuid, p_art text, p_schluessel text, p_werte jsonb DEFAULT '{}'::jsonb, p_ausser uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
/* Meldet der Vereinsleitung (vereinsadmin, sysadmin, organisator - dieselbe
   Menge wie notifyClubAdmins/notify_many) eine Aktion aus der App. Anders als
   notify_many kommen keine fertigen Saetze vom Client: Titel und Text entstehen
   hier aus meldungstexte, je Empfaenger in SEINER Sprache, das Datum im Muster
   dieser Sprache.
   p_werte: wer, fahrzeug, von, bis (von/bis als 'YYYY-MM-DD').
   p_ausser: Mitgliedschafts- ODER Profil-Kennung, die nichts bekommt (die
   betroffene Person). Der Aufrufer selbst bekommt nie etwas.
   Einstellungen wie bei notify_many: notify() und warteschlange_in_glocke
   pruefen beide notification_master und notification_preferences[p_art] -
   genau das ist meldung_erlaubt. Rueckgabe: Anzahl geschriebener Meldungen. */
declare
  v_ich      uuid := auth.uid();
  v_werte    jsonb := case when jsonb_typeof(p_werte) = 'object' then p_werte else '{}'::jsonb end;
  v_wer      text;
  v_fahrzeug text;
  v_von_roh  text;
  v_bis_roh  text;
  v_von      date;
  v_bis      date;
  v_anzahl   integer;
begin
  if v_ich is null then
    raise exception 'nicht_angemeldet' using errcode = '42501';
  end if;
  if p_art is null or p_art not in ('vehicle', 'membership') then
    raise exception 'meldungsart_nicht_erlaubt' using errcode = '42501';
  end if;
  if p_schluessel is null or p_schluessel not in
     ('fahrzeug.gebucht', 'mitglied.gesperrt', 'mitglied.beendet', 'mitglied.entfernt') then
    raise exception 'schluessel_nicht_erlaubt' using errcode = '22023';
  end if;
  /* Art und Text gehoeren zusammen: Fahrzeug nur mit Fahrzeugtext, Mitglied
     nur mit Mitgliedstext. Sonst liesse sich eine Meldung mit fremder Art
     (und damit an der falschen Einstellung vorbei) verschicken. */
  if (p_art = 'vehicle') <> (p_schluessel = 'fahrzeug.gebucht') then
    raise exception 'meldungsart_passt_nicht' using errcode = '22023';
  end if;
  if p_club is null or not public.is_club_member(p_club) then
    raise exception 'nicht_im_verein' using errcode = '42501';
  end if;
  /* Sperren, Beenden und Entfernen kann nur die Vereinsleitung - also darf
     auch nur sie diese Meldungen ausloesen (Gegenpruefung 16.09.2026). */
  if p_art = 'membership' and not exists (
       select 1 from public.club_memberships ich
         join public.membership_roles r on r.membership_id = ich.id
        where ich.club_id = p_club and ich.profile_id = v_ich and ich.status = 'active'
          and r.role in ('vereinsadmin', 'sysadmin', 'organisator')) then
    raise exception 'nur_vereinsleitung' using errcode = '42501';
  end if;

  v_wer      := left(nullif(btrim(v_werte ->> 'wer'), ''), 200);
  v_fahrzeug := left(coalesce(btrim(v_werte ->> 'fahrzeug'), ''), 200);
  v_von_roh  := left(coalesce(btrim(v_werte ->> 'von'), ''), 40);
  v_bis_roh  := left(coalesce(btrim(v_werte ->> 'bis'), ''), 40);
  /* Ein Datum, das sich nicht lesen laesst, bleibt als Rohtext stehen - die
     Meldung soll daran nicht scheitern. */
  if v_von_roh ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then
    begin v_von := left(v_von_roh, 10)::date; exception when others then v_von := null; end;
  end if;
  if v_bis_roh ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then
    begin v_bis := left(v_bis_roh, 10)::date; exception when others then v_bis := null; end;
  end if;

  /* Rezept (Stufe B): werte ist unabhaengig von der Sprache - Ersatzwort als
     Baustein {"s": ...}, lesbares Datum als {"tag": 'YYYY-MM-DD', "jahr": true};
     Name, Fahrzeug und nicht lesbares Datum bleiben Rohtext. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select m.profile_id, p_club, p_art,
         left(public.meldung_rendern(p_schluessel || '.titel', w.sprache, w.werte), 200),
         left(public.meldung_rendern(p_schluessel || '.text',  w.sprache, w.werte), 1000),
         null, null,
         p_schluessel || '.titel', p_schluessel || '.text', w.werte, w.sprache
    from public.club_memberships m
    left join public.profiles p on p.id = m.profile_id
    cross join lateral (
      select coalesce(p.language, 'de') as sprache
    ) s
    cross join lateral (
      select s.sprache,
             jsonb_build_object(
               'wer',      coalesce(to_jsonb(v_wer), jsonb_build_object('s', 'allg.jemand')),
               'fahrzeug', v_fahrzeug,
               'von',      case when v_von is not null
                                then jsonb_build_object('tag', to_char(v_von::timestamp, 'YYYY-MM-DD'), 'jahr', true)
                                else to_jsonb(v_von_roh) end,
               'bis',      case when v_bis is not null
                                then jsonb_build_object('tag', to_char(v_bis::timestamp, 'YYYY-MM-DD'), 'jahr', true)
                                else to_jsonb(v_bis_roh) end) as werte
    ) w
   where m.club_id = p_club
     and m.status = 'active'
     and m.profile_id is not null
     and m.profile_id <> v_ich
     and (p_ausser is null or (m.id <> p_ausser and m.profile_id <> p_ausser))
     and exists (select 1 from public.membership_roles r
                  where r.membership_id = m.id
                    and r.role in ('vereinsadmin', 'sysadmin', 'organisator'))
     and public.meldung_erlaubt(m.profile_id, p_art);

  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$function$
;

-- ================================================================ Pruefung (nur lesend)
-- Erwartet: rumpfe = 9, mit_rendern = 9, mit_rezept = 9, mit_meldungstext = 0,
-- mit_meldung_datum = 0, definer = 9, rechte_unveraendert = 9, config_unveraendert = 9,
-- ausloeser = 8 (leitung_melden und entscheide_fahrzeug_anfrage sind RPCs;
-- vehicle_bookings hat zwei Ausloeser auf fahrzeuganfrage_melden).
with soll(name, args, acl, config) as (values
  ('protokoll_melden', '', 'postgres=X/postgres', 'search_path=""'),
  ('protokollaufgabe_zuweisung_melden', '', 'postgres=X/postgres', 'search_path=""'),
  ('fahrzeuganfrage_melden', '', '=X/postgres,postgres=X/postgres,authenticated=X/postgres', 'search_path=""'),
  ('entscheide_fahrzeug_anfrage', 'target_booking uuid, annehmen boolean', 'postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres', 'search_path=""'),
  ('beitrittsanfrage_melden', '', '=X/postgres,postgres=X/postgres,authenticated=X/postgres', 'search_path=public'),
  ('aufnahme_leitung_melden', '', 'postgres=X/postgres', 'search_path=""'),
  ('notify_new_device', '', '=X/postgres,postgres=X/postgres,authenticated=X/postgres', 'search_path=public'),
  ('notify_family_link_created', '', '=X/postgres,postgres=X/postgres,authenticated=X/postgres', 'search_path=""'),
  ('leitung_melden', 'p_club uuid, p_art text, p_schluessel text, p_werte jsonb, p_ausser uuid', 'postgres=X/postgres,authenticated=X/postgres', 'search_path=""')
), ist as (
  select s.*, p.oid, p.prosrc, p.prosecdef,
         coalesce(array_to_string(p.proacl, ','), '<default>') as ist_acl,
         array_to_string(p.proconfig, ',') as ist_config
    from soll s
    join pg_proc p on p.proname = s.name and p.pronamespace = 'public'::regnamespace
                  and pg_get_function_identity_arguments(p.oid) = s.args
)
select
  (select count(*) from ist) as rumpfe,
  (select count(*) from ist where prosrc like '%public.meldung_rendern(%') as mit_rendern,
  (select count(*) from ist where prosrc like '%titel_schluessel, text_schluessel, werte, sprache%') as mit_rezept,
  (select count(*) from ist where prosrc like '%meldungstext(%') as mit_meldungstext,
  (select count(*) from ist where prosrc like '%meldung_datum(%') as mit_meldung_datum,
  (select count(*) from ist where prosecdef) as definer,
  (select count(*) from ist where ist_acl = acl) as rechte_unveraendert,
  (select count(*) from ist where ist_config = config) as config_unveraendert,
  (select count(*) from pg_trigger t join ist on ist.oid = t.tgfoid where not t.tgisinternal) as ausloeser;

-- ================================================================ aufrufer/aufrufer.sql
-- Uebersetzung Stufe B - Aufrufer von notify_uebersetzt / notify
-- (Agent aufrufer, 16.09.2026). Rumpfe aus PROD (pg_get_functiondef), geaendert
-- NUR die Werte: Ersatzwoerter und Datum gehen als Baustein statt fertig
-- uebersetzt an notify_uebersetzt, damit glocke_neu_rendern sie spaeter in der
-- neuen Sprache neu bauen kann. Titel und Text beim INSERT bleiben gleich
-- (Nachweis: diff-<name>.txt, pruefung-gleichheit.sql).
--
-- REIHENFOLGE: erst NACH dem Kern (meldung_rendern, notify_uebersetzt mit
-- meldung_rendern und data._rezept, warteschlange_in_glocke mit _rezept) und in
-- DERSELBEN Migration/Transaktion. Mit dem alten notify_uebersetzt wuerde ein
-- Baustein als roher JSON-Text im Satz landen. Der Waechter unten bricht ab.
--
-- Unveraendert (nur Namen/Titel als Rohtext, keine Ersatzwoerter, kein Datum):
-- run_duty_task_due_reminders, run_birthday_reminders, notify_penalty_assigned,
-- notify_penalty_paid, notify_penalty_removed, notify_team_joined,
-- notify_vehicle_booking_cancelled.

do $waechter$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                  where n.nspname = 'public' and p.proname = 'meldung_rendern') then
    raise exception 'aufrufer.sql: public.meldung_rendern fehlt - zuerst den Kern einspielen';
  end if;
  if not exists (select 1 from pg_proc p
                  where p.oid = to_regprocedure('public.notify_uebersetzt(uuid,text,text,text,jsonb,jsonb)')
                    and strpos(p.prosrc, 'meldung_rendern') > 0 and strpos(p.prosrc, '_rezept') > 0) then
    raise exception 'aufrufer.sql: notify_uebersetzt rendert noch nicht mit meldung_rendern/_rezept - zuerst den Kern einspielen';
  end if;
  if not exists (select 1 from pg_proc p
                  where p.oid = to_regprocedure('public.warteschlange_in_glocke()')
                    and strpos(p.prosrc, '_rezept') > 0) then
    raise exception 'aufrufer.sql: warteschlange_in_glocke liest data._rezept noch nicht - zuerst den Kern einspielen';
  end if;
end
$waechter$;

-- ---------------------------------------------------------------- beitritt_melden
-- ACL in PROD: =X/postgres postgres=X/postgres authenticated=X/postgres (CREATE OR REPLACE behaelt sie)
CREATE OR REPLACE FUNCTION public.beitritt_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_verein  text;
begin
  if tg_op <> 'UPDATE' or old.status <> 'pending' or new.status = 'pending' then
    return new;
  end if;
  if new.profile_id is null then return new; end if;

  select c.name into v_verein from public.clubs c where c.id = new.club_id;
  /* Rezept (Stufe B): Fehlt der Vereinsname, geht das Ersatzwort als Baustein
     {"s": "allg.deinVerein"} mit - notify_uebersetzt rendert es in der
     Empfaengersprache, ein spaeterer Sprachwechsel uebersetzt es mit. */

  if new.status = 'active' then
    /* Angenommen: Die Meldung oeffnet den Verein, in den man gerade
       aufgenommen wurde - auch wenn in der App noch ein anderer offen ist. */
    perform public.notify_uebersetzt(new.id, 'join_requests',
      'beitritt.angenommen.titel', 'beitritt.angenommen.text',
      jsonb_build_object('verein', coalesce(to_jsonb(v_verein), jsonb_build_object('s', 'allg.deinVerein', 'w', '{}'::jsonb))),
      jsonb_build_object('ziel_art', 'verein', 'ziel_id', new.club_id));
  else
    /* Abgelehnt: bewusst ohne Ziel - siehe Kopf dieser Datei. */
    perform public.notify_uebersetzt(new.id, 'join_requests',
      'beitritt.abgelehnt.titel', 'beitritt.abgelehnt.text',
      jsonb_build_object('verein', coalesce(to_jsonb(v_verein), jsonb_build_object('s', 'allg.deinVerein', 'w', '{}'::jsonb))));
  end if;
  return new;
end;
$function$

;

-- ---------------------------------------------------------------- notify_carpool_joined
-- ACL in PROD: =X/postgres postgres=X/postgres authenticated=X/postgres (CREATE OR REPLACE behaelt sie)
CREATE OR REPLACE FUNCTION public.notify_carpool_joined()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  driver_id uuid;
  passenger_name text;
  v_event uuid;
begin
  select driver_membership_id, event_id into driver_id, v_event
    from public.carpools where id = new.carpool_id;
  select display_name into passenger_name from public.club_memberships where id = new.membership_id;
  if driver_id is not null and driver_id <> new.membership_id then
    /* Eine Fahrgemeinschaft gehoert zu einem Termin - dorthin fuehrt die
       Meldung. Vorher stand hier 'carpool_id', ein Name, den die Glocke gar
       nicht liest.
       Rezept (Stufe B): Das Ersatzwort geht als Baustein {"s": "allg.jemand"}
       mit und wird in der Sprache des Fahrers gerendert. */
    perform public.notify_uebersetzt(driver_id, 'carpool',
      'fahrgemeinschaft.neu.titel', 'fahrgemeinschaft.neu.text',
      jsonb_build_object('wer', coalesce(to_jsonb(passenger_name), jsonb_build_object('s', 'allg.jemand', 'w', '{}'::jsonb))),
      case when v_event is null then '{}'::jsonb
           else jsonb_build_object('ziel_art', 'termin', 'ziel_id', v_event) end);
  end if;
  return new;
end;
$function$

;

-- ---------------------------------------------------------------- run_carpool_gap_check
-- ACL in PROD: postgres=X/postgres service_role=X/postgres (CREATE OR REPLACE behaelt sie)
CREATE OR REPLACE FUNCTION public.run_carpool_gap_check()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled'
      and e.type = 'spiel'
      and coalesce(e.home_away, 'auswaerts') <> 'heim'
      and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
      and e.team_id is not null
      and not exists (select 1 from public.carpools c where c.event_id = e.id)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'carpool',
        'fahrgemeinschaft.fehlt.titel', 'fahrgemeinschaft.fehlt.text',
        jsonb_build_object('titel', ev.title, 'datum', jsonb_build_object('zeit', ev.starts_at, 'uhrzeit', false)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$function$

;

-- ---------------------------------------------------------------- run_duty_gap_check
-- ACL in PROD: postgres=X/postgres service_role=X/postgres (CREATE OR REPLACE behaelt sie)
CREATE OR REPLACE FUNCTION public.run_duty_gap_check()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled' and e.home_away = 'heim'
      and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
      and exists (select 1 from public.duty_tasks dt where dt.event_id = e.id and dt.assignee_membership_id is null and dt.done = false)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'duty',
        'helfer.gesucht.titel', 'helfer.gesucht.text',
        jsonb_build_object('titel', ev.title, 'datum', jsonb_build_object('zeit', ev.starts_at, 'uhrzeit', false)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$function$

;

-- ---------------------------------------------------------------- anzeige_melden
-- ACL in PROD: =X/postgres postgres=X/postgres authenticated=X/postgres (CREATE OR REPLACE behaelt sie)
CREATE OR REPLACE FUNCTION public.anzeige_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_mitglied record; v_sprache text;
begin
  if new.aktiv is not true then return new; end if;

  for v_mitglied in
    select m.id from public.club_memberships m
     where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
  loop
    /* Der Name der Anzeige ist ein Eigenname und bleibt; uebersetzt wird nur
       die Ueberschrift. Rezept (Stufe B) von Hand in data._rezept: nur der
       Titel hat einen Schluessel, der body bleibt beim Sprachwechsel stehen. */
    v_sprache := public.sprache_der_mitgliedschaft(v_mitglied.id);
    perform public.notify(v_mitglied.id, 'news'::text,
      public.meldung_rendern('sponsor.titel', v_sprache, '{}'::jsonb),
      coalesce(new.titel, '')::text,
      jsonb_build_object('_rezept', jsonb_build_object(
        'titel_schluessel', 'sponsor.titel',
        'text_schluessel',  null,
        'werte',            '{}'::jsonb,
        'sprache',          v_sprache)));
  end loop;
  return new;
end;
$function$

;
