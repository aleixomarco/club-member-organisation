-- Ziel im Repo: supabase/migrations/20260927190000_personen_ohne_konto.sql
--
-- Personen ohne App-Konto bei Aufgaben und Helferdiensten hinterlegen.
--
-- WUNSCH DES BETREIBERS (27.09.2026): "Fuer alle Rollen, die in Aufgaben
-- zuteilen koennen, brauchen wir die Moeglichkeit, dass auch Namen eingetragen
-- werden koennen - Namen von Personen, die die App nicht haben. Man legt eine
-- Person an, die nicht als Nutzer aktiv ist, die aber bei einer Aufgabe
-- hinterlegt und vom Vorstand oder den Organisatoren wieder herausgenommen
-- bzw. geloescht werden kann." Ausdruecklich auch beim Helferset.
--
-- WAS SCHON DA WAR (geprueft am 27.09.2026, nur lesend, PROD)
-- Erstaunlich viel. Die Zuteilung selbst kann das bereits:
--   * duty_assignments: die Regel "leaders manage duties" (ALL) erlaubt
--     vereinsadmin, sysadmin, geschaeftsfuehrung, vorstand und organisator,
--     JEDE Mitgliedschaft des Vereins einzutragen und wieder auszutragen. Die
--     Pruefung dahinter ist mitgliedschaft_im_verein(), und die fragt nur nach
--     club_id - ein verwaltetes Profil besteht sie.
--   * club_task_assignees: dieselbe Bauart, Regel "leaders manage task
--     assignees" fuer vereinsadmin, sysadmin, organisator.
--   * Beide haengen per on delete cascade an club_memberships. Wird die Person
--     geloescht, verschwinden ihre Eintragungen mit ihr - keine Karteileichen.
--   * Die Auswahllisten in der App zeigen sie schon heute: die Helferstation
--     filtert nur reine Fans heraus, die Aufgabenzuweisung filtert gar nicht.
-- Es fehlte also nicht das Zuteilen, sondern das ANLEGEN der Person - und
-- zwar aus der Hand derer, die zuteilen.
--
-- WARUM NICHT create_team_player
-- Es gibt sie schon, unter Teams > Mannschaft > Kader. Sie taugt hier aus zwei
-- Gruenden nicht:
--   1. Sie verlangt vereinsadmin, sysadmin ODER trainer - der Organisator,
--      der die Helferdienste macht, steht nicht darin.
--   2. Sie vergibt immer 'mitglied' UND 'spieler'. Wer den Kiosk uebernimmt,
--      waere damit Athlet: er stuende im Kader, waehlbar zur Athletin des
--      Jahres, im Strafenkatalog. Fuer eine Grossmutter am Kuchenstand ist das
--      schlicht falsch.
-- Deshalb eine eigene Funktion mit eigener Bedeutung. create_team_player
-- bleibt unangetastet - wer einen Athleten ohne Konto anlegt, tut das weiter
-- dort.
--
-- WARUM KEINE FREITEXT-SPALTE
-- Naheliegend waere gewesen, duty_assignments und club_task_assignees je eine
-- Spalte "name" zu geben. Dann haette aber jede Zaehlung zwei Faelle: die
-- Platzgrenze in helferstation_plaetze, der Waechter run_duty_gap_check, die
-- offenen Punkte, jede Liste in der App. Jede Stelle, die den zweiten Fall
-- vergisst, zaehlt still falsch. Eine Person, die wie jede andere eine
-- membership_id hat, braucht keine einzige dieser Stellen zu aendern.
--
-- MUSS ZUSAMMEN MIT DER APP AUSGELIEFERT WERDEN: Ohne die Knoepfe im
-- Helferblock und in der Aufgabenzuweisung ruft niemand diese Funktionen auf.

