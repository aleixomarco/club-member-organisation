-- Rechte und Aufraeumen: der Fuhrpark bekommt die heutigen Rollen, die Glocke
-- verliert die leere Zeile "<Verein>: ", notify_many wird zugesperrt und die
-- Warteschlange wird endlich mit aufgeraeumt.
--
-- Ziel: supabase/migrations/20260920100000_rechte_und_aufraeumen.sql
--
-- rollen-12  can_manage_fleet nennt nur abgeschaffte Rollen und sperrt damit
--            sysadmin und organisator aus dem ganzen Fuhrpark aus.
-- glocke-01  Jede Ergebnismeldung erzeugt in der Glocke eine zweite Zeile, die
--            nur aus Vereinsname und Doppelpunkt besteht.
-- rechte-03  notify_many darf authenticated weiter aufrufen, obwohl die App
--            seit dem 16.09.2026 leitung_melden nimmt.
-- putz-02    run_benachrichtigungen_aufraeumen laesst die notification_queue
--            stehen - Meldungstexte bleiben dort dauerhaft lesbar.
-- putz-03    Drei Fremdschluessel der Meldungstabellen haben keinen Index.
--
-- Alle "Bisher"-Staende sind die Live-Definitionen von PROD vom 20.09.2026,
-- nur lesend ueber pg_get_functiondef geholt; die Belege liegen daneben unter
-- prod-*.sql und diff-*.txt. Eine Datenreparatur gibt es nur bei glocke-01
-- (vier Zeilen vom 13.09.2026). Die 344 Warteschlangenzeilen raeumt der
-- woechentliche Cronjob (jobid 6, sonntags 04:30) beim naechsten Lauf weg;
-- wer nicht warten will, ruft danach einmal von Hand
--   select public.run_benachrichtigungen_aufraeumen();

-- ================================================================ rollen-12
-- Bisher (nur auf PROD, in keiner Migration - deshalb steht die alte Fassung
-- hier vollstaendig):
--   can_manage_fleet(target_club uuid) returns boolean, sql stable security
--   definer, search_path 'public':
--     select exists (select 1 from public.membership_roles r
--       join public.club_memberships m on m.id = r.membership_id
--       where m.club_id = target_club and m.profile_id = auth.uid()
--         and m.status = 'active'
--         and r.role in ('vorstand', 'vereinsadmin', 'geschaeftsfuehrung'));
-- Seit 20260905180000 gibt es in PROD keine einzige Zeile mehr mit 'vorstand'
-- oder 'geschaeftsfuehrung': membership_roles zaehlt 9 vereinsadmin,
-- 6 organisator, 2 sysadmin, sonst nur Mannschafts- und Mitgliedsrollen. Die
-- Funktion liess also nur noch den vereinsadmin durch - faellt der aus, ist
-- der Fuhrpark eingefroren.
--
-- Neu: derselbe Rollensatz wie darf_fahrzeug_entscheiden, das hinter
-- fahrzeugbuchung_status_setzen steht. Wer eine Buchung freigeben darf, darf
-- jetzt auch Fahrzeuge pflegen und eine fremde Buchung loeschen - eine Liste
-- fuer dieselbe Sache statt zwei.
-- search_path steht wie beim Zwilling auf '': alles ist ohnehin voll
-- qualifiziert, und eine untergeschobene Tabelle kann so nicht greifen.
-- Die Rechte bleiben, wie sie sind - create or replace fasst sie nicht an.
--
-- An der Funktion haengen genau diese fuenf Regeln; sie aendern sich nicht
-- mit und muessen nicht neu angelegt werden:
--   club_vehicles     "fleet admins manage vehicles"         INSERT with check
--   club_vehicles     "fleet admins update vehicles"         UPDATE using+check
--   club_vehicles     "fleet admins delete vehicles"         DELETE using
--   vehicle_bookings  "owner or fleet admin updates booking" UPDATE using+check
--   vehicle_bookings  "owner or fleet admin deletes booking" DELETE using
-- Sonst nennt sie niemand: keine weitere Funktion (durchsucht ueber
-- pg_get_functiondef), keine View, kein Constraint.
create or replace function public.can_manage_fleet(target_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membership_roles r
    join public.club_memberships m on m.id = r.membership_id
    where m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
      and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
  );
