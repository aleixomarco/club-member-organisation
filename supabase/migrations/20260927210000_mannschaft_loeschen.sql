-- Ziel im Repo: supabase/migrations/20260927210000_mannschaft_loeschen.sql
--
-- Eine Mannschaft endgueltig loeschen - nicht nur stilllegen.
--
-- WUNSCH DES BETREIBERS (27.09.2026): "Man soll als Vereinsadmin auch ein Team
-- loeschen koennen. Dazu klickt man in der Mannschaft auf Bearbeiten und dann
-- auf Loeschen. Anschliessend werden alle anliegenden Verknuepfungen geloescht,
-- auch die Verknuepfung zu den Teilnehmern der Mannschaft wie Athlet/in,
-- Trainer, Manager usw."
--
-- BISHER gibt es nur archive_club_team: Es setzt teams.active auf false. Die
-- Mannschaft verschwindet damit aus den Listen, bleibt aber mit allem daran
-- bestehen - Kanal, Kader, Strafen, Tipprunde. Fuer eine Mannschaft, die es
-- nie wieder geben wird, ist das eine Karteileiche, die in jeder Auswertung
-- weiter mitzaehlt.
--
-- WAS BEIM LOESCHEN VERSCHWINDET
-- Nichts davon muss diese Migration selbst erledigen - die Fremdschluessel auf
-- public.teams regeln es. Am 27.09.2026 lesend geprueft, neun Verweise:
--   mit CASCADE, verschwinden also mit:
--     team_members              die Zuordnung der Athlet/innen, Trainer,
--                               Kapitaene und Teammanager - genau die
--                               "Verknuepfung zu den Teilnehmern"
--     channels                  der Mannschaftskanal samt aller Nachrichten
--     club_tasks                Aufgaben, die nur dieser Mannschaft galten
--     team_penalty_rules        der Strafenkatalog der Mannschaft
--     team_penalty_assignments  offene und bezahlte Strafen
--     tipp_runden               die Tipprunde der Mannschaft samt Tipps
--     team_benachrichtigungen   die Meldungseinstellungen je Mitglied
--   mit SET NULL, bleiben also bestehen:
--     events                    Spiele und Trainings bleiben dem Verein
--                               erhalten und verlieren nur die Mannschaft.
--                               BEWUSST so: An einem Spiel haengen Ergebnis,
--                               Zusagen und Helfereinteilung. Die mit der
--                               Mannschaft zu loeschen hiesse, die halbe
--                               Saison aus der Geschichte zu tilgen.
--     vehicle_bookings          Fahrzeugbuchungen bleiben dem Verein.
-- Die Mitgliedschaften selbst (club_memberships) bleiben unberuehrt: Wer in
-- der Mannschaft war, bleibt Mitglied im Verein. Geloescht wird die
-- Zuordnung, nicht der Mensch.
--
-- WARUM EINE VORSCHAU
-- Ein Loeschen, das eine Tipprunde und einen ganzen Chatverlauf mitnimmt, darf
-- nicht hinter einem beilaeufigen "Wirklich loeschen?" stehen. Die Oberflaeche
-- soll vorher benennen, was verschwindet, und dafuer braucht sie Zahlen. Sie
-- selbst kann sie nicht zaehlen: Auf team_penalty_assignments und tipp_runden
-- sieht ein Vereinsadmin nicht alles, was daranhaengt.

-- ------------------------------------------------- Vorschau
create or replace function public.mannschaft_loesch_folgen(target_club uuid, target_team uuid)
returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare
  ergebnis jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.has_club_role(target_club, array['sysadmin', 'vereinsadmin']::public.club_role[]) then
    raise exception 'Club administrator role required' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.teams t where t.id = target_team and t.club_id = target_club) then
    raise exception 'Team not found';
  end if;

  select jsonb_build_object(
    'name',      (select t.name from public.teams t where t.id = target_team),
    'mitglieder',(select count(*) from public.team_members tm where tm.team_id = target_team),
    'kanaele',   (select count(*) from public.channels c where c.team_id = target_team),
    'aufgaben',  (select count(*) from public.club_tasks ct where ct.team_id = target_team),
    'strafregeln', (select count(*) from public.team_penalty_rules r where r.team_id = target_team),
    'strafen',   (select count(*) from public.team_penalty_assignments a where a.team_id = target_team),
    'tipprunden',(select count(*) from public.tipp_runden tr where tr.team_id = target_team),
    /* Die bleiben - deshalb getrennt ausgewiesen, damit die Meldung nicht den
       Eindruck erweckt, die Saison verschwaende mit. */
    'termine_bleiben', (select count(*) from public.events e where e.team_id = target_team)
  ) into ergebnis;

  return ergebnis;
