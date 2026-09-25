-- Ziel im Repo: supabase/migrations/20260926110000_saetze_mit_plaetzen.sql
--
-- Drei Dinge, die zusammengehoeren.
--
-- ERSTENS: Die Plaetze gehoeren auch in den Satz.
-- Seit 20260926100000 laesst sich je Station einstellen, wie viele Personen
-- hineinpassen. Wer einen Satz vorlud, bekam trotzdem ueberall die Vorgabe
-- zwei und musste danach jede Station einzeln nachstellen - der Satz soll
-- gerade die Handarbeit abnehmen. duty_task_template_items bekommt deshalb
-- eine Spalte plaetze, und apply_duty_template nimmt sie mit an den Termin.
-- Nur fuer Stationen, die neu dazukommen: Steht die Station schon am Termin,
-- bleibt die dort eingestellte Zahl stehen. Wer sie von Hand geaendert hat,
-- soll sie nicht durch ein zweites Anwenden verlieren.
--
-- ZWEITENS: Der Waechter duty-gap-check sieht seit gestern die falsche Liste.
-- Er laeuft taeglich um 9 Uhr, schaut auf Heimspiele in drei Tagen und meldet
-- "Helfer gesucht" an die ganze Mannschaft, sobald eine Zeile in duty_tasks
-- ohne Person dasteht. duty_tasks ist die zweite, gestern aus der Oberflaeche
-- entfernte Helferliste (20260925210000): Wer sich eintraegt, landet in
-- duty_assignments und laesst duty_tasks unberuehrt. Die Zeilen dort stehen
-- also fuer immer auf "niemand" - und der Waechter haette morgen frueh alle
-- Mannschaftsmitglieder von zwei Heimspielen angeschrieben, obwohl die
-- Stationen besetzt sein koennen. Umgekehrt sieht er Stationen gar nicht, die
-- ueber add_duty_station dazugekommen sind, weil die keine Zeile in duty_tasks
-- anlegen. Er liest jetzt dasselbe wie die App: die Stationen am Termin, die
-- Eintragungen und die Platzzahl.
-- Geprueft am 26.09.2026 (nur lesend, PROD): zwei kuenftige Heimspiele
-- erfuellen die alte Bedingung, in duty_assignments steht keine einzige Zeile.
--
-- DRITTENS: apply_duty_template legt keine Zeilen in duty_tasks mehr an.
-- Solange der Waechter sie las, waren sie noetig; jetzt waeren sie nur noch
-- Karteileichen in einer Liste, die niemand mehr sieht - genau wie bei
-- add_duty_station, das von Anfang an keine anlegt. Der Altbestand bleibt
-- liegen und verschwindet mit seinen Terminen; remove_duty_station und
-- clear_duty_stations raeumen ihn weiterhin mit ab.
-- Was duty_tasks noch liest, bleibt unberuehrt und faellt damit still:
-- run_duty_task_due_reminders (erinnert an Fristen, die sich seit gestern
-- nirgends mehr setzen lassen) und in punkte_je_mitglied die 15 Punkte je
-- erledigter Aufgabe. Die 25 Punkte je Helferdienst zaehlen aus
-- duty_assignments und bleiben, wie sie sind.

-- ------------------------------------------------- Plaetze im Satz
alter table public.duty_task_template_items
  add column if not exists plaetze integer not null default 2;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'duty_task_template_items_plaetze_rahmen') then
    alter table public.duty_task_template_items
      add constraint duty_task_template_items_plaetze_rahmen check (plaetze between 1 and 10);
  end if;
end $$;

comment on column public.duty_task_template_items.plaetze is
  'Wie viele Personen an diese Station passen, wenn der Satz auf einen Termin angewendet wird. Vorgabe zwei, erlaubt 1 bis 10 - derselbe Rahmen wie events.helper_caps.';

