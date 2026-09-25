-- Ziel im Repo: supabase/migrations/20260926100000_helferstationen_plaetze.sql
--
-- Zwei Dinge, die am Helferplan fehlten:
--   1. Eine einzelne Station an einem BESTEHENDEN Termin ergaenzen.
--   2. Festlegen, wie viele Personen an eine Station passen.
--
-- ZU 1: Stationen entstanden bisher nur beim Anlegen eines Einzeltermins
-- (Komma-Feld im Formular) oder indem man einen ganzen Satz vorlud
-- (apply_duty_template). Wieder wegnehmen ging einzeln (remove_duty_station),
-- dazulegen nicht - ein Rueckweg ohne Hinweg. Wer am Spieltag merkt, dass noch
-- jemand die Kasse machen muss, musste einen Satz auflegen oder den Termin neu
-- anlegen. add_duty_station schliesst die Luecke, als Gegenstueck zu
-- remove_duty_station und mit derselben Rechtepruefung (can_manage_duty_task).
--
-- ZU 2: Wie viele Leute an eine Station passen, stand als feste Zwei an drei
-- Stellen: STATION_CAP in app/page.tsx, der Auslöser
-- helferdienst_eintrag_pruefen (20260914110400) und die Anzeige "0/2". Fuer
-- einen Grillstand sind zwei Leute wenig und fuer die Zeitnahme einer zu viel.
--
-- WARUM EINE SPALTE UND KEINE NEUE TABELLE
-- events.helper_slots ist ein text[] - dort ist kein Platz fuer eine Zahl. Die
-- Zahl in den Namen zu schreiben ("Grill|4") haette jeden Stationsnamen
-- angefasst, der ein Sonderzeichen enthaelt. Eine eigene Tabelle waere der
-- schwerere Weg: Sie muesste bei jedem Anlegen, Entfernen und Leeren
-- mitgefuehrt werden, und jede Abfrage, die heute helper_slots liest, braeuchte
-- einen Verbund. Eine zweite Spalte daneben kostet nichts und faellt niemandem
-- auf die Fuesse: Steht dort nichts, gilt weiter zwei.
--
-- helper_caps ist also eine Zuordnung Stationsname -> Anzahl, etwa
-- {"Grill": 4, "Zeitnahme": 1}. Fehlt ein Name, gilt die Vorgabe zwei; erlaubt
-- ist 1 bis 10.
--
-- Geprueft am 26.09.2026 (nur lesend, PROD): events hat keine Spalte
-- helper_caps, add_duty_station gibt es nicht, und der Auslöser vergleicht
-- gegen die feste Zahl 2.

alter table public.events add column if not exists helper_caps jsonb not null default '{}'::jsonb;

comment on column public.events.helper_caps is
  'Wie viele Personen an eine Helferstation passen: Stationsname -> Anzahl, z. B. {"Grill": 4}. Fehlt ein Name, gelten zwei Plaetze. Erlaubt sind 1 bis 10.';

/* Die Zahl zu einer Station - an einer Stelle, damit App, Auslöser und
   Funktionen nicht auseinanderlaufen. Nimmt die Zuordnung selbst entgegen und
   nicht die Termin-Kennung: So braucht der Auslöser keine zweite Abfrage.
   jsonb_typeof faengt ab, was kein Zahlenwert ist - ein ::integer auf einen
   Text wuerde die ganze Eintragung mit einem Fehler abbrechen. */
create or replace function public.helferstation_plaetze(caps jsonb, station_name text)
returns integer language sql immutable set search_path = '' as $$
  select greatest(1, least(10, coalesce(
           case when jsonb_typeof(caps -> station_name) = 'number'
                then (caps ->> station_name)::integer end, 2)));
$$;

comment on function public.helferstation_plaetze(jsonb, text) is
  'Plaetze einer Helferstation aus events.helper_caps; ohne Eintrag zwei, begrenzt auf 1 bis 10.';

-- ------------------------------------------------- Station dazulegen
/* Gibt die Zahl der Stationen am Termin zurueck - dieselbe Art von Antwort wie
   bei apply_duty_template, das die Zahl der uebernommenen Stationen liefert.
   Fehler kommen als Schluesselwort, damit die App einen eigenen Satz dafuer
   zeigen kann statt "hat nicht geklappt":
     station_leer        nichts eingetippt
     station_schon_da    die Station steht schon an diesem Termin
     zu_viele_stationen  zwoelf ist die Grenze, wie im Terminformular
     termin_fehlt        der Termin existiert nicht (mehr)
   KEINE Zeile in duty_tasks. Diese Liste war die zweite, inzwischen aus der
   Oberflaeche entfernte Helferliste (siehe 20260925210000); neue Karteileichen
   braucht sie nicht. remove_duty_station raeumt dort weiterhin auf, damit der
   Altbestand verschwindet. */
create or replace function public.add_duty_station(target_event uuid, station_name text, plaetze integer default 2)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_name      text := btrim(coalesce(station_name, ''));
  v_plaetze   integer := greatest(1, least(10, coalesce(plaetze, 2)));
  v_stationen text[];
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;
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
$$;