$$;

-- ================================================================ glocke-01
-- Zwei Stellen ergeben eine leere Zeile in der Glocke:
--   * ergebnis_melden (20260916120000_glocke_folgt_sprache.sql, PROD-Stand
--     Zeichen fuer Zeichen identisch) schreibt body = '' - der ganze Satz
--     steht seit Stufe B im Titel.
--   * meldung_vereinsname_voranstellen (BEFORE INSERT auf user_notifications,
--     20260905200000_meldungen_vereinheitlichen.sql) prueft nur auf null.
--     Aus '' wurde damit "ERG Iserlohn: ".
-- Behoben werden beide. Der Ausloeser ist die robuste Haelfte: auch
-- warteschlange_in_glocke setzt coalesce(new.body, ''), und jede kuenftige
-- Meldung ohne Text laeuft durch denselben Ausloeser.
create or replace function public.meldung_vereinsname_voranstellen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
  /* Ein leerer Text ist kein Text: aus '' wurde sonst die Zeile
     "SV Muster: " - Vereinsname und Doppelpunkt ohne Inhalt. btrim faengt
     auch die Zeilen ab, in denen nur Leerzeichen stehen. */
  if new.club_id is null or new.body is null or btrim(new.body) = '' then return new; end if;
  select name into v_name from public.clubs where id = new.club_id;
  /* Nur voranstellen, wenn er nicht schon dasteht - sonst entsteht
     "SV Muster: SV Muster: ..." bei jeder Meldung, die ihn selbst setzt. */
  if v_name is not null and v_name <> '' and position(v_name || ':' in new.body) <> 1 then
    new.body := v_name || ': ' || new.body;
  end if;
  return new;
end;
$$;

-- Dieselbe Fassung wie in 20260916120000_glocke_folgt_sprache.sql, geaendert
-- ist nur der body der Mannschaftsmeldung: null statt ''. Ohne Text gibt es
-- keine zweite Zeile, mit der der Ausloeser oben ueberhaupt etwas anfangen
-- muesste - und die App zeigt {e.body && ...}, also nichts.
CREATE OR REPLACE FUNCTION public.ergebnis_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_event       record;
  v_vereinsname text;
  v_mannschaft  text;
  v_schluessel  text;
  v_tipper      record;
  v_werte       jsonb;
  v_zeile       jsonb;  -- Rezept der Mannschaftsmeldung (Stufe B)
