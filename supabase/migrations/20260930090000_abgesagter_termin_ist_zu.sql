-- Ziel im Repo: supabase/migrations/20260930090000_abgesagter_termin_ist_zu.sql
--
-- Ein abgesagter Termin nimmt nichts mehr an.
--
-- WUNSCH DES BETREIBERS (30.09.2026): "Wenn ein Spiel oder ein weiteres
-- Ereignis abgesagt wurde, soll dieses Ereignis keine weiteren Aktionen mehr
-- erlauben."
--
-- WAS BISHER GALT
-- Die Absage war eine Sache der Oberflaeche. Geprueft am 30.09.2026: KEINE
-- EINZIGE Zeilenregel nennt 'cancelled'. Die App blendet bei einem abgesagten
-- Termin die Zusage und die Ergebnismeldung aus - aber nicht die
-- Fahrgemeinschaft, nicht die Helferdienste und nicht die Stationsverwaltung.
-- Und was die App ausblendet, verbietet die Datenbank trotzdem nicht: Ein
-- gewoehnlicher Aufruf an PostgREST ging durch.
-- Damit stand die Absage nur als Hinweis da. Wer den Termin offen hatte,
-- konnte sich weiter fuer einen Helferdienst eintragen, der nie stattfindet.
--
-- WAS JETZT GILT
-- Ein Waechter vor dem Schreiben, an den vier Tabellen, die eine Handlung am
-- Termin festhalten: event_attendance (Zu- und Absagen), carpools und
-- carpool_passengers (Fahrgemeinschaften), duty_assignments (Helferdienste)
-- und predictions (Tipps). Dazu die drei Funktionen, die Stationen pflegen.
--
-- WARUM NUR ANLEGEN UND AENDERN, NICHT LOESCHEN
-- Das Loeschen bleibt ausdruecklich erlaubt. Wer einen Termin absagt, muss
-- aufraeumen koennen - Eintragungen entfernen, eine Fahrgemeinschaft
-- zuruecknehmen, eine Station abraeumen. Wuerde der Waechter auch das
-- verbieten, waere der Bestand eines abgesagten Termins fuer immer
-- eingefroren, und remove_duty_station liefe ins Leere. "Keine weiteren
-- Aktionen" heisst: nichts Neues, nichts Geaendertes - nicht: nichts
-- Aufraeumbares.
--
-- WARUM EIN AUSLOESER UND NICHT VIER GEAENDERTE REGELN
-- Die vier Tabellen haben zusammen zehn Zeilenregeln, jede mit eigener
-- Bedingung. Jede davon um " and nicht abgesagt" zu erweitern hiesse, zehn
-- Stellen richtig zu treffen - und bei der naechsten neuen Regel die elfte zu
-- vergessen. Ein Auslöser vor dem Schreiben gilt unabhaengig davon, welche
-- Regel den Zugriff erlaubt hat, und auch fuer Funktionen, die als security
-- definer an den Regeln vorbeischreiben.
--
-- Geprueft am 30.09.2026 (nur lesend, PROD): 2 abgesagte Termine, beide in der
-- Vergangenheit, keine Eintragungen und keine Zusagen daran. Der Waechter
-- sperrt also heute nichts aus, was schon dasteht.
--
-- MUSS ZUSAMMEN MIT DER APP AUSGELIEFERT WERDEN: Ohne die ausgeblendeten
-- Knoepfe laufen Fahrgemeinschaft und Helferdienst in eine Fehlermeldung,
-- statt gar nicht erst angeboten zu werden.

create or replace function public.termin_abgesagt_sperren()
returns trigger
language plpgsql security definer set search_path to '' as $function$
declare
  v_event uuid;
begin
  /* Die vier Tabellen tragen die Kennung des Termins unterschiedlich: drei
     direkt, die Mitfahrer ueber die Fahrgemeinschaft. */
  if tg_table_name = 'carpool_passengers' then
    select c.event_id into v_event from public.carpools c where c.id = new.carpool_id;
  else
    v_event := new.event_id;
  end if;

  if v_event is not null and exists (
       select 1 from public.events e where e.id = v_event and e.status = 'cancelled') then
    raise exception 'Dieser Termin wurde abgesagt'
      using errcode = '23514', hint = 'cancelled_event';
  end if;

  return new;
end;
$function$;

comment on function public.termin_abgesagt_sperren() is
  'Weist Neuanlagen und Aenderungen zurueck, die an einem abgesagten Termin haengen. Loeschen bleibt erlaubt, damit die Leitung aufraeumen kann.';

do $$
declare
  tabelle text;
begin
  foreach tabelle in array array['event_attendance', 'carpools', 'carpool_passengers',
                                 'duty_assignments', 'predictions']
  loop
    execute format('drop trigger if exists %I on public.%I',
                   tabelle || '_abgesagt_sperren', tabelle);
    execute format('create trigger %I before insert or update on public.%I
                    for each row execute function public.termin_abgesagt_sperren()',
                   tabelle || '_abgesagt_sperren', tabelle);
  end loop;
end $$;

-- ------------------------------------------------- Die Stationen am Termin
/* add_duty_station, set_duty_station_plaetze und apply_duty_template laufen
   als security definer - sie kaemen an den Zeilenregeln vorbei und fassen
   events selbst an, nicht die Tabellen mit dem Auslöser. Sie brauchen die
   Pruefung deshalb im Rumpf. remove_duty_station und clear_duty_stations
   bleiben bewusst offen: Das ist Aufraeumen. */
create or replace function public.termin_ist_abgesagt(target_event uuid)
returns boolean
language sql stable security definer set search_path to '' as $function$
  select exists (select 1 from public.events e
                  where e.id = target_event and e.status = 'cancelled');
$function$;

