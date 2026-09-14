-- Vereinsgrenzen: Nachtrag aus der Durchsicht vom 14.09.2026.
--
-- Die Durchsicht vor dem Einspielen fand Regeln, die "Verein als Blase"
-- (20260914110000) noch nicht erfasst hatte. Alle Rumpfe und Regeln hier
-- stammen aus der LIVE-Datenbank (pg_policies / pg_get_functiondef vom
-- 14.09.2026) und aendern nur die genannte Stelle.

-- ------------------------------------------------------------------ Termine
-- Bisher: Die Mannschaftsbedingung pruefte nur can_manage_team(team_id), nicht,
-- ob die Mannschaft zum Verein des Termins gehoert. Ein Trainer legte so einen
-- Termin mit fremder club_id an oder verschob einen Termin seiner Mannschaft
-- in einen fremden Verein - und konnte damit auch eine fremde series_id
-- einschleusen.
drop policy if exists "authorized roles create events" on public.events;
create policy "authorized roles create events" on public.events
  for insert to authenticated
  with check (
    public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::public.club_role[])
    or (team_id is not null and public.can_manage_team(team_id)
        and exists (select 1 from public.teams t where t.id = events.team_id and t.club_id = events.club_id)));

drop policy if exists "authorized roles update events" on public.events;
create policy "authorized roles update events" on public.events
  for update to authenticated
  using (
    public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::public.club_role[])
    or (team_id is not null and public.can_manage_team(team_id)
        and exists (select 1 from public.teams t where t.id = events.team_id and t.club_id = events.club_id)))
  with check (
    public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::public.club_role[])
    or (team_id is not null and public.can_manage_team(team_id)
        and exists (select 1 from public.teams t where t.id = events.team_id and t.club_id = events.club_id)));

-- ------------------------------------------------------------- Helferdienste
-- Bisher: Die Leitung von Verein A konnte eine Mitgliedschaft aus Verein B auf
-- einen Dienst in A setzen - helferdienst_einteilung_melden schickte der Person
-- aus B dann eine Meldung ueber die Vereinsgrenze. USING bleibt wie live.
drop policy if exists "leaders manage duties" on public.duty_assignments;
create policy "leaders manage duties" on public.duty_assignments
  for all to authenticated
  using (exists (
    select 1 from public.events e
     where e.id = duty_assignments.event_id
       and public.has_club_role(e.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[])))
  with check (exists (
    select 1 from public.events e
     where e.id = duty_assignments.event_id
       and public.mitgliedschaft_im_verein(duty_assignments.membership_id, e.club_id)
       and public.has_club_role(e.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[])));

-- -------------------------------------------------- Erinnerung bei Aufgaben
-- Bisher: Jeder Angemeldete konnte fuer einen fremden Verein abfragen, ob 70 %
-- der Mitglieder eingetragen sind - und bei "ja" die Erinnerung dieses Vereins
-- fuer immer als erledigt markieren. Neu nur die Mitgliedschaftspruefung am
-- Anfang; der Rest ist der Live-Rumpf.
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
  if not public.is_club_member(target_club) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
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
    return true;
  end if;
  return false;
end;
$function$;

-- ------------------------------------------------------------ club_app_state
-- Die alte JSON-Tabelle (bis 01.09.2026) haelt fuer einen Verein noch
-- Saisonstimmen, Protokolle, Umfragen und Tipps. Jedes Mitglied konnte sie
-- lesen, der Sponsorenmanager u. a. schreiben - vorbei an U5, am Protokoll-
-- schutz und an "keine Umfragen fuer den Sponsorenmanager". Die App liest und
-- schreibt sie nicht mehr. Lesen nur noch die Vereinsleitung, Schreiben
-- niemand ausser service_role.
drop policy if exists "club managers update app state" on public.club_app_state;
drop policy if exists "club members read app state" on public.club_app_state;
create policy "club leaders read app state" on public.club_app_state
  for select to authenticated
  using (public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[]));

-- Kontrolle
select
  (select count(*) from pg_policies where tablename = 'events' and policyname in ('authorized roles create events','authorized roles update events')
     and coalesce(qual,'') || coalesce(with_check,'') like '%t.club_id = events.club_id%') as termine_mit_vereinsbindung,
  (select count(*) from pg_policies where tablename = 'duty_assignments' and policyname = 'leaders manage duties'
     and with_check like '%mitgliedschaft_im_verein%') as dienste_mit_vereinsbindung,
  (select count(*) from pg_policies where tablename = 'club_app_state') as app_state_regeln;
