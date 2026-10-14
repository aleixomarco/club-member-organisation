-- Ziel im Repo: supabase/migrations/20261014180000_handgemachtes_nachtragen.sql
--
-- Drei Tabellen und drei Spalten gab es nur in der Produktion, in keiner
-- Migration. Diese traegt sie nach.
--
-- GEFUNDEN beim Abgleich am 14.10.2026: Alle 548 Spalten der 62
-- Produktionstabellen gegen alles, was die Migrationen dieses Verzeichnisses
-- anlegen. Uebrig blieben
--   club_task_reminders   (ganze Tabelle)
--   known_devices         (ganze Tabelle, 83 Zeilen)
--   notification_queue    (ganze Tabelle, 34 Zeilen)
--   teams.is_adult
--   profiles.show_birthday
--   duty_tasks.reminded_at
-- Alle sechs werden von Migrationen BENUTZT - gelesen, beschrieben, in
-- Funktionsrumpfen vorausgesetzt - und von keiner ANGELEGT. Sie sind also
-- irgendwann von Hand entstanden, vermutlich in der Oberflaeche von Supabase.
-- Der hauseigene Abgleich (scripts/schema-abgleich.py) sieht nur die Felder,
-- die die App anfasst; was allein die Datenbank benutzt, faellt dort nicht
-- auf. Deshalb hat es ein Jahr gedauert.
--
-- Eine Migration vom 05.09. sagt es sogar selbst, ohne die Folge zu ziehen:
-- 20260905200000:134 "duty_tasks hatte die Spalte reminded_at schon - offenbar
-- war die ...". Da hat es schon jemand gesehen.
--
-- WAS DAS HEISST
-- Das Verzeichnis beschreibt die Produktion nicht mehr vollstaendig. Wer
-- diesen Stand auf einer leeren Datenbank aufbaut - fuer eine zweite Umgebung,
-- nach einem Totalverlust, oder weil jemand den Stand nachvollziehen will -,
-- bekommt eine Datenbank, in der diese sechs Dinge fehlen. Funktionen, die sie
-- lesen, laufen dann bis zur ersten Benutzung durch und scheitern erst dort.
--
-- AENDERT IN PROD NICHTS. Alles steht unter "if not exists" beziehungsweise
-- wird vor dem Anlegen verworfen; in der Produktion ist jede dieser Zeilen ein
-- Nullschritt. Die Migration ist fuer den naechsten Aufbau da, nicht fuer
-- diesen Bestand.
--
-- WAS SIE NICHT LOEST - ausdruecklich, damit es niemand uebersieht:
-- Ein Aufbau von null scheitert weiterhin FRUEHER, naemlich an
-- 20260905200000_meldungen_vereinheitlichen.sql:86:
--     drop trigger if exists notification_queue_in_glocke on public.notification_queue;
-- "drop trigger if exists" vertraegt einen fehlenden Trigger, aber keine
-- fehlende TABELLE. Weil diese Migration hier spaeter datiert ist, kommt sie
-- zu spaet. Das zu beheben hiesse, die Reihenfolge der Geschichte anzufassen -
-- entweder diese Datei vordatieren oder die vom 05.09. nachtraeglich
-- ergaenzen. Beides aendert, was einmal ausgeliefert wurde, und das ist eine
-- Entscheidung des Betreibers, keine Nebensache einer Fehlerbehebung.
--
-- Geprueft am 14.10.2026 (nur lesend, PROD): Spalten, Typen, Vorgabewerte,
-- Schluessel, Indexe, Zeilenregeln, Ausloeser und Rechte stammen Zeichen fuer
-- Zeichen aus dem Katalog der laufenden Datenbank.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden.

-- ------------------------------------------------- Die drei Spalten
/* teams.is_adult: An ihr haengt die ganze Strafenverwaltung - alle vier
   Zeilenregeln auf team_penalty_rules und team_penalty_assignments verlangen
   is_adult_team(team_id), und das liest genau diese Spalte. */
alter table public.teams     add column if not exists is_adult      boolean not null default false;
/* profiles.show_birthday: entscheidet, ob der Geburtstag im Verein sichtbar
   ist. Die Geburtstagserinnerung liest sie (20260907060000:1476). */
alter table public.profiles  add column if not exists show_birthday boolean not null default true;
/* duty_tasks.reminded_at: haelt fest, dass die Erinnerung zu einer
   Helferaufgabe schon hinaus ist - ohne sie kaeme sie taeglich erneut. */
alter table public.duty_tasks add column if not exists reminded_at  timestamptz;

-- ------------------------------------------------- club_task_reminders
/* Eine Zeile je Verein, sobald die erste Erinnerung an offene Vereinsaufgaben
   ausgeloest wurde. Mehr steht nicht drin: Der Primaerschluessel IST die
   Vereinskennung, und "on conflict do nothing" beim Einfuegen macht daraus
   den Riegel, der die Erinnerung genau einmal je Verein schickt. */
create table if not exists public.club_task_reminders (
  club_id      uuid        not null primary key references public.clubs(id) on delete cascade,
  triggered_at timestamptz not null default now()
);
alter table public.club_task_reminders enable row level security;
drop policy if exists "club members read task reminders" on public.club_task_reminders;
create policy "club members read task reminders" on public.club_task_reminders
  for select using (exists (
    select 1 from public.club_memberships m
     where m.club_id = club_task_reminders.club_id
       and m.profile_id = auth.uid()
       and m.status = 'active'));
