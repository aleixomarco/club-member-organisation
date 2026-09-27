-- Ziel im Repo: supabase/migrations/20260928030000_helferset_synchronisieren.sql
--
-- Aendert man ein Helferset zentral, aendern sich die schon belegten Spieltage mit.
--
-- WUNSCH DES BETREIBERS (27.09.2026): "Wenn man die Helfersets zentral
-- abaendert - z. B. die Anzahl der benoetigten Personen -, sollen diese
-- Aenderungen auch auf alle bereits bestehenden Datensaetze synchronisiert
-- werden. Beispiel: Helferset A wurde bei 13 Spielen angelegt und wird dann
-- zentral angepasst, eine Station braucht eine Person mehr oder wird
-- geloescht - dann muss das direkt bei den bereits eingeteilten Sets auch
-- synchronisiert werden."
--
-- DAS HINDERNIS: ES GAB KEINE SPUR
-- apply_duty_template kopierte die Stationsnamen in events.helper_slots und
-- die Platzzahlen in events.helper_caps - und vergass, woher sie kamen. Kein
-- Termin wusste, welches Set auf ihn angewendet worden war. Ohne diese Spur
-- gibt es nichts zu synchronisieren.
--
-- WARUM EINE EIGENE TABELLE UND NICHT DIE HERKUNFT IN helper_caps
-- Naheliegend waere gewesen, aus {"Grill": 4} ein {"Grill": {"plaetze": 4,
-- "set": "..."}} zu machen. Dagegen sprechen zwei Dinge, beide am 27.09.2026
-- geprueft: helper_caps hat NEUN Leser (acht Funktionen in der Datenbank,
-- einen in der App), und beide Entschluessler - helferstation_plaetze und
-- plaetzeFuer - fallen bei einer unbekannten Form STILL auf zwei Plaetze
-- zurueck, statt zu scheitern. Ein vergessener Leser haette also keinen Fehler
-- gezeigt, sondern falsche Platzzahlen. Eine Tabelle daneben laesst alle neun
-- unberuehrt.
--
-- WAS DIE SPUR BEDEUTET
-- Steht eine Station in event_duty_station_source, kam sie aus einem Set und
-- wird mitgezogen. Steht sie NICHT darin, hat jemand sie von Hand angelegt -
-- dann wird sie beim Abgleich nie angefasst. Genau das ist der Grund, warum
-- die Spur je STATION gefuehrt wird und nicht je Termin: An einem Termin
-- koennen Stationen aus einem Set und von Hand nebeneinanderstehen.
--
-- DIE REGELN DES ABGLEICHS (vom Betreiber so entschieden)
--   Platzzahl geaendert  -> am Termin uebernehmen
--   Posten neu           -> Station am Termin anlegen
--   Posten geloescht     -> Station verschwindet NUR, wo niemand eingetragen
--                           ist. Wo jemand steht, bleibt sie - und gilt von da
--                           an als von Hand angelegt. Niemandem wird sein
--                           Dienst unter den Fuessen weggezogen.
--   Platzzahl kleiner als die Zahl der Eingetragenen -> niemand fliegt raus,
--                           die Station ist dann ueberbelegt und zeigt "3/2".
--   Betroffen sind nur kuenftige, nicht abgesagte Termine.
--
-- ALTBESTAND (27.09.2026 lesend geprueft)
-- 13 Termine mit Stationen bei ERG Iserlohn. Die Zuordnung wird nur dort
-- nachgetragen, wo sie EINDEUTIG ist: alle Posten des Sets stehen am Termin
-- UND jede Platzzahl stimmt ueberein. Das trifft 10 Termine bei "Heimspiel
-- Jugend" und 1 bei "Standard Heimspiel". Die uebrigen 2 tragen dieselben
-- Namen, aber von Hand geaenderte Platzzahlen - dort waere jede Zuordnung
-- geraten, und ein Abgleich wuerde die Handarbeit ueberschreiben. Sie bleiben
-- bewusst ohne Spur, bis jemand das Set dort bewusst neu anwendet.
--
-- MUSS ZUSAMMEN MIT DER APP AUSGELIEFERT WERDEN: Ohne den Entwurfszustand im
-- Set-Editor gibt es keinen Moment, an dem die Rueckfrage erscheinen koennte.

