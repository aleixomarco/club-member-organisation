-- Tippspiel: getrennte Runden je Mannschaft.
--
-- BISHER war das Tippspiel eine einzige Runde ueber ALLE Spiele des Vereins.
-- Wer bei den Herren mittippte, hatte automatisch auch die U11-Spiele in
-- seiner Liste, und in der Tabelle standen Erwachsene neben Kindern. Beitreten
-- musste niemand - man war drin, sobald der Verein die Funktion einschaltete.
--
-- JETZT gibt es pro Mannschaft eine eigene Runde mit eigener Tabelle, und die
-- Vereinsleitung entscheidet, welche Mannschaften ueberhaupt eine bekommen -
-- wie bei den Chatkanaelen.
--
-- BEITRETEN IST PFLICHT, und zwar je Mannschaft einzeln. Das ist der
-- Unterschied zu vorher und der Grund fuer die zweite Tabelle: Wer bei den
-- Herren tippt, will nicht zwangslaeufig auch bei der U15 in einer Tabelle
-- stehen. Und eine Tabelle mit fuenfzig Namen, von denen drei je einen Tipp
-- abgegeben haben, sagt nichts aus.
--
-- DIE TIPPS SELBST bleiben, wo sie sind (predictions, je Spiel und Person).
-- Ein Spiel gehoert ueber events.team_id zu genau einer Mannschaft, also zu
-- genau einer Runde - die Zuordnung braucht keine eigene Spalte und kann
-- nicht auseinanderlaufen.

create table if not exists public.tipp_runden (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs(id) on delete cascade,
  team_id    uuid not null references public.teams(id) on delete cascade,
  aktiv      boolean not null default true,
  created_at timestamptz not null default now(),
  unique (club_id, team_id)
);

create table if not exists public.tipp_teilnehmer (
  runde_id      uuid not null references public.tipp_runden(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  joined_at     timestamptz not null default now(),
  primary key (runde_id, membership_id)
);

alter table public.tipp_runden      enable row level security;
alter table public.tipp_teilnehmer  enable row level security;

drop policy if exists "club members read tipp rounds" on public.tipp_runden;
create policy "club members read tipp rounds" on public.tipp_runden
  for select using (public.is_club_member(club_id));

drop policy if exists "leaders manage tipp rounds" on public.tipp_runden;
create policy "leaders manage tipp rounds" on public.tipp_runden
  for all using (public.has_club_role(club_id, array['vereinsadmin','sysadmin']::club_role[]))
  with check (public.has_club_role(club_id, array['vereinsadmin','sysadmin']::club_role[]));

drop policy if exists "club members read participants" on public.tipp_teilnehmer;
create policy "club members read participants" on public.tipp_teilnehmer
  for select using (
    exists (select 1 from public.tipp_runden r where r.id = runde_id and public.is_club_member(r.club_id))
  );

/* Beitreten und verlassen darf jeder nur fuer sich. Niemand wird in eine
   Tabelle eingetragen, in der er nicht stehen will. */
drop policy if exists "members join tipp rounds" on public.tipp_teilnehmer;
create policy "members join tipp rounds" on public.tipp_teilnehmer
  for all using (
    membership_id in (select id from public.club_memberships where profile_id = auth.uid())
  ) with check (
    membership_id in (select id from public.club_memberships where profile_id = auth.uid())
  );

/* Welche Mannschaften gibt es, welche haben eine Runde, bin ich dabei?
   Eine Abfrage fuer alles - die App soll nicht drei Listen zusammenrechnen. */
create or replace function public.tipprunden_fuer_verein(target_club uuid)
returns table (team_id uuid, team_name text, runde_id uuid, aktiv boolean, ich_dabei boolean, teilnehmer integer)
language plpgsql stable security definer set search_path = 'public' as $$
declare v_mein uuid;
begin
  if not public.is_club_member(target_club) then raise exception 'Not authorized'; end if;
  select id into v_mein from public.club_memberships
   where club_id = target_club and profile_id = auth.uid() and status = 'active' limit 1;

  return query
  select t.id, t.name, r.id, coalesce(r.aktiv, false),
         exists (select 1 from public.tipp_teilnehmer p where p.runde_id = r.id and p.membership_id = v_mein),
         (select count(*)::integer from public.tipp_teilnehmer p where p.runde_id = r.id)
  from public.teams t
  left join public.tipp_runden r on r.team_id = t.id and r.club_id = target_club
  where t.club_id = target_club
  order by t.name;
end;
$$;

/* Runde ein- oder ausschalten - nur die Vereinsleitung. Ausschalten loescht
   nichts: Die Tipps und die Teilnehmerliste bleiben stehen, damit eine
   versehentlich abgeschaltete Runde nicht eine halbe Saison mitnimmt. */
create or replace function public.tipprunde_setzen(target_club uuid, target_team uuid, an boolean)
returns uuid language plpgsql security definer set search_path = 'public' as $$
declare v_id uuid;
begin
  if not public.has_club_role(target_club, array['vereinsadmin','sysadmin']::club_role[]) then
    raise exception 'Not authorized';
  end if;
  insert into public.tipp_runden (club_id, team_id, aktiv)
  values (target_club, target_team, an)
  on conflict (club_id, team_id) do update set aktiv = excluded.aktiv
  returning id into v_id;
  return v_id;
end;
$$;

/* Die Tabelle einer Runde. Punkte werden HIER gerechnet, nicht im Geraet:
   Sonst sieht jeder eine Tabelle, die von seiner eigenen Rechnung abhaengt,
   und zwei Telefone zeigen verschiedene Plaetze.
   Genaues Ergebnis 3 Punkte, richtige Tendenz 1 Punkt - dieselbe Regel, die
   in der App steht. */
create or replace function public.tipp_tabelle(target_runde uuid)
returns table (membership_id uuid, name text, punkte integer, tipps integer)
language plpgsql stable security definer set search_path = 'public' as $$
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
    count(p.event_id)::integer
  from public.tipp_teilnehmer tp
  join public.club_memberships m on m.id = tp.membership_id
  left join public.predictions p on p.profile_id = m.profile_id
  left join public.events e on e.id = p.event_id and e.team_id = v_team and e.type = 'spiel'
  left join public.event_results er on er.event_id = e.id
  where tp.runde_id = target_runde
  group by m.id, m.display_name
  order by 3 desc, 2;
end;
$$;

grant execute on function public.tipprunden_fuer_verein(uuid)        to authenticated, service_role;
grant execute on function public.tipprunde_setzen(uuid, uuid, boolean) to authenticated, service_role;
grant execute on function public.tipp_tabelle(uuid)                  to authenticated, service_role;

select
  (select count(*) from information_schema.tables where table_schema='public' and table_name in ('tipp_runden','tipp_teilnehmer')) as tabellen,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('tipprunden_fuer_verein','tipprunde_setzen','tipp_tabelle')) as funktionen;
