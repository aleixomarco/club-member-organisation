-- Rechte und Sichtbarkeit (Betreiberentscheidungen vom 13.09.2026).
--
-- rollen-03  E-Mail und Mitgliedsnummer anderer Mitglieder sowie wartende,
--            abgelehnte und gesperrte Bewerber sieht nur die Vereinsleitung
--            (vereinsadmin, sysadmin, organisator). Mitglieder und Fans sehen
--            Namen.
-- rollen-04  Fans sehen keine Trainings - jetzt in der Datenbank, nicht nur in
--            der Oberflaeche.
-- U5         Stimmen der Saisonwahl liest nur, wer sie abgegeben hat; den
--            Stand gibt saisonwahl_stand.
-- rollen-10  has_beyond_basic_role zaehlt 'fan' nicht mehr als erhoeht.
-- rollen-05  Umfragen: organisator statt der abgeschafften Rollen.
-- U15        Sponsorenmanager schaltet die Werbeplaetze des eigenen Vereins.
-- rollen-09  Kapitaene duerfen die Mannschaftsschalter setzen.
-- rollen-07  set_managed_player_teams: Leitung vereinsweit, Trainer und
--            Teammanager nur fuer ihre eigenen Mannschaften.
-- B3         Serientermine in Ortszeit; Organisation darf Serien anlegen,
--            absagen und loeschen.
-- U4         Die letzte Vereinsadministration kann sich nicht selbst beenden,
--            sperren oder entfernen.
--
-- Alle Live-Definitionen wurden am 14.09.2026 lesend von PROD geholt
-- (pg_policies, pg_get_functiondef); die bisherige Fassung steht jeweils als
-- Kommentar darueber.
--
-- MUSS zusammen mit der App ausgeliefert werden (Branch ergebnisse-heim-gast):
-- Die alte App liest email und membership_number in der Mitgliederliste und
-- scheitert nach dieser Migration mit "permission denied for column".

-- ================================================================ rollen-03
-- Bisher:
--   "members read club memberships" SELECT to public
--     using (is_club_member(club_id) OR (profile_id = auth.uid()))
--   "club leaders read all memberships" SELECT to authenticated (nur auf PROD)
--     using (has_club_role(club_id, ARRAY['sysadmin','vereinsadmin','vorstand']))
drop policy if exists "club leaders read all memberships" on public.club_memberships;
drop policy if exists "members read club memberships" on public.club_memberships;
create policy "members read club memberships" on public.club_memberships
  for select to authenticated
  using (
    (public.is_club_member(club_id) and status = 'active')
    or profile_id = (select auth.uid())
    or public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[]));

-- Spalten: Ein Spaltenrecht laesst sich nicht entziehen, solange das Recht auf
-- die ganze Tabelle besteht. Also die Tabelle entziehen und die Spalten ohne
-- email, membership_number, rejection_count und blocked_until einzeln geben.
-- Spaltenliste von PROD (information_schema.columns, 14.09.2026). INSERT,
-- UPDATE und DELETE bleiben unberuehrt; die Regeln entscheiden dort weiter.
-- Lesende SECURITY-INVOKER-Sichten auf diese Spalten gibt es nicht
-- (team_penalty_totals liest nur display_name).
revoke select on public.club_memberships from anon, authenticated;
grant select (id, club_id, profile_id, display_name, member_since, status,
              is_managed_profile, created_by, created_at, updated_at,
              requested_role, requested_team, team_filter)
  on public.club_memberships to authenticated;

-- Die geschuetzten Felder: fuer die Leitung alle Mitgliedschaften des Vereins,
-- fuer alle anderen nur die eigene.
create or replace function public.kontaktdaten_im_verein(target_club uuid)
returns table (membership_id uuid, email text, membership_number text,
               rejection_count integer, blocked_until timestamptz)
language sql stable security definer set search_path = '' as $$
  select m.id, m.email, m.membership_number, m.rejection_count, m.blocked_until
    from public.club_memberships m
   where m.club_id = target_club
     and (m.profile_id = (select auth.uid())
          or public.has_club_role(target_club, array['vereinsadmin','sysadmin','organisator']::public.club_role[]));
