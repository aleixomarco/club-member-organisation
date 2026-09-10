-- Rückbau eines Rückbaus: Die Aktions-Zeitprüfung war weg.
--
-- Migration 20260910050000 hat anzeige_fuer_platz und anzeigen_fuer_verein
-- neu geschrieben, um telefon und email durchzureichen. Dabei habe ich den
-- Funktionsrumpf aus der URSPRÜNGLICHEN Migration (20260831150000) kopiert -
-- und damit eine zehn Tage jüngere Korrektur (20260831210000_aktionszeitraum)
-- stillschweigend zurückgenommen. Verloren gingen:
--
--   1. aktion_laeuft - die Prüfung, OB die Aktion gerade läuft. Ohne sie kommt
--      aktion_titel immer zurück, und im Inserat steht
--      "laeuft = !!anzeige.aktion_titel". Eine beendete Rabattaktion erschien
--      dadurch für immer als laufend, samt Knopf "Zur Aktion".
--   2. Die Spalte aktion_bis. Ohne sie ist anzeige.aktion_bis undefined, und
--      die Zeile "Läuft noch bis ..." verschwand aus jedem Inserat.
--
-- Die Oberfläche hatte sich ausdrücklich auf diese Funktion verlassen; im
-- Kommentar an SponsorSlot steht: "Ob die Aktion laeuft, hat die Datenbank
-- schon entschieden. Hier steht deshalb keine zweite, moeglicherweise
-- abweichende Rechnung." Genau dieser Vertrag war gebrochen.
--
-- LEHRE: Wer eine Funktion mit drop+create ersetzt, muss ihren AKTUELLEN
-- Rumpf nehmen - pg_get_functiondef() aus der Datenbank oder die zuletzt
-- ändernde Migration -, niemals die erste Fassung aus der Datei, die sie
-- ursprünglich angelegt hat. Zwischen beiden können Korrekturen liegen, und
-- ein drop+create nimmt sie wortlos zurück.

drop function if exists public.anzeigen_fuer_verein(uuid);
drop function if exists public.anzeige_fuer_platz(uuid, text);

create or replace function public.anzeige_fuer_platz(target_club uuid, ziel_platz text)
returns table (
  id uuid, herkunft text, titel text, text text, bild_pfad text, ziel_url text,
  telefon text, email text,
  aktion_titel text, aktion_text text, aktion_url text, aktion_bis timestamptz,
  laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  with laufend as (
    select a.*,
           case when a.club_id is null then 'betreiber' else 'verein' end as herkunft,
           /* Die Aktion hat einen eigenen Zeitraum innerhalb der Laufzeit des
              Sponsors. Läuft sie nicht, kommen ihre Felder leer zurück - der
              Sponsor bleibt stehen, der Aktionsknopf verschwindet von selbst. */
           (a.aktion_titel is not null
            and coalesce(a.aktion_von, a.laeuft_von) <= now()
            and a.aktion_bis > now()) as aktion_laeuft
      from public.anzeigen a
     where a.platz = ziel_platz
       and a.aktiv
       and a.laeuft_von <= now()
       and (a.laeuft_bis is null or a.laeuft_bis > now())
       and (
         a.club_id is null
         or (a.club_id = target_club
             and exists (select 1 from public.clubs c
                          where c.id = target_club and c.sponsoring_freigeschaltet))
       )
  )
  select l.id, l.herkunft, l.titel, l.text, l.bild_pfad, l.ziel_url,
         l.telefon, l.email,
         case when l.aktion_laeuft then l.aktion_titel end,
         case when l.aktion_laeuft then l.aktion_text end,
         case when l.aktion_laeuft then l.aktion_url end,
         case when l.aktion_laeuft then l.aktion_bis end,
         l.laeuft_bis
    from laufend l
   order by case when l.herkunft = 'verein' then 0 else 1 end,
            l.created_at desc
   limit 1;
$$;

grant execute on function public.anzeige_fuer_platz(uuid, text) to authenticated;

create or replace function public.anzeigen_fuer_verein(target_club uuid)
returns table (
  platz text, id uuid, herkunft text, titel text, text text, bild_pfad text,
  ziel_url text, telefon text, email text,
  aktion_titel text, aktion_text text, aktion_url text,
  aktion_bis timestamptz, laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.platz, a.id, a.herkunft, a.titel, a.text, a.bild_pfad,
         a.ziel_url, a.telefon, a.email,
         a.aktion_titel, a.aktion_text, a.aktion_url,
         a.aktion_bis, a.laeuft_bis
    from (values ('dashboard_top'), ('dashboard_bottom'), ('events_header'), ('profile_bottom')) as p(platz)
    cross join lateral public.anzeige_fuer_platz(target_club, p.platz) a;
$$;

grant execute on function public.anzeigen_fuer_verein(uuid) to authenticated;