-- ------------------------------------------------- Plaetze aendern
/* Gibt die gesetzte Zahl zurueck. Wer die Zahl unter die Zahl der bereits
   Eingetragenen setzt, wirft niemanden hinaus - die Station ist dann voller
   als vorgesehen, und das sieht die Leitung in der Liste. Das ist die
   freundlichere Haelfte des Fehlers: Jemandem den Dienst stillschweigend zu
   streichen waere die andere. */
create or replace function public.set_duty_station_plaetze(target_event uuid, station_name text, plaetze integer)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_plaetze   integer := greatest(1, least(10, coalesce(plaetze, 2)));
  v_stationen text[];
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

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
$$;

-- ------------------------------------------------- Aufraeumen beim Entfernen
/* Unveraendert aus 20260905150000, bis auf eine Zeile: Mit der Station geht
   auch ihre Platzzahl. Bliebe sie stehen, bekaeme eine spaeter gleichnamige
   Station stillschweigend die alte Zahl. */
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

  delete from public.duty_assignments
   where event_id = target_event and station = station_name;
  get diagnostics v_eintragungen = row_count;

  delete from public.duty_tasks
   where event_id = target_event and title = station_name;

  update public.events
     set helper_slots = array_remove(helper_slots, station_name),
         helper_caps  = coalesce(helper_caps, '{}'::jsonb) - station_name,
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
         helper_caps  = '{}'::jsonb,
         updated_at = now()
   where id = target_event;

  return v_eintragungen;
end;
$$;

-- ------------------------------------------------- Der Riegel beim Eintragen
/* Unveraendert aus 20260914110400, bis auf die Platzzahl: Statt der festen
   Zwei gilt jetzt, was an der Station steht. Die Leitung bleibt wie bisher
   aussen vor - sie darf auch eine volle Station belegen, etwa wenn sie jemanden
   kurzfristig zusaetzlich einteilt. */
create or replace function public.helferdienst_eintrag_pruefen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_club      uuid;
  v_stationen text[];
  v_caps      jsonb;
  v_belegt    integer;
begin
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then return new; end if;

  select e.club_id, e.helper_slots, e.helper_caps into v_club, v_stationen, v_caps
    from public.events e where e.id = new.event_id for update;
  if v_club is null then return new; end if;

  if public.has_club_role(v_club, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[]) then
    return new;
  end if;

  if not (new.station = any(coalesce(v_stationen, '{}'::text[]))) then
    raise exception 'station_unbekannt' using errcode = 'P0001';
  end if;
  select count(*) into v_belegt
    from public.duty_assignments d
   where d.event_id = new.event_id and d.station = new.station;
  if v_belegt >= public.helferstation_plaetze(coalesce(v_caps, '{}'::jsonb), new.station) then
    raise exception 'voll' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.membership_roles r
              where r.membership_id = new.membership_id and r.role = 'fan')
     and not exists (select 1 from public.membership_roles r
                      where r.membership_id = new.membership_id and r.role <> 'fan') then
    raise exception 'fan_kein_helferdienst' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function public.helferstation_plaetze(jsonb, text) from public, anon;
revoke all on function public.add_duty_station(uuid, text, integer) from public, anon;
revoke all on function public.set_duty_station_plaetze(uuid, text, integer) from public, anon;
revoke all on function public.helferdienst_eintrag_pruefen() from public, anon, authenticated;
grant execute on function public.helferstation_plaetze(jsonb, text) to authenticated, service_role;
grant execute on function public.add_duty_station(uuid, text, integer) to authenticated, service_role;
grant execute on function public.set_duty_station_plaetze(uuid, text, integer) to authenticated, service_role;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: spalte_da = 1, dazulegen = 1, plaetze_setzen = 1,
-- riegel_liest_plaetze = true, entfernen_raeumt_caps = true,
-- vorgabe_zwei = 2, grenze_oben = 10, eigener_wert = 4.
select (select count(*) from information_schema.columns
         where table_schema='public' and table_name='events' and column_name='helper_caps')        as spalte_da,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='add_duty_station')                                as dazulegen,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='set_duty_station_plaetze')                        as plaetze_setzen,
       (select position('helferstation_plaetze' in pg_get_functiondef(
          'public.helferdienst_eintrag_pruefen()'::regprocedure)) > 0)                             as riegel_liest_plaetze,
       (select position('helper_caps' in pg_get_functiondef(
          'public.remove_duty_station(uuid, text)'::regprocedure)) > 0)                            as entfernen_raeumt_caps,
       public.helferstation_plaetze('{}'::jsonb, 'Grill')                                          as vorgabe_zwei,
       public.helferstation_plaetze('{"Grill": 99}'::jsonb, 'Grill')                               as grenze_oben,
       public.helferstation_plaetze('{"Grill": 4}'::jsonb, 'Grill')                                as eigener_wert;
