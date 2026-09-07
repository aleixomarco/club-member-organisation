-- update_own_profile_settings gab es zweimal.
--
-- Eine Fassung mit 18 Parametern, eine mit 19 - die neuere kann zusaetzlich
-- show_birthday. Beide standen nebeneinander in der Datenbank.
--
-- WARUM DAS GEFAEHRLICH IST
-- PostgREST sucht die passende Fassung anhand der NAMEN der uebergebenen
-- Felder aus. Die App schickt alle 19 und trifft damit die richtige - solange
-- sie alle 19 schickt. Vergisst irgendwann jemand new_show_birthday, landet
-- der Aufruf lautlos bei der alten Fassung, und die Einstellung "Geburtstag
-- anzeigen" wird beim Speichern der persoenlichen Daten stillschweigend
-- verworfen. Kein Fehler, keine Meldung - der Schalter springt einfach
-- zurueck.
--
-- Genau diese Sorte Doppelung hat heute schon einmal Schaden angerichtet:
-- zwei Saetze Meldungsfunktionen nebeneinander, einer lebendig, einer tot,
-- und die Benachrichtigungsschalter waren monatelang wirkungslos.
--
-- GEPRUEFT VOR DEM LOESCHEN
-- Die App ruft update_own_profile_settings an genau einer Stelle
-- (ProfileDataSettings) und uebergibt dort alle 19 Felder einschliesslich
-- new_show_birthday. Die 18er-Fassung wird von nichts aufgerufen: nicht aus
-- der App, nicht aus einer anderen Datenbankfunktion, nicht aus einem
-- Ausloeser.
drop function if exists public.update_own_profile_settings(
  uuid, text, text, text, text[], text[], date, text, text, text, text, text, text, text,
  boolean, jsonb, integer, text);

select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='update_own_profile_settings') as fassungen_uebrig,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='update_own_profile_settings'
      and p.prosrc like '%show_birthday%') as kann_geburtstag;
