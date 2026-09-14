-- Jeder Verein ist eine Blase (Betreiberentscheidung 13.09.2026): Keine Zeile,
-- keine Funktion und keine Meldung darf die Vereinsgrenze ueberqueren.
--
-- B1 - Schreibregeln an den Verein der Zielzeile binden.
-- Die Regeln unten pruefen bisher nur, dass die eingetragene Mitgliedschaft
-- dem Aufrufer gehoert - nicht, dass sie zum Verein der Zielzeile gehoert. Wer
-- in Verein A Mitglied ist, konnte mit seiner A-Mitgliedschaft in eine
-- Fahrgemeinschaft, einen Helferdienst, eine Zusage, eine Vereinsaufgabe, eine
-- Tipprunde oder eine Fahrzeugbuchung von Verein B schreiben. Die Kennungen
-- sind kein Geheimnis: Der Kalender-Feed traegt sie als UID. Jede Regel geht
-- jetzt ueber die Zielzeile zu ihrem Verein und verlangt dort eine AKTIVE
-- Mitgliedschaft des Aufrufers.
--
-- Grundlage sind die Live-Definitionen aus pg_policies (gelesen 14.09.2026,
-- nur lesend); die bisherige Fassung steht jeweils als Kommentar darueber.
-- Mehrere dieser Regeln stehen in keiner Migration (Abweichung PROD/Repo).
--
-- Unterabfragen in einer Regel sehen andere Tabellen durch deren eigene
-- Regeln. Der Weg ueber public.events traegt deshalb auch "Fans sehen keine
-- Trainings" aus 20260914110100 mit - ein Fan kann fuer ein Training weder
-- zusagen noch mitfahren.
--
-- PROD hat 0 vereinsuebergreifende Zeilen (geprueft 13./14.09.2026:
-- Mannschaftszuordnungen, Tipprunden, Helferaufgaben) - es gibt nichts
-- aufzuraeumen.
--
-- Dazu in dieser Migration:
-- B4        sync_club_role_entitlement nur noch fuer service_role.
-- rollen-02 Die vier Zeitplanfunktionen nicht mehr fuer jeden aufrufbar.
-- C2        Keine Helferdienst-Erinnerung fuer abgesagte Termine.

-- Gehoert eine (fremde) Mitgliedschaft zu diesem Verein? Als SECURITY DEFINER,
-- weil die Leseregel von club_memberships (20260914110100) inaktive Zeilen
-- vor Nicht-Leitung verbirgt: Ein Trainer koennte sonst eine Helferaufgabe
-- nicht mehr aendern, deren Zugewiesene inzwischen ausgetreten ist. Verraet
-- nur, ob eine bekannte Kennung zu einem Verein gehoert.
create or replace function public.mitgliedschaft_im_verein(p_membership uuid, p_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.club_memberships m
                  where m.id = p_membership and m.club_id = p_club);
$$;
revoke all on function public.mitgliedschaft_im_verein(uuid, uuid) from public, anon;
grant execute on function public.mitgliedschaft_im_verein(uuid, uuid) to authenticated, service_role;