$$;
revoke all on function public.kontaktdaten_im_verein(uuid) from public, anon;
grant execute on function public.kontaktdaten_im_verein(uuid) to authenticated;
comment on function public.kontaktdaten_im_verein(uuid) is
  'E-Mail, Mitgliedsnummer, Ablehnungen und Sperrfrist: fuer vereinsadmin, sysadmin und organisator alle Mitgliedschaften des Vereins, fuer alle anderen nur die eigene. Die Spalten selbst sind fuer authenticated nicht lesbar (rollen-03).';

-- ================================================================ rollen-04
-- "Nur Fan" wie in notify_event_audience: 'fan' und keine andere Rolle.
create or replace function public.ist_nur_fan(target_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_memberships m
     where m.club_id = target_club
       and m.profile_id = (select auth.uid())
       and m.status = 'active'
       and exists (select 1 from public.membership_roles r
                    where r.membership_id = m.id and r.role = 'fan')
       and not exists (select 1 from public.membership_roles r
                        where r.membership_id = m.id and r.role <> 'fan'));
$$;
revoke all on function public.ist_nur_fan(uuid) from public, anon;
grant execute on function public.ist_nur_fan(uuid) to authenticated, service_role;

-- Bisher: "members read events" SELECT to public using (is_club_member(club_id))
-- Die Leitung ist nie "nur Fan"; Anlegen und Aendern sind davon nicht betroffen.
-- Regeln, die ueber public.events gehen (Zusagen, Mitfahrten, Helferdienste,
-- Tipps), sehen Trainings damit fuer Fans ebenfalls nicht. SECURITY-DEFINER-
-- Funktionen, die Termine zurueckgeben, laufen nur fuer Leitung und Betreuer
-- (anwesenheit_fuer_termin ueber darf_anwesenheit_sehen); der Kalender-Feed
-- filtert Fans selbst.
drop policy if exists "members read events" on public.events;
create policy "members read events" on public.events
  for select to authenticated
  using (public.is_club_member(club_id)
         and (type <> 'training' or not public.ist_nur_fan(club_id)));

-- Bisher: "club members read duty tasks" SELECT to public
--   using (exists (club_memberships m where m.club_id = duty_tasks.club_id
--                  and m.profile_id = auth.uid() and m.status = 'active'))
-- Neu: nur zu Terminen, die man sehen darf.
drop policy if exists "club members read duty tasks" on public.duty_tasks;
create policy "club members read duty tasks" on public.duty_tasks
  for select to authenticated
  using (
    exists (select 1 from public.club_memberships m
             where m.club_id = duty_tasks.club_id
               and m.profile_id = (select auth.uid())
               and m.status = 'active')
    and exists (select 1 from public.events e where e.id = duty_tasks.event_id));

-- ================================================================ U5
-- Bisher: "members read season votes" SELECT to public using (is_club_member(club_id))
--         "members cast season vote" INSERT to public
--           with check ((voter_profile_id = auth.uid()) and is_club_member(club_id))
--         "members change season vote" UPDATE to authenticated
--           using (voter_profile_id = auth.uid())
--           with check ((voter_profile_id = auth.uid()) and is_club_member(club_id))
drop policy if exists "members read season votes" on public.season_votes;
drop policy if exists "members read own season vote" on public.season_votes;
create policy "members read own season vote" on public.season_votes
  for select to authenticated
  using (voter_profile_id = (select auth.uid()));

drop policy if exists "members cast season vote" on public.season_votes;
create policy "members cast season vote" on public.season_votes
  for insert to authenticated
  with check (
    voter_profile_id = (select auth.uid())
    and public.is_club_member(club_id)
    and exists (select 1 from public.club_memberships c
                 where c.id = season_votes.candidate_membership_id
                   and c.club_id = season_votes.club_id and c.status = 'active'));