-- ------------------------------------------------- Die Spur
create table if not exists public.event_duty_station_source (
  event_id    uuid not null references public.events(id) on delete cascade,
  station     text not null,
  template_id uuid not null references public.duty_task_templates(id) on delete cascade,
  gesetzt_am  timestamptz not null default now(),
  primary key (event_id, station)
);

comment on table public.event_duty_station_source is
  'Woher eine Helferstation an einem Termin stammt. Vorhanden = aus einem Set uebernommen und wird beim zentralen Aendern mitgezogen. Fehlt = von Hand angelegt und wird nie automatisch angefasst.';

alter table public.event_duty_station_source enable row level security;

drop policy if exists "members read station source" on public.event_duty_station_source;
create policy "members read station source" on public.event_duty_station_source
  for select using (
    exists (select 1 from public.events e
             where e.id = event_duty_station_source.event_id and public.is_club_member(e.club_id)));

/* Geschrieben wird ausschliesslich durch die Funktionen unten, die als
   security definer laufen. Eine Schreibregel fuer authenticated gibt es
   bewusst nicht: Die Spur von Hand zu setzen haette keinen Sinn und koennte
   einen Abgleich auf Stationen loslassen, die niemand aus einem Set hat. */

create index if not exists event_duty_station_source_template
  on public.event_duty_station_source (template_id);

-- ------------------------------------------------- Satz anwenden legt die Spur
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

  /* Die Spur wird fuer ALLE Posten des Satzes gelegt, auch fuer die, die schon
     dastanden: Sie stammen ab jetzt aus diesem Satz und sollen mitgezogen
     werden. Ein zweites Anwenden desselben Satzes traegt also nichts nach,
     legt aber die Spur nach - genau das braucht man, um Altbestand
     nachtraeglich anzubinden. */
  insert into public.event_duty_station_source (event_id, station, template_id)
  select target_event, i.title, target_template
    from public.duty_task_template_items i
   where i.template_id = target_template
     and (i.title = any(v_vorher) or i.title = any(v_neu))
  on conflict (event_id, station) do update set template_id = excluded.template_id, gesetzt_am = now();

  if cardinality(v_neu) = 0 then return 0; end if;

  update public.events e
     set helper_slots = coalesce(e.helper_slots, '{}'::text[]) || v_neu,
         helper_caps  = coalesce(e.helper_caps, '{}'::jsonb) || v_neue_caps,
         updated_at   = now()
   where e.id = target_event;

  return cardinality(v_neu);
end;
$function$;

-- ------------------------------------------------- Altbestand nachtragen
/* Nur das Eindeutige - siehe Kopf. Die Bedingung verlangt beides: alle Posten
   stehen am Termin UND jede Platzzahl stimmt. */
insert into public.event_duty_station_source (event_id, station, template_id)
select e.id, i.title, t.id
  from public.events e
  join public.duty_task_templates t on t.club_id = e.club_id
  join public.duty_task_template_items i on i.template_id = t.id
 where cardinality(coalesce(e.helper_slots, '{}'::text[])) > 0
   and not exists (select 1 from public.duty_task_template_items i2
                    where i2.template_id = t.id
                      and not (i2.title = any(coalesce(e.helper_slots, '{}'::text[]))))
   and not exists (select 1 from public.duty_task_template_items i3
                    where i3.template_id = t.id
                      and public.helferstation_plaetze(coalesce(e.helper_caps, '{}'::jsonb), i3.title)
                          is distinct from greatest(1, least(10, coalesce(i3.plaetze, 2))))
on conflict (event_id, station) do nothing;

-- ------------------------------------------------- Wird das Set schon benutzt?
create or replace function public.helferset_nutzung(target_template uuid)
returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare
  v_club uuid;
  ergebnis jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select club_id into v_club from public.duty_task_templates where id = target_template;
  if v_club is null then raise exception 'Template not found'; end if;
  if not public.can_manage_duty_templates(v_club) then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;

  select jsonb_build_object(
    'spiele', count(distinct e.id),
    'eintragungen', coalesce(sum((select count(*) from public.duty_assignments d
                                   where d.event_id = e.id and d.station = q.station)), 0)
  ) into ergebnis
    from public.event_duty_station_source q
    join public.events e on e.id = q.event_id
   where q.template_id = target_template
     and e.starts_at >= now() and e.status = 'scheduled';

  return coalesce(ergebnis, jsonb_build_object('spiele', 0, 'eintragungen', 0));