end;
$function$;

revoke all on function public.mannschaft_loesch_folgen(uuid, uuid) from public, anon;
grant execute on function public.mannschaft_loesch_folgen(uuid, uuid) to authenticated;

comment on function public.mannschaft_loesch_folgen(uuid, uuid) is
  'Zaehlt vor dem Loeschen einer Mannschaft, was daran haengt - damit die Rueckfrage in der App benennen kann, was verschwindet. Aendert nichts.';

-- ------------------------------------------------- Loeschen
create or replace function public.mannschaft_loeschen(target_club uuid, target_team uuid)
returns void
language plpgsql security definer set search_path to '' as $function$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  /* Dieselbe Huerde wie beim Archivieren: nur die Vereinsadministration.
     Trainer und Teammanager duerfen ihre Mannschaft pflegen, aber nicht
     abschaffen - und ein Organisator hat mit Mannschaften nichts zu tun. */
  if not public.has_club_role(target_club, array['sysadmin', 'vereinsadmin']::public.club_role[]) then
    raise exception 'Club administrator role required' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.teams t where t.id = target_team and t.club_id = target_club) then
    raise exception 'Team not found';
  end if;

  /* Die Fremdschluessel raeumen den Rest ab - siehe Kopf. Eine Zeile genuegt;
     was hier von Hand nachgeholfen wuerde, liefe Gefahr, bei der naechsten
     neuen Tabelle vergessen zu werden. */
  delete from public.teams where id = target_team and club_id = target_club;
end;
$function$;

revoke all on function public.mannschaft_loeschen(uuid, uuid) from public, anon;
grant execute on function public.mannschaft_loeschen(uuid, uuid) to authenticated;

comment on function public.mannschaft_loeschen(uuid, uuid) is
  'Loescht eine Mannschaft endgueltig. Kader, Kanal, Strafen und Tipprunde gehen per Fremdschluessel mit; Termine und Fahrzeugbuchungen bleiben dem Verein und verlieren nur die Mannschaft. Nur Vereinsadministration und Sysadmin. Zum blossen Stilllegen gibt es archive_club_team.';

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: loeschen_da = 1, vorschau_da = 1, beide_erklaert = 2,
-- beide_nur_admin = true, vorschau_aendert_nichts = true,
-- kader_haengt_mit_cascade = 1, termine_bleiben_erhalten = 1.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'mannschaft_loeschen') as loeschen_da,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'mannschaft_loesch_folgen') as vorschau_da,
  (select count(*) from pg_description d join pg_proc p on p.oid = d.objoid
    where p.proname in ('mannschaft_loeschen', 'mannschaft_loesch_folgen')) as beide_erklaert,
  (select bool_and(pg_get_functiondef(p.oid) like '%vereinsadmin%'
                   and pg_get_functiondef(p.oid) not like '%organisator%')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('mannschaft_loeschen', 'mannschaft_loesch_folgen')) as beide_nur_admin,
  (select p.provolatile = 's'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'mannschaft_loesch_folgen') as vorschau_aendert_nichts,
  (select count(*) from pg_constraint c
    where c.contype = 'f' and c.confrelid = 'public.teams'::regclass
      and c.conrelid = 'public.team_members'::regclass and c.confdeltype = 'c') as kader_haengt_mit_cascade,
  (select count(*) from pg_constraint c
    where c.contype = 'f' and c.confrelid = 'public.teams'::regclass
      and c.conrelid = 'public.events'::regclass and c.confdeltype = 'n') as termine_bleiben_erhalten;