drop policy if exists "members change season vote" on public.season_votes;
create policy "members change season vote" on public.season_votes
  for update to authenticated
  using (voter_profile_id = (select auth.uid()))
  with check (
    voter_profile_id = (select auth.uid())
    and public.is_club_member(club_id)
    and exists (select 1 from public.club_memberships c
                 where c.id = season_votes.candidate_membership_id
                   and c.club_id = season_votes.club_id and c.status = 'active'));

-- Der Stand der Wahl. Die Frist rechnet der Server aus der Saisonkennung,
-- nach derselben Regel wie laufendeSaison() in app/page.tsx: Saison
-- "JJJJ/JJ" beginnt am 1. September, die Wahl endet am 31. August des
-- Folgejahres um 23:59:59 Ortszeit (Europe/Berlin).
-- Leitung: jederzeit je Kandidat. Alle anderen Mitglieder: je Kandidat erst
-- nach der Frist, vorher nur die Gesamtzahl (eine Zeile mit Kandidat null).
create or replace function public.saisonwahl_stand(target_club uuid, p_season text)
returns table (candidate_membership_id uuid, stimmen integer)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_beginn integer;
  v_frist  timestamptz;
begin
  if auth.uid() is null or not public.is_club_member(target_club) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_season is null or p_season !~ '^[0-9]{4}/[0-9]{2}$' then
    raise exception 'Invalid season' using errcode = '22023';
  end if;
  v_beginn := substr(p_season, 1, 4)::integer;
  v_frist := make_timestamptz(v_beginn + 1, 8, 31, 23, 59, 59, 'Europe/Berlin');

  if public.has_club_role(target_club, array['vereinsadmin','sysadmin','organisator']::public.club_role[])
     or now() > v_frist then
    return query
      select v.candidate_membership_id, count(*)::integer
        from public.season_votes v
       where v.club_id = target_club and v.season = p_season
       group by v.candidate_membership_id;
  else
    return query
      select null::uuid, count(*)::integer
        from public.season_votes v
       where v.club_id = target_club and v.season = p_season;
  end if;
end;
$$;
revoke all on function public.saisonwahl_stand(uuid, text) from public, anon;
grant execute on function public.saisonwahl_stand(uuid, text) to authenticated;

-- ================================================================ rollen-10
-- Einziger Verwender (PROD, pg_policies und pg_proc am 14.09.2026 gesucht):
-- club_tasks "authorized members create tasks" fuer vereinsweite Aufgaben.
-- Bisher (nur auf PROD): ... and r.role not in ('spieler', 'mitglied'), Suchpfad public.
create or replace function public.has_beyond_basic_role(target_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membership_roles r
    join public.club_memberships m on m.id = r.membership_id
    where m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
      and r.role not in ('spieler', 'mitglied', 'fan')
  );
$$;

-- ================================================================ rollen-05
-- Bisher: "poll managers manage polls" ALL to public, using = check =
--   has_club_role(club_id, ARRAY['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin'])
--         "poll managers manage options" ALL to public, using = check =
--   exists (polls p where p.id = poll_id and has_club_role(p.club_id, dieselbe Liste))
-- Die Leseregel aus 20260907200000:158 bleibt unberuehrt.
drop policy if exists "poll managers manage polls" on public.polls;
create policy "poll managers manage polls" on public.polls
  for all to authenticated
  using (public.has_club_role(club_id, array['organisator','sponsorenmanager','vereinsadmin','sysadmin']::public.club_role[]))
  with check (public.has_club_role(club_id, array['organisator','sponsorenmanager','vereinsadmin','sysadmin']::public.club_role[]));

drop policy if exists "poll managers manage options" on public.poll_options;
create policy "poll managers manage options" on public.poll_options
  for all to authenticated
  using (exists (
    select 1 from public.polls p
     where p.id = poll_options.poll_id
       and public.has_club_role(p.club_id, array['organisator','sponsorenmanager','vereinsadmin','sysadmin']::public.club_role[])))
  with check (exists (
    select 1 from public.polls p
     where p.id = poll_options.poll_id
       and public.has_club_role(p.club_id, array['organisator','sponsorenmanager','vereinsadmin','sysadmin']::public.club_role[])));

