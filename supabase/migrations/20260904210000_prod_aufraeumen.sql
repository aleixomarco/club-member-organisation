-- Produktion aufräumen: nur ERG Iserlohn mit Spielen und Trainings bleibt
--
-- Auftrag des Betreibers am 04.09.2026: "ERG Iserlohn kann bestehen bleiben
-- mit den Spielen und Trainingseinheiten", alles andere weg, "auch user".
--
-- BEHALTEN, mit Begründung:
--   ERG Iserlohn                 - ausdrücklich gewünscht
--   dessen Mannschaften          - events.team_id ist "on delete set null".
--                                  Ohne Mannschaft verlieren die Spiele ihre
--                                  Zuordnung und erscheinen in der App nicht
--                                  mehr - die Zeilen wären da, sichtbar wären
--                                  sie nicht.
--   dessen Spiele und Trainings  - ausdrücklich gewünscht
--   SV Musterstadt komplett      - der Apple-Prüfzugang braucht einen Verein
--                                  MIT Inhalten. Ein leerer war schon einmal
--                                  Ablehnungsgrund (Richtlinie 1.2).
--   demo@idbranding.de           - vom Betreiber bestätigt: bleibt
--   aleixo.marco@idbranding.de   - sonst käme der Betreiber nicht mehr in
--                                  seine eigene App. Wer das doch will,
--                                  löscht es hinterher in zehn Sekunden;
--                                  umgekehrt gibt es kein Zurück.
--
-- GELÖSCHT:
--   alle übrigen Personenprofile und deren Mitgliedschaften
--   in ERG Iserlohn: News, Umfragen, Protokolle, Aufgaben, Nachrichten
--   in ERG Iserlohn: Termine vom Typ "event" (Vereins-Events)
--
-- KEINE SICHERUNG VORHANDEN. Der Betreiber hat das ausdrücklich so gewählt.
-- Dieses Skript läuft in einer Transaktion: Bricht etwas ab, bleibt alles
-- unverändert. Was es aber erfolgreich löscht, ist endgültig fort.

do $$
declare
  v_erg   uuid;
  v_demo  uuid := 'd0000000-0000-4000-a000-000000000001';
begin
  select id into v_erg from public.clubs where id <> v_demo order by created_at limit 1;
  if v_erg is null then
    raise exception 'Kein zweiter Verein gefunden - Abbruch, damit nichts Falsches passiert.';
  end if;

  /* Profile, die bleiben: die beiden benannten Konten. Erkannt über die
     E-Mail in club_memberships, weil profiles keine E-Mail führt. */
  create temporary table behalten_profile (id uuid) on commit drop;
  insert into behalten_profile
  select distinct m.profile_id
    from public.club_memberships m
   where m.profile_id is not null
     and lower(m.email) in ('demo@idbranding.de', 'aleixo.marco@idbranding.de');

  /* Sicherheitsnetz: Findet sich keines der beiden, wird nichts gelöscht.
     Ein leeres behalten_profile würde sonst ALLE Konten mitnehmen. */
  if (select count(*) from behalten_profile) = 0 then
    raise exception 'Weder Betreiber- noch Pruefkonto gefunden - Abbruch.';
  end if;

  -- Inhalte von ERG Iserlohn, die nicht Spiel oder Training sind
  delete from public.messages    where channel_id in (select id from public.channels where club_id = v_erg);
  delete from public.news_posts  where club_id = v_erg;
  delete from public.polls       where club_id = v_erg;
  delete from public.protocols   where club_id = v_erg;
  delete from public.club_tasks  where club_id = v_erg;
  delete from public.events      where club_id = v_erg and type = 'event';

  -- Mitgliedschaften aller uebrigen Personen (Kindtabellen haengen per cascade)
  delete from public.club_memberships
   where profile_id is null
      or profile_id not in (select id from behalten_profile);

  -- Und die Profile selbst. auth.users loescht profiles per cascade mit.
  delete from auth.users
   where id not in (select id from behalten_profile);
end $$;

-- Kontrolle
select 'clubs' as tabelle, count(*) from public.clubs
union all select 'profiles', count(*) from public.profiles
union all select 'club_memberships', count(*) from public.club_memberships
union all select 'teams', count(*) from public.teams
union all select 'events', count(*) from public.events
union all select 'messages', count(*) from public.messages;
