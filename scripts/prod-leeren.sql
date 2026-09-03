-- ACHTUNG: Dieses Skript löscht Produktionsdaten. Es ist NICHT umkehrbar.
--
-- Stand der Datenbank am 04.09.2026, bevor irgendetwas gelöscht wurde:
--     2 Vereine
--    32 Personenprofile
--    47 Mitgliedschaften
--     9 Mannschaften, 42 Zuordnungen
--   177 Termine
--     9 Chat-Nachrichten, 11 Kanäle
--     4 News, 3 Umfragen, 1 Protokoll, 5 Aufgaben
--   110 Rollenzuweisungen
--     4 Vereinsabos
--
-- Diese Zahlen sind kein leeres Testsystem. Wer das hier ausführt, vernichtet
-- die Konten von rund 30 Menschen und die Terminplanung eines laufenden
-- Vereins. Es gibt kein Zurück und keine Sicherung, die das auffängt.
--
-- ----------------------------------------------------------------- Vorher
--
-- 1. SICHERUNG ZIEHEN. Im Supabase-Dashboard unter Database > Backups, oder
--    per pg_dump. Ohne Sicherung nicht ausführen.
--
-- 2. Entscheiden, ob der Apple-Prüfzugang bleiben soll. Steht er in den
--    App-Prüfungsinformationen - und das tut er -, wird JEDES künftige Update
--    damit geprüft. Ohne ihn meldet der Prüfer sich an und sieht nichts;
--    das war schon einmal der Ablehnungsgrund nach Richtlinie 1.2.
--
-- 3. Die App ist seit dem 03.09.2026 im Store (READY_FOR_SALE). Wer sich
--    seither registriert hat, verliert sein Konto ohne Vorwarnung.

begin;

-- Was NICHT gelöscht wird: der Demo-Verein für die Apple-Prüfung.
-- Soll auch der weg, diese Zeile auf eine unmögliche Kennung setzen.
create temporary table behalten (club_id uuid);
insert into behalten values ('d0000000-0000-4000-a000-000000000001');

-- Reihenfolge egal, wo Fremdschlüssel "on delete cascade" tragen - die
-- Kindtabellen gehen mit dem Verein. Aufgeräumt wird trotzdem ausdrücklich,
-- damit sichtbar ist, was verschwindet.
delete from public.messages          where channel_id in (select id from public.channels where club_id not in (select club_id from behalten));
delete from public.channels          where club_id not in (select club_id from behalten);
delete from public.events            where club_id not in (select club_id from behalten);
delete from public.news_posts        where club_id not in (select club_id from behalten);
delete from public.polls             where club_id not in (select club_id from behalten);
delete from public.protocols         where club_id not in (select club_id from behalten);
delete from public.club_tasks        where club_id not in (select club_id from behalten);
delete from public.team_members      where team_id in (select id from public.teams where club_id not in (select club_id from behalten));
delete from public.teams             where club_id not in (select club_id from behalten);
delete from public.membership_roles  where membership_id in (select id from public.club_memberships where club_id not in (select club_id from behalten));
delete from public.club_memberships  where club_id not in (select club_id from behalten);
delete from public.clubs             where id not in (select club_id from behalten);

-- Profile ohne jede Mitgliedschaft. Das trifft die Personen selbst.
-- Auskommentiert, weil es der schwerste Schritt ist: Ein Profil zu löschen
-- entfernt auch das Anmeldekonto in auth.users.
-- delete from auth.users where id in (
--   select p.id from public.profiles p
--   where not exists (select 1 from public.club_memberships m where m.profile_id = p.id)
-- );

-- Kontrolle VOR dem Bestätigen. Sieht das Ergebnis falsch aus: rollback;
select 'clubs' as tabelle, count(*) from public.clubs
union all select 'profiles', count(*) from public.profiles
union all select 'club_memberships', count(*) from public.club_memberships
union all select 'events', count(*) from public.events
union all select 'messages', count(*) from public.messages;

-- Erst wenn die Zahlen stimmen:
--   commit;
-- Sonst:
--   rollback;
rollback;
