-- Nachtrag: Offene Fahrzeug-Buchungsanfragen gehoeren auch auf das Board.
--
-- Sie sind der dringendste Punkt der Liste: Wer ein Fahrzeug anfragt, plant
-- damit eine Fahrt. Bleibt die Anfrage liegen, weiss er bis zuletzt nicht, ob
-- er fahren kann - und erfaehrt es womoeglich gar nicht.

create or replace function public.offene_punkte_fuer_verein(target_club uuid)
returns table (art text, titel text, detail text, ziel text, ziel_id uuid, seit timestamptz)
language plpgsql stable security definer set search_path = 'public' as $$
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

  select 'aufgabe'::text, 'Offene Aufgabe'::text,
         t.title || coalesce(' · fällig ' || to_char(t.due_date, 'DD.MM.'), ''),
         'duty'::text, t.id, coalesce(t.due_date::timestamptz, t.created_at)
  from public.club_tasks t
  where t.club_id = target_club
    and (t.due_date is null or t.due_date <= current_date + 14)

  order by 6 asc;
end;
$$;