-- ------------------------------------------------- Anlegen
create or replace function public.person_ohne_konto_anlegen(target_club uuid, person_name text)
returns uuid
language plpgsql security definer set search_path to '' as $function$
declare
  neue_id uuid;
  name_sauber text := nullif(btrim(person_name), '');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if name_sauber is null then raise exception 'Name required'; end if;
  /* Laenge begrenzen wie ueberall sonst bei Freitext aus der Oberflaeche -
     display_name ist sonst unbegrenzt, und eine Liste mit einem 4000 Zeichen
     langen "Namen" zerlegt jede Ansicht, in der sie auftaucht. */
  if length(name_sauber) > 80 then name_sauber := left(name_sauber, 80); end if;

  /* Genau die Rollen, die auch zuteilen duerfen - der Wunsch nennt
     Vereinsadministration und Organisation. sysadmin steht mit dabei, weil
     register_new_club dem Gruender eines Vereins beide Rollen zugleich gibt. */
  if not public.has_club_role(target_club,
       array['vereinsadmin', 'sysadmin', 'organisator']::public.club_role[]) then
    raise exception 'Not authorized to add people without an account'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.club_memberships (
    club_id, profile_id, display_name, member_since, status, is_managed_profile, created_by)
  values (
    target_club, null, name_sauber, extract(year from current_date)::integer, 'active', true, auth.uid())
  returning id into neue_id;

  /* NUR 'mitglied'. Kein 'spieler' - siehe Kopf. Ganz ohne Rolle ginge auch
     nicht: istNurFan und isFormalMember in der App lesen den Rollensatz, und
     ein leerer Satz wuerde die Person aus der Helferauswahl werfen, in die sie
     gerade hinein soll. */
  insert into public.membership_roles (membership_id, role, granted_by)
  values (neue_id, 'mitglied', auth.uid());

  return neue_id;
end;
$function$;

revoke all on function public.person_ohne_konto_anlegen(uuid, text) from public, anon;
grant execute on function public.person_ohne_konto_anlegen(uuid, text) to authenticated;

comment on function public.person_ohne_konto_anlegen(uuid, text) is
  'Legt eine Person ohne App-Konto an (verwaltetes Profil, nur Rolle mitglied), damit Vereinsadministration und Organisation sie bei Helferstationen und Vereinsaufgaben hinterlegen koennen. Fuer Athlet/innen ohne Konto gibt es create_team_player - die vergibt zusaetzlich die Rolle spieler.';

-- ------------------------------------------------- Loeschen
create or replace function public.person_ohne_konto_entfernen(target_membership uuid)
returns void
language plpgsql security definer set search_path to '' as $function$
declare
  v_club uuid;
  v_verwaltet boolean;
  v_profil uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select m.club_id, m.is_managed_profile, m.profile_id
    into v_club, v_verwaltet, v_profil
    from public.club_memberships m where m.id = target_membership
     for update;
  if v_club is null then raise exception 'Person not found'; end if;

  /* Der doppelte Riegel. is_managed_profile allein genuegt nicht: Ein
     betreutes Kinderprofil, das ueber claim_managed_membership ein echtes
     Konto bekommen hat, koennte das Kennzeichen noch tragen. Erst beides
     zusammen - Kennzeichen UND kein Profil - heisst sicher: hier haengt kein
     Mensch mit Anmeldung dran, den dieser Aufruf aus dem Verein wuerfe. */
  if not coalesce(v_verwaltet, false) or v_profil is not null then
    raise exception 'Only people without an account can be removed this way'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.has_club_role(v_club,
       array['vereinsadmin', 'sysadmin', 'organisator']::public.club_role[]) then
    raise exception 'Not authorized to remove people without an account'
      using errcode = 'insufficient_privilege';
  end if;

  /* Die Eintragungen gehen per on delete cascade mit: duty_assignments,
     club_task_assignees, club_task_signups, team_members, membership_roles.
     Genau darum steht die Person in denselben Tabellen wie alle anderen. */
  delete from public.club_memberships where id = target_membership;
end;
$function$;