-- ============================================================ B1: Mitfahrten
-- Bisher: "club members create carpools" INSERT to authenticated
--   with check (driver_membership_id in (select m.id from club_memberships m
--               where m.profile_id = auth.uid() and m.status = 'active'))
drop policy if exists "club members create carpools" on public.carpools;
create policy "club members create carpools" on public.carpools
  for insert to authenticated
  with check (exists (
    select 1
      from public.events e
      join public.club_memberships m on m.club_id = e.club_id
     where e.id = carpools.event_id
       and m.id = carpools.driver_membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'));

-- Bisher: "club members join carpool" INSERT to authenticated
--   with check (membership_id in (select m.id from club_memberships m
--               where m.profile_id = auth.uid() and m.status = 'active'))
-- Ohne Bindung nannte notify_carpool_joined dem Fahrer in Verein B den Namen
-- aus Verein A.
drop policy if exists "club members join carpool" on public.carpool_passengers;
create policy "club members join carpool" on public.carpool_passengers
  for insert to authenticated
  with check (exists (
    select 1
      from public.carpools c
      join public.events e on e.id = c.event_id
      join public.club_memberships m on m.club_id = e.club_id
     where c.id = carpool_passengers.carpool_id
       and m.id = carpool_passengers.membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'));

-- ============================================================ B1: Zusagen
-- Bisher: "members set own attendance" ALL to public
--   using/check (membership_id in (select id from club_memberships
--                where profile_id = auth.uid()))
drop policy if exists "members set own attendance" on public.event_attendance;
create policy "members set own attendance" on public.event_attendance
  for all to authenticated
  using (exists (
    select 1
      from public.events e
      join public.club_memberships m on m.club_id = e.club_id
     where e.id = event_attendance.event_id
       and m.id = event_attendance.membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'))
  with check (exists (
    select 1
      from public.events e
      join public.club_memberships m on m.club_id = e.club_id
     where e.id = event_attendance.event_id
       and m.id = event_attendance.membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'));

-- ============================================================ B1: Helferdienste
-- Bisher: "members manage own duties" ALL to public
--   using/check (exists (select 1 from club_memberships m
--                where m.id = duty_assignments.membership_id and m.profile_id = auth.uid()))
-- Platzgrenze und Fan-Sperre fuer Selbsteintragungen: 20260914110400 (M5).
drop policy if exists "members manage own duties" on public.duty_assignments;
create policy "members manage own duties" on public.duty_assignments
  for all to authenticated
  using (exists (
    select 1
      from public.events e
      join public.club_memberships m on m.club_id = e.club_id
     where e.id = duty_assignments.event_id
       and m.id = duty_assignments.membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'))
  with check (exists (
    select 1
      from public.events e
      join public.club_memberships m on m.club_id = e.club_id
     where e.id = duty_assignments.event_id
       and m.id = duty_assignments.membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'));

-- Bisher: "authorized insert duty tasks" INSERT to public with check (can_manage_duty_task(event_id))
--         "authorized update duty tasks" UPDATE to public using (can_manage_duty_task(event_id)), ohne CHECK
-- duty_tasks.club_id stand frei neben dem Termin, und die zugewiesene
-- Mitgliedschaft durfte aus jedem Verein kommen - aufgabe_zugewiesen_melden
-- meldete dann ueber die Grenze. Auf PROD stimmen alle Zeilen (0 abweichend).
drop policy if exists "authorized insert duty tasks" on public.duty_tasks;
create policy "authorized insert duty tasks" on public.duty_tasks
  for insert to authenticated
  with check (
    public.can_manage_duty_task(event_id)
    and exists (select 1 from public.events e
                 where e.id = duty_tasks.event_id and e.club_id = duty_tasks.club_id)
    and (duty_tasks.assignee_membership_id is null
         or public.mitgliedschaft_im_verein(duty_tasks.assignee_membership_id, duty_tasks.club_id)));

drop policy if exists "authorized update duty tasks" on public.duty_tasks;
create policy "authorized update duty tasks" on public.duty_tasks
  for update to authenticated
  using (public.can_manage_duty_task(event_id))
  with check (
    public.can_manage_duty_task(event_id)
    and exists (select 1 from public.events e
                 where e.id = duty_tasks.event_id and e.club_id = duty_tasks.club_id)
    and (duty_tasks.assignee_membership_id is null
         or public.mitgliedschaft_im_verein(duty_tasks.assignee_membership_id, duty_tasks.club_id)));

-- ============================================================ B1: Vereinsaufgaben
-- Bisher: "club members signup for tasks" INSERT to authenticated
--   with check (membership_id in (select m.id from club_memberships m
--               where m.profile_id = auth.uid() and m.status = 'active'))
drop policy if exists "club members signup for tasks" on public.club_task_signups;
create policy "club members signup for tasks" on public.club_task_signups
  for insert to authenticated
  with check (exists (
    select 1
      from public.club_tasks t
      join public.club_memberships m on m.club_id = t.club_id
     where t.id = club_task_signups.task_id
       and m.id = club_task_signups.membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'));

-- Bisher: "leaders manage task assignees" ALL to public, using/check nur ueber
--   club_tasks t und has_club_role(t.club_id, vereinsadmin/sysadmin/organisator).
-- Die zugewiesene Mitgliedschaft war nicht an den Verein der Aufgabe gebunden.
drop policy if exists "leaders manage task assignees" on public.club_task_assignees;
create policy "leaders manage task assignees" on public.club_task_assignees
  for all to authenticated
  using (exists (
    select 1 from public.club_tasks t
     where t.id = club_task_assignees.task_id
       and public.has_club_role(t.club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])))
  with check (exists (
    select 1 from public.club_tasks t
     where t.id = club_task_assignees.task_id
       and public.mitgliedschaft_im_verein(club_task_assignees.membership_id, t.club_id)
       and public.has_club_role(t.club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])));

-- Bisher: "authorized members create tasks" INSERT to public
--   with check ((created_by in (select m.id from club_memberships m
--                where m.profile_id = auth.uid() and m.status = 'active'))
--     and (((team_id is not null) and (can_manage_team(team_id)
--             or has_club_role(club_id, vereinsadmin/sysadmin/organisator)))
--          or ((team_id is null) and has_beyond_basic_role(club_id))))
-- created_by durfte eine Mitgliedschaft aus einem anderen Verein sein, und die
-- Mannschaft war nicht an den Verein gebunden.
drop policy if exists "authorized members create tasks" on public.club_tasks;
create policy "authorized members create tasks" on public.club_tasks
  for insert to authenticated
  with check (
    exists (select 1 from public.club_memberships m
             where m.id = club_tasks.created_by
               and m.profile_id = (select auth.uid())
               and m.club_id = club_tasks.club_id
               and m.status = 'active')
    and (
      (club_tasks.team_id is not null
        and exists (select 1 from public.teams t
                     where t.id = club_tasks.team_id and t.club_id = club_tasks.club_id)
        and (public.can_manage_team(club_tasks.team_id)
             or public.has_club_role(club_tasks.club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])))
      or (club_tasks.team_id is null and public.has_beyond_basic_role(club_tasks.club_id))));

-- Bisher: "authorized members update tasks" UPDATE to public, using = check =
--   (created_by in eigene Mitgliedschaften) or has_club_role(club_id, Leitung)
--   or (team_id is not null and can_manage_team(team_id))
-- Neu nur: Die Mannschaft muss zum Verein der Aufgabe gehoeren.
drop policy if exists "authorized members update tasks" on public.club_tasks;
create policy "authorized members update tasks" on public.club_tasks
  for update to authenticated
  using (
    (created_by in (select m.id from public.club_memberships m where m.profile_id = (select auth.uid())))
    or public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])
    or (team_id is not null and public.can_manage_team(team_id)))
  with check (
    /* Der Ersteller nur mit einer Mitgliedschaft IM Verein der Aufgabe -
       sonst verschob er sie per UPDATE in einen fremden Verein (Durchsicht). */
    ((created_by in (select m.id from public.club_memberships m where m.profile_id = (select auth.uid())
                       and m.club_id = club_tasks.club_id and m.status = 'active'))
     or public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])
     or (team_id is not null and public.can_manage_team(team_id)))
    and (team_id is null
         or exists (select 1 from public.teams t where t.id = club_tasks.team_id and t.club_id = club_tasks.club_id)));

-- ============================================================ B1: Protokollaufgaben
-- Bisher: "protokollaufgaben verwalten" ALL to authenticated, using = check =
--   exists (protocols p where p.id = protocol_id and darf_protokolle_verwalten(p.club_id))
-- Die zugewiesene Person durfte aus einem anderen Verein sein -
-- protokollaufgabe_zuweisung_melden meldete dann ueber die Grenze.
drop policy if exists "protokollaufgaben verwalten" on public.protocol_tasks;
create policy "protokollaufgaben verwalten" on public.protocol_tasks
  for all to authenticated
  using (exists (
    select 1 from public.protocols p
     where p.id = protocol_tasks.protocol_id and public.darf_protokolle_verwalten(p.club_id)))
  with check (exists (
    select 1 from public.protocols p
     where p.id = protocol_tasks.protocol_id
       and public.darf_protokolle_verwalten(p.club_id)
       and (protocol_tasks.assignee_membership_id is null
            or public.mitgliedschaft_im_verein(protocol_tasks.assignee_membership_id, p.club_id))));

-- ============================================================ B1: Mannschaften
-- Bisher: "admins manage team assignments" ALL to public, using = check =
--   exists (teams t where t.id = team_id and has_club_role(t.club_id, sysadmin/vereinsadmin))
-- Die Mitgliedschaft war nicht an den Verein der Mannschaft gebunden.
drop policy if exists "admins manage team assignments" on public.team_members;
create policy "admins manage team assignments" on public.team_members
  for all to authenticated
  using (exists (
    select 1 from public.teams t
     where t.id = team_members.team_id
       and public.has_club_role(t.club_id, array['sysadmin','vereinsadmin']::public.club_role[])))
  with check (exists (
    select 1 from public.teams t
     where t.id = team_members.team_id
       and public.mitgliedschaft_im_verein(team_members.membership_id, t.club_id)
       and public.has_club_role(t.club_id, array['sysadmin','vereinsadmin']::public.club_role[])));

-- ============================================================ B1: Tippspiel
-- Bisher: "members join tipp rounds" ALL to public, using = check =
--   (membership_id in (select id from club_memberships where profile_id = auth.uid()))
-- Mit einer fremden Runde stuende der eigene Name in der Tabelle eines anderen
-- Vereins (tipp_tabelle liest display_name ohne Vereinsfilter).
drop policy if exists "members join tipp rounds" on public.tipp_teilnehmer;
create policy "members join tipp rounds" on public.tipp_teilnehmer
  for all to authenticated
  using (membership_id in (select m.id from public.club_memberships m where m.profile_id = (select auth.uid())))
  with check (exists (
    select 1
      from public.tipp_runden r
      join public.club_memberships m on m.club_id = r.club_id
     where r.id = tipp_teilnehmer.runde_id
       and m.id = tipp_teilnehmer.membership_id
       and m.profile_id = (select auth.uid())
       and m.status = 'active'));

-- Bisher: "members manage own predictions" ALL to authenticated
--   using (profile_id = auth.uid())
--   with check ((profile_id = auth.uid()) and not exists (event_results r where r.event_id = predictions.event_id))
-- Getippt werden darf nur auf Spiele eines eigenen Vereins.
drop policy if exists "members manage own predictions" on public.predictions;
create policy "members manage own predictions" on public.predictions
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (
    profile_id = (select auth.uid())
    and not exists (select 1 from public.event_results r where r.event_id = predictions.event_id)
    and exists (select 1 from public.events e
                 where e.id = predictions.event_id and public.is_club_member(e.club_id)));

-- ============================================================ B1: Fahrzeugbuchungen
-- Bisher: "members request bookings" INSERT to public
--   with check (membership_id in (select id from club_memberships
--               where profile_id = auth.uid() and club_id = vehicle_bookings.club_id
--                 and status = 'active'))
-- Fahrzeug und Mannschaft waren nicht an den Verein der Buchung gebunden.
drop policy if exists "members request bookings" on public.vehicle_bookings;
create policy "members request bookings" on public.vehicle_bookings
  for insert to authenticated
  with check (
    exists (select 1 from public.club_memberships m
             where m.id = vehicle_bookings.membership_id
               and m.profile_id = (select auth.uid())
               and m.club_id = vehicle_bookings.club_id
               and m.status = 'active')
    and exists (select 1 from public.club_vehicles v
                 where v.id = vehicle_bookings.vehicle_id and v.club_id = vehicle_bookings.club_id)
    and (vehicle_bookings.team_id is null
         or exists (select 1 from public.teams t
                     where t.id = vehicle_bookings.team_id and t.club_id = vehicle_bookings.club_id)));

-- Bisher (nur auf PROD): "owner or fleet admin updates booking" UPDATE to public
--   using/check ((membership_id in (select id from club_memberships
--                 where profile_id = auth.uid())) or can_manage_fleet(club_id))
-- Status und Entscheidung schuetzt ab 20260914110400 ein eigener Ausloeser (M4).
drop policy if exists "owner or fleet admin updates booking" on public.vehicle_bookings;
create policy "owner or fleet admin updates booking" on public.vehicle_bookings
  for update to authenticated
  using (
    exists (select 1 from public.club_memberships m
             where m.id = vehicle_bookings.membership_id
               and m.profile_id = (select auth.uid())
               and m.club_id = vehicle_bookings.club_id)
    or public.can_manage_fleet(club_id))
  with check (
    (exists (select 1 from public.club_memberships m
              where m.id = vehicle_bookings.membership_id
                and m.profile_id = (select auth.uid())
                and m.club_id = vehicle_bookings.club_id
                and m.status = 'active')
     or public.can_manage_fleet(club_id))
    and exists (select 1 from public.club_vehicles v
                 where v.id = vehicle_bookings.vehicle_id and v.club_id = vehicle_bookings.club_id)
    and (vehicle_bookings.team_id is null
         or exists (select 1 from public.teams t
                     where t.id = vehicle_bookings.team_id and t.club_id = vehicle_bookings.club_id)));

-- Nicht geaendert, weil bereits gebunden oder nur eigene Zeilen betreffend:
-- carpools/carpool_passengers/club_task_signups DELETE (nur eigene Zeile),
-- vehicle_bookings DELETE (die Mitgliedschaft ist seit dem INSERT an den Verein
-- gebunden), team_benachrichtigungen (prueft den Verein schon), poll_votes
-- (Schreiben nur ueber abstimmung_stimmen), season_votes (20260914110100, U5),
-- family_links (20260914110200, B2), anzeigen und sponsor-bilder (an club_id
-- bzw. den Ordner des Vereins gebunden).

-- ============================================================ C2
-- Rumpf aus PROD (pg_get_functiondef, 14.09.2026), geaendert: Termin muss
-- existieren und darf nicht abgesagt sein; leerer Suchpfad.
create or replace function public.run_duty_task_due_reminders()
returns void language plpgsql security definer set search_path = '' as $$
declare
  t record;
begin
  for t in
    select dt.id, dt.assignee_membership_id, dt.title, dt.event_id
      from public.duty_tasks dt
      join public.events e on e.id = dt.event_id
     where dt.due_date = current_date + 1
       and dt.assignee_membership_id is not null
       and not dt.done
       and dt.reminded_at is null
       and e.status is distinct from 'cancelled'
  loop
    perform public.notify_uebersetzt(t.assignee_membership_id, 'duty',
      'helfer.faellig.titel', 'helfer.faellig.text',
      jsonb_build_object('titel', t.title),
      jsonb_build_object('ziel_art', 'helferdienst', 'ziel_id', t.event_id));
    update public.duty_tasks set reminded_at = now() where id = t.id;
  end loop;
end;
$$;

-- ============================================================ rollen-02
-- Die Zeitplanfunktionen verschickten auf Zuruf jedes angemeldeten Nutzers
-- Meldungen an alle Vereine. pg_cron ruft sie als postgres auf, die App nie.
-- Vorbild: 20260903110000_postfach.sql:64, 20260907110000:57-58.
-- MUSS nach dem create or replace oben stehen.
revoke execute on function public.run_birthday_reminders() from public, anon, authenticated;
revoke execute on function public.run_carpool_gap_check() from public, anon, authenticated;
revoke execute on function public.run_duty_gap_check() from public, anon, authenticated;
revoke execute on function public.run_duty_task_due_reminders() from public, anon, authenticated;

-- ============================================================ B4
-- Jedes Mitglied konnte in einem Verein ohne Abo alle Zusatzrollen loeschen
-- (Trainer, Kapitaen, Organisation ...). Die App ruft die Funktion nicht mehr
-- auf; was bei abgelaufenem Abo mit Rollen geschieht, entscheidet der
-- Betreiber (L4).
revoke execute on function public.sync_club_role_entitlement(uuid) from public, anon, authenticated;
grant execute on function public.sync_club_role_entitlement(uuid) to service_role;

-- Erwartet: alle *_offen = false, alle Regeln vorhanden (regeln = 16).
select
  has_function_privilege('authenticated', 'public.run_birthday_reminders()', 'execute') as geburtstag_offen,
  has_function_privilege('authenticated', 'public.run_carpool_gap_check()', 'execute') as mitfahrt_luecke_offen,
  has_function_privilege('authenticated', 'public.run_duty_gap_check()', 'execute') as dienst_luecke_offen,
  has_function_privilege('authenticated', 'public.run_duty_task_due_reminders()', 'execute') as dienst_erinnerung_offen,
  has_function_privilege('authenticated', 'public.sync_club_role_entitlement(uuid)', 'execute') as rollenabgleich_offen,
  (select count(*) from pg_policies
    where schemaname = 'public'
      and (tablename, policyname) in (
        ('carpools', 'club members create carpools'),
        ('carpool_passengers', 'club members join carpool'),
        ('event_attendance', 'members set own attendance'),
        ('duty_assignments', 'members manage own duties'),
        ('duty_tasks', 'authorized insert duty tasks'),
        ('duty_tasks', 'authorized update duty tasks'),
        ('club_task_signups', 'club members signup for tasks'),
        ('club_task_assignees', 'leaders manage task assignees'),
        ('club_tasks', 'authorized members create tasks'),
        ('club_tasks', 'authorized members update tasks'),
        ('protocol_tasks', 'protokollaufgaben verwalten'),
        ('team_members', 'admins manage team assignments'),
        ('tipp_teilnehmer', 'members join tipp rounds'),
        ('predictions', 'members manage own predictions'),
        ('vehicle_bookings', 'members request bookings'),
        ('vehicle_bookings', 'owner or fleet admin updates booking'))) as regeln;
