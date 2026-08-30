-- Ein Mitglied muss sich aus dem Verein entfernen lassen.
--
-- Die Sicherheitsregel erlaubt es der Vereinsleitung längst ("admins manage
-- memberships" deckt ALL ab). Praktisch scheiterte es aber an vier
-- Fremdschlüsseln, die auf NO ACTION standen und die Löschung damit blockieren:
--
--   club_tasks.created_by
--   club_vehicles.created_by
--   duty_task_templates.created_by
--   duty_tasks.created_by
--
-- Wer je eine Aufgabe, ein Fahrzeug oder eine Helfer-Vorlage angelegt hat -
-- also so gut wie jede und jeder aus der Vereinsleitung - liess sich nicht
-- entfernen. Es ist dieselbe Falle wie bei news_posts.author_id.
--
-- Alle vier Spalten sind bereits nullable, es genügt das Löschverhalten. Die
-- angelegten Aufgaben, Fahrzeuge und Vorlagen bleiben dem Verein erhalten und
-- verlieren nur den Vermerk, wer sie angelegt hat - das ist richtig so, denn
-- sie gehören dem Verein, nicht der Person.
--
-- Die übrigen Verweise stehen längst auf CASCADE (Rollen, Mannschaftszuordnung,
-- Fahrgemeinschaften, Helfereinteilung, Beiträge, Benachrichtigungen) oder auf
-- SET NULL. Sie brauchen nichts.

alter table public.club_tasks drop constraint if exists club_tasks_created_by_fkey;
alter table public.club_tasks
  add constraint club_tasks_created_by_fkey
  foreign key (created_by) references public.club_memberships(id) on delete set null;

alter table public.club_vehicles drop constraint if exists club_vehicles_created_by_fkey;
alter table public.club_vehicles
  add constraint club_vehicles_created_by_fkey
  foreign key (created_by) references public.club_memberships(id) on delete set null;

alter table public.duty_task_templates drop constraint if exists duty_task_templates_created_by_fkey;
alter table public.duty_task_templates
  add constraint duty_task_templates_created_by_fkey
  foreign key (created_by) references public.club_memberships(id) on delete set null;

alter table public.duty_tasks drop constraint if exists duty_tasks_created_by_fkey;
alter table public.duty_tasks
  add constraint duty_tasks_created_by_fkey
  foreign key (created_by) references public.club_memberships(id) on delete set null;

-- Kontrolle: keiner dieser vier darf noch blockieren.
select c.conrelid::regclass::text as tabelle, c.confdeltype as verhalten
from pg_constraint c
where c.contype = 'f'
  and c.confrelid = 'public.club_memberships'::regclass
  and c.confdeltype in ('a', 'r')
order by tabelle;