begin
  if tg_op = 'UPDATE'
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  select e.team_id, e.home_away, e.club_id, e.title, e.type, e.status
    into v_event
    from public.events e
   where e.id = new.event_id;
  if not found then return new; end if;
  if v_event.type is distinct from 'spiel' then return new; end if;
  if v_event.status = 'cancelled' then return new; end if;

  v_werte := public.ergebnis_meldewerte(v_event.home_away, new.heim, new.auswaerts);

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

  /* Tippspiel zuerst - getippt wird auch auf Begegnungen ohne Mannschaft. */
  for v_tipper in
    select m.id
      from public.predictions pr
      join public.club_memberships m
        on m.profile_id = pr.profile_id and m.club_id = new.club_id
     where pr.event_id = new.event_id and m.status = 'active'
  loop
    /* Mit Sprungziel (U8): warteschlange_in_glocke uebernimmt ziel_art und
       ziel_id aus p_data. Die App oeffnet damit das Tippspiel, ohne Abo den
       Termin. */
    perform public.notify_uebersetzt(v_tipper.id, 'tipp',
      'tipp.titel', 'tipp.text',
      jsonb_build_object(
        /* Stufe B: Ersatzwort als Baustein - notify_uebersetzt rendert es in
           der Empfaengersprache und legt das Rezept in data._rezept. */
        'titel', case when v_event.title is null then jsonb_build_object('s', 'allg.begegnung')
                      else to_jsonb(v_event.title) end,
        'heim', v_werte -> 'heim', 'auswaerts', v_werte -> 'auswaerts'),
      jsonb_build_object('ziel_art', 'termin', 'ziel_id', new.event_id));
  end loop;

  if v_mannschaft is null or (v_werte ->> 'ort') is null then return new; end if;

  v_schluessel := 'ergebnis.' || (v_werte ->> 'ort') || '.' || (v_werte ->> 'ausgang');

  /* Stufe B: Der ganze Satz steht im Titel und folgt der Sprache; einen
     zweiten Text gibt es nicht (kein text_schluessel, wird nie neu
     gerendert). Deshalb body null statt '': bei '' hing
     meldung_vereinsname_voranstellen den Vereinsnamen davor, und in der
     Glocke stand unter dem Satz eine zweite Zeile "ERG Iserlohn: ". */
  v_zeile := jsonb_build_object(
    'verein', case when v_vereinsname is null then jsonb_build_object('s', 'allg.verein')
                   else to_jsonb(v_vereinsname) end,
    'mannschaft', v_mannschaft,
    'heim', v_werte -> 'heim', 'auswaerts', v_werte -> 'auswaerts');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, 'results',
         public.meldung_rendern(v_schluessel, coalesce(p.language, 'de'), v_zeile),
         null::text,
         'termin', new.event_id,
         v_schluessel, null::text, v_zeile, coalesce(p.language, 'de')
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = v_event.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = v_event.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, v_event.team_id, 'ergebnisse')
    and public.meldung_erlaubt(m.profile_id, 'results');

  return new;
end;
$function$;

-- Die vier Zeilen vom 13.09.2026, die es schon erwischt hat: kind 'results',
-- body genau "<Verein>:" nach btrim, zwei Empfaenger, zwei Spiele. body null
-- statt '' - die App zeigt {e.body && ...}, also gar nichts mehr.
-- Kein Push und keine neue Zahl am App-Symbol: user_notifications_push haengt
-- am INSERT, und push_zaehler_anstossen meldet nur, wo read_at von null auf
-- gesetzt springt. read_at fassen wir nicht an.
update public.user_notifications n
   set body = null
  from public.clubs c
 where c.id = n.club_id
   and n.body is not null
   and btrim(n.body) = btrim(c.name || ':');

-- ================================================================ rechte-03
-- notify_many(uuid[],text,text,text) nimmt Freitext entgegen (200/1000
-- Zeichen) und verlangt fuer 'membership' nur is_club_member. Ihr Nachfolger
-- leitung_melden verlangt zusaetzlich eine Leitungsrolle und baut Titel und
-- Text serverseitig aus Schluesseln - also uebersetzt und nicht in fremdem
-- Namen. Die App ruft seit dem Umstieg am 16.09.2026 nur noch leitung_melden
-- (app/page.tsx:1093); an den beiden anderen Fundstellen (:1084, :6108) steht
-- notify_many nur noch im Kommentar.
--
-- Gegenprobe vor dem Zusperren, nur lesend:
--   * pg_stat_statements (Fenster seit 01.08.2026) kennt zwei PostgREST-
--     Aufrufe von notify_many mit 9 und 2 Aufrufen, Eintraege seit dem 08.08.
--     bzw. 30.08.2026. Einen Zeitpunkt des letzten Aufrufs fuehrt die
--     Erweiterung nicht - allein damit ist nichts bewiesen.
--   * Deshalb die Daten: notify schreibt jeden durchgelassenen Aufruf in die
--     notification_queue, und mehr als 'vehicle' und 'membership' laesst
--     notify_many gar nicht zu. Die juengste Zeile mit 'vehicle' ist vom
--     09.09.2026, mit 'membership' vom 11.09.2026. Seit dem Umstieg kam also
--     kein Aufruf mehr an.
-- service_role behaelt das Recht (Server- und Wartungswege), postgres ohnehin.
-- Die Funktion selbst bleibt stehen: sie wird noch von Servercode gerufen.
-- Zum do-Block: ein unbedingtes REVOKE auf eine Funktion, die es nicht gibt,
-- braeche die ganze Migration ab (42883).
do $$
begin
  if to_regprocedure('public.notify_many(uuid[], text, text, text)') is not null then
    execute 'revoke execute on function public.notify_many(uuid[], text, text, text) from authenticated';
  end if;
