-- Vereinsaufgaben brauchen Uhrzeiten.
--
-- Bisher gab es nur ein Faelligkeitsdatum. "Kuchenverkauf am 12.09." sagt
-- nicht, ob jemand um 9 Uhr aufbaut oder um 15 Uhr uebernimmt - und genau das
-- ist die Frage, die den Helfer interessiert.
--
-- Zwei getrennte Zeitspalten statt zweier Zeitstempel: Das Datum steht schon in
-- due_date, und eine Aufgabe laeuft nicht ueber Mitternacht. Zwei timestamptz
-- waeren dieselbe Information doppelt - und zwei Stellen, an denen das Datum
-- auseinanderlaufen kann.

alter table public.club_tasks
  add column if not exists start_time time,
  add column if not exists end_time   time;

/* Ende nach Anfang - sonst steht in der Liste "14:00 bis 09:00". */
do $$ begin
  alter table public.club_tasks
    add constraint club_tasks_zeitfolge
    check (start_time is null or end_time is null or end_time > start_time);
exception when duplicate_object then null; end $$;

select count(*) as spalten from information_schema.columns
 where table_schema='public' and table_name='club_tasks' and column_name in ('start_time','end_time');