revoke all on function public.termin_ist_abgesagt(uuid) from public, anon;
grant execute on function public.termin_ist_abgesagt(uuid) to authenticated;

/* Die drei Schreibwege an den Stationen. Sie fassen events selbst an, nicht
   die Tabellen mit dem Auslöser - die Pruefung muss deshalb in den Rumpf.
   Geaendert ist jeweils NUR die eine neue Zeile; der Rest steht Wort fuer Wort
   wie zuvor. */
create or replace function public.add_duty_station(target_event uuid, station_name text, plaetze integer default 2)
returns integer
language plpgsql security definer set search_path to '' as $function$
declare
  v_name      text := btrim(coalesce(station_name, ''));
  v_plaetze   integer := greatest(1, least(10, coalesce(plaetze, 2)));
  v_stationen text[];
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;
  if public.termin_ist_abgesagt(target_event) then
    raise exception 'Dieser Termin wurde abgesagt' using errcode = '23514', hint = 'cancelled_event';
  end if;
  if v_name = '' then raise exception 'station_leer' using errcode = 'P0001'; end if;
  v_name := left(v_name, 60);

  select coalesce(e.helper_slots, '{}'::text[]) into v_stationen
    from public.events e where e.id = target_event for update;
  if not found then raise exception 'termin_fehlt' using errcode = 'P0001'; end if;

  /* Gross- und Kleinschreibung zaehlt hier nicht: "Grill" und "grill" waeren
     zwei Zeilen im Plan, die niemand auseinanderhalten kann. */
  if exists (select 1 from unnest(v_stationen) s where lower(btrim(s)) = lower(v_name)) then
    raise exception 'station_schon_da' using errcode = 'P0001';
  end if;
  if coalesce(array_length(v_stationen, 1), 0) >= 12 then
    raise exception 'zu_viele_stationen' using errcode = 'P0001';
  end if;

  update public.events
     set helper_slots = coalesce(helper_slots, '{}'::text[]) || v_name,
         helper_caps  = coalesce(helper_caps, '{}'::jsonb) || jsonb_build_object(v_name, v_plaetze),
         updated_at   = now()
   where id = target_event;

  return coalesce(array_length(v_stationen, 1), 0) + 1;
end;
$function$;

create or replace function public.set_duty_station_plaetze(target_event uuid, station_name text, plaetze integer)
returns integer
language plpgsql security definer set search_path to '' as $function$
declare
  v_plaetze   integer := greatest(1, least(10, coalesce(plaetze, 2)));
  v_stationen text[];
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;
  if public.termin_ist_abgesagt(target_event) then
    raise exception 'Dieser Termin wurde abgesagt' using errcode = '23514', hint = 'cancelled_event';
  end if;

  select coalesce(e.helper_slots, '{}'::text[]) into v_stationen
    from public.events e where e.id = target_event for update;
  if not found then raise exception 'termin_fehlt' using errcode = 'P0001'; end if;
  if not (station_name = any(v_stationen)) then
    raise exception 'station_unbekannt' using errcode = 'P0001';
  end if;

  update public.events
     set helper_caps = coalesce(helper_caps, '{}'::jsonb) || jsonb_build_object(station_name, v_plaetze),
         updated_at  = now()
   where id = target_event;

  return v_plaetze;
end;
$function$;

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
  if public.termin_ist_abgesagt(target_event) then
    raise exception 'Dieser Termin wurde abgesagt' using errcode = '23514', hint = 'cancelled_event';
  end if;

  select club_id, coalesce(helper_slots, '{}'::text[]) into ev_club, v_vorher
    from public.events where id = target_event for update;
  if ev_club is null then return 0; end if;

  /* Das Set muss zum Verein des Termins gehoeren - siehe 20260928120000. */
  if not exists (select 1 from public.duty_task_templates t
                  where t.id = target_template and t.club_id = ev_club) then
    raise exception 'Template belongs to a different club' using errcode = '42501';
  end if;

  select coalesce(array_agg(i.title order by i.sort_order), '{}'::text[]),
         coalesce(jsonb_object_agg(i.title, greatest(1, least(10, coalesce(i.plaetze, 2)))), '{}'::jsonb)
    into v_neu, v_neue_caps
    from public.duty_task_template_items i
   where i.template_id = target_template
     and not (i.title = any(v_vorher));

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

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: waechter_da = 1, ausloeser = 5, nur_vor_dem_schreiben = true,
-- loeschen_bleibt_offen = true, hilfsfunktion_da = 1, stationen_pruefen = 3.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'termin_abgesagt_sperren') as waechter_da,
  (select count(*) from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%_abgesagt_sperren') as ausloeser,
  /* Im Klartext statt in Bits. Der erste Versuch rechnete mit falschen
     Werten (Bit 4 ist INSERT, nicht DELETE) und meldete deshalb
     "loeschen_bleibt_offen = false", obwohl alle fuenf Ausloeser sauber auf
     BEFORE INSERT OR UPDATE stehen. Eine Kontrolle, die man erst entziffern
     muss, taugt nichts. */
  (select bool_and(pg_get_triggerdef(t.oid) like '%BEFORE INSERT OR UPDATE%')
     from pg_trigger t where not t.tgisinternal and t.tgname like '%_abgesagt_sperren') as nur_vor_dem_schreiben,
  (select bool_and(pg_get_triggerdef(t.oid) not like '%DELETE%')
     from pg_trigger t where not t.tgisinternal and t.tgname like '%_abgesagt_sperren') as loeschen_bleibt_offen,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'termin_ist_abgesagt') as hilfsfunktion_da,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('add_duty_station', 'set_duty_station_plaetze', 'apply_duty_template')
      and pg_get_functiondef(p.oid) like '%termin_ist_abgesagt%') as stationen_pruefen;