revoke all on function public.person_ohne_konto_entfernen(uuid) from public, anon;
grant execute on function public.person_ohne_konto_entfernen(uuid) to authenticated;

comment on function public.person_ohne_konto_entfernen(uuid) is
  'Loescht eine Person ohne App-Konto samt ihren Eintragungen (cascade). Weist ab, sobald ein Profil daranhaengt - ein Mensch mit Anmeldung laesst sich hierueber nicht entfernen.';

-- ------------------------------------------------- Der alte Knopf im Kader
-- Nebenbefund derselben Durchsicht: Unter Teams > Mannschaft > Kader zeigt die
-- App den Knopf "Spieler/in ohne Konto anlegen" auch der Organisation
-- (canAssignPlayers in app/page.tsx), create_team_player verlangt aber
-- vereinsadmin, sysadmin ODER trainer. Ein Organisator, der dort klickt, laeuft
-- also garantiert in die Fehlermeldung - und zwar seit dem 08.08.2026.
-- Da der Betreiber die Organisation ausdruecklich zu denen zaehlt, die Personen
-- anlegen duerfen, kommt sie hier dazu. Nur die Rollenzeile aendert sich; der
-- Rest der Funktion bleibt Wort fuer Wort, wie er war.
-- NICHT geaendert: teammanager. Die App zeigt den Knopf auch dieser Rolle, und
-- auch sie laeuft heute in den Fehler. Ob ein Teammanager Personen anlegen darf,
-- ist eine Entscheidung des Betreibers und keine, die hier nebenbei faellt.
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
     and acting_role.role in ('vereinsadmin', 'sysadmin', 'trainer', 'organisator')
    where acting_membership.club_id = target_club
      and acting_membership.profile_id = auth.uid()
      and acting_membership.status = 'active'
  ) then raise exception 'Club administrator, trainer or organiser role required'; end if;

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
-- Erwartet: anlegen_da = 1, entfernen_da = 1, beide_erklaert = 2,
-- anlegen_ohne_spieler = true, anlegen_kennt_organisator = true,
-- entfernen_schuetzt_konten = true, zuteilung_cascade = 3,
-- kader_kennt_organisator = true.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'person_ohne_konto_anlegen') as anlegen_da,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'person_ohne_konto_entfernen') as entfernen_da,
  (select count(*) from pg_description d join pg_proc p on p.oid = d.objoid
    where p.proname in ('person_ohne_konto_anlegen', 'person_ohne_konto_entfernen')) as beide_erklaert,
  /* Auf die EINFUEGUNG schauen, nicht auf das ganze Wort: Der erste Versuch
     fragte nach '%spieler%' und schlug fehl, weil der Kommentar im Rumpf
     erklaert, warum die Rolle gerade NICHT vergeben wird. */
  (select pg_get_functiondef(p.oid) like '%values (neue_id, ''mitglied'', auth.uid());%'
      and pg_get_functiondef(p.oid) not like '%(neue_id, ''spieler''%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'person_ohne_konto_anlegen') as anlegen_ohne_spieler,
  (select pg_get_functiondef(p.oid) like '%organisator%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'person_ohne_konto_anlegen') as anlegen_kennt_organisator,
  /* Die Variable heisst v_profil, nicht profile_id - der erste Versuch suchte
     den Spaltennamen und fand ihn nicht. */
  (select pg_get_functiondef(p.oid) like '%v_profil is not null%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'person_ohne_konto_entfernen') as entfernen_schuetzt_konten,
  (select count(*) from pg_constraint c
    where c.contype = 'f' and c.confrelid = 'public.club_memberships'::regclass
      and c.confdeltype = 'c'
      and c.conrelid::regclass::text in ('duty_assignments', 'club_task_assignees', 'club_task_signups')) as zuteilung_cascade,
  (select pg_get_functiondef(p.oid) like '%organisator%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_team_player') as kader_kennt_organisator;