-- ================================================================ U15
-- Bisher: "admins manage feature toggles" ALL to public using = check =
--   can_manage_club_settings(club_id)  (vereinsadmin, vorstand, sysadmin)
-- Der Schalter "Werbeflaeche ein-/ausblenden" schreibt per upsert
-- sponsor_<platz> und braucht dafuer INSERT und UPDATE. Nur diese Schluessel,
-- nur im eigenen Verein. Einen Hauptschalter fuer Werbung gibt es nicht
-- (CLUB_FEATURES in app/page.tsx).
-- Sponsorinhalte: "sponsoren pflegen" auf public.anzeigen (ALL, club_id not
-- null) und die Ablage sponsor-bilder (Ordner = club_id) schliessen den
-- Sponsorenmanager des Vereins schon ein - daran aendert sich nichts.
-- Tabellen sponsors/sponsor_placements gibt es auf PROD nicht.
drop policy if exists "sponsorenmanager legt werbeplatzschalter an" on public.club_feature_toggles;
create policy "sponsorenmanager legt werbeplatzschalter an" on public.club_feature_toggles
  for insert to authenticated
  with check (feature_key like 'sponsor\_%'
              and public.has_club_role(club_id, array['sponsorenmanager']::public.club_role[]));

drop policy if exists "sponsorenmanager schaltet werbeplaetze" on public.club_feature_toggles;
create policy "sponsorenmanager schaltet werbeplaetze" on public.club_feature_toggles
  for update to authenticated
  using (feature_key like 'sponsor\_%'
         and public.has_club_role(club_id, array['sponsorenmanager']::public.club_role[]))
  with check (feature_key like 'sponsor\_%'
              and public.has_club_role(club_id, array['sponsorenmanager']::public.club_role[]));