end $$;

-- ================================================================ putz-02
-- Bisher (20260903110000_postfach.sql, PROD-Stand identisch) loescht die
-- woechentliche Aufraeumfunktion (cron jobid 6, sonntags 04:30) nur aus
-- user_notifications. Die notification_queue steht seit dem 16.08.2026
-- unberuehrt da: 344 Zeilen, 608 kB und damit die groesste Tabelle der
-- Datenbank, jede Zeile mit Titel und Text. Die Regel "members read own
-- notification queue" laesst das Mitglied genau diese Zeilen lesen.
-- Von den 344 haben 328 keine Glockenzeile mehr: entweder hat das Mitglied
-- sie geloescht, oder sie kam nie an (darunter alle 31 'security'-Zeilen vom
-- 16.08. bis 11.09.2026 - der Weg, auf dem sie verschwanden, ist seit
-- 20260911070000_geraetemeldung_nur_einmal zu). Der Text blieb trotzdem
-- lesbar - Loeschung und Aufbewahrungsfrist griffen nur zur Haelfte.
--
-- Neu: zwei Regeln fuer die Warteschlange.
--   1. Alter. Nach 30 Tagen weg. Nach dem AFTER-INSERT-Ausloeser
--      notification_queue_in_glocke hat die Zeile keine Aufgabe mehr; die 30
--      Tage sind reine Nachschau bei Stoerungen.
--   2. Waise. Zeilen ohne Glockenzeile schon nach einem Tag. Verbunden wird
--      ueber das, was warteschlange_in_glocke uebertraegt: Profil der
--      Mitgliedschaft, Verein, Art und die Zeit. Beide created_at kommen aus
--      demselben now() derselben Transaktion - in PROD stimmen 16 von 17
--      Paaren auf die Mikrosekunde ueberein, der groesste Abstand liegt bei
--      0,15 s. Die fuenf Sekunden sind also reichlich, und der Tag Schonfrist
--      haelt frisch eingefuegte Zeilen sicher heraus.
-- Die beiden DELETE sehen dieselbe Momentaufnahme: was der erste aus der
-- Glocke raeumt, gilt fuer den zweiten noch als vorhanden. Eine
-- Warteschlangenzeile wird also nie zur Waise, nur weil die Glockenzeile in
-- derselben Ausfuehrung verfallen ist - sie faellt eine Woche spaeter unter
-- Regel 1 oder 2.
-- Die Rueckgabe zaehlt beide Tabellen zusammen; der Cronjob liest sie nicht,
-- sie steht nur im Protokoll.
-- Nebenbei erledigt sich damit die tote Spalte processed_at: die 84 Zeilen
-- ohne processed_at sind kein Rueckstau, sondern Altlast - der Ausloeser
-- on_notification_queued ist seit 20260905220000 weg, gesetzt hat sie seither
-- niemand mehr. Sie verschwinden mit ihren Zeilen.
create or replace function public.run_benachrichtigungen_aufraeumen()
returns integer language sql security definer set search_path = '' as $$
  with glocke as (
    delete from public.user_notifications
     where (read_at is not null and read_at < now() - interval '90 days')
        or created_at < now() - interval '365 days'
    returning 1
  ),
  warteschlange as (
    delete from public.notification_queue q
     where q.created_at < now() - interval '30 days'
        or (q.created_at < now() - interval '1 day'
            and not exists (
              select 1
                from public.club_memberships m
                join public.user_notifications n on n.profile_id = m.profile_id
               where m.id = q.membership_id
                 and n.club_id is not distinct from q.club_id
                 and n.kind = q.notif_type
                 and n.created_at between q.created_at - interval '5 seconds'
                                      and q.created_at + interval '5 seconds'))
    returning 1
  )
  select ((select count(*) from glocke) + (select count(*) from warteschlange))::integer;
