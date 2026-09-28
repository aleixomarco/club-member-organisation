-- Ziel im Repo: supabase/migrations/20260928170000_teammanager_darf_anlegen.sql
--
-- Der Teammanager darf Athlet/innen ohne Konto anlegen.
--
-- ENTSCHEIDUNG DES BETREIBERS (28.09.2026), auf die Frage aus der Durchsicht:
-- "ja, Teammanager soll das auch duerfen".
--
-- WAS VORHER WAR
-- app/page.tsx:7790 zeigt den Knopf "Spieler/in ohne Konto anlegen" fuer
-- vereinsadmin, sysadmin, organisator, trainer UND teammanager.
-- create_team_player kannte teammanager nicht - der Knopf lief also fuer diese
-- eine Rolle garantiert in die Fehlermeldung tm.spielerAnlegenFehler, und zwar
-- seit dem 08.08.2026 (20260808170000). Der Organisator wurde am 27.09.
-- nachgetragen, der Teammanager blieb offen, weil er eine Entscheidung war und
-- keine Panne.
--
-- WARUM DAS UNBEDENKLICH IST
-- Die Funktion legt eine verwaltete Mitgliedschaft aus einem Namen an - sie
-- ordnet sie keiner Mannschaft zu. Das macht set_managed_player_teams, und die
-- laesst Trainer und Teammanager seit jeher nur ihre EIGENEN Mannschaften
-- waehlen (hoechstens drei je Person). Der Teammanager bekommt also genau das,
-- was er zum Fuehren seines Kaders braucht, und keinen Schritt mehr.
--
-- Damit sagen App und Datenbank an dieser Stelle zum ersten Mal dasselbe.

create or replace function public.create_team_player(target_club uuid, player_name text, membership_number text default null::text)
returns uuid
language plpgsql security definer set search_path to '' as $function$
declare
  new_id uuid;
  normalized_name text := nullif(trim(player_name), '');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if normalized_name is null then raise exception 'Player name required'; end if;

  if not exists (
    select 1
    from public.club_memberships acting_membership
    join public.membership_roles acting_role
      on acting_role.membership_id = acting_membership.id
     and acting_role.role in ('vereinsadmin', 'sysadmin', 'trainer', 'organisator', 'teammanager')
    where acting_membership.club_id = target_club
      and acting_membership.profile_id = auth.uid()
      and acting_membership.status = 'active'
  ) then raise exception 'Club administrator, trainer, organiser or team manager role required'; end if;

  insert into public.club_memberships (
    club_id, profile_id, display_name, member_since, status, is_managed_profile, membership_number, created_by
  ) values (
    target_club, null, normalized_name, extract(year from current_date)::integer, 'active', true,
    nullif(trim(membership_number), ''), auth.uid()
  ) returning id into new_id;

  insert into public.membership_roles (membership_id, role, granted_by)
  values (new_id, 'mitglied', auth.uid()), (new_id, 'spieler', auth.uid());

  return new_id;
end;
$function$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: kennt_teammanager = true, rollensatz_vollstaendig = 5,
-- zuordnung_bleibt_eng = true.
select
  (select pg_get_functiondef(p.oid) like '%''teammanager''%'
     from pg_proc p where p.proname = 'create_team_player') as kennt_teammanager,
  (select count(*) from unnest(array['vereinsadmin','sysadmin','trainer','organisator','teammanager']) as r(rolle)
    where (select pg_get_functiondef(p.oid) from pg_proc p where p.proname = 'create_team_player')
          like '%''' || r.rolle || '''%') as rollensatz_vollstaendig,
  /* Die Mannschaftszuordnung bleibt eng: set_managed_player_teams laesst
     Trainer und Teammanager weiterhin nur die eigenen Mannschaften. */
  (select pg_get_functiondef(p.oid) like '%teammanager%'
     from pg_proc p where p.proname = 'set_managed_player_teams') as zuordnung_bleibt_eng;
