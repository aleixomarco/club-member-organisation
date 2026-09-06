-- Eine Vereinsaufgabe laesst sich abhaken - und wer verantwortlich ist,
-- belegt einen Platz.
--
-- WAS NICHT STIMMTE
-- Eine Aufgabe kennt zwei Arten von Menschen, und die stehen in zwei
-- Tabellen:
--   club_task_assignees  wer dafuer VERANTWORTLICH ist (von der Leitung
--                        eingetragen)
--   club_task_signups    wer sich FREIWILLIG gemeldet hat
--
-- Die Ansicht zaehlte nur die zweite. Wer als Verantwortlicher eingetragen
-- war, sah deshalb "1 von 1 frei" und einen Knopf "Eintragen" - fuer eine
-- Aufgabe, die ihm bereits gehoert. Genau das ist passiert: Die Aufgabe
-- stand in seiner To-do-Liste, und die Ansicht dahinter tat, als suche sie
-- noch jemanden.
--
-- UND: ES GAB KEIN ERLEDIGT
-- club_tasks hatte keine Spalte dafuer. Eine Aufgabe blieb ewig offen; im
-- To-do-Board der Vereinsleitung stand sie bis in alle Zeit, weil die
-- Abfrage gar keine Bedingung hatte, unter der sie verschwindet.
--
-- WARUM EINE FUNKTION UND NICHT EINE REGEL AUF DER TABELLE
-- Abhaken darf, wer die Aufgabe uebernommen hat - der Verantwortliche, der
-- Eingetragene, der Ersteller, die Vereinsleitung. Die Schreibregel auf
-- club_tasks fuer diese Gruppe zu oeffnen hiesse, ihnen auch Titel, Frist
-- und Plaetze freizugeben. Diese Funktion schreibt genau zwei Spalten.

alter table public.club_tasks add column if not exists erledigt_am timestamptz;
alter table public.club_tasks add column if not exists erledigt_von uuid
  references public.club_memberships(id) on delete set null;

comment on column public.club_tasks.erledigt_am is
  'Wann die Aufgabe abgehakt wurde. Leer heisst: offen.';

create or replace function public.aufgabe_erledigen(target_task uuid, erledigt boolean default true)
returns timestamptz
language plpgsql security definer set search_path = 'public' as $$
declare
  v_club uuid;
  v_mitglied uuid;
begin
  select club_id into v_club from public.club_tasks where id = target_task;
  if v_club is null then raise exception 'Aufgabe nicht gefunden'; end if;

  select m.id into v_mitglied
  from public.club_memberships m
  where m.club_id = v_club and m.profile_id = auth.uid() and m.status = 'active';
  if v_mitglied is null then raise exception 'Not authorized'; end if;

  /* Wer darf abhaken: der Verantwortliche, wer sich eingetragen hat, der
     Ersteller - und die Vereinsleitung, damit eine Aufgabe nicht liegen
     bleibt, weil die zustaendige Person den Verein verlassen hat. */
  if not (
    exists (select 1 from public.club_task_assignees a
             where a.task_id = target_task and a.membership_id = v_mitglied)
    or exists (select 1 from public.club_task_signups s
                where s.task_id = target_task and s.membership_id = v_mitglied)
    or exists (select 1 from public.club_tasks t
                where t.id = target_task and t.created_by = v_mitglied)
    or public.has_club_role(v_club, array['vereinsadmin','sysadmin','organisator']::club_role[])
  ) then
    raise exception 'Not authorized';
  end if;

  update public.club_tasks
     set erledigt_am = case when erledigt then now() else null end,
         erledigt_von = case when erledigt then v_mitglied else null end
   where id = target_task;

  return (select erledigt_am from public.club_tasks where id = target_task);
end;
$$;

grant execute on function public.aufgabe_erledigen(uuid, boolean) to authenticated, service_role;

select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='club_tasks'
      and column_name in ('erledigt_am','erledigt_von')) as spalten,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='aufgabe_erledigen') as funktion;
CREATE OR REPLACE FUNCTION public.offene_punkte_fuer_verein(target_club uuid)
 RETURNS TABLE(art text, titel text, detail text, ziel text, ziel_id uuid, seit timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.has_club_role(target_club, array['vereinsadmin','sysadmin','organisator']::club_role[]) then
    raise exception 'Not authorized';
  end if;

  return query
  select 'mitgliedsantrag'::text, 'Offener Mitgliedsantrag'::text,
         m.display_name || coalesce(', ' || u.email, ''),
         'memberships'::text, m.id, m.created_at
  from public.club_memberships m
  left join auth.users u on u.id = m.profile_id
  where m.club_id = target_club and m.status = 'pending'

  union all

  select 'fahrzeuganfrage'::text, 'Offene Fahrzeug-Buchungsanfrage'::text,
         coalesce(m.display_name, 'Unbekannt') || ' · ' || to_char(b.starts_at, 'DD.MM. HH24:MI'),
         'vehicle'::text, b.id, b.created_at
  from public.vehicle_bookings b
  left join public.club_memberships m on m.id = b.membership_id
  where b.club_id = target_club and b.status = 'angefragt'

  union all

  select 'spielergebnis'::text, 'Offenes Spielergebnis'::text,
         e.title || coalesce(' · ' || t.name, ''),
         'results'::text, e.id, e.starts_at
  from public.events e
  left join public.teams t on t.id = e.team_id
  left join public.event_results r on r.event_id = e.id
  where e.club_id = target_club and e.type = 'spiel'
    and e.status is distinct from 'cancelled'
    and e.starts_at < now() - interval '3 hours'
    and e.starts_at > now() - interval '60 days'
    and r.event_id is null

  union all

  /* Helferstationen -> Helferplanung */
  select 'helferstation'::text, 'Unbesetzte Helferstation'::text,
         t.title || coalesce(' · ' || to_char(e.starts_at, 'DD.MM.'), ''),
         'duty'::text, t.id, e.starts_at
  from public.duty_tasks t
  join public.events e on e.id = t.event_id
  where t.club_id = target_club and t.done is not true
    and t.assignee_membership_id is null
    and e.starts_at between now() and now() + interval '14 days'
    and e.status is distinct from 'cancelled'

  union all

  /* Vereinsaufgaben -> eigene Aufgaben-Ansicht */
  select 'aufgabe'::text, 'Offene Aufgabe'::text,
         t.title || coalesce(' · fällig ' || to_char(t.due_date, 'DD.MM.'), ''),
         'tasks'::text, t.id, coalesce(t.due_date::timestamptz, t.created_at)
  from public.club_tasks t
  where t.club_id = target_club
    and t.erledigt_am is null
    and (t.due_date is null or t.due_date <= current_date + 14)

  order by 6 asc;
end;
$function$
;