-- ------------------------------------------------- Satz anwenden
create or replace function public.apply_duty_template(target_event uuid, target_template uuid)
returns integer
language plpgsql security definer set search_path to 'public' as $function$
declare
  ev_club    uuid;
  v_vorher   text[];
  v_neu      text[];
  v_neue_caps jsonb;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

  select club_id, coalesce(helper_slots, '{}'::text[]) into ev_club, v_vorher
    from public.events where id = target_event for update;
  if ev_club is null then return 0; end if;

  /* Nur die Stationen, die noch nicht dastehen. Wer eine Vorlage versehentlich
     zweimal anwendet, soll nicht zweimal "Grill" bekommen - und die Platzzahl
     einer schon vorhandenen Station bleibt so, wie die Leitung sie gesetzt
     hat. */
  select coalesce(array_agg(i.title order by i.sort_order), '{}'::text[]),
         coalesce(jsonb_object_agg(i.title, greatest(1, least(10, coalesce(i.plaetze, 2)))), '{}'::jsonb)
    into v_neu, v_neue_caps
    from public.duty_task_template_items i
   where i.template_id = target_template
     and not (i.title = any(v_vorher));

  if cardinality(v_neu) = 0 then return 0; end if;

  update public.events e
     set helper_slots = coalesce(e.helper_slots, '{}'::text[]) || v_neu,
         helper_caps  = coalesce(e.helper_caps, '{}'::jsonb) || v_neue_caps,
         updated_at   = now()
   where e.id = target_event;

  /* Die Rueckgabe ist die Zahl der uebernommenen Stationen. Sie zaehlt jetzt
     nur noch die NEUEN - vorher zaehlte sie alle Stationen des Satzes, auch
     die, die schon dastanden. Die Meldung in der App ("3 Stationen
     uebernommen") stimmt damit zum ersten Mal mit dem ueberein, was man
     danach sieht. */
  return cardinality(v_neu);
end;
$function$;

-- ------------------------------------------------- Der taegliche Waechter
create or replace function public.run_duty_gap_check()
returns void
language plpgsql security definer set search_path to 'public' as $function$
declare
  ev     record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled' and e.home_away = 'heim'
      and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
      and exists (
        /* Eine Station, an der noch Plaetze frei sind. Gezaehlt wird, was die
           App zeigt: die Eintragungen gegen die Platzzahl der Station. */
        select 1
          from unnest(coalesce(e.helper_slots, '{}'::text[])) as s(station)
         where (select count(*) from public.duty_assignments d
                 where d.event_id = e.id and d.station = s.station)
               < public.helferstation_plaetze(coalesce(e.helper_caps, '{}'::jsonb), s.station))
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'duty',
        'helfer.gesucht.titel', 'helfer.gesucht.text',
        jsonb_build_object('titel', ev.title, 'datum', jsonb_build_object('zeit', ev.starts_at, 'uhrzeit', false)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$function$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: spalte_da = 1, rahmen_da = 1, satz_nimmt_plaetze_mit = true,
-- satz_ohne_karteileichen = true, waechter_liest_eintragungen = true,
-- waechter_ohne_duty_tasks = true, termine_die_heute_melden_wuerden = 0.
select (select count(*) from information_schema.columns
         where table_schema='public' and table_name='duty_task_template_items' and column_name='plaetze') as spalte_da,
       (select count(*) from pg_constraint where conname='duty_task_template_items_plaetze_rahmen')       as rahmen_da,
       (select position('helper_caps' in pg_get_functiondef(
          'public.apply_duty_template(uuid, uuid)'::regprocedure)) > 0)                                   as satz_nimmt_plaetze_mit,
       (select position('duty_tasks' in pg_get_functiondef(
          'public.apply_duty_template(uuid, uuid)'::regprocedure)) = 0)                                   as satz_ohne_karteileichen,
       (select position('duty_assignments' in pg_get_functiondef(
          'public.run_duty_gap_check()'::regprocedure)) > 0)                                              as waechter_liest_eintragungen,
       (select position('duty_tasks' in pg_get_functiondef(
          'public.run_duty_gap_check()'::regprocedure)) = 0)                                              as waechter_ohne_duty_tasks,
       (select count(*) from public.events e
         where e.status = 'scheduled' and e.home_away = 'heim'
           and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
           and exists (select 1 from unnest(coalesce(e.helper_slots, '{}'::text[])) as s(station)
                        where (select count(*) from public.duty_assignments d
                                where d.event_id = e.id and d.station = s.station)
                              < public.helferstation_plaetze(coalesce(e.helper_caps, '{}'::jsonb), s.station)))
                                                                                                          as termine_die_heute_melden_wuerden;