grant select, insert, update, delete on public.club_task_reminders to authenticated, service_role;

-- ------------------------------------------------- known_devices
/* Welches Geraet dieses Konto schon einmal benutzt hat. Daran haengt die
   Meldung "Neue Anmeldung auf einem unbekannten Geraet": Ist das Paar aus
   Konto und Geraetekennung neu, geht sie hinaus, sonst nicht.
   Der Fremdschluessel zeigt auf auth.users, nicht auf profiles - ein Geraet
   gehoert zum KONTO, nicht zur Mitgliedschaft in einem Verein. */
create table if not exists public.known_devices (
  profile_id    uuid        not null references auth.users(id) on delete cascade,
  device_hash   text        not null,
  user_agent    text,
  first_seen_at timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  primary key (profile_id, device_hash)
);
alter table public.known_devices enable row level security;
drop policy if exists "users read own known devices" on public.known_devices;
create policy "users read own known devices" on public.known_devices
  for select using (profile_id = auth.uid());
grant select, insert, update, delete on public.known_devices to authenticated, service_role;

-- ------------------------------------------------- notification_queue
/* Der alte Weg der Mitteilungen: notify_* schrieb hierhin, ein Ausloeser
   schickte die Push. Seit dem 05.09. ist das umgedreht - geschrieben wird in
   user_notifications, und was noch hier landet, traegt der Ausloeser
   notification_queue_in_glocke in die Glocke nach. Die Tabelle ist damit kein
   toter Rest, sondern die Bruecke fuer alles, was den alten Weg noch geht. */
create table if not exists public.notification_queue (
  id            uuid        not null primary key default gen_random_uuid(),
  club_id       uuid        not null references public.clubs(id) on delete cascade,
  membership_id uuid        not null references public.club_memberships(id) on delete cascade,
  notif_type    text        not null,
  title         text        not null,
  body          text        not null,
  data          jsonb       default '{}'::jsonb,
  created_at    timestamptz not null default now(),
  processed_at  timestamptz
);
create index if not exists notification_queue_club_id_idx       on public.notification_queue (club_id);
create index if not exists notification_queue_membership_id_idx on public.notification_queue (membership_id);
alter table public.notification_queue enable row level security;
drop policy if exists "members read own notification queue" on public.notification_queue;
create policy "members read own notification queue" on public.notification_queue
  for select using (membership_id in (
    select m.id from public.club_memberships m where m.profile_id = auth.uid()));
grant select, insert, update, delete on public.notification_queue to authenticated, service_role;

/* Der Ausloeser nur, wenn es seine Funktion schon gibt. Auf einem Aufbau von
   null entsteht sie frueher (20260905200000); sollte jemand diese Migration
   je allein einspielen, bleibt sie ohne Ausloeser stehen, statt mit einem
   Fehler abzubrechen. Ein fehlender Ausloeser laesst sich nachtragen, eine
   abgebrochene Migration kostet den ganzen Lauf. */
do $$
begin
  if to_regprocedure('public.warteschlange_in_glocke()') is not null then
    drop trigger if exists notification_queue_in_glocke on public.notification_queue;
    create trigger notification_queue_in_glocke
      after insert on public.notification_queue
      for each row execute function public.warteschlange_in_glocke();
  else
    raise warning 'warteschlange_in_glocke() fehlt - Ausloeser auf notification_queue nicht angelegt.';
  end if;
end $$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: drei_tabellen = 3, drei_spalten = 3, zeilenregeln = 3,
--           rls_an = 3, ausloeser_haengt = true,
--           known_devices_zeilen = 83, warteschlange_zeilen = 34,
--           erinnerungen_zeilen = 0 (Stand vom 14.10.2026 - die Migration
--           legt nichts an und loescht nichts).
select
  (select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace
     and c.relname in ('club_task_reminders','known_devices','notification_queue')) as drei_tabellen,
  (select count(*) from pg_attribute a where not a.attisdropped and a.attnum > 0
     and ((a.attrelid = 'public.teams'::regclass      and a.attname = 'is_adult')
       or (a.attrelid = 'public.profiles'::regclass   and a.attname = 'show_birthday')
       or (a.attrelid = 'public.duty_tasks'::regclass and a.attname = 'reminded_at'))) as drei_spalten,
  (select count(*) from pg_policy
     where polrelid::regclass::text in ('club_task_reminders','known_devices','notification_queue')) as zeilenregeln,
  (select count(*) from pg_class c where c.relnamespace = 'public'::regnamespace
     and c.relname in ('club_task_reminders','known_devices','notification_queue')
     and c.relrowsecurity)                                                           as rls_an,
  (select exists (select 1 from pg_trigger t join pg_class c on c.oid = t.tgrelid
     where c.relname = 'notification_queue' and t.tgname = 'notification_queue_in_glocke'
       and not t.tgisinternal))                                                      as ausloeser_haengt,
  (select count(*) from public.known_devices)        as known_devices_zeilen,
  (select count(*) from public.notification_queue)   as warteschlange_zeilen,
  (select count(*) from public.club_task_reminders)  as erinnerungen_zeilen;
