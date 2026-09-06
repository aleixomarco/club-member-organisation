-- Nachtrag: Die Liste war verrauscht.
--
-- Der erste Wurf nahm JEDE unerledigte Aufgabe auf. Bei einem Verein mit
-- woechentlichen Heimspielen sind das drei Helferstationen pro Spieltag - nach
-- vier Spieltagen zwoelf Zeilen "Zeitnahme, Grill, Hallensprecher", immer
-- dieselben. Eine Liste, die man wegscrollt, ist keine Liste.
--
-- Aufgenommen wird jetzt nur, was HANDLUNG BRAUCHT:
--   Helferstationen: nur unbesetzte, und nur fuer Termine in den naechsten
--     14 Tagen. Eine unbesetzte Station in sechs Wochen ist kein Problem.
--   Vereinsaufgaben: nur faellige oder ueberfaellige.
--
-- Mitgliedsantraege und fehlende Ergebnisse bleiben unveraendert - die sind
-- immer dringend.

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

  /* Unbesetzte Helferstationen der naechsten 14 Tage */
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

  /* Faellige oder ueberfaellige Vereinsaufgaben */
  select 'aufgabe'::text, 'Offene Aufgabe'::text,
         t.title || coalesce(' · fällig ' || to_char(t.due_date, 'DD.MM.'), ''),
         'duty'::text, t.id, coalesce(t.due_date::timestamptz, t.created_at)
  from public.club_tasks t
  where t.club_id = target_club
    and (t.due_date is null or t.due_date <= current_date + 14)

  order by 6 asc;
end;
$$;

select count(*) as funktion from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='offene_punkte_fuer_verein';
