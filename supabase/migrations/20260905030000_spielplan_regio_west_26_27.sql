-- Spielplan Regionalliga West 2026/27 für ERG Iserlohn, Herren 1
--
-- Quelle: "Spielplan_26_27_-_Regio 2.pdf" des Verbands. Zwanzig Partien,
-- zehn zu Hause, zehn auswärts.
--
-- Zur Datumsermittlung: Eine Überschrift "Spieltag N - TT.MM.JJJJ" setzt das
-- Datum für die folgenden Zeilen; eine nackte Datumszeile mitten im Block
-- verschiebt alle Zeilen danach. Sieben Partien tragen dadurch ein anderes
-- Datum als ihr Spieltag - sie sind unten mit dem Grund vermerkt.
--
-- Zwei unabhängige Durchgänge haben denselben Auszug ergeben; die Zuordnung
-- der drei überschriftslosen Tabellen (Nr. 1-5, 6-9, 56-61) ist über die
-- laufende Nummerierung erschlossen und passt lückenlos: Spieltag 3 beginnt
-- bei 10, Spieltag 11 endet bei 55, Spieltag 13 beginnt bei 62.
--
-- Zeiten sind Ortszeit. In timestamptz umgerechnet über
-- "AT TIME ZONE 'Europe/Berlin'" - sonst läge alles zwei Stunden daneben.
-- Als Ende ist jeweils zwei Stunden nach Anpfiff eingetragen; das lässt sich
-- in der App je Termin ändern.

do $$
declare
  v_club   uuid := 'e7ccf0d5-2835-445d-b94e-af7127165fe1';  -- ERG Iserlohn
  v_team   uuid;
  v_wer    uuid;
  v_halle  text := 'Hemberghalle, Iserlohn';
  v_reihe  record;
  v_anzahl integer := 0;
begin
  if not exists (select 1 from public.clubs where id = v_club) then
    raise exception 'Verein % nicht gefunden.', v_club;
  end if;

  select id into v_team from public.teams where club_id = v_club and name = 'Herren 1';
  if v_team is null then
    raise exception 'Mannschaft "Herren 1" gibt es in diesem Verein noch nicht - bitte zuerst anlegen.';
  end if;

  /* Als Ersteller das erste Mitglied des Vereins. created_by darf leer sein,
     ein Name ist aber schöner, wenn jemand den Termin später bearbeitet. */
  select profile_id into v_wer from public.club_memberships
   where club_id = v_club and profile_id is not null order by created_at limit 1;

  for v_reihe in
    select * from (values
      ('2026-09-12'::date, '16:00'::time, false, 'IGR Remscheid II',         'Spieltag 1'),
      ('2026-09-26',       '16:00',       false, 'RSC Cronenberg II',        'Spieltag 2'),
      ('2026-10-11',       '13:00',       true,  'RC de Lichtstad',          'Spieltag 4'),
      ('2026-10-18',       '16:00',       false, 'SK Germania Herringen II', 'Spieltag 5'),
      ('2026-10-25',       '16:00',       true,  'RESG Walsum II',           'Spieltag 3, verlegt'),
      ('2026-11-15',       '16:00',       true,  'HSV Krefeld II',           'Spieltag 6'),
      ('2026-11-29',       '16:00',       true,  'RHC Recklinghausen II',    'Spieltag 7, Sonntagstermin'),
      ('2026-12-06',       '16:00',       false, 'SC Moskitos Wuppertal',    'Spieltag 8'),
      ('2027-01-24',       '16:00',       false, 'HSV Krefeld I',            'Spieltag 11'),
      ('2027-02-06',       '16:00',       false, 'RHC Recklinghausen II',    'Spieltag 12, Samstag'),
      ('2027-02-07',       '16:00',       true,  'IGR Remscheid II',         'Spieltag 12'),
      ('2027-02-21',       '16:00',       false, 'RESG Walsum II',           'Spieltag 14'),
      ('2027-03-07',       '13:00',       false, 'RC de Lichtstad',          'Spieltag 15'),
      ('2027-03-21',       '16:00',       true,  'SK Germania Herringen II', 'Spieltag 16'),
      ('2027-04-04',       '16:00',       false, 'HSV Krefeld II',           'Spieltag 17'),
      ('2027-04-11',       '11:00',       true,  'RSC Cronenberg II',        'Spieltag 17, Anstoß 11:00 wegen Pokalfinale'),
      ('2027-04-25',       '16:00',       false, 'TuS Düsseldorf-Nord II',   'Spieltag 18'),
      ('2027-05-02',       '16:00',       true,  'SC Moskitos Wuppertal',    'Spieltag 18, verlegt'),
      ('2027-05-30',       '16:00',       true,  'TuS Düsseldorf-Nord II',   'Spieltag 21, verlegt'),
      ('2027-06-06',       '16:00',       true,  'HSV Krefeld I',            'Spieltag 22')
    ) as t(datum, zeit, heim, gegner, vermerk)
  loop
    insert into public.events
      (club_id, team_id, type, status, title, description, starts_at, ends_at, location, created_by, home_away)
    values (
      v_club, v_team, 'spiel', 'scheduled',
      case when v_reihe.heim then 'Heimspiel vs. ' || v_reihe.gegner
                             else 'Auswärtsspiel bei ' || v_reihe.gegner end,
      'Regionalliga West 2026/27 · ' || v_reihe.vermerk,
      ((v_reihe.datum + v_reihe.zeit) at time zone 'Europe/Berlin'),
      ((v_reihe.datum + v_reihe.zeit + interval '2 hours') at time zone 'Europe/Berlin'),
      case when v_reihe.heim then v_halle else v_reihe.gegner end,
      v_wer,
      case when v_reihe.heim then 'heim' else 'auswaerts' end
    );
    v_anzahl := v_anzahl + 1;
  end loop;

  raise notice '% Partien eingetragen.', v_anzahl;
end $$;

-- Kontrolle
select to_char(e.starts_at at time zone 'Europe/Berlin', 'DD.MM.YYYY HH24:MI') as anpfiff,
       e.home_away, e.title, e.location
  from public.events e
  join public.teams t on t.id = e.team_id
 where t.name = 'Herren 1' and e.type = 'spiel'
 order by e.starts_at;
