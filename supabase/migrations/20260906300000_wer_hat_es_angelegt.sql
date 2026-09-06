-- Wer hat das angelegt, und wann?
--
-- WARUM
-- In einem Verein arbeiten viele an denselben Daten. Wenn ein Termin falsch
-- steht, eine Aufgabe doppelt da ist oder eine Strafe ueberrascht, ist die
-- erste Frage immer dieselbe: Wer war das? Bisher konnte das niemand
-- beantworten - die Angabe stand in der Datenbank, aber nirgends in der App.
--
-- WAS SCHON DA WAR
-- Die meisten Tabellen halten es laengst fest, nur unter verschiedenen
-- Namen: events.created_by, news_posts.author_id, event_results.erfasst_von,
-- carpools.driver_membership_id, vehicle_bookings.membership_id,
-- team_penalty_assignments.assigned_by. Fuer die aendert sich hier nichts -
-- sie werden nur endlich angezeigt.
--
-- WAS FEHLTE
-- Zwei Tabellen halten nur den Zeitpunkt fest, nicht die Person: teams und
-- tipp_runden. Die bekommen created_by dazu.
--
-- KEINE NACHTRAEGLICHE ZUORDNUNG
-- Fuer alles, was vor heute angelegt wurde, bleibt created_by leer. Man
-- KOENNTE raten - der aelteste Vereinsadmin wird es schon gewesen sein -,
-- aber eine geratene Angabe ist schlimmer als gar keine: Sie sieht aus wie
-- eine Tatsache. Die App zeigt in diesem Fall nur das Datum.

alter table public.teams
  add column if not exists created_by uuid references public.club_memberships(id) on delete set null;
alter table public.tipp_runden
  add column if not exists created_by uuid references public.club_memberships(id) on delete set null;

comment on column public.teams.created_by is
  'Wer die Mannschaft angelegt hat. Leer bei allem, was vor September 2026 entstand.';
comment on column public.tipp_runden.created_by is
  'Wer die Tipprunde freigegeben hat. Leer bei allem, was vor September 2026 entstand.';

/* Die Regel auf teams laesst nur Vereinsleitung schreiben; die neue Spalte
   aendert daran nichts. tipp_runden wird ueber eine Funktion geschrieben -
   die muss den Wert mitgeben, sonst bleibt er leer. */

select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='teams' and column_name='created_by') as teams,
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='tipp_runden' and column_name='created_by') as tipprunden;
