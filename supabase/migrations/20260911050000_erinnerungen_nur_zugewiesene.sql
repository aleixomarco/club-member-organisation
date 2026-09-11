-- Erinnerungen zu Aufgaben nur noch an die, denen die Aufgabe gehört
--
-- Nachtrag zu 20260911030000 (Mitteilungen nur bei Zuweisung). Die Prüfung vor
-- dem Live-Schalten fand zwei Wege, auf denen weiter Mitglieder benachrichtigt
-- wurden, denen nichts zugewiesen war:
--
-- 1. aufgaben_erinnerung_senden() - täglich 18 Uhr (Cron 'aufgaben-erinnerung').
--    Eine Vereinsaufgabe ohne Verantwortliche erinnerte am Vorabend den ganzen
--    Verein, eine Mannschaftsaufgabe die ganze Mannschaft. Jetzt nur noch:
--    Verantwortliche (club_task_assignees) und wer sich eingetragen hat
--    (club_task_signups) - wer sich einträgt, hat die Aufgabe übernommen.
--    Stationen (duty_tasks) wie bisher nur an die zugewiesene Person, jetzt mit
--    Sprung zum Termin (ziel_art 'helferdienst', ziel_id = Termin).
-- 2. check_task_reminder_threshold() - der einmalige Aufruf "Der Verein braucht
--    Unterstützung" an alle, die sich noch nirgends eingetragen hatten, entfällt.
--    Die Schwelle wird weiter vermerkt; die Karte auf der Startseite
--    (get_task_signup_ratio) hängt nicht daran.
--
-- Beide Funktionen sind auf dem aktuellen Stand in Produktion aufgebaut
-- (pg_get_functiondef vom 11.09.2026), nicht auf ihrer ersten Migration.

create or replace function public.aufgaben_erinnerung_senden()
 returns integer
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select t.id, t.club_id, t.title, t.event_id, m.profile_id, coalesce(pr.language, 'de') as sprache
    from public.duty_tasks t
    join public.club_memberships m on m.id = t.assignee_membership_id
    left join public.profiles pr on pr.id = m.profile_id
    where t.due_date = (current_date + 1)
      and t.reminded_at is null and t.done is not true
      and m.profile_id is not null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select f.profile_id, f.club_id, 'duty',
           public.meldungstext('erinnerung.titel', f.sprache),
           public.meldungstext('erinnerung.morgen', f.sprache, jsonb_build_object('titel', f.title)),
           case when f.event_id is not null then 'helferdienst' end, f.event_id
    from faellig f
    where public.meldung_erlaubt(f.profile_id, 'duty')
    returning 1
  )
  update public.duty_tasks set reminded_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;

  with faellig2 as (
    select t.id, t.club_id, t.team_id, t.title
    from public.club_tasks t
    /* erledigt_am mitpruefen - wer seine Vereinsaufgabe abgehakt hat, soll am
       Vorabend keine Erinnerung mehr bekommen. */
    where t.due_date = (current_date + 1) and t.reminded_at is null
      and t.erledigt_am is null
  ), beteiligte as (
    /* Nur wem die Aufgabe gehoert: verantwortlich eingetragen oder selbst
       eingetragen. Keine Rueckfalls-Empfaenger mehr (ganzer Verein, ganze
       Mannschaft), wenn niemand verantwortlich ist. */
    select a.task_id, a.membership_id from public.club_task_assignees a
     where a.task_id in (select id from faellig2)
    union
    select s.task_id, s.membership_id from public.club_task_signups s
     where s.task_id in (select id from faellig2)
  ), empfaenger as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, f.club_id, 'tasks',
           public.meldungstext('erinnerung.titel', pr.language),
           public.meldungstext('erinnerung.morgen', pr.language, jsonb_build_object('titel', f.title)),
           'aufgabe', f.id
    from faellig2 f
    join beteiligte b on b.task_id = f.id
    join public.club_memberships m on m.id = b.membership_id and m.club_id = f.club_id and m.status = 'active'
    left join public.profiles pr on pr.id = m.profile_id
    where m.profile_id is not null
      and public.team_meldung_erlaubt(m.id, f.team_id, 'aufgaben')
      and public.meldung_erlaubt(m.profile_id, 'tasks')
    returning 1
  )
  update public.club_tasks set reminded_at = now() where id in (select id from faellig2);

  return v_anzahl;
end;
$function$;

create or replace function public.check_task_reminder_threshold(target_club uuid)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  total_active integer;
  signed_up integer;
  already_triggered boolean;
begin
  select count(*) into total_active from public.club_memberships where club_id = target_club and status = 'active';
  if total_active = 0 then return false; end if;
  select count(distinct s.membership_id) into signed_up
  from public.club_task_signups s
  join public.club_memberships m on m.id = s.membership_id
  where m.club_id = target_club and m.status = 'active';
  select exists(select 1 from public.club_task_reminders where club_id = target_club) into already_triggered;
  if already_triggered then return false; end if;
  if (signed_up::numeric / total_active::numeric) >= 0.7 then
    insert into public.club_task_reminders (club_id) values (target_club) on conflict do nothing;
    /* Hier ging bisher an jedes Mitglied ohne Eintrag "Der Verein braucht
       Unterstuetzung". Seit 20260911050000 nicht mehr: Mitteilungen zu
       Aufgaben bekommt nur, wem eine zugewiesen ist. */
    return true;
  end if;
  return false;
end;
$function$;
