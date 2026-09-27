-- Ziel im Repo: supabase/migrations/20260927140000_terminadresse.sql
--
-- Eine Adresse zum Antippen an jedem Termin.
--
-- WARUM
-- events.location traegt heute den Ort, wie ihn der Verein nennt:
-- "Hemberghalle, Iserlohn", "Wimbern · 85 km", "Vereinsheim am Hemberg". Das
-- ist ein Name, keine Anschrift - ein Navigationsgeraet findet damit nichts,
-- und wer zum ersten Mal zu einem Auswaertsspiel faehrt, sucht die Halle in
-- einer zweiten App zusammen. Genau dort gehen Eltern verloren, die nur ihr
-- Kind hinbringen.
--
-- BISHER
-- Der Ort war das einzige Feld. Wer eine Anschrift unterbringen wollte,
-- schrieb sie in die Beschreibung - dort ist sie Fliesstext und nichts kann
-- sie antippbar machen.
--
-- JETZT
-- Eine zweite Spalte daneben. Der Ort bleibt, wie er ist: Pflicht in der App
-- und der vertraute Name, den alle kennen. Die Adresse kommt freiwillig dazu
-- und wird in der App zu einem Link, der die Navigations-App des Geraets
-- oeffnet.
--
-- WARUM EINE SPALTE UND KEINE NEUE TABELLE
-- Dieselbe Begruendung wie bei helper_caps (20260926100000): Eine eigene
-- Tabelle muesste bei jedem Anlegen, Aendern und Loeschen eines Termins
-- mitgefuehrt werden, und jede bestehende Abfrage braeuchte einen Verbund.
-- Ein Termin hat genau eine Adresse - dafuer ist eine Spalte daneben das
-- richtige Mass.
--
-- WARUM DER AUSLOESER SIE NICHT MITBEKOMMT
-- events_notify_audience meldet Terminaenderungen an alle Betroffenen und
-- horcht dafuer auf status, starts_at, ends_at, location, title, team_id und
-- type. address steht dort BEWUSST nicht: Eine nachgetragene oder korrigierte
-- Hausnummer ist keine Terminaenderung. Wer sie aufnaehme, liesse bei jedem
-- Tippfehler in der Anschrift den ganzen Verein klingeln.
--
-- MUSS ZUSAMMEN MIT DER APP AUSGELIEFERT WERDEN: Ohne die erweiterte
-- select-Liste in app/page.tsx (Laden der Termine) kommt die Spalte nie auf
-- dem Geraet an, und ohne das neue Feld im Formular traegt sie niemand ein.
--
-- Geprueft am 27.09.2026 (nur lesend, PROD): events hat 26 Spalten, keine
-- heisst address. Die vier Zeilenregeln auf events pruefen nur club_id und
-- team_id und fuehren keine Spaltenliste; die Rechte haengen an der ganzen
-- Tabelle. Eine neue Spalte braucht deshalb weder ein grant noch eine
-- geaenderte Regel.

-- ------------------------------------------------- Die Spalte
alter table public.events
  add column if not exists address text;

comment on column public.events.address is
  'Anschrift zum Navigieren, freiwillig - z. B. "Hauptstrasse 12, 58644 Iserlohn". Ergaenzt location, ersetzt es nicht: location traegt den vertrauten Namen des Ortes und bleibt in der App Pflicht. Leer heisst NULL, nicht Leerstring. Die App macht daraus einen Link in die Navigations-App des Geraets.';

-- ------------------------------------------------- Terminreihen
-- create_recurring_events legt eine ganze Trainingsreihe in EINEM Aufruf an.
-- Ohne einen dreizehnten Parameter koennte man eine Adresse zwar am einzelnen
-- Termin eintragen, aber nie an einer Reihe - das Feld stuende im Formular und
-- verschwaende beim Speichern stillschweigend. Genau diese Sorte Fehler faellt
-- erst auf, wenn jemand vor der falschen Halle steht.
--
-- Die alte Fassung wird abgeraeumt, statt daneben stehen zu bleiben: Ein
-- zusaetzlicher Parameter MIT Vorgabewert erzeugt eine zweite Funktion gleichen
-- Namens, und PostgREST kann dann nicht mehr entscheiden, welche gemeint ist -
-- dieselbe Lage, die 20260920100100 fuer news_bild beschreibt.
drop function if exists public.create_recurring_events(uuid, uuid, public.event_type, text, text, text, integer[], time, time, date, date, text);

