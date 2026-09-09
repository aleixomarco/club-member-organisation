/* Erinnerung nur an OFFENE Vereinsaufgaben.

 * aufgaben_erinnerung_senden hat zwei Zweige. Der erste, fuer duty_tasks,
 * prueft "t.done is not true". Der zweite, fuer club_tasks, prueft nur
 * due_date und reminded_at - obwohl die Tabelle erledigt_am und erledigt_von
 * traegt.
 *
 * Folge: Wer seine Vereinsaufgabe erledigt und abgehakt hatte, bekam am
 * Vorabend trotzdem die Erinnerung, sie sei morgen faellig. Der Zeitplan
 * laeuft taeglich um 18 Uhr; das trifft jeden Betroffenen genau einmal je
 * Aufgabe (reminded_at wird danach gesetzt), aber es trifft ihn zu Unrecht.
 *
 * Der uebrige Rumpf stammt unveraendert aus der Datenbank.
 */

CREATE OR REPLACE FUNCTION public.aufgaben_erinnerung_senden()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select t.id, t.club_id, t.title, m.profile_id, coalesce(pr.language, 'de') as sprache
    from public.duty_tasks t
    join public.club_memberships m on m.id = t.assignee_membership_id
    left join public.profiles pr on pr.id = m.profile_id
    where t.due_date = (current_date + 1)
      and t.reminded_at is null and t.done is not true
      and m.profile_id is not null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select f.profile_id, f.club_id, 'duty',
           public.meldungstext('erinnerung.titel', f.sprache),
           public.meldungstext('erinnerung.morgen', f.sprache, jsonb_build_object('titel', f.title))
    from faellig f
    where public.meldung_erlaubt(f.profile_id, 'duty')
    returning 1
  )
  update public.duty_tasks set reminded_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;

  with faellig2 as (
    select t.id, t.club_id, t.team_id, t.title,
           exists (select 1 from public.club_task_assignees a where a.task_id = t.id) as hat_verantwortliche
    from public.club_tasks t
    /* erledigt_am mitpruefen - der duty_tasks-Zweig oben tut das mit
       "t.done is not true" seit jeher, dieser Zweig nicht. Wer seine
       Vereinsaufgabe abgehakt hatte, bekam am Vorabend trotzdem die
       Erinnerung, sie sei faellig. */
    where t.due_date = (current_date + 1) and t.reminded_at is null
      and t.erledigt_am is null
  ), empfaenger as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, f.club_id, 'tasks',
           public.meldungstext('erinnerung.titel', pr.language),
           public.meldungstext('erinnerung.morgen', pr.language, jsonb_build_object('titel', f.title)),
           'aufgabe', f.id
    from faellig2 f
    join public.club_memberships m on m.club_id = f.club_id and m.status = 'active'
    left join public.profiles pr on pr.id = m.profile_id
    left join public.team_members tm on tm.membership_id = m.id and tm.team_id = f.team_id
    left join public.club_task_assignees a on a.task_id = f.id and a.membership_id = m.id
    where m.profile_id is not null
      and (case when f.hat_verantwortliche then a.membership_id is not null
                when f.team_id is not null  then tm.membership_id is not null
                else true end)
      and public.team_meldung_erlaubt(m.id, f.team_id, 'aufgaben')
      and public.meldung_erlaubt(m.profile_id, 'tasks')
    returning 1
  )
  update public.club_tasks set reminded_at = now() where id in (select id from faellig2);

  return v_anzahl;
end;
$function$;
