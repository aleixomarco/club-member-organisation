-- Ziel im Repo: supabase/migrations/20260928130000_abgleich_sperre_richtig.sql
--
-- helferset_speichern war seit der vorigen Migration kaputt.
--
-- WAS PASSIERT IST
-- 20260928120000 hat dem Abgleich eine Sperre auf die Termine gegeben, damit
-- zwei gleichzeitig gespeicherte Sets sich nicht in die Quere kommen. Die
-- Sperre kam als "for update of e" an eine Schleife, die mit "select distinct"
-- beginnt - und das verbietet PostgreSQL:
--   ERROR 0A000: FOR UPDATE is not allowed with DISTINCT clause
-- Die Funktion warf damit bei JEDEM Speichern eines Helfersets. Aufgefallen
-- ist es beim Nachspielen in einer zurueckgenommenen Transaktion, nicht beim
-- Kontrollblock: Der prueft, ob der Text "e.club_id = v_club" im Rumpf steht,
-- und das tut er auch in einer Funktion, die nie laeuft. Eine Kontrolle, die
-- nur liest, was dasteht, findet so etwas nicht.
--
-- DIE LOESUNG
-- Das distinct war ohnehin nur noetig, weil ein Termin mehrere Spur-Zeilen
-- desselben Sets traegt - eine je Station. Mit "e.id in (select event_id ...)"
-- faellt die Mehrfachnennung schon in der Unterabfrage weg, die Sperre ist
-- erlaubt, und die feste Reihenfolge ueber "order by e.id" bleibt.

create or replace function public.helferset_speichern(target_template uuid, posten jsonb)
returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare
  v_club uuid;
  p jsonb;
  v_titel text;
  v_plaetze int;
  v_behalten text[] := '{}';
  v_weg text[];
  ev record;
  v_spiele int := 0;
  v_neu int := 0;
  v_geaendert int := 0;
  v_entfernt int := 0;
  v_behalten_wegen int := 0;
  v_sortierung int := 0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select club_id into v_club from public.duty_task_templates where id = target_template;
  if v_club is null then raise exception 'Template not found'; end if;
  if not public.can_manage_duty_templates(v_club) then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;
  if jsonb_typeof(posten) <> 'array' then raise exception 'Posten must be an array'; end if;

  for p in select * from jsonb_array_elements(posten) loop
    v_titel := nullif(btrim(coalesce(p->>'title', '')), '');
    if v_titel is null then continue; end if;
    if length(v_titel) > 60 then v_titel := left(v_titel, 60); end if;
    v_plaetze := greatest(1, least(10, coalesce((p->>'plaetze')::int, 2)));
    v_behalten := v_behalten || v_titel;

    if exists (select 1 from public.duty_task_template_items
                where template_id = target_template and title = v_titel) then
      update public.duty_task_template_items
         set plaetze = v_plaetze, sort_order = v_sortierung
       where template_id = target_template and title = v_titel;
    else
      insert into public.duty_task_template_items (template_id, title, sort_order, plaetze)
      values (target_template, v_titel, v_sortierung, v_plaetze);
    end if;
    v_sortierung := v_sortierung + 1;
  end loop;

  select coalesce(array_agg(title), '{}') into v_weg
    from public.duty_task_template_items
   where template_id = target_template and not (title = any(v_behalten));

  delete from public.duty_task_template_items
   where template_id = target_template and title = any(v_weg);

  /* Ohne distinct: Die Unterabfrage nennt jeden Termin einmal, auch wenn er
     sechs Spur-Zeilen desselben Sets traegt. Erst dadurch ist die Sperre
     erlaubt - siehe Kopf. Feste Reihenfolge, damit zwei gleichzeitige
     Speicherungen die Termine nicht ueber Kreuz sperren. */
  for ev in
    select e.id, coalesce(e.helper_slots, '{}'::text[]) as slots,
           coalesce(e.helper_caps, '{}'::jsonb) as caps
      from public.events e
     where e.id in (select q.event_id from public.event_duty_station_source q
                     where q.template_id = target_template)
       and e.club_id = v_club
       and e.starts_at >= now() and e.status = 'scheduled'
     order by e.id
     for update
  loop
    v_spiele := v_spiele + 1;

    declare
      i record;
      neue_slots text[] := ev.slots;
      neue_caps jsonb := ev.caps;
      frisch boolean;
    begin
      for i in select title, greatest(1, least(10, coalesce(plaetze, 2))) as plaetze
                 from public.duty_task_template_items where template_id = target_template
      loop
        frisch := not (i.title = any(neue_slots));
        if frisch then
          neue_slots := neue_slots || i.title;
          v_neu := v_neu + 1;
          insert into public.event_duty_station_source (event_id, station, template_id)
          values (ev.id, i.title, target_template)
          on conflict (event_id, station) do update set template_id = excluded.template_id;
        end if;
        if exists (select 1 from public.event_duty_station_source q2
                    where q2.event_id = ev.id and q2.station = i.title and q2.template_id = target_template)
           and public.helferstation_plaetze(neue_caps, i.title) is distinct from i.plaetze then
          neue_caps := neue_caps || jsonb_build_object(i.title, i.plaetze);
          if not frisch then v_geaendert := v_geaendert + 1; end if;
        end if;
      end loop;

      declare g text;
      begin
        foreach g in array v_weg loop
          if exists (select 1 from public.event_duty_station_source q3
                      where q3.event_id = ev.id and q3.station = g and q3.template_id = target_template) then
            if exists (select 1 from public.duty_assignments d
                        where d.event_id = ev.id and d.station = g) then
              delete from public.event_duty_station_source
               where event_id = ev.id and station = g;
              v_behalten_wegen := v_behalten_wegen + 1;
            else
              if g = any(neue_slots) then v_entfernt := v_entfernt + 1; end if;
              neue_slots := array_remove(neue_slots, g);
              neue_caps := neue_caps - g;
              delete from public.event_duty_station_source
               where event_id = ev.id and station = g;
            end if;
          end if;
        end loop;
      end;

      update public.events
         set helper_slots = neue_slots, helper_caps = neue_caps, updated_at = now()
       where id = ev.id;
    end;
  end loop;

  return jsonb_build_object(
    'spiele', v_spiele, 'stationen_neu', v_neu, 'plaetze_geaendert', v_geaendert,
    'stationen_entfernt', v_entfernt, 'stationen_behalten', v_behalten_wegen);
end;
$function$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: ohne_distinct = true, mit_sperre = true, prueft_verein = true.
-- Der eigentliche Nachweis steht NICHT hier, sondern im Nachspielen gegen
-- PROD: Ob die Funktion laeuft, sieht man nur, wenn man sie laufen laesst.
select
  (select pg_get_functiondef(p.oid) not like '%select distinct e.id%'
     from pg_proc p where p.proname = 'helferset_speichern') as ohne_distinct,
  (select pg_get_functiondef(p.oid) like '%for update%'
     from pg_proc p where p.proname = 'helferset_speichern') as mit_sperre,
  (select pg_get_functiondef(p.oid) like '%e.club_id = v_club%'
     from pg_proc p where p.proname = 'helferset_speichern') as prueft_verein;
