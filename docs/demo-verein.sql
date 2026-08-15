-- =====================================================================
-- DEMO-VEREIN "SV Musterstadt" fuer App-Store-Screenshots
-- Ausfuehren im Supabase SQL Editor (laeuft als Rolle postgres, RLS wird
-- dabei umgangen - genau deshalb koennen hier Zeilen entstehen, die ein
-- normaler Client wegen der Insert-Policies nie anlegen koennte).
-- Datei: /private/tmp/claude-501/-Users-marcoaleixo-Documents-Codex-2026-08-01/4d754b56-30ad-4d23-82ab-4e7265cd48fb/scratchpad/demo_verein_sv_musterstadt.sql
--
-- Grundsaetze dieses Skripts:
--   * Alle IDs sind fest verdrahtet, damit jeder erneute Lauf dieselben
--     Zeilen trifft (Upsert statt Dublette) - das Skript ist idempotent.
--   * Es werden ausschliesslich Zeilen mit diesen festen IDs bzw. Zeilen
--     mit club_id = Demo-Verein angefasst. Das einzige DELETE trifft die
--     Kapitaens- und Teammanager-Zeilen der vier Demo-Teams (Abschnitt 7);
--     es ist unvermeidbar, weil die dortigen PARTIELLEN Unique-Indizes
--     nicht als ON-CONFLICT-Arbiter taugen. Kein UPDATE auf Fremddaten,
--     kein Schreibzugriff auf auth.users.
--   * Alles ist erkennbar fiktiv (Verein, Personen, Gegner, Kennzeichen).
--
-- VORAUSSETZUNG (Abschnitt 1b prueft sie und bricht sonst sauber ab, bevor
-- irgendetwas geschrieben wird): Der Demo-Verein darf nicht bereits auf
-- anderem Weg entstanden sein - etwa ueber register_new_club() /
-- create_club_team() in der App oder eine fruehere Skriptfassung. Alle
-- Upserts hier arbitrieren ueber den Primaerschluessel; die zusaetzlichen
-- natuerlichen Schluessel der Tabellen loest ein fest verdrahteter
-- Primaerschluessel nicht auf:
--     clubs.slug unique, clubs_referral_code_unique on upper(referral_code),
--     teams unique (club_id, name),
--     club_memberships unique (club_id, membership_number),
--     club_subscriptions unique (provider, provider_subscription_id).
-- Trifft eine dieser Kombinationen auf eine bestehende Zeile mit ANDERER id,
-- greift ON CONFLICT nicht und die Anweisung bricht mit unique_violation ab -
-- der SQL-Editor fuehrt die Datei transaktional aus, also waere der GESAMTE
-- Lauf verloren. Auf teams stattdessen "on conflict (club_id, name)" zu
-- verwenden ist KEINE Loesung, weil die Abschnitte 7 und 8 auf den festen
-- Team-IDs aufbauen. Der Ausweg ist, den Altbestand einmal zu entfernen -
-- das kaskadiert ueber die FKs auf teams, club_memberships, events und
-- club_subscriptions und beruehrt keinen anderen Verein:
--     delete from public.clubs where id = 'd0000000-0000-4000-a000-000000000001';
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. KONFIGURATION: echtes Anmeldekonto
-- ---------------------------------------------------------------------
-- Hier die E-Mail des bereits existierenden Supabase-Kontos eintragen, das
-- den Demo-Verein spaeter als Vereinsadmin sehen soll. Das Konto wird NICHT
-- angelegt - existiert es nicht, ueberspringt Abschnitt 10 seinen Teil und
-- der Rest des Skripts laeuft trotzdem durch.
-- Als Session-Variable abgelegt statt als Literal weiter unten, damit die
-- Adresse nur an dieser einen Stelle am Skriptanfang steht.
select set_config('demo.admin_email', 'aleixo.marco@idbranding.de', false);

-- Protokolltabelle: der Supabase-SQL-Editor zeigt im Ergebnisbereich nur das
-- letzte Result-Set und echte Fehler an, aber KEINE NOTICE-Ausgaben. Ein
-- stiller Fehlschlag in einem der geschuetzten do-Bloecke (Abschnitte 9 und
-- 10) bliebe damit unsichtbar - das Skript meldete Erfolg, die Demo-Ansicht
-- waere leer. Jeder dieser Bloecke schreibt seine Meldung und die tatsaechlich
-- eingefuegte Zeilenzahl deshalb zusaetzlich hier hinein; Abschnitt 11 gibt
-- das Protokoll in der Pruefabfrage mit aus.
drop table if exists pg_temp.demo_log;
create temp table demo_log (
  lfd     serial primary key,
  bereich text,
  meldung text
);


-- ---------------------------------------------------------------------
-- 1b. VORPRUEFUNG (Abbruch statt halb geschriebenem Lauf)
-- ---------------------------------------------------------------------
-- Prueft genau die natuerlichen Schluessel, die der ON-CONFLICT-Arbiter (id)
-- nicht abdeckt. Lieber hier mit klarer Meldung abbrechen, als spaeter mitten
-- im Lauf mit einem nackten "duplicate key value violates unique constraint".
do $outer$
declare
  fremd text;
begin
  select string_agg(c.name || ' (id ' || c.id || ')', ', ')
    into fremd
  from public.clubs c
  where c.id <> 'd0000000-0000-4000-a000-000000000001'
    and (c.slug = 'sv-musterstadt-demo-2026' or upper(c.referral_code) = 'SVMDEMO2026');
  if fremd is not null then
    raise exception 'Slug sv-musterstadt-demo-2026 oder Referral-Code SVMDEMO2026 ist bereits von einem anderen Verein belegt: %. Bitte beides im Skriptkopf (Abschnitt 2) aendern.', fremd;
  end if;

  select string_agg(t.name || ' (id ' || t.id || ')', ', ')
    into fremd
  from public.teams t
  where t.club_id = 'd0000000-0000-4000-a000-000000000001'
    and t.name in ('Herren 1', 'Damen 1', 'U15', 'U11')
    and t.id not in (
      'd0000000-0000-4000-a000-000000000101',
      'd0000000-0000-4000-a000-000000000102',
      'd0000000-0000-4000-a000-000000000103',
      'd0000000-0000-4000-a000-000000000104'
    );
  if fremd is not null then
    raise exception 'Im Demo-Verein existieren Mannschaften mit den Demo-Namen, aber fremden IDs: %. Das verletzt teams unique (club_id, name). Demo-Verein einmal komplett entfernen (siehe Skriptkopf) und Skript erneut ausfuehren.', fremd;
  end if;

  select string_agg(m.membership_number || ' (id ' || m.id || ')', ', ')
    into fremd
  from public.club_memberships m
  where m.club_id = 'd0000000-0000-4000-a000-000000000001'
    and m.profile_id is null
    and m.membership_number like 'SVM-%'
    and m.id not in (
      select ('d0000000-0000-4000-a000-0000000002' || to_char(i, 'FM00'))::uuid
      from generate_series(1, 20) as i
    );
  if fremd is not null then
    raise exception 'Im Demo-Verein sind Mitgliedsnummern SVM-* an fremde IDs vergeben: %. Das verletzt club_memberships unique (club_id, membership_number). Demo-Verein einmal komplett entfernen (siehe Skriptkopf) und Skript erneut ausfuehren.', fremd;
  end if;

  select string_agg(s.id::text, ', ')
    into fremd
  from public.club_subscriptions s
  where s.provider = 'manual'
    and s.provider_subscription_id = 'demo-sv-musterstadt-premium'
    and s.id <> 'd0000000-0000-4000-a000-000000000401';
  if fremd is not null then
    raise exception 'Die Abo-Kennung demo-sv-musterstadt-premium haengt bereits an einer fremden Zeile: %. Das verletzt club_subscriptions unique (provider, provider_subscription_id).', fremd;
  end if;

  insert into demo_log (bereich, meldung)
  values ('vorpruefung', 'Keine Kollision mit natuerlichen Schluesseln gefunden.');
