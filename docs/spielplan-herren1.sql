-- Spielplan Herren 1, Regionalliga West, Saison 2026/27
--
-- In PROD ausführen. Wiederholbar: Ein Spiel wird nur angelegt, wenn zu
-- derselben Mannschaft, Art und Anstoßzeit noch keines existiert. Zweimal
-- ausführen erzeugt also keine Dubletten.
--
-- Zeiten stehen als Europe/Berlin und werden von Postgres korrekt in UTC
-- abgelegt - die Sommerzeitumstellung Ende Oktober ist damit berücksichtigt.
--
-- Der Ort bleibt leer: Er steht nicht im Spielplan. Trag ihn in der App nach,
-- oder setze ihn hier ein, bevor du ausführst.

with verein as (
  select id from public.clubs where name ilike '%ERG%Iserlohn%' or short_name ilike 'ERGI' limit 1
),
mannschaft as (
  select t.id from public.teams t, verein v
  where t.club_id = v.id and t.name ilike 'Herren 1%' limit 1
),
spiele(anstoss, gegner, heim) as (values
  -- Hinrunde 2026
  (timestamptz '2026-09-12 16:00 Europe/Berlin', 'IGR Remscheid II',        false),
  (timestamptz '2026-09-26 16:00 Europe/Berlin', 'RSC Cronenberg II',       false),
  (timestamptz '2026-10-11 13:00 Europe/Berlin', 'RC de Lichtstad',         true ),
  (timestamptz '2026-10-18 16:00 Europe/Berlin', 'SK Germania Herringen II',false),
  (timestamptz '2026-10-25 16:00 Europe/Berlin', 'RESG Walsum II',          true ),
  (timestamptz '2026-11-15 16:00 Europe/Berlin', 'HSV Krefeld II',          true ),
  (timestamptz '2026-11-29 16:00 Europe/Berlin', 'RHC Recklinghausen II',   true ),
  (timestamptz '2026-12-06 16:00 Europe/Berlin', 'SC Moskitos Wuppertal',   false),
  -- Rückrunde 2027
  (timestamptz '2027-01-24 16:00 Europe/Berlin', 'HSV Krefeld I',           false),
  (timestamptz '2027-02-06 16:00 Europe/Berlin', 'RHC Recklinghausen II',   false),
  (timestamptz '2027-02-07 16:00 Europe/Berlin', 'IGR Remscheid II',        true ),
  (timestamptz '2027-02-21 16:00 Europe/Berlin', 'RESG Walsum II',          false),
  (timestamptz '2027-03-07 13:00 Europe/Berlin', 'RC de Lichtstad',         false),
  (timestamptz '2027-03-21 16:00 Europe/Berlin', 'SK Germania Herringen II',true ),
  (timestamptz '2027-04-04 16:00 Europe/Berlin', 'HSV Krefeld II',          false),
  (timestamptz '2027-04-11 11:00 Europe/Berlin', 'RSC Cronenberg II',       true ),
  (timestamptz '2027-04-25 16:00 Europe/Berlin', 'TuS Düsseldorf-Nord II',  false),
  (timestamptz '2027-05-02 16:00 Europe/Berlin', 'SC Moskitos Wuppertal',   true ),
  (timestamptz '2027-05-30 16:00 Europe/Berlin', 'TuS Düsseldorf-Nord II',  true ),
  (timestamptz '2027-06-06 16:00 Europe/Berlin', 'HSV Krefeld I',           true )
)
insert into public.events (club_id, team_id, type, status, title, starts_at, ends_at, opponent, home_away)
select
  v.id,
  m.id,
  'spiel',
  'scheduled',
  case when s.heim then 'ERGI – ' || s.gegner else s.gegner || ' – ERGI' end,
  s.anstoss,
  s.anstoss + interval '2 hours',
  s.gegner,
  case when s.heim then 'heim' else 'auswaerts' end
from spiele s, verein v, mannschaft m
where not exists (
  select 1 from public.events e
  where e.team_id = m.id and e.type = 'spiel' and e.starts_at = s.anstoss
);

-- Kontrolle
select to_char(e.starts_at at time zone 'Europe/Berlin', 'DD.MM.YYYY HH24:MI') as anstoss,
       e.title, e.home_away
from public.events e
join public.teams t on t.id = e.team_id
where t.name ilike 'Herren 1%' and e.type = 'spiel'
order by e.starts_at;
