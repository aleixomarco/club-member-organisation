-- Ziel im Repo: supabase/migrations/20260928140000_entfernte_station_bleibt_entfernt.sql
--
-- Eine von Hand entfernte Station bleibt entfernt.
--
-- WAS NOCH FEHLTE
-- 20260928120000 hat dafuer gesorgt, dass remove_duty_station die
-- Herkunftsspur mit abraeumt. Beim Nachspielen gegen PROD kam die Station
-- trotzdem zurueck:
--   2 nach Entfernen      Stationen=5, Spuren=5      (richtig)
--   3 nach Set-Speichern  Station wieder da: true    (falsch)
-- Der Grund liegt eine Ebene tiefer. Der Abgleich legt JEDEN Posten des Sets
-- an, der am Termin fehlt - er fragt nur "steht die Station schon in
-- helper_slots?". Eine eben entfernte Station steht dort nicht, also gilt sie
-- als neu und wird wieder angelegt. Das Abraeumen der Spur allein reicht
-- nicht; es macht die Unterscheidung erst MOEGLICH, benutzt wird sie noch
-- nicht.
--
-- DIE UNTERSCHEIDUNG
-- Zwei Faelle sehen gleich aus - "Posten im Set, Station nicht am Termin" -
-- und muessen verschieden behandelt werden:
--   (a) Der Posten ist NEU ins Set gekommen. Dann soll er ueberall dazu.
--       Genau dafuer gibt es den Abgleich.
--   (b) Der Posten war schon da, und an DIESEM Termin hat die Leitung die
--       Station entfernt. Dann soll sie entfernt bleiben. Wer eine Station
--       wegnimmt, hat einen Grund - an diesem Spieltag gibt es keinen Kiosk.
-- Unterscheiden laesst sich das, seit die Spur beim Entfernen mit
-- verschwindet: Fehlt die Spur UND war der Posten schon vorher im Set, ist es
-- Fall (b).
--
-- Deshalb merkt sich die Funktion jetzt, welche Posten das Set VOR dieser
-- Speicherung hatte, und legt eine Station nur dann an, wenn der Posten neu
-- ist oder die Spur noch steht.
--
-- WAS DAS FUER DEN BETREIBER HEISST
-- Eine zentral geloeschte Station verschwindet weiterhin ueberall (ausser wo
-- jemand eingeteilt ist). Ein zentral hinzugefuegter Posten kommt weiterhin
-- ueberall dazu. Neu ist nur: Eine oertlich entfernte Station holt der
-- Abgleich nicht mehr zurueck. Will man sie doch wiederhaben, legt man sie am
-- Termin von Hand an oder wendet das Set dort neu an.

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
  v_vorher_posten text[];
  ev record;
  v_spiele int := 0;
  v_neu int := 0;
  v_geaendert int := 0;
  v_entfernt int := 0;
  v_behalten_wegen int := 0;
  v_uebergangen int := 0;
  v_sortierung int := 0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select club_id into v_club from public.duty_task_templates where id = target_template;
  if v_club is null then raise exception 'Template not found'; end if;
  if not public.can_manage_duty_templates(v_club) then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;
  if jsonb_typeof(posten) <> 'array' then raise exception 'Posten must be an array'; end if;

  /* Der Stand VOR dieser Speicherung - die Grundlage der Unterscheidung oben.
     Muss vor dem Schreiben gelesen werden, sonst sind alle Posten "alt". */
  select coalesce(array_agg(title), '{}') into v_vorher_posten
    from public.duty_task_template_items where template_id = target_template;

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
      hat_spur boolean;
      posten_neu boolean;
    begin
      for i in select title, greatest(1, least(10, coalesce(plaetze, 2))) as plaetze
                 from public.duty_task_template_items where template_id = target_template
      loop
        frisch := not (i.title = any(neue_slots));
        hat_spur := exists (select 1 from public.event_duty_station_source q2
                             where q2.event_id = ev.id and q2.station = i.title
                               and q2.template_id = target_template);
        posten_neu := not (i.title = any(v_vorher_posten));

        if frisch then
          if posten_neu or hat_spur then
            neue_slots := neue_slots || i.title;
            v_neu := v_neu + 1;
            insert into public.event_duty_station_source (event_id, station, template_id)
            values (ev.id, i.title, target_template)
            on conflict (event_id, station) do update set template_id = excluded.template_id;
            hat_spur := true;
          else
            /* Fall (b): Die Station wurde an diesem Termin bewusst entfernt.
               Sie bleibt weg, und der Betreiber erfaehrt in der Rueckmeldung,
               dass es sie gab. */
            v_uebergangen := v_uebergangen + 1;
            continue;
          end if;
        end if;

        if hat_spur
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
    'stationen_entfernt', v_entfernt, 'stationen_behalten', v_behalten_wegen,
    'stationen_uebergangen', v_uebergangen);
end;
$function$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: kennt_vorherige_posten = true, kennt_uebergangen = true.
-- Der eigentliche Nachweis ist das Nachspielen gegen PROD: Station am Termin
-- entfernen, Set speichern, Station bleibt weg.
select
  (select pg_get_functiondef(p.oid) like '%v_vorher_posten%'
     from pg_proc p where p.proname = 'helferset_speichern') as kennt_vorherige_posten,
  (select pg_get_functiondef(p.oid) like '%stationen_uebergangen%'
     from pg_proc p where p.proname = 'helferset_speichern') as kennt_uebergangen;
