-- Ziel im Repo: supabase/migrations/20261004160000_gegner_nachtragen.sql
--
-- Die Gegner der bestehenden Spiele nachtragen.
--
-- WARUM SIE FEHLTEN
-- Die Spalte events.opponent gibt es seit jeher, und die Ergebnisansicht
-- zeigt sie auch (app/page.tsx: ev.opponent || t("feld.gegner")). Nur konnte
-- sie niemand fuellen: Im Terminformular fehlte das Feld. Darum stand bei 54
-- von 70 Spielen "Gegner" statt eines Namens - gemeldet vom Betreiber am
-- 04.10.2026 mit Bildschirmfoto. Das Feld kommt mit derselben Auslieferung.
--
-- WARUM HIER TROTZDEM AUS DEM TITEL GELESEN WIRD
-- In app/page.tsx:1900 steht, aus dem Titel einen Gegner zu lesen sei Raten,
-- weil die Titel frei geschrieben sind. Das gilt fuer die ALLGEMEINE Regel in
-- der App und bleibt richtig. Fuer diese 54 Zeilen gilt es nicht: Sie stammen
-- alle aus dem Spielplan-Import (20260905030000) und tragen einheitliche
-- Titel. Nachgemessen am 04.10.2026, nur lesend:
--   54 Spiele ohne Gegner, 54 davon lesbar, 0 nicht lesbar.
-- Zwanzig verschiedene Vereine, alle aus der Regionalliga West.
--
-- Deshalb steht die Zerlegung HIER und nicht in der App: Sie gilt einmal, fuer
-- einen bekannten Bestand, mit gezaehltem Ergebnis - und nicht als Regel fuer
-- alles, was kuenftig eingetippt wird. Kuenftig fuellt das Formular die
-- Spalte.
--
-- UEBERSCHRIEBEN WIRD NICHTS: Die Bedingung fasst nur Zeilen an, deren
-- opponent leer ist. Die 16 Spiele, die schon einen Gegner tragen, bleiben
-- unberuehrt.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden - die Anzeige kann
-- opponent laengst.

update public.events e
   set opponent = case
         when e.title ~* '\m[Gg]egen\s' then btrim(regexp_replace(e.title, '^.*?\m[Gg]egen\s+', ''))
         when e.title ~* '\mvs\.?\s'    then btrim(regexp_replace(e.title, '^.*?\mvs\.?\s+', ''))
         when e.title ~* '\m[Bb]ei\s'   then btrim(regexp_replace(e.title, '^.*?\m[Bb]ei\s+', ''))
       end
 where e.type = 'spiel'
   and btrim(coalesce(e.opponent, '')) = ''
   and (e.title ~* '\m[Gg]egen\s' or e.title ~* '\mvs\.?\s' or e.title ~* '\m[Bb]ei\s');

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: ohne_gegner = 0, mit_gegner = 70, kein_rest_mit_praeposition = 0,
--           keine_leeren = 0, verschiedene_gegner = 20.
-- Der letzte Punkt ist die eigentliche Probe: Bliebe irgendwo ein "vs." oder
-- ein "gegen" im Namen stehen, waere die Zerlegung schiefgegangen.
select
  (select count(*) from public.events
    where type = 'spiel' and btrim(coalesce(opponent, '')) = '') as ohne_gegner,
  (select count(*) from public.events
    where type = 'spiel' and btrim(coalesce(opponent, '')) <> '') as mit_gegner,
  (select count(*) from public.events
    where type = 'spiel'
      and (opponent ~* '\m(gegen|vs|bei)\M' or opponent ~* '^[.:]')) as kein_rest_mit_praeposition,
  (select count(*) from public.events
    where type = 'spiel' and opponent is not null and btrim(opponent) = '') as keine_leeren,
  (select count(distinct opponent) from public.events
    where type = 'spiel' and btrim(coalesce(opponent, '')) <> '') as verschiedene_gegner;