-- ================================================================ rollen-09
-- Rumpf aus PROD; geaendert: 'kapitaen' in der Mannschaftsliste (die App
-- zeigt Kapitaenen die Schalter), leerer Suchpfad, Ausfuehrung nicht mehr fuer
-- PUBLIC.
create or replace function public.mannschaft_funktionen_setzen(target_team uuid, p_zusagen boolean default null, p_strafen boolean default null, p_zusagen_spiele boolean default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_club uuid;
begin
  select club_id into v_club from public.teams where id = target_team;
  if v_club is null then raise exception 'Team not found'; end if;

  /* Trainer, Kapitaen oder Teammanager der Mannschaft - oder die
     Vereinsleitung, damit sich niemand aussperrt, wenn ein Trainer den Verein
     verlaesst. */
  if not exists (
    select 1 from public.team_members tm
    join public.club_memberships m on m.id = tm.membership_id
    where tm.team_id = target_team and m.profile_id = auth.uid()
      and m.status = 'active' and tm.function in ('trainer', 'teammanager', 'kapitaen')
  ) and not public.has_club_role(v_club, array['vereinsadmin','sysadmin']::public.club_role[]) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  update public.teams
     set zusagen_aktiv = coalesce(p_zusagen, zusagen_aktiv),
         strafen_aktiv = coalesce(p_strafen, strafen_aktiv),
         zusagen_spiele_aktiv = coalesce(p_zusagen_spiele, zusagen_spiele_aktiv)
   where id = target_team;
end;
$$;
revoke all on function public.mannschaft_funktionen_setzen(uuid, boolean, boolean, boolean) from public, anon;
grant execute on function public.mannschaft_funktionen_setzen(uuid, boolean, boolean, boolean) to authenticated;

-- ================================================================ rollen-07 + U2
-- Aus dem PROD-Rumpf (die Fassung in 20260802080000 ist veraltet). Bisher:
-- Wer irgendwo im Verein trainer, teammanager, vorstand, vereinsadmin oder
-- sysadmin war, durfte ALLE Spielerzeilen des Athleten loeschen und neu
-- setzen; organisator durfte gar nicht.
-- Neu:
--   Leitung (vereinsadmin, sysadmin, organisator): jede Mannschaft des Vereins.
--   Trainer und Teammanager (Zeile in team_members): nur die eigenen
--   Mannschaften. Zeilen in anderen Mannschaften bleiben unberuehrt; eine
--   fremde Mannschaft darf in der Auswahl nur stehen, wenn der Athlet schon
--   dort spielt (die App schickt die ganze Liste).
--   vorstand faellt weg (abgeschafft).
create or replace function public.set_managed_player_teams(target_club uuid, target_membership uuid, target_team_ids uuid[] default array[]::uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_erlaubt  uuid[];
  v_bisher   uuid[];
  v_ziel     uuid[];
  v_ergebnis uuid[];
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;

  if public.has_club_role(target_club, array['vereinsadmin','sysadmin','organisator']::public.club_role[]) then
    select coalesce(array_agg(t.id), array[]::uuid[]) into v_erlaubt
      from public.teams t where t.club_id = target_club;
  else
    select coalesce(array_agg(distinct tm.team_id), array[]::uuid[]) into v_erlaubt
      from public.team_members tm
      join public.club_memberships m on m.id = tm.membership_id
      join public.teams t on t.id = tm.team_id
     where m.profile_id = auth.uid() and m.club_id = target_club and m.status = 'active'
       and t.club_id = target_club
       and tm.function in ('trainer', 'teammanager');
  end if;
  if cardinality(v_erlaubt) = 0 then
    raise exception 'Club leadership, trainer or teammanager of a team required' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.club_memberships player_membership
    join public.membership_roles player_role
      on player_role.membership_id = player_membership.id
     and player_role.role = 'spieler'
    where player_membership.id = target_membership
      and player_membership.club_id = target_club
      and player_membership.status = 'active'
  ) then raise exception 'Active player membership required'; end if;

  select coalesce(array_agg(distinct s), array[]::uuid[]) into v_ziel
    from unnest(coalesce(target_team_ids, array[]::uuid[])) s where s is not null;
  select coalesce(array_agg(tm.team_id), array[]::uuid[]) into v_bisher
    from public.team_members tm
   where tm.membership_id = target_membership and tm.function = 'spieler';

  if exists (
    select 1
    from unnest(v_ziel) s
    left join public.teams team on team.id = s
    where team.id is null or team.club_id <> target_club
       or (not team.active and not (s = any(v_bisher)))
  ) then raise exception 'Invalid team selection'; end if;

  if exists (select 1 from unnest(v_ziel) s
              where not (s = any(v_erlaubt)) and not (s = any(v_bisher))) then
    raise exception 'Team outside your own teams' using errcode = '42501';
  end if;

  v_ergebnis := array(
    select s from unnest(v_bisher) s where not (s = any(v_erlaubt))
    union
    select s from unnest(v_ziel) s where s = any(v_erlaubt));
  if cardinality(v_ergebnis) > 3 then
    raise exception 'A player can belong to at most three teams';
  end if;

  delete from public.team_members
   where membership_id = target_membership and function = 'spieler'
     and team_id = any(v_erlaubt) and not (team_id = any(v_ziel));
  insert into public.team_members (team_id, membership_id, function)
  select s, target_membership, 'spieler'::public.club_role
    from unnest(v_ziel) s
   where s = any(v_erlaubt)
  on conflict do nothing;
end;
$$;
revoke all on function public.set_managed_player_teams(uuid, uuid, uuid[]) from public, anon;
grant execute on function public.set_managed_player_teams(uuid, uuid, uuid[]) to authenticated, service_role;

-- ================================================================ B3
-- Bisher (PROD): (d + start_time)::timestamptz - bei TimeZone=UTC landeten
-- Serientermine 2 h (Sommer) bzw. 1 h (Winter) zu spaet. Die Zeit ist jetzt
-- Ortszeit in p_tz (Voreinstellung Europe/Berlin; ein unbekannter Name faellt
-- darauf zurueck). Weil ein Parameter dazukommt, faellt die alte Signatur.
-- Bestehende Serien auf PROD kamen aus einer Migration mit AT TIME ZONE und
-- brauchen keine Reparatur.
drop function if exists public.create_recurring_events(uuid, uuid, public.event_type, text, text, text, integer[], time without time zone, time without time zone, date, date);
create or replace function public.create_recurring_events(
  target_club uuid, target_team uuid, event_type public.event_type, event_title text,
  event_description text, event_location text, weekdays integer[],
  start_time time without time zone, end_time time without time zone,
  range_start date, range_end date, p_tz text default 'Europe/Berlin')
returns setof uuid language plpgsql security definer set search_path = '' as $$
declare
  v_series uuid := gen_random_uuid();
  v_creator uuid := auth.uid();
  v_title text := nullif(trim(event_title), '');
  v_tz text := 'Europe/Berlin';
begin
  if v_creator is null then raise exception 'Authentication required'; end if;
  if v_title is null then raise exception 'Title required'; end if;
  if range_start is null or range_end is null then raise exception 'Date range required'; end if;
  if range_end < range_start then raise exception 'End date must be after start date'; end if;
  if range_end - range_start > 366 then raise exception 'Date range too long (max one year)'; end if;
  if weekdays is null or cardinality(weekdays) = 0 then raise exception 'At least one weekday required'; end if;
  if end_time <= start_time then raise exception 'End time must be after start time'; end if;

  if p_tz is not null and exists (select 1 from pg_catalog.pg_timezone_names z where z.name = p_tz) then
    v_tz := p_tz;
  end if;

  if not (
    public.can_manage_team(target_team)
    or public.has_club_role(target_club, array['sysadmin','vereinsadmin','organisator']::public.club_role[])
  ) then raise exception 'Not authorized to create events for this team' using errcode = '42501'; end if;

  return query
    insert into public.events (club_id, team_id, type, status, title, description, starts_at, ends_at, location, created_by, series_id)
    select
      target_club,
      target_team,
      event_type,
      'scheduled',
      v_title,
      nullif(trim(event_description), ''),
      ((d::date + start_time) at time zone v_tz),
      ((d::date + end_time) at time zone v_tz),
      nullif(trim(event_location), ''),
      v_creator,
      v_series
    from generate_series(range_start, range_end, interval '1 day') as d
    where extract(isodow from d::date)::int = any(weekdays)
    returning id;
end;
$$;
revoke all on function public.create_recurring_events(uuid, uuid, public.event_type, text, text, text, integer[], time without time zone, time without time zone, date, date, text) from public, anon;
grant execute on function public.create_recurring_events(uuid, uuid, public.event_type, text, text, text, integer[], time without time zone, time without time zone, date, date, text) to authenticated;

-- Rumpf aus PROD; neu: organisator (wie die Terminregeln aus 20260906310000).
create or replace function public.delete_event_series(target_series uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.events
  where series_id = target_series
    and (
      public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::public.club_role[])
      or (team_id is not null and public.can_manage_team(team_id))
    );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Rumpf aus PROD; neu: organisator, leerer Suchpfad.
create or replace function public.absage_serie(target_series uuid, grund text)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_club uuid; v_team uuid; v_anzahl integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_series is null then raise exception 'Serie fehlt'; end if;
  if nullif(trim(grund), '') is null then raise exception 'Grund fehlt'; end if;

  select club_id, team_id into v_club, v_team
    from public.events where series_id = target_series limit 1;
  if v_club is null then raise exception 'Reihe nicht gefunden'; end if;

  if not (
    public.has_club_role(v_club, array['sysadmin','vereinsadmin','organisator']::public.club_role[])
    or (v_team is not null and public.can_manage_team(v_team))
  ) then raise exception 'Not authorized'; end if;

  update public.events
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = auth.uid(),
         cancel_reason = trim(grund)
   where series_id = target_series
     and status <> 'cancelled'
     and starts_at >= now();

  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$$;

-- ================================================================ U4
-- letzten_vereinsadmin_schuetzen (20260907160000) greift nur beim Loeschen der
-- ROLLE. Beenden, Sperren oder Entfernen der MITGLIEDSCHAFT ging daran vorbei
-- - beim Entfernen laeuft das Loeschen der Rolle als Kaskade, wenn die
-- Mitgliedschaft schon weg ist, und die Pruefung findet keinen Verein mehr.
-- Dieselbe Zaehlung wie dort: Allein im Verein darf man gehen.
-- Ausgenommen: Aufrufe ohne Anmeldung oder als service_role (Kontoloeschung,
-- Betreiber) und das Aufloesen des Vereins (die Vereinszeile ist dann weg).
create or replace function public.letzte_vereinsadmin_mitgliedschaft_schuetzen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_andere int; v_nutzer int;
begin
  if tg_op = 'UPDATE' and (old.status is distinct from 'active' or new.status = 'active') then
    return new;
  end if;
  if old.status is distinct from 'active'
     or auth.uid() is null
     or coalesce(auth.role(), '') = 'service_role'
     or not exists (select 1 from public.clubs c where c.id = old.club_id)
     or not exists (select 1 from public.membership_roles r
                     where r.membership_id = old.id and r.role = 'vereinsadmin') then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  select count(distinct m.profile_id) into v_andere
    from public.club_memberships m
    join public.membership_roles r on r.membership_id = m.id
   where m.club_id = old.club_id and m.status = 'active'
     and m.profile_id is not null and coalesce(m.is_managed_profile, false) = false
     and r.role = 'vereinsadmin' and m.id <> old.id;

  select count(*) into v_nutzer
    from public.club_memberships m
   where m.club_id = old.club_id and m.status = 'active'
     and m.profile_id is not null and coalesce(m.is_managed_profile, false) = false
     and m.id <> old.id;

  if v_andere = 0 and v_nutzer > 0 then
    raise exception 'letzter_vereinsadmin'
      using hint = 'Bestimme zuerst einen weiteren Vereinsadministrator.';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function public.letzte_vereinsadmin_mitgliedschaft_schuetzen() from public, anon, authenticated;

drop trigger if exists club_memberships_letzter_admin on public.club_memberships;
create trigger club_memberships_letzter_admin
  before update of status or delete on public.club_memberships
  for each row execute function public.letzte_vereinsadmin_mitgliedschaft_schuetzen();

-- Erwartet: email_lesbar = false, name_lesbar = true, regeln_mitglieder = 1,
-- stand_ausfuehrbar = true, kontakt_ausfuehrbar = true, alte_serie = 0,
-- neue_serie = 1, serie_sommer = 17:30, serie_winter = 18:30,
-- fan_regel = true, ausloeser = 1.
select
  has_column_privilege('authenticated', 'public.club_memberships', 'email', 'select') as email_lesbar,
  has_column_privilege('authenticated', 'public.club_memberships', 'display_name', 'select') as name_lesbar,
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'club_memberships' and cmd = 'SELECT') as regeln_mitglieder,
  has_function_privilege('authenticated', 'public.saisonwahl_stand(uuid, text)', 'execute') as stand_ausfuehrbar,
  has_function_privilege('authenticated', 'public.kontaktdaten_im_verein(uuid)', 'execute') as kontakt_ausfuehrbar,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_recurring_events' and p.pronargs = 11) as alte_serie,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_recurring_events' and p.pronargs = 12) as neue_serie,
  to_char(((date '2026-10-24' + time '19:30') at time zone 'Europe/Berlin') at time zone 'UTC', 'HH24:MI') as serie_sommer,
  to_char(((date '2026-10-26' + time '19:30') at time zone 'Europe/Berlin') at time zone 'UTC', 'HH24:MI') as serie_winter,
  (select qual like '%ist_nur_fan%' from pg_policies
    where schemaname = 'public' and tablename = 'events' and policyname = 'members read events') as fan_regel,
  (select count(*) from pg_trigger where tgrelid = 'public.club_memberships'::regclass
    and tgname = 'club_memberships_letzter_admin') as ausloeser;
