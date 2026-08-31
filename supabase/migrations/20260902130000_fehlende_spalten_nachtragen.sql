-- Spalten, die es nur in der Produktivdatenbank gab.
--
-- Derselbe Befund wie bei den sieben Tabellen: benutzt von der App, in keiner
-- Migration beschrieben. Auf einer frisch aufgebauten Datenbank würde die App
-- an jeder dieser Stellen mit "column does not exist" abbrechen.
--
-- Aus der laufenden Datenbank ausgelesen; dort sind die Anweisungen wirkungslos.

alter table public.club_memberships
  -- Wie oft eine Beitrittsanfrage abgelehnt wurde. Reine Zählung: Eine Frist
  -- hängt seit dem 31.08. ausdrücklich nicht mehr daran, abgelehnte Personen
  -- dürfen sich jederzeit wieder melden.
  add column if not exists rejection_count integer not null default 0,
  -- Bis wann jemand keine neue Anfrage stellen konnte. Altbestand aus der
  -- abgeschafften Frist; die App setzt die Spalte nur noch auf null.
  add column if not exists blocked_until timestamptz,
  -- Als was sich jemand beworben hat, bevor die Vereinsleitung entschieden hat.
  add column if not exists requested_role public.club_role,
  add column if not exists requested_team text;

-- Terminserien: Alle Termine einer Serie tragen dieselbe Kennung, damit sich
-- "diesen Termin" und "die ganze Serie" unterscheiden lassen.
alter table public.events
  add column if not exists series_id uuid;

create index if not exists events_series_idx on public.events(series_id) where series_id is not null;

-- Helferaufgaben: erledigt und bis wann.
alter table public.duty_tasks
  add column if not exists done boolean not null default false,
  add column if not exists due_date date;
