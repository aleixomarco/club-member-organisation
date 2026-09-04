-- "Vorlage wurde angewendet" - und dann passierte nichts.
--
-- BEOBACHTUNG DES BETREIBERS
-- Ein Spiel aufklappen, den Helferdienst-Satz "Standard Heimspiel" auswaehlen
-- (darin: Zeitnahme, Grill, Hallensprecher), auf "Anwenden" tippen. Es kommt
-- die Meldung "Vorlage wurde angewendet" - aber die Stationen erscheinen
-- nirgends zur Auswahl.
--
-- URSACHE: ZWEI ABLAGEN, DIE NICHTS VONEINANDER WISSEN
-- apply_duty_template schrieb ausschliesslich nach public.duty_tasks. Welche
-- Stationen ein Termin aber wirklich HAT - und woran sich Mitglieder eintragen
-- koennen - steht seit 20260903090000 an einer ganz anderen Stelle:
-- public.events.helper_slots. Die Liste "Helfer:innen gesucht" in der
-- aufgeklappten Karte liest genau diese Spalte.
--
-- Die Vorlage fuellte also eine Liste, die an dieser Stelle niemand anzeigt,
-- und liess die Liste, auf die es ankommt, unberuehrt. Die Erfolgsmeldung war
-- nicht einmal falsch - es wurde ja etwas geschrieben. Nur eben ins Leere.
--
-- Dazu kam: Die Funktion gab void zurueck. Ob ueberhaupt eine Station dabei
-- war, konnte die App gar nicht wissen. Ein Satz ohne Stationen meldete
-- genauso freundlich "angewendet" wie ein voller.
--
-- WAS SICH AENDERT
-- 1. Die Stationen der Vorlage werden an events.helper_slots angehaengt -
--    ohne Dubletten und in der Reihenfolge der Vorlage. Erst dadurch kann sich
--    jemand eintragen.
-- 2. Der Eintrag in duty_tasks bleibt. Das ist die Aufgabenliste der
--    Vereinsleitung am Termin und wird an anderer Stelle gebraucht.
-- 3. Die Funktion gibt die Zahl der uebernommenen Stationen zurueck, damit die
--    App bei einem leeren Satz die Wahrheit sagen kann statt "angewendet".
--
-- Der Rueckgabetyp aendert sich, deshalb muss die alte Fassung zuerst weichen -
-- create or replace kann das nicht.

drop function if exists public.apply_duty_template(uuid, uuid);

create or replace function public.apply_duty_template(target_event uuid, target_template uuid)
returns integer
language plpgsql security definer set search_path to 'public' as $function$
declare
  ev_club           uuid;
  acting_membership uuid;
  stationen         text[];
  item              record;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

  select club_id into ev_club from public.events where id = target_event;
  if ev_club is null then return 0; end if;

  select id into acting_membership
    from public.club_memberships
   where profile_id = auth.uid() and club_id = ev_club;

  -- Die Stationen der Vorlage, in ihrer Reihenfolge.
  select coalesce(array_agg(i.title order by i.sort_order), '{}')
    into stationen
    from public.duty_task_template_items i
   where i.template_id = target_template;

  if cardinality(stationen) = 0 then return 0; end if;

  -- 1) Aufgabenliste der Vereinsleitung am Termin (wie bisher).
  for item in select title from public.duty_task_template_items
               where template_id = target_template order by sort_order loop
    insert into public.duty_tasks (event_id, club_id, title, created_by)
    values (target_event, ev_club, item.title, acting_membership);
  end loop;

  -- 2) Die Stationen, an denen sich Mitglieder eintragen koennen. Nur was noch
  --    nicht dasteht, wird hinten angehaengt: Wer eine Vorlage versehentlich
  --    zweimal anwendet, soll nicht zweimal "Grill" bekommen.
  update public.events e
     set helper_slots = e.helper_slots || (
           select coalesce(array_agg(u.titel order by u.reihenfolge), '{}')
             from unnest(stationen) with ordinality as u(titel, reihenfolge)
            where not (u.titel = any(e.helper_slots))
         ),
         updated_at = now()
   where e.id = target_event;

  return cardinality(stationen);
end;
$function$;

grant execute on function public.apply_duty_template(uuid, uuid) to authenticated, service_role;
revoke all on function public.apply_duty_template(uuid, uuid) from public, anon;

-- Kontrolle: Die Funktion muss jetzt integer liefern.
select p.proname, pg_catalog.format_type(p.prorettype, null) as rueckgabe
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'apply_duty_template';
