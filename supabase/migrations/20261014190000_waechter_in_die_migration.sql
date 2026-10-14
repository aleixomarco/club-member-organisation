-- Ziel im Repo: supabase/migrations/20261014190000_waechter_in_die_migration.sql
--
-- Vier der neun naechtlichen Auftraege gab es nur von Hand. Diese traegt sie
-- nach.
--
-- GEFUNDEN am 14.10.2026, beim selben Durchgang, der schon drei Tabellen und
-- drei Spalten gefunden hat: Was laeuft, muss auch in den Migrationen stehen,
-- sonst laesst sich dieser Stand nicht nachbauen.
--
--   schedule in einer Migration      nur von Hand in cron.job
--   ---------------------------      ------------------------
--   aufgaben-erinnerung              birthday-reminders
--   benachrichtigungen-aufraeumen    carpool-gap-check
--   bewirtung-erinnerung             duty-gap-check
--   ergebnis-erinnerung              duty-task-due-reminders
--   fehlerberichte-aufraeumen
--
-- Die vier rechts kommen in Migrationen VOR - aber nur im Fliesstext und in
-- Kontrollbloecken ("where jobname in (...)"). Angelegt hat sie keine.
-- Gezaehlt wurde nicht mit grep auf den Namen, sondern auf cron.schedule:
-- Eine Erwaehnung ist keine Einplanung.
--
-- WAS DAS HEISST
-- Auf einer frisch aufgebauten Datenbank liefen vier der neun Auftraege nicht:
-- kein "Helfer gesucht" drei Tage vor dem Heimspiel, kein "Noch keine
-- Fahrgemeinschaft" vor dem Auswaertsspiel, keine Geburtstagsmeldung, keine
-- Erinnerung an faellige Helferaufgaben. Und zwar lautlos - ein Auftrag, den
-- es nicht gibt, meldet sich nicht.
--
-- AENDERT IN PROD NICHTS. cron.schedule legt einen Auftrag unter demselben
-- Namen nicht doppelt an, sondern schreibt ihn um; Zeitplan und Befehl sind
-- Zeichen fuer Zeichen die, die heute in cron.job stehen. Die Auftragsnummern
-- bleiben dieselben, die Laufgeschichte bleibt stehen.
--
-- WARUM NICHT GLEICH ALLE NEUN: Die fuenf anderen stehen schon in Migrationen.
-- Sie hier zu wiederholen hiesse, zwei Stellen zu haben, die dasselbe sagen -
-- und beim naechsten Umbau sagen sie Verschiedenes.
--
-- Geprueft am 14.10.2026 (nur lesend, PROD): Alle vier Funktionen gibt es
-- (run_birthday_reminders, run_carpool_gap_check, run_duty_gap_check,
-- run_duty_task_due_reminders), alle vier Auftraege stehen auf active und
-- haben in den letzten sieben Tagen ausschliesslich mit "succeeded" geendet.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden.

/* Nur einplanen, was es auch zu rufen gibt. Auf einem Aufbau von null
   entstehen die Funktionen frueher; sollte eine fehlen, bleibt der Auftrag
   aus, statt die Migration abzubrechen - und sagt warum. Ein fehlender
   Auftrag laesst sich nachtragen, ein abgebrochener Lauf kostet alles
   dahinter.

   Vier Mal dasselbe ausgeschrieben statt einer Schleife ueber eine
   Werteliste - mit Absicht. Eine Schleife haette die Namen in Variablen
   versteckt, und scripts/schema-drift.py sucht genau nach
   cron.schedule('<name>'. Eine Migration, die einplant, ohne dass man es
   lesen kann, ist fuer jede Pruefung dasselbe wie keine. Lieber vier Zeilen
   mehr, die man findet. */
do $$
begin
  if to_regprocedure('public.run_birthday_reminders()') is not null then
    perform cron.schedule('birthday-reminders', '0 7 * * *', 'select public.run_birthday_reminders();');
  else
    raise warning 'public.run_birthday_reminders() fehlt - birthday-reminders nicht eingeplant.';
  end if;

  if to_regprocedure('public.run_duty_task_due_reminders()') is not null then
    perform cron.schedule('duty-task-due-reminders', '0 7 * * *', 'select public.run_duty_task_due_reminders();');
  else
    raise warning 'public.run_duty_task_due_reminders() fehlt - duty-task-due-reminders nicht eingeplant.';
  end if;

  if to_regprocedure('public.run_duty_gap_check()') is not null then
    perform cron.schedule('duty-gap-check', '0 9 * * *', 'select public.run_duty_gap_check();');
  else
    raise warning 'public.run_duty_gap_check() fehlt - duty-gap-check nicht eingeplant.';
  end if;

  if to_regprocedure('public.run_carpool_gap_check()') is not null then
    perform cron.schedule('carpool-gap-check', '0 9 * * *', 'select public.run_carpool_gap_check();');
  else
    raise warning 'public.run_carpool_gap_check() fehlt - carpool-gap-check nicht eingeplant.';
  end if;
end $$;

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: auftraege_gesamt = 9, alle_aktiv = true, die vier Zeitplaene
--           unveraendert (0 7, 0 7, 0 9, 0 9) und jeder Befehl auf seine
--           Funktion zeigend.
select
  (select count(*) from cron.job)                                as auftraege_gesamt,
  (select bool_and(active) from cron.job)                        as alle_aktiv,
  (select count(*) from cron.job
    where (jobname, schedule, command) in (
      ('birthday-reminders',      '0 7 * * *', 'select public.run_birthday_reminders();'),
      ('duty-task-due-reminders', '0 7 * * *', 'select public.run_duty_task_due_reminders();'),
      ('duty-gap-check',          '0 9 * * *', 'select public.run_duty_gap_check();'),
      ('carpool-gap-check',       '0 9 * * *', 'select public.run_carpool_gap_check();')))
                                                                 as die_vier_wie_zuvor,
  (select count(*) from cron.job_run_details d
    where d.start_time > now() - interval '7 days' and d.status <> 'succeeded')
                                                                 as fehlgeschlagene_laeufe;