create or replace function public.create_recurring_events(
  target_club uuid, target_team uuid, event_type public.event_type,
  event_title text, event_description text, event_location text,
  weekdays integer[], start_time time without time zone, end_time time without time zone,
  range_start date, range_end date, p_tz text default 'Europe/Berlin'::text,
  event_address text default null)
returns setof uuid
language plpgsql security definer set search_path to '' as $function$
declare
  v_series uuid := gen_random_uuid();
  v_creator uuid := auth.uid();
  v_title text := nullif(trim(event_title), '');
  v_tz text := 'Europe/Berlin';
begin
  if v_creator is null then raise exception 'Authentication required'; end if;
  if v_title is null then raise exception 'Title required'; end if;
  if range_start is null or range_end is null then raise exception 'Date range required'; end if;
  if range_end < range_start then raise exception 'End date must be after start date'; end if;
  if range_end - range_start > 366 then raise exception 'Date range too long (max one year)'; end if;
  if weekdays is null or cardinality(weekdays) = 0 then raise exception 'At least one weekday required'; end if;
  if end_time <= start_time then raise exception 'End time must be after start time'; end if;

  if p_tz is not null and exists (select 1 from pg_catalog.pg_timezone_names z where z.name = p_tz) then
    v_tz := p_tz;
  end if;

  if not (
    public.can_manage_team(target_team)
    or public.has_club_role(target_club, array['sysadmin','vereinsadmin','organisator']::public.club_role[])
  ) then raise exception 'Not authorized to create events for this team' using errcode = '42501'; end if;
  /* Die Mannschaft muss zum Verein gehoeren (Durchsicht 14.09.): Sonst legte
     ein Trainer von Mannschaft X aus Verein A bis zu 366 Termine im Kalender
     von Verein B an. */
  if target_team is not null and not exists (
    select 1 from public.teams t where t.id = target_team and t.club_id = target_club
  ) then raise exception 'Team not in club' using errcode = '42501'; end if;

  return query
    insert into public.events (club_id, team_id, type, status, title, description, starts_at, ends_at, location, address, created_by, series_id)
    select
      target_club,
      target_team,
      event_type,
      'scheduled',
      v_title,
      nullif(trim(event_description), ''),
      ((d::date + start_time) at time zone v_tz),
      ((d::date + end_time) at time zone v_tz),
      nullif(trim(event_location), ''),
      nullif(trim(event_address), ''),
      v_creator,
      v_series
    from generate_series(range_start, range_end, interval '1 day') as d
    where extract(isodow from d::date)::int = any(weekdays)
    returning id;
end;
$function$;

/* Dieselben Rechte wie vorher - am 27.09.2026 lesend geprueft, die alte
   Fassung hatte genau postgres und authenticated. Nach einem drop sind die
   Rechte weg und muessen von Hand zurueck; ohne diese beiden Zeilen koennte
   niemand mehr eine Trainingsreihe anlegen. */
revoke all on function public.create_recurring_events(uuid, uuid, public.event_type, text, text, text, integer[], time, time, date, date, text, text) from public, anon;
grant execute on function public.create_recurring_events(uuid, uuid, public.event_type, text, text, text, integer[], time, time, date, date, text, text) to authenticated;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: spalte_da = 1, spalte_erklaert = 1, serie_nimmt_adresse = true,
-- serie_nur_einmal = 1, serie_darf_authenticated = true,
-- ausloeser_ohne_adresse = true.
select
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'events' and column_name = 'address') as spalte_da,
  (select count(*) from pg_description d
     join pg_class c on c.oid = d.objoid
     join pg_attribute a on a.attrelid = c.oid and a.attnum = d.objsubid
    where c.relname = 'events' and a.attname = 'address') as spalte_erklaert,
  (select pg_get_functiondef(p.oid) like '%event_address%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_recurring_events') as serie_nimmt_adresse,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_recurring_events') as serie_nur_einmal,
  (select has_function_privilege('authenticated', p.oid, 'execute')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'create_recurring_events') as serie_darf_authenticated,
  (select not bool_or(pg_get_triggerdef(t.oid) like '%address%')
     from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where c.relname = 'events' and not t.tgisinternal) as ausloeser_ohne_adresse;
