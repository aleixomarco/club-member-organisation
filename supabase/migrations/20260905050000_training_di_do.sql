-- Training Herren 1: dienstags und donnerstags, 19:30 bis 22:00
--
-- Zeitraum: 08.09.2026 bis 30.06.2027 - vom Dienstag vor dem ersten Spieltag
-- (12.09.) bis zum Monatsende nach dem letzten Spiel (06.06.). Das ergibt
-- 43 Dienstage und 42 Donnerstage, zusammen 85 Termine.
--
-- Keine Kollision mit dem Spielplan: Alle zwanzig Partien liegen samstags oder
-- sonntags.
--
-- Ferien und Feiertage sind NICHT ausgespart - der Verband gibt sie nicht vor
-- und ich kenne eure Hallenzeiten nicht. Einzelne Termine lassen sich in der
-- App absagen oder loeschen; die ganze Reihe traegt eine gemeinsame series_id,
-- ueber die sie sich auch am Stueck entfernen laesst.
--
-- Zeiten sind Ortszeit und werden ueber AT TIME ZONE 'Europe/Berlin' in
-- timestamptz umgerechnet - ohne das laege alles zwei Stunden daneben.

do $$
declare
  v_club   uuid := 'e7ccf0d5-2835-445d-b94e-af7127165fe1';  -- ERG Iserlohn
  v_team   uuid;
  v_wer    uuid;
  v_serie  uuid := gen_random_uuid();
  v_von    date := '2026-09-08';
  v_bis    date := '2027-06-30';
  v_anzahl integer;
begin
  select id into v_team from public.teams where club_id = v_club and name = 'Herren 1';
  if v_team is null then
    raise exception 'Mannschaft "Herren 1" nicht gefunden.';
  end if;

  select profile_id into v_wer from public.club_memberships
   where club_id = v_club and profile_id is not null order by created_at limit 1;

  insert into public.events
    (club_id, team_id, type, status, title, description, starts_at, ends_at, location, created_by, series_id)
  select
    v_club, v_team, 'training', 'scheduled',
    'Training Herren 1',
    'Woechentliches Mannschaftstraining',
    ((d::date + time '19:30') at time zone 'Europe/Berlin'),
    ((d::date + time '22:00') at time zone 'Europe/Berlin'),
    'Hemberghalle, Iserlohn',
    v_wer,
    v_serie
  from generate_series(v_von, v_bis, interval '1 day') as d
  /* isodow: Montag = 1 ... Sonntag = 7. Dienstag ist 2, Donnerstag 4. */
  where extract(isodow from d)::int in (2, 4);

  get diagnostics v_anzahl = row_count;
  raise notice '% Trainingstermine angelegt, Serie %.', v_anzahl, v_serie;
end $$;

-- Kontrolle: die ersten und letzten Termine der Reihe
select to_char(e.starts_at at time zone 'Europe/Berlin', 'Dy DD.MM.YYYY HH24:MI') as beginn,
       to_char(e.ends_at   at time zone 'Europe/Berlin', 'HH24:MI')               as ende,
       e.location
  from public.events e
  join public.teams t on t.id = e.team_id
 where t.name = 'Herren 1' and e.type = 'training'
 order by e.starts_at
 limit 6;
