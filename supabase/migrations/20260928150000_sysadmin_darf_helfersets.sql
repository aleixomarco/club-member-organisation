-- Ziel im Repo: supabase/migrations/20260928150000_sysadmin_darf_helfersets.sql
--
-- Der Sys-Admin sah Knoepfe, die die Datenbank ihm verweigert.
--
-- GEFUNDEN BEI DER DURCHSICHT vom 28.09.2026: Die App entscheidet ueber
-- canManageDuty = isAdmin || organisator, und isAdmin ist fuer 'sysadmin'
-- wahr. Die Datenbank entscheidet ueber can_manage_duty_templates, und dort
-- stehen 'organisator', 'vorstand' und 'vereinsadmin' - 'sysadmin' fehlt.
-- Alle Handgriffe, die am 25.-28.09. dazugekommen sind, haengen daran:
-- add_duty_station, set_duty_station_plaetze, remove_duty_station,
-- clear_duty_stations, apply_duty_template, helferset_nutzung,
-- helferset_speichern. Ein Sys-Admin ohne zusaetzliche Vereinsadmin-Rolle
-- bekommt sie alle gezeigt und laeuft bei jedem einzelnen in eine
-- Fehlermeldung.
--
-- WARUM SYSADMIN UND NICHT DIE APP EINGEENGT WIRD
-- Derselbe Grund wie in darfVereinVerwalten, beitritt_entscheiden und
-- mannschaft_loeschen, die ihn alle ausdruecklich nennen: register_new_club
-- gibt dem Gruender eines Vereins sysadmin UND vereinsadmin zugleich. Ihn hier
-- auszusperren hiesse, Vereine auszusperren, deren einziger Zugang dieser
-- Gruender ist. Die uebrigen neuen Funktionen dieser vier Tage fuehren
-- sysadmin durchgehend mit; diese eine war die Ausnahme.
--
-- 'vorstand' bleibt unangetastet, obwohl die Rolle am 05.09. abgeschafft wurde
-- (20260905160000) und niemand sie mehr traegt: Sie hier zu streichen waere
-- eine zweite, unabhaengige Aenderung an einer Rechtepruefung - und die
-- gehoert nicht in eine Fehlerbehebung.

create or replace function public.can_manage_duty_templates(target_club uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $function$
  select exists (
    select 1 from public.membership_roles r
    join public.club_memberships m on m.id = r.membership_id
    where m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
      and r.role in ('organisator', 'vorstand', 'vereinsadmin', 'sysadmin')
  );
$function$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: kennt_sysadmin = true, kennt_organisator = true,
-- kennt_vereinsadmin = true.
select
  (select pg_get_functiondef(p.oid) like '%''sysadmin''%'
     from pg_proc p where p.proname = 'can_manage_duty_templates') as kennt_sysadmin,
  (select pg_get_functiondef(p.oid) like '%''organisator''%'
     from pg_proc p where p.proname = 'can_manage_duty_templates') as kennt_organisator,
  (select pg_get_functiondef(p.oid) like '%''vereinsadmin''%'
     from pg_proc p where p.proname = 'can_manage_duty_templates') as kennt_vereinsadmin;
