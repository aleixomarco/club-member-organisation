-- Tipp-Tabelle: abgesagte Spiele zaehlen nicht, und tipps zaehlt nur, was in
-- die Wertung geht.
--
-- Angenommene Vorgabe vom 13.09.2026: Das verwaiste Ergebnis am abgesagten
-- Spiel bleibt verborgen. Die App rechnet abgesagte Spiele schon heute nicht
-- (tippBegegnungen in app/page.tsx), die Tabelle aus 20260906100000:112-140
-- aber schon: Das verwaiste Ergebnis bringt einem Tipper in einer AKTIVEN Runde
-- 4 Punkte fuer ein Spiel, das in seiner Liste gar nicht auftaucht.
-- Wirkung dieser Migration heute: genau diese 4 Punkte fallen weg.
--
-- Zweite Korrektur: count(p.event_id) zaehlte alle Tipps des Profils ueber alle
-- Mannschaften und Vereine, weil der LEFT JOIN auf events p nicht einschraenkt.
-- count(e.id) zaehlt nur Tipps auf gewertete Spiele dieser Runde.
--
-- Die Speicherung (wir:Gegner in beiden Tabellen) ist fuer den Vergleich
-- unerheblich, solange beide dieselbe haben - daran aendert dieses Release nichts.
-- Der Suchpfad ist jetzt leer; is_club_member setzt seinen eigenen.
create or replace function public.tipp_tabelle(target_runde uuid)
returns table (membership_id uuid, name text, punkte integer, tipps integer)
language plpgsql stable security definer set search_path = '' as $$
declare v_club uuid; v_team uuid;
begin
  select club_id, team_id into v_club, v_team from public.tipp_runden where id = target_runde;
  if v_club is null then raise exception 'Round not found'; end if;
  if not public.is_club_member(v_club) then raise exception 'Not authorized'; end if;

  return query
  select m.id, m.display_name,
    coalesce(sum(
      case
        when er.heim is null or p.home_score is null then 0
        when p.home_score = er.heim and p.away_score = er.auswaerts then 3
        when sign(p.home_score - p.away_score) = sign(er.heim - er.auswaerts) then 1
        else 0
      end)::integer, 0),
    count(e.id)::integer
  from public.tipp_teilnehmer tp
  join public.club_memberships m on m.id = tp.membership_id
  left join public.predictions p on p.profile_id = m.profile_id
  left join public.events e on e.id = p.event_id and e.team_id = v_team and e.type = 'spiel'
                           and e.status is distinct from 'cancelled'
  left join public.event_results er on er.event_id = e.id
  where tp.runde_id = target_runde
  group by m.id, m.display_name
  order by 3 desc, 2;
end;
$$;

grant execute on function public.tipp_tabelle(uuid) to authenticated, service_role;

-- Erwartet: 1
select count(*) as gefiltert
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'tipp_tabelle'
  and p.prosrc like '%is distinct from ''cancelled''%';