$$;

-- ================================================================ putz-03
-- Drei einspaltige Fremdschluessel ohne Index, alle drei ON DELETE CASCADE.
-- Ohne Index liest Postgres beim Loeschen eines Vereins, einer Mitgliedschaft
-- oder eines Termins die Kindtabelle einmal von vorn bis hinten. Bei 344 und
-- 88 Zeilen faellt das nicht auf - die Warteschlange ist aber schon die
-- groesste Tabelle, und der Waisen-Test im Aufraeumen oben sucht ueber
-- membership_id. Nachgesehen: keinen der drei Indizes gibt es (pg_indexes
-- kennt bisher nur die beiden Primaerschluessel und drei Indizes auf
-- user_notifications). Die uebrigen 56 Fremdschluessel ohne Index bleiben
-- bewusst, wie sie sind - kein Index auf Verdacht.
create index if not exists notification_queue_membership_id_idx
  on public.notification_queue (membership_id);
create index if not exists notification_queue_club_id_idx
  on public.notification_queue (club_id);
create index if not exists user_notifications_source_event_id_idx
  on public.user_notifications (source_event_id);

-- ---------------------------------------------------------------- Nachweis
-- Nur lesend. Erwartet: fuhrpark_rollen_neu = 1, fuhrpark_alte_rollen = 0,
-- fuhrpark_regeln = 5, praefix_prueft_leer = 1, ergebnis_body_null = 1,
-- ergebnis_body_leer = 0, leere_vereinszeilen = 0,
-- notify_many_authenticated = false, notify_many_service_role = true,
-- aufraeumen_mit_warteschlange = 1, indizes = 3.
-- warteschlange_jetzt ist nur zur Einordnung: so viele Zeilen liegen noch da,
-- wenn der Cronjob das naechste Mal laeuft.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'can_manage_fleet'
      and p.prosrc like '%''vereinsadmin'', ''sysadmin'', ''organisator''%') as fuhrpark_rollen_neu,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'can_manage_fleet'
      and (p.prosrc like '%vorstand%' or p.prosrc like '%geschaeftsfuehrung%')) as fuhrpark_alte_rollen,
  (select count(*) from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') like '%can_manage_fleet%'
        or coalesce(with_check, '') like '%can_manage_fleet%')) as fuhrpark_regeln,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'meldung_vereinsname_voranstellen'
      and p.prosrc like '%btrim(new.body) = ''''%') as praefix_prueft_leer,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'ergebnis_melden'
      and p.prosrc ~ 'v_zeile\),\s*null::text,') as ergebnis_body_null,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'ergebnis_melden'
      and p.prosrc ~ 'v_zeile\),\s*'''',') as ergebnis_body_leer,
  (select count(*) from public.user_notifications n
     join public.clubs c on c.id = n.club_id
    where n.body is not null and btrim(n.body) = btrim(c.name || ':')) as leere_vereinszeilen,
  (case when to_regprocedure('public.notify_many(uuid[], text, text, text)') is null then false
        else has_function_privilege('authenticated',
          'public.notify_many(uuid[], text, text, text)', 'EXECUTE') end) as notify_many_authenticated,
  (case when to_regprocedure('public.notify_many(uuid[], text, text, text)') is null then false
        else has_function_privilege('service_role',
          'public.notify_many(uuid[], text, text, text)', 'EXECUTE') end) as notify_many_service_role,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'run_benachrichtigungen_aufraeumen'
      and p.prosrc like '%notification_queue%') as aufraeumen_mit_warteschlange,
  (select count(*) from pg_indexes
    where schemaname = 'public'
      and indexname in ('notification_queue_membership_id_idx',
                        'notification_queue_club_id_idx',
                        'user_notifications_source_event_id_idx')) as indizes,
  (select count(*) from public.notification_queue) as warteschlange_jetzt;