end;
$function$;

revoke all on function public.helferset_nutzung(uuid) from public, anon;
grant execute on function public.helferset_nutzung(uuid) to authenticated;

comment on function public.helferset_nutzung(uuid) is
  'Wie viele kuenftige, nicht abgesagte Termine benutzen dieses Helferset, und wie viele Eintragungen haengen an dessen Stationen. Grundlage fuer die Rueckfrage vor dem Speichern. Aendert nichts.';

-- ------------------------------------------------- Speichern samt Abgleich
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

    /* Neue Posten dazu, Platzzahlen nachziehen. Angefasst wird nur, was laut
       Spur aus DIESEM Satz stammt - eine von Hand angelegte Station gleichen
       Namens bliebe unberuehrt. */
    declare
      i record;
      neue_slots text[] := ev.slots;
      neue_caps jsonb := ev.caps;
    begin
      for i in select title, greatest(1, least(10, coalesce(plaetze, 2))) as plaetze
                 from public.duty_task_template_items where template_id = target_template
      loop
        if not (i.title = any(neue_slots)) then
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
          v_geaendert := v_geaendert + 1;
        end if;
      end loop;

      /* Geloeschte Posten: nur dort weg, wo niemand eingetragen ist. */
      declare g text;
      begin
        foreach g in array v_weg loop
          if exists (select 1 from public.event_duty_station_source q3
                      where q3.event_id = ev.id and q3.station = g and q3.template_id = target_template) then
            if exists (select 1 from public.duty_assignments d
                        where d.event_id = ev.id and d.station = g) then
              /* Jemand steht dort - Station bleibt und gilt ab jetzt als von
                 Hand angelegt. */
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

revoke all on function public.helferset_speichern(uuid, jsonb) from public, anon;
grant execute on function public.helferset_speichern(uuid, jsonb) to authenticated;

comment on function public.helferset_speichern(uuid, jsonb) is
  'Speichert ein Helferset als Ganzes und zieht die Aenderung an allen kuenftigen, nicht abgesagten Terminen nach, die es benutzen. Eine geloeschte Station verschwindet nur dort, wo niemand eingetragen ist; wo jemand steht, bleibt sie und gilt fortan als von Hand angelegt. Niemand wird ausgetragen.';

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: spur_tabelle = 1, spur_erklaert = 1, anwenden_legt_spur = true,
-- nutzung_da = 1, speichern_da = 1, nachgetragen_jugend = 10,
-- nachgetragen_standard = 1, termine_ohne_spur = 5.
-- Die 5 sind: 2 Termine mit den Namen von "Standard Heimspiel", aber von
-- Hand geaenderten Platzzahlen (dort waere jede Zuordnung geraten), und 3
-- Termine bei SV Musterstadt, wo es ueberhaupt kein Set gibt. Vorab lesend
-- ermittelt: 16 Termine mit Stationen, 11 eindeutig zuordenbar.
select
  (select count(*) from information_schema.tables
    where table_schema='public' and table_name='event_duty_station_source') as spur_tabelle,
  (select count(*) from pg_description d join pg_class c on c.oid=d.objoid
    where c.relname='event_duty_station_source' and d.objsubid=0) as spur_erklaert,
  (select pg_get_functiondef(p.oid) like '%event_duty_station_source%'
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='apply_duty_template') as anwenden_legt_spur,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='helferset_nutzung') as nutzung_da,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='helferset_speichern') as speichern_da,
  (select count(distinct q.event_id) from public.event_duty_station_source q
     join public.duty_task_templates t on t.id=q.template_id where t.name='Heimspiel Jugend') as nachgetragen_jugend,
  (select count(distinct q.event_id) from public.event_duty_station_source q
     join public.duty_task_templates t on t.id=q.template_id where t.name='Standard Heimspiel') as nachgetragen_standard,
  (select count(*) from public.events e
    where cardinality(coalesce(e.helper_slots,'{}'::text[])) > 0
      and not exists (select 1 from public.event_duty_station_source q where q.event_id=e.id)) as termine_ohne_spur;
