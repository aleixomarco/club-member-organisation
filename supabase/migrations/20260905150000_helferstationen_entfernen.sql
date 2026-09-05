-- Helferstationen wieder entfernen - einzeln oder den ganzen Satz.
--
-- ANLASS
-- Seit 20260905090000 laesst sich ein Helferdienst-Satz auf einen Termin
-- anwenden. Der Rueckweg fehlte: Wer sich vertan hat, den falschen Satz
-- erwischt oder eine Station am Spieltag doch nicht braucht, konnte sie nicht
-- mehr loswerden.
--
-- WARUM ALS DATENBANKFUNKTION
-- Eine Station steht an drei Stellen:
--   events.helper_slots   welche Stationen es an diesem Termin gibt
--   duty_assignments      wer sich dafuer eingetragen hat
--   duty_tasks            die Aufgabenliste der Vereinsleitung
-- Wer nur die erste Stelle raeumt, hinterlaesst Eintragungen fuer eine Station,
-- die es nicht mehr gibt: Die Person steht weiter im Plan, sieht davon aber
-- nichts mehr und erfaehrt nie, dass ihr Dienst entfallen ist. Alle drei
-- gehoeren in einen Vorgang - und der gehoert dorthin, wo auch die Rechte
-- geprueft werden.
--
-- Geprueft wird mit can_manage_duty_task, derselben Regel wie beim Anwenden
-- einer Vorlage. Wer einen Satz auflegen darf, darf ihn auch wieder abraeumen.
--
-- Beide Funktionen liefern die Zahl der geloeschten EINTRAGUNGEN zurueck, nicht
-- die der Stationen. Das ist die Zahl, die zaehlt: Sie sagt, wie vielen
-- Menschen gerade ihr Dienst gestrichen wurde. Die App kann damit vorher
-- warnen, statt hinterher zu erklaeren.

create or replace function public.remove_duty_station(target_event uuid, station_name text)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_club        uuid;
  v_eintragungen integer;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

  select club_id into v_club from public.events where id = target_event;
  if v_club is null then return 0; end if;

  -- 1) Eintragungen fuer genau diese Station
  delete from public.duty_assignments
   where event_id = target_event and station = station_name;
  get diagnostics v_eintragungen = row_count;

  -- 2) Die Aufgabe in der Liste der Vereinsleitung
  delete from public.duty_tasks
   where event_id = target_event and title = station_name;

  -- 3) Die Station selbst. array_remove trifft alle Vorkommen; doppelte
  --    Eintraege koennen zwar nicht entstehen (apply_duty_template schliesst
  --    sie aus), aber ein von Hand angelegter Termin ist davon nicht gedeckt.
  update public.events
     set helper_slots = array_remove(helper_slots, station_name),
         updated_at = now()
   where id = target_event;

  return v_eintragungen;
end;
$$;

create or replace function public.clear_duty_stations(target_event uuid)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_eintragungen integer;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

  delete from public.duty_assignments where event_id = target_event;
  get diagnostics v_eintragungen = row_count;

  delete from public.duty_tasks where event_id = target_event;

  update public.events
     set helper_slots = '{}',
         updated_at = now()
   where id = target_event;

  return v_eintragungen;
end;
$$;

grant execute on function public.remove_duty_station(uuid, text) to authenticated, service_role;
grant execute on function public.clear_duty_stations(uuid)      to authenticated, service_role;
revoke all on function public.remove_duty_station(uuid, text) from public, anon;
revoke all on function public.clear_duty_stations(uuid)      from public, anon;

-- Kontrolle: Beide Funktionen muessen stehen und integer liefern.
select p.proname, pg_catalog.format_type(p.prorettype, null) as rueckgabe
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('remove_duty_station', 'clear_duty_stations')
order by p.proname;
