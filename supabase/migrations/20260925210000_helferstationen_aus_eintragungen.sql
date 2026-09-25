-- Ziel im Repo: supabase/migrations/20260925210000_helferstationen_aus_eintragungen.sql
--
-- Die offenen Punkte zaehlen unbesetzte Helferstationen jetzt dort, wo der
-- Verein sie auch einteilt.
--
-- WAS NICHT STIMMTE
-- Es gab zwei Helferlisten nebeneinander, jede mit eigener Ablage:
--   oben  "Helfer:innen gesucht"  -> events.helper_slots + duty_assignments
--                                    (selbst uebernehmen, Leitung traegt ein)
--   unten "Helferdienst"          -> duty_tasks (eine Person je Station,
--                                    Frist, "Erledigt?")
-- Wer oben jemanden eintrug, aenderte unten nichts und umgekehrt. In PROD
-- war das am 25.09.2026 deutlich zu sehen: 12 Zeilen in duty_tasks, davon 2
-- mit Person - und 0 Zeilen in duty_assignments.
--
-- Der Betreiber hat sich fuer die obere Liste entschieden: Vorlage je
-- Heimspiel waehlen, dann tragen sich Helfer selbst ein oder die Leitung
-- traegt sie ein. Die untere Liste verschwindet aus der Oberflaeche.
--
-- Damit stimmte dieser Zweig nicht mehr: Er las duty_tasks. Eine Station,
-- die oben voll besetzt ist, haette in der Verwaltung weiter als "unbesetzt"
-- gestanden - und zwar fuer immer, weil sie unten niemand mehr zuweisen
-- kann.
--
-- JETZT: gezaehlt wird eine Station des Termins (events.helper_slots), zu der
-- es keine einzige Eintragung in duty_assignments gibt. Dieselbe Frist wie
-- bisher (die naechsten vierzehn Tage), abgesagte Termine bleiben aussen vor.
--
-- ziel_id ist jetzt der Termin und nicht mehr die Aufgabenzeile. Das ist
-- ohne Folgen: Fuer ziel = 'duty' oeffnet die App die Helferplanung
-- (goHelfer) und benutzt ziel_id nicht. Ein Termin kann aber mehrere
-- unbesetzte Stationen haben, deshalb kommt ziel_id mehrfach vor - die Liste
-- in der Verwaltung unterscheidet die Zeilen ab sofort zusaetzlich ueber
-- ihre Reihenfolge.
--
-- Die uebrigen fuenf Zweige stehen Wort fuer Wort wie vorher.
-- Geprueft am 25.09.2026 gegen den Livestand (nur lesend).

create or replace function public.offene_punkte_fuer_verein(target_club uuid)
returns table(art text, titel text, detail text, ziel text, ziel_id uuid, seit timestamptz)
language plpgsql stable security definer set search_path to 'public' as $function$
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
         s.station || coalesce(' · ' || to_char(e.starts_at, 'DD.MM.'), ''),
         'duty'::text, e.id, e.starts_at
  from public.events e
  cross join lateral unnest(e.helper_slots) as s(station)
  where e.club_id = target_club
    and e.helper_slots is not null
    and e.starts_at between now() and now() + interval '14 days'
    and e.status is distinct from 'cancelled'
    and not exists (select 1 from public.duty_assignments a
                     where a.event_id = e.id and a.station = s.station)

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
$function$;

revoke all on function public.offene_punkte_fuer_verein(uuid) from public, anon;
grant execute on function public.offene_punkte_fuer_verein(uuid) to authenticated, service_role;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: liest_eintragungen = true, liest_duty_tasks_nicht_mehr = true,
-- authenticated_darf = true, anon_darf_nicht = false.
select (select position('duty_assignments' in pg_get_functiondef(
          'public.offene_punkte_fuer_verein(uuid)'::regprocedure)) > 0)          as liest_eintragungen,
       (select position('duty_tasks' in pg_get_functiondef(
          'public.offene_punkte_fuer_verein(uuid)'::regprocedure)) = 0)          as liest_duty_tasks_nicht_mehr,
       (select has_function_privilege('authenticated',
          'public.offene_punkte_fuer_verein(uuid)'::regprocedure, 'EXECUTE'))    as authenticated_darf,
       (select has_function_privilege('anon',
          'public.offene_punkte_fuer_verein(uuid)'::regprocedure, 'EXECUTE'))    as anon_darf_nicht;