end
$outer$;


-- ---------------------------------------------------------------------
-- 2. VEREIN
-- ---------------------------------------------------------------------
-- created_at wird bewusst weit in die Vergangenheit gesetzt: sonst laeuft
-- der 14-Tage-Vereinstrial (club_subscription_tier -> trial_period()) und
-- die App zeigt in den Screenshots ein Trial-Banner. So beweist der
-- Screenshot, dass das echte Premium-Abo aus Abschnitt 3 greift.
-- created_at steht deshalb AUCH im DO-UPDATE-Zweig - sonst wuerde ein
-- bereits ueber register_new_club() entstandener Demo-Verein nie
-- zurueckdatiert und club_trial_info() meldete weiter trialing = true.
-- least() haelt den Wert monoton, damit ein Wiederholungslauf ein bereits
-- zurueckdatiertes created_at nicht wieder nach vorne zieht.
-- slug und referral_code sind bewusst sperrig gewaehlt: auf beiden liegt
-- eine eigene Eindeutigkeitsregel (slug not null unique,
-- clubs_referral_code_unique ueber upper(referral_code)), die der Arbiter
-- (id) nicht aufloest - ein Zufallstreffer mit einem bestehenden Verein
-- wuerde den ganzen Lauf abbrechen. Abschnitt 1b prueft beides vorab.
insert into public.clubs (
  id, slug, name, short_name, city, founded_year,
  register_number, currency, referral_code, referral_credit_months,
  primary_color, secondary_color, sport, created_at
) values (
  'd0000000-0000-4000-a000-000000000001', 'sv-musterstadt-demo-2026', 'SV Musterstadt', 'SVM', 'Musterstadt', 1971,
  'VR 4711 Musterstadt (Demo)', 'EUR', 'SVMDEMO2026', 0,
  '#1D4ED8', '#2B2F36', 'rollhockey', now() - interval '400 days'
)
on conflict (id) do update set
  slug            = excluded.slug,
  name            = excluded.name,
  short_name      = excluded.short_name,
  city            = excluded.city,
  founded_year    = excluded.founded_year,
  register_number = excluded.register_number,
  currency        = excluded.currency,
  referral_code   = excluded.referral_code,
  primary_color   = excluded.primary_color,
  secondary_color = excluded.secondary_color,
  sport           = excluded.sport,
  created_at      = least(clubs.created_at, excluded.created_at);


-- ---------------------------------------------------------------------
-- 3. PREMIUM-ABO
-- ---------------------------------------------------------------------
-- club_subscription_tier() liefert 'premium' nur, wenn eine Zeile in
-- club_subscriptions mit status='active', gueltigem Zeitraum UND einem Plan
-- mit code LIKE 'club_premium_%' existiert. Deshalb wird der Plan ueber
-- seinen code gesucht statt eine ID zu raten; fehlt der Plan (Migration
-- 20260808130000 nicht eingespielt), fuegt das SELECT einfach nichts ein
-- und das Skript laeuft ohne Fehler weiter.
-- provider/provider_subscription_id sind NOT NULL ohne Default, status hat
-- Default 'pending' und muss daher aktiv gesetzt werden.
insert into public.club_subscriptions (
  id, club_id, plan_id, provider, provider_subscription_id, status,
  current_period_start, current_period_end, cancel_at_period_end, last_payment_at
)
select
  'd0000000-0000-4000-a000-000000000401',
  'd0000000-0000-4000-a000-000000000001',
  p.id, 'manual', 'demo-sv-musterstadt-premium', 'active',
  now() - interval '30 days', now() + interval '365 days', false, now() - interval '30 days'
from public.subscription_plans p
where p.code = 'club_premium_yearly'
on conflict (id) do update set
  plan_id              = excluded.plan_id,
  status               = 'active',
  current_period_start = excluded.current_period_start,
  -- Laufzeitende wandert bei jedem Lauf mit, damit die Demo nie ablaeuft.
  current_period_end   = excluded.current_period_end,
  cancel_at_period_end = false,
  cancelled_at         = null,
  last_payment_at      = excluded.last_payment_at;


-- ---------------------------------------------------------------------
-- 4. MANNSCHAFTEN
-- ---------------------------------------------------------------------
-- teams.name ist faktisch ein Schluessel (unique (club_id, name) und
-- set_trainer_teams() sucht ueber den Namen), deshalb exakt die Namen, die
-- auch im Frontend erwartet werden. Genau wegen dieser zweiten Eindeutig-
-- keitsregel prueft Abschnitt 1b vorab, ob die vier Namen bereits an fremden
-- IDs haengen - der Arbiter (id) faengt das nicht ab.
insert into public.teams (id, club_id, name, category, active) values
  ('d0000000-0000-4000-a000-000000000101', 'd0000000-0000-4000-a000-000000000001', 'Herren 1', 'Aktive', true),
  ('d0000000-0000-4000-a000-000000000102', 'd0000000-0000-4000-a000-000000000001', 'Damen 1',  'Aktive', true),
  ('d0000000-0000-4000-a000-000000000103', 'd0000000-0000-4000-a000-000000000001', 'U15',      'Jugend', true),
  ('d0000000-0000-4000-a000-000000000104', 'd0000000-0000-4000-a000-000000000001', 'U11',      'Jugend', true)
on conflict (id) do update set
  name     = excluded.name,
  category = excluded.category,
  active   = excluded.active;


-- ---------------------------------------------------------------------
-- 5. MITGLIEDER (ohne Benutzerkonten)
-- ---------------------------------------------------------------------
-- profile_id bleibt NULL und is_managed_profile = true: genau so legt auch
-- create_team_player() Spieler ohne eigenes Konto an. profiles setzt ein
-- auth.users-Konto voraus, und Konten darf dieses Skript nicht erzeugen.
-- Folge davon: Geburtsdaten sind nicht speicherbar (birthdate haengt an
-- profiles, club_memberships hat keine solche Spalte). Die Altersstruktur
-- bildet deshalb die Mannschaftszuordnung (U11/U15/Aktive) zusammen mit
-- member_since ab - beides ist auch das, was die App anzeigt.
-- email bleibt NULL, weil sie laut Modell eine Kopie aus auth.users ist.
-- Es sind 20 statt der geforderten ~16 Personen, damit jede der vier
-- Mannschaften auf dem Screenshot drei Spieler plus Trainer zeigt.
-- on conflict (id) deckt unique (club_id, membership_number) nicht ab -
-- manuell geaenderte Mitgliedsnummern faengt die Vorpruefung in 1b ab.
insert into public.club_memberships (
  id, club_id, profile_id, display_name, email, member_since, membership_number,
  status, is_managed_profile, created_by
) values
  ('d0000000-0000-4000-a000-000000000201', 'd0000000-0000-4000-a000-000000000001', null, 'Bernd Hoffmeister', null, 1998, 'SVM-001', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000202', 'd0000000-0000-4000-a000-000000000001', null, 'Katrin Vogelsang',  null, 2009, 'SVM-002', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000203', 'd0000000-0000-4000-a000-000000000001', null, 'Uwe Brandner',      null, 1995, 'SVM-003', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000204', 'd0000000-0000-4000-a000-000000000001', null, 'Silke Reinhardt',   null, 2004, 'SVM-004', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000205', 'd0000000-0000-4000-a000-000000000001', null, 'Marek Lindow',      null, 2016, 'SVM-005', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000206', 'd0000000-0000-4000-a000-000000000001', null, 'Doreen Hartwig',    null, 2018, 'SVM-006', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000207', 'd0000000-0000-4000-a000-000000000001', null, 'Petra Terheyden',   null, 2019, 'SVM-007', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000208', 'd0000000-0000-4000-a000-000000000001', null, 'Stefan Radtke',     null, 2017, 'SVM-008', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000209', 'd0000000-0000-4000-a000-000000000001', null, 'Tobias Grunert',    null, 2011, 'SVM-009', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000210', 'd0000000-0000-4000-a000-000000000001', null, 'Jannik Osterloh',   null, 2015, 'SVM-010', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000211', 'd0000000-0000-4000-a000-000000000001', null, 'Fabian Kettler',    null, 2013, 'SVM-011', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000212', 'd0000000-0000-4000-a000-000000000001', null, 'Annika Peschel',    null, 2012, 'SVM-012', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000213', 'd0000000-0000-4000-a000-000000000001', null, 'Lea Sandmann',      null, 2018, 'SVM-013', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000214', 'd0000000-0000-4000-a000-000000000001', null, 'Miriam Kolb',       null, 2016, 'SVM-014', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000215', 'd0000000-0000-4000-a000-000000000001', null, 'Jonas Feldmann',    null, 2021, 'SVM-015', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000216', 'd0000000-0000-4000-a000-000000000001', null, 'Emilia Radtke',     null, 2021, 'SVM-016', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000217', 'd0000000-0000-4000-a000-000000000001', null, 'Ben Kuschel',       null, 2022, 'SVM-017', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000218', 'd0000000-0000-4000-a000-000000000001', null, 'Luis Terheyden',    null, 2023, 'SVM-018', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000219', 'd0000000-0000-4000-a000-000000000001', null, 'Greta Osterloh',    null, 2023, 'SVM-019', 'active', true, null),
  ('d0000000-0000-4000-a000-000000000220', 'd0000000-0000-4000-a000-000000000001', null, 'Paul Zielke',       null, 2024, 'SVM-020', 'active', true, null)
