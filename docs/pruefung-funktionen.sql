-- Welche Funktionen existieren wirklich in der Datenbank?
--
-- Hintergrund: Die App ruft 44 Datenbankfunktionen auf. 16 davon kommen in
-- keiner der 31 Migrationen vor - sie wurden vermutlich von Hand im
-- SQL-Editor angelegt. Solange die Datenbank steht, faellt das nicht auf.
-- Muesste sie neu aufgebaut werden, fehlten sie.
--
-- In PROD ausführen. Ändert nichts.

select
  p.proname                                   as funktion,
  pg_get_function_identity_arguments(p.oid)   as parameter,
  case p.prosecdef when true then 'definer' else 'invoker' end as rechte,
  case when p.proname = any (array[
    'apply_duty_template','archive_club_team','can_manage_duty_task',
    'check_task_reminder_threshold','claim_duty_task','create_recurring_events',
    'delete_event_series','get_booking_contact_phone','get_task_signup_ratio',
    'mark_penalty_paid','notify_club','notify_many','respond_to_join_request',
    'run_season_reset','update_club_team','update_news_post'
  ]) then 'FEHLT ALS MIGRATION' else '' end   as hinweis
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by hinweis desc, p.proname;

-- Kurzfassung: Wie viele der 16 sind tatsächlich vorhanden?
select count(*) as vorhanden_von_16
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = any (array[
    'apply_duty_template','archive_club_team','can_manage_duty_task',
    'check_task_reminder_threshold','claim_duty_task','create_recurring_events',
    'delete_event_series','get_booking_contact_phone','get_task_signup_ratio',
    'mark_penalty_paid','notify_club','notify_many','respond_to_join_request',
    'run_season_reset','update_club_team','update_news_post'
  ]);
