-- Ziel im Repo: supabase/migrations/20260928040000_helferset_zahlen_ehrlich.sql
--
-- Die Rueckmeldung von helferset_speichern zaehlte eine Station doppelt.
--
-- BEIM DURCHSPIELEN GEGEN PROD (27.09.2026, in einer zurueckgenommenen
-- Transaktion) meldete der Abgleich fuer zehn Spiele:
--   {"spiele": 10, "stationen_neu": 10, "plaetze_geaendert": 20, ...}
-- Zwanzig Platzaenderungen bei zehn Spielen, obwohl nur EINE Platzzahl
-- geaendert wurde. Der Grund: Eine frisch angelegte Station hat am Termin noch
-- keinen Eintrag in helper_caps. helferstation_plaetze liefert dafuer die
-- Vorgabe zwei, das weicht von der Platzzahl des Postens ab - und die Schleife
-- zaehlte das als Aenderung, obwohl die Station im selben Durchgang gerade
-- erst entstanden ist. Sie steckte damit zweimal in der Meldung: einmal unter
-- stationen_neu und einmal unter plaetze_geaendert.
--
-- WARUM DAS NICHT EGAL IST
-- Diese Zahlen gehen in die Rueckfrage vor dem Speichern - "an 10 Spielen
-- werden 20 Platzzahlen geaendert". Wer daraufhin nachsieht und zehn findet,
-- glaubt der naechsten Zahl nicht mehr. Eine Warnung ist nur so viel wert wie
-- ihre Genauigkeit.
--
-- Geaendert ist ausschliesslich die Zaehlung. Was die Funktion an den Terminen
-- TUT, bleibt Zeile fuer Zeile dasselbe - die Platzzahl der neuen Station wird
-- weiterhin gesetzt, sie wird nur nicht mehr als Aenderung mitgezaehlt.

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

  -- ---------- 1. Das Set selbst
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

  -- ---------- 2. Der Abgleich an den Terminen
  for ev in
    select distinct e.id, coalesce(e.helper_slots, '{}'::text[]) as slots,
           coalesce(e.helper_caps, '{}'::jsonb) as caps
      from public.event_duty_station_source q
      join public.events e on e.id = q.event_id
     where q.template_id = target_template
       and e.starts_at >= now() and e.status = 'scheduled'
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
          /* Nur zaehlen, wenn die Station vorher schon dastand. Eine gerade
             erst angelegte steckt bereits in stationen_neu - sie ein zweites
             Mal zu melden, macht die Rueckfrage unglaubwuerdig. */
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
              neue_slots := array_remove(neue_slots, g);
              neue_caps := neue_caps - g;
              delete from public.event_duty_station_source
               where event_id = ev.id and station = g;
              v_entfernt := v_entfernt + 1;
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
-- Erwartet: kennt_frisch = true, zaehlt_nur_bestehende = true.
select
  (select pg_get_functiondef(p.oid) like '%frisch boolean%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'helferset_speichern') as kennt_frisch,
  (select pg_get_functiondef(p.oid) like '%if not frisch then v_geaendert%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'helferset_speichern') as zaehlt_nur_bestehende;