on conflict (id) do update set
  display_name       = excluded.display_name,
  member_since       = excluded.member_since,
  membership_number  = excluded.membership_number,
  status             = excluded.status,
  is_managed_profile = excluded.is_managed_profile;


-- ---------------------------------------------------------------------
-- 6. ROLLEN
-- ---------------------------------------------------------------------
-- 'mitglied' bekommt jeder, weil sync_club_role_entitlement() bei einem
-- abgelaufenen Vereinsabo alle anderen Rollen entfernt und 'mitglied' die
-- Basis bleibt. Die uebrigen Rollen decken Vorstand, Geschaeftsfuehrung,
-- Trainer, Kapitaen, Teammanager, Spieler und Eltern ab.
insert into public.membership_roles (membership_id, role) values
  ('d0000000-0000-4000-a000-000000000201', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000201', 'vorstand'),
  ('d0000000-0000-4000-a000-000000000202', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000202', 'geschaeftsfuehrung'),
  ('d0000000-0000-4000-a000-000000000202', 'teammanager'),
  ('d0000000-0000-4000-a000-000000000203', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000203', 'trainer'),
  ('d0000000-0000-4000-a000-000000000204', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000204', 'trainer'),
  ('d0000000-0000-4000-a000-000000000205', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000205', 'trainer'),
  ('d0000000-0000-4000-a000-000000000206', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000206', 'trainer'),
  ('d0000000-0000-4000-a000-000000000207', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000207', 'eltern'),
  ('d0000000-0000-4000-a000-000000000207', 'teammanager'),
  ('d0000000-0000-4000-a000-000000000208', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000208', 'eltern'),
  ('d0000000-0000-4000-a000-000000000208', 'teammanager'),
  ('d0000000-0000-4000-a000-000000000209', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000209', 'spieler'),
  ('d0000000-0000-4000-a000-000000000209', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000210', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000210', 'spieler'),
  ('d0000000-0000-4000-a000-000000000211', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000211', 'spieler'),
  ('d0000000-0000-4000-a000-000000000212', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000212', 'spieler'),
  ('d0000000-0000-4000-a000-000000000212', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000213', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000213', 'spieler'),
  ('d0000000-0000-4000-a000-000000000214', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000214', 'spieler'),
  ('d0000000-0000-4000-a000-000000000215', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000215', 'spieler'),
  ('d0000000-0000-4000-a000-000000000215', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000216', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000216', 'spieler'),
  ('d0000000-0000-4000-a000-000000000217', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000217', 'spieler'),
  ('d0000000-0000-4000-a000-000000000218', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000218', 'spieler'),
  ('d0000000-0000-4000-a000-000000000218', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000219', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000219', 'spieler'),
  ('d0000000-0000-4000-a000-000000000220', 'mitglied'),
  ('d0000000-0000-4000-a000-000000000220', 'spieler')
on conflict (membership_id, role) do nothing;


-- ---------------------------------------------------------------------
-- 7. MANNSCHAFTSZUORDNUNGEN
-- ---------------------------------------------------------------------
-- team_members haengt an membership_id (nicht an profile_id) - nur deshalb
-- lassen sich die kontolosen Mitglieder ueberhaupt Teams zuordnen.
-- function ist per CHECK auf spieler/trainer/kapitaen/teammanager begrenzt;
-- 'kapitaen' steht zusaetzlich zu 'spieler', da der PK (team_id,
-- membership_id, function) mehrere Funktionen pro Person erlaubt.
-- Die partiellen Unique-Indizes lassen genau einen Kapitaen und einen
-- Teammanager pro Team zu - deshalb hier je Team hoechstens einer.
--
-- Vor dem INSERT werden genau diese beiden Funktionen fuer genau die vier
-- Demo-Teams geraeumt: one_captain_per_team und one_teammanager_per_team
-- sind PARTIELLE Unique-Indizes und damit NICHT der ON-CONFLICT-Arbiter (das
-- ist der Primaerschluessel). Hat in der App zwischenzeitlich
-- set_team_captain() oder set_teammanager_team() die bestehende Zeile
-- geloescht und eine mit anderer membership_id angelegt, gaebe es beim
-- naechsten Lauf keinen PK-Konflikt, wohl aber einen Konflikt gegen den
-- partiellen Index - DO NOTHING griffe nicht und der GESAMTE transaktionale
-- Lauf braeche ab. Der Eingriff bleibt auf den Demo-Verein beschraenkt; die
-- 'spieler'- und 'trainer'-Zeilen bleiben unberuehrt, weil sie ausschliess-
-- lich vom PK abgedeckt sind und dort DO NOTHING korrekt greift.
delete from public.team_members
where function in ('kapitaen', 'teammanager')
  and team_id in (
    'd0000000-0000-4000-a000-000000000101',
    'd0000000-0000-4000-a000-000000000102',
    'd0000000-0000-4000-a000-000000000103',
    'd0000000-0000-4000-a000-000000000104'
  );

insert into public.team_members (team_id, membership_id, function) values
  -- Herren 1
  ('d0000000-0000-4000-a000-000000000101', 'd0000000-0000-4000-a000-000000000203', 'trainer'),
  ('d0000000-0000-4000-a000-000000000101', 'd0000000-0000-4000-a000-000000000202', 'teammanager'),
  ('d0000000-0000-4000-a000-000000000101', 'd0000000-0000-4000-a000-000000000209', 'spieler'),
  ('d0000000-0000-4000-a000-000000000101', 'd0000000-0000-4000-a000-000000000209', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000101', 'd0000000-0000-4000-a000-000000000210', 'spieler'),
  ('d0000000-0000-4000-a000-000000000101', 'd0000000-0000-4000-a000-000000000211', 'spieler'),
  -- Damen 1
  ('d0000000-0000-4000-a000-000000000102', 'd0000000-0000-4000-a000-000000000204', 'trainer'),
  ('d0000000-0000-4000-a000-000000000102', 'd0000000-0000-4000-a000-000000000212', 'spieler'),
  ('d0000000-0000-4000-a000-000000000102', 'd0000000-0000-4000-a000-000000000212', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000102', 'd0000000-0000-4000-a000-000000000213', 'spieler'),
  ('d0000000-0000-4000-a000-000000000102', 'd0000000-0000-4000-a000-000000000214', 'spieler'),
  -- U15
  ('d0000000-0000-4000-a000-000000000103', 'd0000000-0000-4000-a000-000000000205', 'trainer'),
  ('d0000000-0000-4000-a000-000000000103', 'd0000000-0000-4000-a000-000000000208', 'teammanager'),
  ('d0000000-0000-4000-a000-000000000103', 'd0000000-0000-4000-a000-000000000215', 'spieler'),
  ('d0000000-0000-4000-a000-000000000103', 'd0000000-0000-4000-a000-000000000215', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000103', 'd0000000-0000-4000-a000-000000000216', 'spieler'),
  ('d0000000-0000-4000-a000-000000000103', 'd0000000-0000-4000-a000-000000000217', 'spieler'),
  -- U11
  ('d0000000-0000-4000-a000-000000000104', 'd0000000-0000-4000-a000-000000000206', 'trainer'),
  ('d0000000-0000-4000-a000-000000000104', 'd0000000-0000-4000-a000-000000000207', 'teammanager'),
  ('d0000000-0000-4000-a000-000000000104', 'd0000000-0000-4000-a000-000000000218', 'spieler'),
  ('d0000000-0000-4000-a000-000000000104', 'd0000000-0000-4000-a000-000000000218', 'kapitaen'),
  ('d0000000-0000-4000-a000-000000000104', 'd0000000-0000-4000-a000-000000000219', 'spieler'),
  ('d0000000-0000-4000-a000-000000000104', 'd0000000-0000-4000-a000-000000000220', 'spieler')
on conflict (team_id, membership_id, function) do nothing;


-- ---------------------------------------------------------------------
-- 8. TERMINE
-- ---------------------------------------------------------------------
-- Auf events haengt der Trigger events_notify_audience; notify_event_audience()
-- schreibt bei JEDEM insert/update fuer jedes aktive Mitglied mit profile_id
-- eine Zeile in public.user_notifications. Die Termine sind an
-- date_trunc('month'/'day', now()) verankert, also verschieben sich starts_at
-- und ends_at zwangslaeufig, sobald der Lauf an einem anderen Tag bzw. in
-- einem anderen Monat wiederholt wird - der Guard am Ende des Upserts greift
-- dann nicht mehr und das Postfach des Admin-Kontos aus Abschnitt 10 fuellte
-- sich mit bis zu 31 Meldungen, wegen der CASE-Reihenfolge in
-- notify_event_audience() sogar mit falschen "neues Training"-Meldungen.
-- Deshalb wird der Trigger fuer die Dauer von Abschnitt 8 abgeschaltet. Das
-- ist transaktional: ein Abbruch stellt ihn automatisch wieder her.
do $outer$
begin
  if exists (
    select 1
    from pg_trigger g
    join pg_class c on c.oid = g.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'events'
      and g.tgname = 'events_notify_audience' and not g.tgisinternal
  ) then
    execute 'alter table public.events disable trigger events_notify_audience';
    insert into demo_log (bereich, meldung)
    values ('events', 'Trigger events_notify_audience fuer Abschnitt 8 abgeschaltet.');
  else
    insert into demo_log (bereich, meldung)
    values ('events', 'Trigger events_notify_audience nicht vorhanden - nichts abzuschalten.');
  end if;
end
$outer$;

-- Alle Zeiten sind relativ zum Monatsersten des aktuellen Monats, damit der
-- Kalender bei jedem Lauf und in jedem Monat gefuellt aussieht.
-- date_trunc laeuft bewusst ueber "now() at time zone 'Europe/Berlin'" und
-- das Ergebnis wird zurueckkonvertiert: sonst wuerde die Session-Zeitzone
-- (in Supabase UTC) die Trainingszeiten im Sommer um zwei Stunden
-- verschieben und 19:30 waere in der App 21:30.
-- Groesster Offset ist +27 Tage, damit auch der Februar nicht ueberlaeuft.
with basis as (
  select date_trunc('month', now() at time zone 'Europe/Berlin') as m0
), termin(id, team_id, typ, titel, beschreibung, start_offset, dauer, ort, heim_auswaerts, gegner) as (
  values
    -- aktueller Monat: Trainingsrhythmus
    ('d0000000-0000-4000-a000-000000000301'::uuid, 'd0000000-0000-4000-a000-000000000101'::uuid, 'training'::public.event_type, 'Training Herren 1', 'Technik und Spielformen', interval '2 days 19 hours 30 minutes', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null::text, null::text),
    ('d0000000-0000-4000-a000-000000000302', 'd0000000-0000-4000-a000-000000000103', 'training', 'Training U15', 'Passspiel und Torabschluss', interval '3 days 17 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000303', 'd0000000-0000-4000-a000-000000000102', 'training', 'Training Damen 1', 'Konterspiel', interval '3 days 19 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000304', 'd0000000-0000-4000-a000-000000000104', 'training', 'Training U11', 'Skatetechnik und Ballgewoehnung', interval '4 days 16 hours', interval '75 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000305', 'd0000000-0000-4000-a000-000000000101', 'spiel', 'Heimspiel gegen SG Lindental - Herren 1', 'Punktspiel, Halle ab 17:00 offen', interval '6 days 18 hours', interval '2 hours', 'Rollhockeyhalle am Deichweg', 'heim', 'SG Lindental'),
    ('d0000000-0000-4000-a000-000000000306', 'd0000000-0000-4000-a000-000000000101', 'training', 'Training Herren 1', 'Standards und Powerplay', interval '9 days 19 hours 30 minutes', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000307', 'd0000000-0000-4000-a000-000000000103', 'training', 'Training U15', 'Zweikampfverhalten', interval '10 days 17 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000308', 'd0000000-0000-4000-a000-000000000102', 'training', 'Training Damen 1', 'Torschusstraining', interval '10 days 19 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000309', 'd0000000-0000-4000-a000-000000000104', 'training', 'Training U11', 'Spielerische Grundlagen', interval '11 days 16 hours', interval '75 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000310', 'd0000000-0000-4000-a000-000000000102', 'spiel', 'Gastspiel bei TuS Ahornbach - Damen 1', 'Abfahrt 13:30 am Vereinsheim', interval '13 days 16 hours', interval '2 hours', 'Sporthalle Ahornbach', 'auswaerts', 'TuS Ahornbach'),
    ('d0000000-0000-4000-a000-000000000311', 'd0000000-0000-4000-a000-000000000101', 'training', 'Training Herren 1', 'Kondition und Spielaufbau', interval '16 days 19 hours 30 minutes', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000312', 'd0000000-0000-4000-a000-000000000102', 'training', 'Training Damen 1', 'Ueberzahlspiel', interval '17 days 19 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000313', 'd0000000-0000-4000-a000-000000000103', 'spiel', 'Heimspiel gegen RSC Kieferngrund - U15', 'Jugendpunktspiel', interval '20 days 11 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', 'heim', 'RSC Kieferngrund'),
    ('d0000000-0000-4000-a000-000000000314', 'd0000000-0000-4000-a000-000000000101', 'spiel', 'Gastspiel bei SV Buchenfelde - Herren 1', 'Abfahrt 15:45 am Vereinsheim', interval '20 days 18 hours 30 minutes', interval '2 hours', 'Sportzentrum Buchenfelde', 'auswaerts', 'SV Buchenfelde'),
    ('d0000000-0000-4000-a000-000000000315', null, 'event', 'Jahreshauptversammlung', 'Berichte, Entlastung und Neuwahlen. Alle Mitglieder sind eingeladen.', interval '23 days 19 hours', interval '150 minutes', 'Vereinsheim am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000316', 'd0000000-0000-4000-a000-000000000104', 'training', 'Training U11', 'Kleinfeldturnier im Training', interval '25 days 16 hours', interval '75 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000317', 'd0000000-0000-4000-a000-000000000104', 'spiel', 'Heimspiel gegen TSV Farnstedt - U11', 'Spieltag mit drei Begegnungen', interval '27 days 10 hours', interval '3 hours', 'Rollhockeyhalle am Deichweg', 'heim', 'TSV Farnstedt'),
    -- Folgemonat
    ('d0000000-0000-4000-a000-000000000318', 'd0000000-0000-4000-a000-000000000101', 'training', 'Training Herren 1', 'Saisonvorbereitung', interval '1 month 2 days 19 hours 30 minutes', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000319', 'd0000000-0000-4000-a000-000000000103', 'training', 'Training U15', 'Torwarttraining', interval '1 month 3 days 17 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000320', 'd0000000-0000-4000-a000-000000000102', 'training', 'Training Damen 1', 'Spielaufbau aus der Abwehr', interval '1 month 3 days 19 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000321', 'd0000000-0000-4000-a000-000000000104', 'training', 'Training U11', 'Staffelspiele und Technik', interval '1 month 4 days 16 hours', interval '75 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000322', 'd0000000-0000-4000-a000-000000000101', 'spiel', 'Heimspiel gegen TSV Farnstedt - Herren 1', 'Punktspiel', interval '1 month 7 days 18 hours', interval '2 hours', 'Rollhockeyhalle am Deichweg', 'heim', 'TSV Farnstedt'),
    ('d0000000-0000-4000-a000-000000000323', 'd0000000-0000-4000-a000-000000000101', 'training', 'Training Herren 1', 'Videoanalyse und Einheit', interval '1 month 9 days 19 hours 30 minutes', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000324', 'd0000000-0000-4000-a000-000000000103', 'spiel', 'Gastspiel bei SG Lindental - U15', 'Fahrgemeinschaft ab 09:00', interval '1 month 10 days 11 hours', interval '90 minutes', 'Sporthalle Lindental', 'auswaerts', 'SG Lindental'),
    ('d0000000-0000-4000-a000-000000000325', null, 'event', 'Sommerfest des SV Musterstadt', 'Grillstand, Schnupperhockey und Siegerehrung der Jugend.', interval '1 month 13 days 14 hours', interval '5 hours', 'Vereinsheim am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000326', 'd0000000-0000-4000-a000-000000000102', 'training', 'Training Damen 1', 'Konterabsicherung', interval '1 month 17 days 19 hours', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000327', 'd0000000-0000-4000-a000-000000000104', 'training', 'Training U11', 'Technikparcours', interval '1 month 18 days 16 hours', interval '75 minutes', 'Rollhockeyhalle am Deichweg', null, null),
    ('d0000000-0000-4000-a000-000000000328', 'd0000000-0000-4000-a000-000000000102', 'spiel', 'Heimspiel gegen RSC Kieferngrund - Damen 1', 'Punktspiel', interval '1 month 20 days 16 hours', interval '2 hours', 'Rollhockeyhalle am Deichweg', 'heim', 'RSC Kieferngrund'),
    ('d0000000-0000-4000-a000-000000000329', 'd0000000-0000-4000-a000-000000000101', 'training', 'Training Herren 1', 'Abschlusstraining vor dem Spieltag', interval '1 month 23 days 19 hours 30 minutes', interval '90 minutes', 'Rollhockeyhalle am Deichweg', null, null)
)
insert into public.events (
  id, club_id, team_id, type, status, title, description, starts_at, ends_at, location, home_away, opponent
)
select
  t.id, 'd0000000-0000-4000-a000-000000000001', t.team_id, t.typ, 'scheduled', t.titel, t.beschreibung,
  (b.m0 + t.start_offset) at time zone 'Europe/Berlin',
  (b.m0 + t.start_offset + t.dauer) at time zone 'Europe/Berlin',
  t.ort, t.heim_auswaerts, t.gegner
from termin t cross join basis b
on conflict (id) do update set
  team_id     = excluded.team_id,
  type        = excluded.type,
  status      = excluded.status,
  title       = excluded.title,
  description = excluded.description,
  starts_at   = excluded.starts_at,
  ends_at     = excluded.ends_at,
  location    = excluded.location,
  home_away   = excluded.home_away,
  opponent    = excluded.opponent
-- Nur schreiben, wenn sich wirklich etwas aendert. Das spart im selben Monat
-- den kompletten UPDATE; gegen die Benachrichtigungsflut bei einem Lauf in
-- einem spaeteren Monat (dann verschieben sich alle Termine und die
-- Bedingung ist erfuellt) schuetzt der oben abgeschaltete Trigger.
where events.starts_at   is distinct from excluded.starts_at
   or events.title       is distinct from excluded.title
   or events.team_id     is distinct from excluded.team_id
   or events.description is distinct from excluded.description
   or events.location    is distinct from excluded.location;

-- Zwei bereits gespielte Partien mit Ergebnis, damit Ergebnis- und
-- Tippspielansicht nicht leer sind. Diese beiden haengen bewusst an "heute"
-- statt am Monatsanfang, damit immer ein frisches Resultat sichtbar ist -
-- ihr starts_at wandert deshalb bei jedem Lauf an einem neuen Kalendertag,
-- der Guard unten greift dann nicht. Genau dafuer ist der Trigger
-- abgeschaltet.
with basis as (
  select date_trunc('day', now() at time zone 'Europe/Berlin') as d0
), termin(id, team_id, titel, beschreibung, start_offset, dauer, ort, heim_auswaerts, gegner, heim_tore, gast_tore) as (
  values
    ('d0000000-0000-4000-a000-000000000330'::uuid, 'd0000000-0000-4000-a000-000000000101'::uuid, 'Heimspiel gegen SC Weidengrund - Herren 1', 'Punktspiel', interval '-4 days 18 hours', interval '2 hours', 'Rollhockeyhalle am Deichweg', 'heim'::text, 'SC Weidengrund'::text, 5, 3),
    ('d0000000-0000-4000-a000-000000000331', 'd0000000-0000-4000-a000-000000000102', 'Gastspiel bei SV Buchenfelde - Damen 1', 'Punktspiel', interval '-11 days 16 hours', interval '2 hours', 'Sportzentrum Buchenfelde', 'auswaerts', 'SV Buchenfelde', 2, 2)
)
insert into public.events (
  id, club_id, team_id, type, status, title, description, starts_at, ends_at, location,
  home_away, opponent, home_score, away_score, result_entered_at
)
select
  t.id, 'd0000000-0000-4000-a000-000000000001', t.team_id, 'spiel', 'scheduled', t.titel, t.beschreibung,
  (b.d0 + t.start_offset) at time zone 'Europe/Berlin',
  (b.d0 + t.start_offset + t.dauer) at time zone 'Europe/Berlin',
  t.ort, t.heim_auswaerts, t.gegner, t.heim_tore, t.gast_tore,
  (b.d0 + t.start_offset + t.dauer) at time zone 'Europe/Berlin'
from termin t cross join basis b
on conflict (id) do update set
  starts_at         = excluded.starts_at,
  ends_at           = excluded.ends_at,
  home_score        = excluded.home_score,
  away_score        = excluded.away_score,
  result_entered_at = excluded.result_entered_at
where events.starts_at is distinct from excluded.starts_at;

-- Trigger wieder einschalten: ab hier soll die App wieder normal
-- benachrichtigen.
do $outer$
begin
  if exists (
    select 1
    from pg_trigger g
    join pg_class c on c.oid = g.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'events'
      and g.tgname = 'events_notify_audience' and not g.tgisinternal
  ) then
    execute 'alter table public.events enable trigger events_notify_audience';
    insert into demo_log (bereich, meldung)
    values ('events', 'Trigger events_notify_audience wieder eingeschaltet.');
  end if;
end
$outer$;

-- Falls fruehere Skriptlaeufe (ohne die Trigger-Abschaltung oben) das
-- Postfach bereits gefuellt haben, raeumt diese Zeile gezielt auf. Sie
-- beruehrt nur den Demo-Verein und ist deshalb bewusst auskommentiert -
-- einkommentieren, wenn die Screenshots ein leeres Postfach zeigen sollen:
-- delete from public.user_notifications where club_id = 'd0000000-0000-4000-a000-000000000001';


-- ---------------------------------------------------------------------
-- 9. HELFERDIENSTE UND FAHRZEUGE
-- ---------------------------------------------------------------------
-- duty_assignments ist die einzige Helferdienst-Tabelle, die im
-- Migrationsstand garantiert existiert; station ist freier Text (es gibt
-- keine Stationen-Stammtabelle). Zugeordnet werden nur Erwachsene.
-- ACHTUNG: Das Frontend liest fuer die Helferplanung ausschliesslich
-- duty_tasks (app/page.tsx). Die Zeilen hier sind schemakonform, erscheinen
-- aber in keiner Ansicht - sichtbar wird die Helferplanung erst durch den
-- duty_tasks-Block weiter unten.
insert into public.duty_assignments (event_id, station, membership_id) values
  ('d0000000-0000-4000-a000-000000000305', 'Kasse',                  'd0000000-0000-4000-a000-000000000207'),
  ('d0000000-0000-4000-a000-000000000305', 'Kuchentheke',            'd0000000-0000-4000-a000-000000000208'),
  ('d0000000-0000-4000-a000-000000000305', 'Grillstand',             'd0000000-0000-4000-a000-000000000201'),
  ('d0000000-0000-4000-a000-000000000305', 'Schiedsrichterbetreuung','d0000000-0000-4000-a000-000000000202'),
  ('d0000000-0000-4000-a000-000000000313', 'Kasse',                  'd0000000-0000-4000-a000-000000000208'),
  ('d0000000-0000-4000-a000-000000000313', 'Aufbau und Abbau',       'd0000000-0000-4000-a000-000000000207'),
  ('d0000000-0000-4000-a000-000000000317', 'Kasse',                  'd0000000-0000-4000-a000-000000000202'),
  ('d0000000-0000-4000-a000-000000000317', 'Kuchentheke',            'd0000000-0000-4000-a000-000000000207')
on conflict (event_id, station, membership_id) do nothing;

-- Die produktiv genutzten Tabellen duty_tasks, club_vehicles und
-- vehicle_bookings wurden laut Projektdoku direkt im SQL-Editor angelegt und
-- liegen in KEINER der Migrationen (per grep ueber supabase/migrations/*.sql
-- geprueft) - Spaltentypen sind daher nicht sicher bekannt. Deshalb laufen
-- sie hier in geschuetzten Bloecken: existiert die Tabelle nicht oder passt
-- eine Spalte nicht, gibt es nur einen Protokolleintrag statt eines
-- Abbruchs, der den gesamten (transaktionalen) Skriptlauf zuruecknehmen
-- wuerde. Jeder Block protokolliert zusaetzlich seine Zeilenzahl in
-- demo_log, damit ein stiller Fehlschlag in Abschnitt 11 sichtbar wird.
--
-- VOR dem ersten Lauf im Zielprojekt einmal das tatsaechliche Schema pruefen
-- und die Bloecke ggf. daran anpassen (oder die fehlenden Tabellen als
-- Migration nachziehen):
--   select table_name, column_name, data_type, is_nullable, column_default
--     from information_schema.columns
--    where table_schema = 'public'
--      and table_name in ('duty_tasks','club_vehicles','vehicle_bookings','club_feature_toggles')
--    order by table_name, ordinal_position;
do $outer$
declare
  eingefuegt bigint := 0;
begin
  if to_regclass('public.duty_tasks') is null then
    raise notice 'duty_tasks existiert nicht - Helferdienst-Aufgaben uebersprungen.';
    insert into demo_log (bereich, meldung)
    values ('duty_tasks', 'FEHLT: Tabelle existiert nicht - Helferplanung bleibt in der App LEER.');
    return;
  end if;
  execute $q$
    insert into public.duty_tasks (id, event_id, club_id, title, assignee_membership_id, created_by)
    select v.task_id, v.event_id, 'd0000000-0000-4000-a000-000000000001'::uuid, v.titel, v.assignee,
           'd0000000-0000-4000-a000-000000000202'::uuid
    from (values
      ('d0000000-0000-4000-a000-000000000701'::uuid, 'd0000000-0000-4000-a000-000000000305'::uuid, 'Kasse besetzen',        'd0000000-0000-4000-a000-000000000207'::uuid),
      ('d0000000-0000-4000-a000-000000000702', 'd0000000-0000-4000-a000-000000000305', 'Kuchentheke betreuen',  'd0000000-0000-4000-a000-000000000208'),
      ('d0000000-0000-4000-a000-000000000703', 'd0000000-0000-4000-a000-000000000305', 'Halle aufbauen',        null),
      ('d0000000-0000-4000-a000-000000000704', 'd0000000-0000-4000-a000-000000000313', 'Kasse besetzen',        'd0000000-0000-4000-a000-000000000208'),
      ('d0000000-0000-4000-a000-000000000705', 'd0000000-0000-4000-a000-000000000313', 'Getraenkeausgabe',      null)
    ) as v(task_id, event_id, titel, assignee)
    where not exists (select 1 from public.duty_tasks d where d.id = v.task_id)
  $q$;
  get diagnostics eingefuegt = row_count;
  insert into demo_log (bereich, meldung)
  values ('duty_tasks', eingefuegt || ' Aufgabe(n) neu angelegt (0 = alle 5 waren schon da).');
exception when others then
  raise notice 'duty_tasks konnte nicht befuellt werden (%). Uebersprungen.', sqlerrm;
  insert into demo_log (bereich, meldung)
  values ('duty_tasks', 'FEHLER: ' || sqlerrm || ' - uebersprungen, Helferplanung bleibt LEER.');
end
$outer$;

do $outer$
declare
  fahrzeuge bigint := 0;
  buchungen bigint := 0;
begin
  if to_regclass('public.club_vehicles') is null then
    raise notice 'club_vehicles existiert nicht - Fuhrpark uebersprungen.';
    insert into demo_log (bereich, meldung)
    values ('club_vehicles', 'FEHLT: Tabelle existiert nicht - Fuhrpark bleibt in der App LEER.');
    return;
  end if;
  -- created_by referenziert im Frontend die Mitgliedschafts-ID; falls die
  -- Live-Tabelle die Spalte anders auslegt, greift der zweite Versuch ohne
  -- created_by.
  begin
    execute $q$
      insert into public.club_vehicles (id, club_id, label, license_plate, seats, created_by)
      values ('d0000000-0000-4000-a000-000000000501'::uuid, 'd0000000-0000-4000-a000-000000000001'::uuid, 'Vereinsbus', 'MST-SV 1971', 9, 'd0000000-0000-4000-a000-000000000202'::uuid),
             ('d0000000-0000-4000-a000-000000000502'::uuid, 'd0000000-0000-4000-a000-000000000001'::uuid, 'Jugendbus',  'MST-SV 1988', 8, 'd0000000-0000-4000-a000-000000000202'::uuid)
      on conflict do nothing
    $q$;
    get diagnostics fahrzeuge = row_count;
  exception when others then
    insert into demo_log (bereich, meldung)
    values ('club_vehicles', 'Hinweis: Variante mit created_by scheiterte (' || sqlerrm || '), zweiter Versuch ohne created_by.');
    execute $q$
      insert into public.club_vehicles (id, club_id, label, license_plate, seats)
      values ('d0000000-0000-4000-a000-000000000501'::uuid, 'd0000000-0000-4000-a000-000000000001'::uuid, 'Vereinsbus', 'MST-SV 1971', 9),
             ('d0000000-0000-4000-a000-000000000502'::uuid, 'd0000000-0000-4000-a000-000000000001'::uuid, 'Jugendbus',  'MST-SV 1988', 8)
      on conflict do nothing
    $q$;
    get diagnostics fahrzeuge = row_count;
  end;
  insert into demo_log (bereich, meldung)
  values ('club_vehicles', fahrzeuge || ' Fahrzeug(e) neu angelegt (0 = beide waren schon da).');

  if to_regclass('public.vehicle_bookings') is null then
    raise notice 'vehicle_bookings existiert nicht - Buchungen uebersprungen.';
    insert into demo_log (bereich, meldung)
    values ('vehicle_bookings', 'FEHLT: Tabelle existiert nicht - Buchungsuebersicht bleibt LEER.');
    return;
  end if;
  -- Startzeiten bewusst auf volle Stunden: die Live-Tabelle hat laut Doku
  -- einen CHECK darauf und einen EXCLUDE-Constraint gegen Ueberschneidungen.
  execute $q$
    insert into public.vehicle_bookings (id, club_id, vehicle_id, membership_id, team_id, private_label, starts_at, ends_at)
    select v.booking_id, 'd0000000-0000-4000-a000-000000000001'::uuid, v.vehicle_id, v.membership_id, v.team_id, v.private_label,
           (date_trunc('day', now() at time zone 'Europe/Berlin') + v.start_offset) at time zone 'Europe/Berlin',
           (date_trunc('day', now() at time zone 'Europe/Berlin') + v.end_offset) at time zone 'Europe/Berlin'
    from (values
      ('d0000000-0000-4000-a000-000000000601'::uuid, 'd0000000-0000-4000-a000-000000000501'::uuid, 'd0000000-0000-4000-a000-000000000202'::uuid, 'd0000000-0000-4000-a000-000000000101'::uuid, null::text, interval '3 days 13 hours', interval '3 days 22 hours'),
      ('d0000000-0000-4000-a000-000000000602', 'd0000000-0000-4000-a000-000000000502', 'd0000000-0000-4000-a000-000000000208', 'd0000000-0000-4000-a000-000000000103', null, interval '10 days 8 hours', interval '10 days 17 hours'),
      ('d0000000-0000-4000-a000-000000000603', 'd0000000-0000-4000-a000-000000000501', 'd0000000-0000-4000-a000-000000000207', null, 'Materialtransport Sommerfest', interval '17 days 9 hours', interval '17 days 15 hours')
    ) as v(booking_id, vehicle_id, membership_id, team_id, private_label, start_offset, end_offset)
    where not exists (select 1 from public.vehicle_bookings b where b.id = v.booking_id)
    on conflict do nothing
  $q$;
  get diagnostics buchungen = row_count;
  insert into demo_log (bereich, meldung)
  values ('vehicle_bookings', buchungen || ' Buchung(en) neu angelegt (0 = alle 3 waren schon da).');
exception when others then
  raise notice 'Fuhrpark konnte nicht vollstaendig befuellt werden (%). Uebersprungen.', sqlerrm;
  insert into demo_log (bereich, meldung)
  values ('fuhrpark', 'FEHLER: ' || sqlerrm || ' - Fuhrpark unvollstaendig.');
end
$outer$;

-- Feature-Schalter: eine fehlende Zeile bedeutet in der App bereits "Feature
-- aktiv", die Zeilen werden trotzdem gesetzt, damit die Schalter in den
-- Vereinseinstellungen sichtbar auf "an" stehen.
do $outer$
declare
  gesetzt bigint := 0;
begin
  if to_regclass('public.club_feature_toggles') is null then
    raise notice 'club_feature_toggles existiert nicht - Features gelten ohnehin als aktiv.';
    insert into demo_log (bereich, meldung)
    values ('club_feature_toggles', 'FEHLT: Tabelle existiert nicht - Features gelten ohnehin als aktiv.');
    return;
  end if;
  execute $q$
    insert into public.club_feature_toggles (club_id, feature_key, enabled)
    select 'd0000000-0000-4000-a000-000000000001'::uuid, k, true
    from unnest(array['duty_roster','vehicle_booking','tippspiel','season_award']) as k
    on conflict (club_id, feature_key) do update set enabled = true
  $q$;
  get diagnostics gesetzt = row_count;
  insert into demo_log (bereich, meldung)
  values ('club_feature_toggles', gesetzt || ' Schalter gesetzt.');
exception when others then
  raise notice 'club_feature_toggles konnte nicht gesetzt werden (%). Uebersprungen.', sqlerrm;
  insert into demo_log (bereich, meldung)
  values ('club_feature_toggles', 'FEHLER: ' || sqlerrm || ' - Schalter nicht gesetzt.');
end
$outer$;


-- ---------------------------------------------------------------------
-- 10. ZUGANG FUER DAS ECHTE ANMELDEKONTO
-- ---------------------------------------------------------------------
-- Bewusst als letzter Schritt: der Trigger events_notify_audience aus
-- Abschnitt 8 benachrichtigt alle aktiven Mitglieder MIT Konto. Wird die
-- Admin-Mitgliedschaft erst jetzt angelegt, bleibt das Postfach beim ersten
-- Lauf leer statt mit 31 Terminmeldungen gefuellt.
-- Der ganze Block ist gekapselt: fehlt das Konto oder scheitert etwas, gibt
-- es nur einen Protokolleintrag - der bereits angelegte Demo-Verein bleibt
-- bestehen.
do $outer$
declare
  admin_email      text := nullif(trim(current_setting('demo.admin_email', true)), '');
  admin_user       uuid;
  admin_name       text;
  admin_membership uuid;
begin
  if admin_email is null then
    raise notice 'Keine Admin-E-Mail konfiguriert - Vereinsadmin-Zuordnung uebersprungen.';
    insert into demo_log (bereich, meldung)
    values ('vereinsadmin', 'FEHLT: Keine Admin-E-Mail konfiguriert - Zuordnung uebersprungen.');
    return;
  end if;

  select u.id into admin_user
  from auth.users u
  where lower(u.email) = lower(admin_email)
  limit 1;

  if admin_user is null then
    raise notice 'Kein Auth-Konto zu % gefunden - Vereinsadmin-Zuordnung uebersprungen. Konto zuerst in der App registrieren und Skript erneut ausfuehren.', admin_email;
    insert into demo_log (bereich, meldung)
    values ('vereinsadmin', 'FEHLT: Kein Auth-Konto zu ' || admin_email || ' - Konto zuerst in der App registrieren und Skript erneut ausfuehren.');
    return;
  end if;

  -- Normalerweise legt der Trigger on_auth_user_created die profiles-Zeile
  -- an; fuer Altkonten aus der Zeit davor wird sie hier nachgezogen.
  insert into public.profiles (id, full_name)
  values (admin_user, '')
  on conflict (id) do nothing;

  select coalesce(nullif(trim(p.full_name), ''), split_part(admin_email, '@', 1))
    into admin_name
  from public.profiles p where p.id = admin_user;

  -- Konflikt wird ueber (club_id, profile_id) aufgeloest, nicht ueber die
  -- ID: eine eventuell schon vorhandene Mitgliedschaft dieses Kontos im
  -- Demo-Verein wird aktiviert statt dupliziert.
  -- created_at wandert bei jedem Lauf mit, weil member_has_access() den
  -- persoenlichen 14-Tage-Trial ab club_memberships.created_at rechnet -
  -- so bleiben die Premium-Ansichten fuer Screenshots offen, ohne dass ein
  -- kostenpflichtiges Mitglieder-Abo eingetragen werden muss.
  insert into public.club_memberships (
    club_id, profile_id, display_name, email, member_since, membership_number,
    status, is_managed_profile, created_at
  ) values (
    'd0000000-0000-4000-a000-000000000001', admin_user, admin_name, admin_email,
    extract(year from now())::integer, 'SVM-000', 'active', false, now()
  )
  on conflict (club_id, profile_id) do update set
    display_name       = excluded.display_name,
    email              = excluded.email,
    status             = 'active',
    is_managed_profile = false,
    created_at         = now()
  returning id into admin_membership;

  insert into public.membership_roles (membership_id, role) values
    (admin_membership, 'mitglied'),
    (admin_membership, 'vereinsadmin'),
    (admin_membership, 'vorstand')
  on conflict (membership_id, role) do nothing;

  raise notice 'Vereinsadmin-Mitgliedschaft % fuer % angelegt bzw. aktualisiert.', admin_membership, admin_email;
  insert into demo_log (bereich, meldung)
  values ('vereinsadmin', 'Mitgliedschaft ' || admin_membership || ' fuer ' || admin_email || ' angelegt bzw. aktualisiert.');
exception when others then
  raise notice 'Vereinsadmin-Zuordnung fehlgeschlagen (%). Der Demo-Verein selbst ist angelegt.', sqlerrm;
  insert into demo_log (bereich, meldung)
  values ('vereinsadmin', 'FEHLER: ' || sqlerrm || ' - Der Demo-Verein selbst ist angelegt, aber ohne Admin-Zugang.');
end
$outer$;

-- Optional: dauerhaftes Mitglieder-Basisabo statt des 14-Tage-Trials oben.
-- Nur einkommentieren, wenn die Screenshots spaeter als zwei Wochen nach dem
-- letzten Skriptlauf entstehen sollen.
-- do $outer$
-- declare admin_user uuid;
-- begin
--   select u.id into admin_user from auth.users u
--    where lower(u.email) = lower(nullif(trim(current_setting('demo.admin_email', true)), ''));
--   if admin_user is null then return; end if;
--   insert into public.user_subscriptions (id, profile_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
--   select 'd0000000-0000-4000-a000-000000000801', admin_user, p.id, 'manual', 'demo-sv-musterstadt-member', 'active', now() - interval '30 days', now() + interval '365 days'
--   from public.subscription_plans p where p.code = 'member_yearly'
--   on conflict (id) do update set status = 'active', current_period_end = excluded.current_period_end;
-- end $outer$;


-- ---------------------------------------------------------------------
-- 11. PRUEFABFRAGE
-- ---------------------------------------------------------------------
-- Zusaetzlich zur Tabelle unten wird der echte Tarif ueber die App-Funktion
-- gemeldet - aber nur, wenn sie im Zielprojekt existiert, damit ein alter
-- Migrationsstand die Pruefung nicht abbrechen laesst.
do $outer$
declare tier text;
begin
  if to_regprocedure('public.club_subscription_tier(uuid)') is not null then
    execute 'select public.club_subscription_tier($1)' into tier using 'd0000000-0000-4000-a000-000000000001'::uuid;
    raise notice 'club_subscription_tier() liefert fuer den Demo-Verein: %', tier;
    insert into demo_log (bereich, meldung)
    values ('abo', 'club_subscription_tier() liefert: ' || coalesce(tier, 'null'));
  end if;
end
$outer$;

-- Die vier optionalen Tabellen aus Abschnitt 9 lassen sich nicht statisch
-- abfragen (fehlt eine, scheitert schon das Parsen). Deshalb werden ihre
-- Zeilenzahlen hier to_regclass-geschuetzt ermittelt und in eine temporaere
-- Tabelle geschrieben, die die Pruefabfrage unten mitselektiert.
drop table if exists pg_temp.demo_zaehler;
create temp table demo_zaehler (tabelle text primary key, zeilen bigint);

do $outer$
declare
  t text;
  n bigint;
begin
  foreach t in array array['duty_tasks', 'club_vehicles', 'vehicle_bookings', 'club_feature_toggles'] loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    begin
      execute format('select count(*) from public.%I where club_id = $1', t)
        into n using 'd0000000-0000-4000-a000-000000000001'::uuid;
      insert into demo_zaehler (tabelle, zeilen) values (t, n);
    exception when others then
      insert into demo_log (bereich, meldung)
      values (t, 'Zaehlung fehlgeschlagen: ' || sqlerrm);
    end;
  end loop;
end
$outer$;

select
  c.name                                                                        as verein,
  c.short_name                                                                  as kurzname,
  (select count(*) from public.club_memberships m where m.club_id = c.id)       as mitglieder,
  (select count(*) from public.club_memberships m
     where m.club_id = c.id and m.profile_id is null)                           as davon_ohne_konto,
  (select count(*) from public.club_memberships m
     where m.club_id = c.id and m.profile_id is not null)                       as davon_mit_konto,
  (select count(*) from public.teams t where t.club_id = c.id)                  as mannschaften,
  (select count(*) from public.team_members tm
     join public.teams t on t.id = tm.team_id where t.club_id = c.id)           as team_zuordnungen,
  (select count(*) from public.events e where e.club_id = c.id)                 as termine,
  (select count(*) from public.events e
     where e.club_id = c.id and e.type = 'training')                            as davon_training,
  (select count(*) from public.events e
     where e.club_id = c.id and e.type = 'spiel')                               as davon_spiele,
  (select count(*) from public.events e
     where e.club_id = c.id and e.type = 'event')                               as davon_vereinsevents,
  (select count(*) from public.duty_assignments d
     join public.events e on e.id = d.event_id where e.club_id = c.id)          as helfer_zuordnungen,
  -- Die vier optionalen Tabellen: 'Tabelle fehlt' bedeutet, dass der
  -- zugehoerige Block in Abschnitt 9 nichts geschrieben hat.
  coalesce((select z.zeilen::text from demo_zaehler z
     where z.tabelle = 'duty_tasks'), 'Tabelle fehlt')                          as helferdienst_aufgaben,
  coalesce((select z.zeilen::text from demo_zaehler z
     where z.tabelle = 'club_vehicles'), 'Tabelle fehlt')                       as fahrzeuge,
  coalesce((select z.zeilen::text from demo_zaehler z
     where z.tabelle = 'vehicle_bookings'), 'Tabelle fehlt')                    as fahrzeugbuchungen,
  coalesce((select z.zeilen::text from demo_zaehler z
     where z.tabelle = 'club_feature_toggles'), 'Tabelle fehlt')                as feature_schalter,
  coalesce((
    select p.code from public.club_subscriptions s
    join public.subscription_plans p on p.id = s.plan_id
    where s.club_id = c.id and s.status = 'active'
      and (s.current_period_end is null or s.current_period_end > now())
    order by case when p.code like 'club_premium_%' then 0 else 1 end
    limit 1
  ), 'kein aktives Abo')                                                        as abo_plan,
  -- Gleiche Logik wie club_subscription_tier(), nur ohne Funktionsaufruf,
  -- damit die Pruefung auch bei aelterem Migrationsstand ein Ergebnis liefert.
  coalesce((
    select case
      when p.code like 'club_premium_%' then 'premium'
      when p.code like 'club_basic_%'   then 'basic'
    end
    from public.club_subscriptions s
    join public.subscription_plans p on p.id = s.plan_id
    where s.club_id = c.id and s.status = 'active'
      and (s.current_period_end is null or s.current_period_end > now())
    order by case when p.code like 'club_premium_%' then 0 else 1 end
    limit 1
  ), 'none')                                                                    as abo_status,
  (select s.current_period_end from public.club_subscriptions s
    where s.club_id = c.id and s.status = 'active'
    order by s.current_period_end desc nulls first limit 1)                     as abo_laeuft_bis,
  c.created_at                                                                  as verein_angelegt_am,
  -- Protokoll aller geschuetzten Bloecke. Der SQL-Editor zeigt keine
  -- NOTICE-Ausgaben, deshalb steht hier, was uebersprungen wurde oder
  -- fehlgeschlagen ist. Zeilen mit FEHLT/FEHLER bedeuten leere Ansichten.
  coalesce((
    select string_agg(l.bereich || ': ' || l.meldung, chr(10) order by l.lfd)
    from demo_log l
  ), 'keine Meldungen')                                                         as protokoll
from public.clubs c
where c.id = 'd0000000-0000-4000-a000-000000000001';