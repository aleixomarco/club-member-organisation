-- Ziel im Repo: supabase/migrations/20261004250000_waechter_hoeren_auf_die_schalter.sql
--
-- Die beiden taeglichen Waechter hoeren jetzt auf die Schalter, die es fuer
-- sie gibt: den Vereinsschalter "Helferdienste" und den Mannschaftsschalter
-- "Benachrichtigungen erhalten".
--
-- ZWEI FUNDE DER SYSTEMPRUEFUNG VOM 04.10.2026, EINE MIGRATION. Sie schreiben
-- beide run_duty_gap_check um; getrennt eingespielt wuerde der zweite die
-- Aenderung des ersten wieder herausnehmen.
--
-- ===================================================================
-- FUND A: ABGESCHALTETE HELFERDIENSTE ERINNERTEN WEITER
-- ===================================================================
-- Die Schalter aus CLUB_FEATURES liegen in club_feature_toggles. Ausgewertet
-- hat sie bisher ausschliesslich die Oberflaeche: featureEnabled blendet die
-- Kachel auf der Startseite aus, den Stationsblock am Termin und den ganzen
-- Reiter Helferplanung. In der Datenbank las sie keine einzige Funktion -
-- nachgemessen am 04.10.2026:
--   select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname='public' and pg_get_functiondef(p.oid) ilike '%club_feature_toggles%';
--   -> 0 Zeilen
--
-- Die beiden Helfer-Auftraege liefen deshalb unabhaengig vom Schalter weiter:
--   duty-gap-check        0 9  * * *  run_duty_gap_check()        'Helfer gesucht'
--   bewirtung-erinnerung  0 18 * * *  run_bewirtung_erinnerung()  'Du hast morgen Dienst'
--
-- SCHADEN: Ein Verein schaltet die Helferdienste ab, waehrend fuer die
-- naechsten Heimspiele schon eingeteilt ist. Am Vorabend bekommen die
-- Eingeteilten weiter "Du hast morgen Dienst an der Station Grill", und
-- "Helfer gesucht" geht sogar an die ganze Mannschaft. Tippt man darauf,
-- oeffnet der Termin OHNE Stationsblock - den blendet die Oberflaeche aus.
-- Der Satz ist nicht nachvollziehbar und mit genau dem Schalter, der dafuer
-- da ist, auch nicht abstellbar.
--
-- WARUM NICHT SCHICKEN statt erst in der Glocke abfangen: Eine Meldung, die
-- in user_notifications steht, ist bereits als Push unterwegs - sie liegt auf
-- dem Telefon, bevor eine Oberflaeche entscheiden kann, ob man sie antippen
-- darf. Ein Riegel auf ziel_art 'termin' traefe ausserdem jede Terminmeldung
-- mit: neuer Termin, verschoben, abgesagt, "Ergebnis fehlt", Tippspiel. Der
-- Schalter heisst duty_roster, nicht events.
--
-- NUR FUER DIE HELFERDIENSTE: run_carpool_gap_check bekommt KEINEN
-- Funktionsriegel, und zwar nicht aus Nachlaessigkeit - es gibt keinen
-- Schalter dafuer. CLUB_FEATURES kennt duty_roster, vehicle_booking,
-- tippspiel und season_award; vehicle_booking ist die Buchung der
-- VEREINSfahrzeuge, nicht die Fahrgemeinschaft. Was es nicht gibt, kann man
-- nicht abfragen.
--
-- STAND HEUTE (nur lesend, PROD, 04.10.2026): Beide Vereine haben alle vier
-- Schalter auf true. Diese Haelfte der Migration aendert heute also nichts -
-- sie verhindert, was beim ERSTEN Abschalten passieren wuerde.
--
-- ===================================================================
-- FUND B: DER MANNSCHAFTSSCHALTER WAR FUER DIESE ZWEI MELDUNGEN TOT
-- ===================================================================
-- run_duty_gap_check und run_carpool_gap_check holten ihre Empfaenger mit
--   select distinct membership_id from public.team_members where team_id = ...
-- und fragten public.team_meldung_erlaubt nie. notify prueft danach nur den
-- GLOBALEN Schalter des Profils (notification_preferences->>'duty' bzw.
-- 'carpool'), nicht team_benachrichtigungen.aktiv.
--
-- SCHADEN: Der Schalter heisst in der App "Benachrichtigungen erhalten" und
-- steht unter "Benachrichtigungen zu dieser Mannschaft". Wer ihn fuer seine
-- Mannschaft ausschaltete, bekam trotzdem vor jedem Heim- und jedem
-- Auswaertsspiel eine Push - ohne jeden Weg, das abzustellen, ausser die
-- Helferdienste oder die Fahrgemeinschaften VEREINSWEIT abzubestellen. Ein
-- Schalter, der nicht schaltet, kostet mehr als ein fehlender: Man drueckt
-- ihn, bekommt am naechsten Tag wieder die Meldung und glaubt der App nichts
-- mehr. Jede andere mannschaftsbezogene Meldung fragt ihn:
-- notify_event_audience, ergebnis_melden, chatnachricht_melden und der
-- Aufgabenzweig derselben Erinnerungsfunktion.
--
-- WARUM 'helferdienste' UND 'fahrgemeinschaften' ALS MELDUNGSART
-- team_meldung_erlaubt kennt in seinem case nur 'spiele', 'trainings' und
-- 'ergebnisse'; alles andere faellt in den else-Zweig, und dann zaehlt genau
-- tb.aktiv - der Hauptschalter. Das ist hier gewollt: Es gibt keinen eigenen
-- Schalter je Mannschaft fuer Helferdienste, und 'spiele' zu uebergeben waere
-- falsch - wer die Spielmeldungen abbestellt hat, faehrt trotzdem mit und
-- steht trotzdem an der Theke. Dasselbe Vorgehen wie beim Aufgabenzweig, der
-- 'aufgaben' uebergibt.
--
-- WER OHNE ZEILE DABEI BLEIBT
-- team_meldung_erlaubt legt um seine Abfrage ein coalesce: Findet es keine
-- Zeile in team_benachrichtigungen, zaehlt "steht im Kader dieser
-- Mannschaft" - und das tun hier alle, denn die Schleife laeuft ueber
-- team_members. Niemand verliert also seine Meldung, der den Schalter nie
-- angefasst hat; in PROD stehen 58 Zeilen zu 35 Mitgliedschaften, viele
-- Kadermitglieder haben fuer manche Mannschaft gar keine. Wer diesen
-- Rueckfall je auf false aendert, schaltet mit einem Handgriff alle stumm,
-- die ihn nie gebraucht haben.
--
-- WARUM DIE EMPFAENGERLISTE AM KADER BLEIBT
-- notify_event_audience nimmt zusaetzlich jeden, der der Mannschaft nur
-- FOLGT (tb.aktiv ohne Kaderzugehoerigkeit). Das waere hier falsch: Gefragt
-- wird, wer den Dienst uebernehmen oder fahren KANN. Ein Follower sitzt nicht
-- im Auto, und ein reiner Fan darf sich ohnehin nicht selbst eintragen
-- (20261002200000, 20261004190000) - eine Aufforderung an ihn waere eine
-- Bitte, die das System gleich danach abweist. Diese Migration macht den
-- Kreis also kleiner, nie groesser.
--
-- Geprueft am 04.10.2026 (nur lesend, PROD): 58 Zeilen in
-- team_benachrichtigungen, 20 davon aktiv = false. Keine der 20 gehoert heute
-- zu einem Kadermitglied derselben Mannschaft - es wird also aktuell niemand
-- gegen seinen Willen angeschrieben. Der Knopf ist trotzdem tot, und
-- stummschalten kann jedes Kadermitglied seine eigene Mannschaft.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden: Alle drei Funktionen
-- ruft nur pg_cron auf, die App nie (die Ausfuehrungsrechte sind seit
-- 20260914110000 entzogen und bleiben es - create or replace laesst ACLs
-- unberuehrt).

-- ------------------------------------------------- Der Schalter, in SQL lesbar
create or replace function public.vereinsfunktion_an(p_club uuid, p_schluessel text)
returns boolean
language sql stable security definer set search_path to '' as $$
  /* Kein Eintrag = eingeschaltet, genau wie clubFeatures[key] !== false in der
     App (DEFAULT_CLUB_FEATURES). Umgekehrt waere jede Funktion in jedem
     Verein aus, der den Einrichtungs-Fragebogen nie durchlaufen hat - und das
     sind alle Vereine von vor den Schaltern. */
  select coalesce((select t.enabled
                     from public.club_feature_toggles t
                    where t.club_id = p_club
                      and t.feature_key = p_schluessel), true);
$$;

comment on function public.vereinsfunktion_an(uuid, text) is
  'Liest einen Schalter aus club_feature_toggles. Kein Eintrag bedeutet eingeschaltet - dieselbe Regel wie DEFAULT_CLUB_FEATURES in der App. Gedacht fuer die Cron-Funktionen.';

/* Gedacht fuer die Cron-Funktionen. Angemeldete lesen den Schalter ohnehin
   direkt aus der Tabelle; eine zweite Tuer dorthin braucht niemand. */
revoke all on function public.vereinsfunktion_an(uuid, text) from public, anon, authenticated;

-- ------------------------------------------------- 'Helfer gesucht'
create or replace function public.run_duty_gap_check()
returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  ev     record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled' and e.home_away = 'heim'
      and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
      /* Hat der Verein die Helferdienste abgeschaltet, gibt es keine Luecke
         zu melden. Der Stationsblock am Termin ist dann gar nicht zu sehen -
         die Meldung schickte die ganze Mannschaft auf eine Seite ohne das,
         wovon sie spricht. */
      and public.vereinsfunktion_an(e.club_id, 'duty_roster')
      and exists (
        /* Eine Station, an der noch Plaetze frei sind. Gezaehlt wird, was die
           App zeigt: die Eintragungen gegen die Platzzahl der Station. */
        select 1
          from unnest(coalesce(e.helper_slots, '{}'::text[])) as s(station)
         where (select count(*) from public.duty_assignments d
                 where d.event_id = e.id and d.station = s.station)
               < public.helferstation_plaetze(coalesce(e.helper_caps, '{}'::jsonb), s.station))
  loop
    /* Der Mannschaftsschalter zaehlt auch hier. Ohne diese Bedingung bekam
       jemand, der "Benachrichtigungen erhalten" fuer seine Mannschaft
       ausgeschaltet hatte, vor jedem Heimspiel wieder eine Push - und hielt
       den Schalter zu Recht fuer kaputt.
       Die Meldungsart 'helferdienste' faellt in den else-Zweig von
       team_meldung_erlaubt; dort zaehlt genau tb.aktiv. 'spiele' waere
       falsch: Wer Spielmeldungen abbestellt, steht trotzdem an der Theke. */
    for member in
      select distinct tm.membership_id as id
        from public.team_members tm
       where tm.team_id = ev.team_id
         and public.team_meldung_erlaubt(tm.membership_id, ev.team_id, 'helferdienste')
    loop
      perform public.notify_uebersetzt(member.id, 'duty',
        'helfer.gesucht.titel', 'helfer.gesucht.text',
        jsonb_build_object('titel', ev.title, 'datum', jsonb_build_object('zeit', ev.starts_at, 'uhrzeit', false)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$$;

-- ------------------------------------------------- 'Noch keine Fahrgemeinschaft'
create or replace function public.run_carpool_gap_check()
returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  ev     record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled'
      and e.type = 'spiel'
      and coalesce(e.home_away, 'auswaerts') <> 'heim'
      and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
      and e.team_id is not null
      and not exists (select 1 from public.carpools c where c.event_id = e.id)
  loop
    /* Wie beim Helferdienst: Der Schalter der Mannschaft gilt auch fuer diese
       Meldung. 'fahrgemeinschaften' faellt in den else-Zweig von
       team_meldung_erlaubt, es zaehlt also tb.aktiv.
       Einen VEREINSschalter gibt es hier nicht - CLUB_FEATURES kennt keine
       Fahrgemeinschaft (vehicle_booking ist die Buchung der Vereinsfahrzeuge
       und etwas anderes). */
    for member in
      select distinct tm.membership_id as id
        from public.team_members tm
       where tm.team_id = ev.team_id
         and public.team_meldung_erlaubt(tm.membership_id, ev.team_id, 'fahrgemeinschaften')
    loop
      perform public.notify_uebersetzt(member.id, 'carpool',
        'fahrgemeinschaft.fehlt.titel', 'fahrgemeinschaft.fehlt.text',
        jsonb_build_object('titel', ev.title, 'datum', jsonb_build_object('zeit', ev.starts_at, 'uhrzeit', false)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$$;

-- ------------------------------------------------- 'Du hast morgen Dienst'
create or replace function public.run_bewirtung_erinnerung()
returns void
language plpgsql security definer set search_path to 'public' as $$
declare
  d record;
begin
  for d in
    select da.id, da.membership_id, da.station, e.id as event_id, e.title, e.starts_at
      from public.duty_assignments da
      join public.events e on e.id = da.event_id
     where da.membership_id is not null
       and da.erinnert_am is null
       and e.status = 'scheduled'
       /* Morgen, in deutscher Zeit gerechnet - wie run_duty_gap_check
          (20260926110000:113). Ein Dienst um 9 Uhr morgens faellt sonst je
          nach Serverzeitzone auf den falschen Tag. */
       and (e.starts_at at time zone 'Europe/Berlin')::date
           = (now() at time zone 'Europe/Berlin')::date + 1
       /* Wie in run_duty_gap_check: Mit abgeschalteten Helferdiensten waere
          "Du hast morgen Dienst an der Station Grill" ein Satz ueber eine
          Funktion, die dieser Verein nicht mehr hat.
          erinnert_am bleibt dabei absichtlich null: Wird der Schalter vor dem
          Termin wieder umgelegt, geht die Erinnerung noch raus. Ein Sperren
          auf Vorrat wuerde sie dann fuer immer verschlucken. */
       and public.vereinsfunktion_an(e.club_id, 'duty_roster')
  loop
    /* JE EMPFAENGER ein eigener Block. Die Funktion ist EINE Transaktion -
       ohne diesen Zweig rollt ein einziger Fehlschlag alle Meldungen und alle
       erinnert_am des ganzen Laufs zurueck, und am naechsten Tag ist der
       Termin vorbei. Ein Block mit exception legt einen Sicherungspunkt an;
       scheitert einer, bleibt der Rest stehen.
       Der Fehlschlag wird laut: Als Warnung steht er im Protokoll der
       Datenbank, statt stillschweigend zu verschwinden. */
    begin
      perform public.notify_uebersetzt(d.membership_id, 'duty',
        'helfer.erinnerung.titel', 'helfer.erinnerung.text',
        jsonb_build_object('titel', d.title, 'station', d.station,
                           'datum', jsonb_build_object('zeit', d.starts_at, 'uhrzeit', true)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', d.event_id));
      update public.duty_assignments set erinnert_am = now() where id = d.id;
    exception when others then
      raise warning 'Bewirtungs-Erinnerung fuer Dienst % fehlgeschlagen: %', d.id, sqlerrm;
    end;
  end loop;
end;
$$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: dienst_fragt_vereinsschalter = true,
--           erinnerung_fragt_vereinsschalter = true,
--           dienst_fragt_mannschaftsschalter = true,
--           mitfahrt_fragt_mannschaftsschalter = true,
--           dienst_bleibt_am_kader = true, mitfahrt_bleibt_am_kader = true,
--           schalter_nicht_fuer_angemeldete = true,
--           waechter_nicht_fuer_angemeldete = true,
--           auftraege_laufen = 3,
--           stumme_im_kader = 0 (am 04.10.2026; ab der ersten
--           Stummschaltung eines Kadermitglieds steigt die Zahl - genau
--           diese Leute waren vorher nicht abschaltbar).
select
  pg_get_functiondef('public.run_duty_gap_check()'::regprocedure)
    like '%vereinsfunktion_an%'                        as dienst_fragt_vereinsschalter,
  pg_get_functiondef('public.run_bewirtung_erinnerung()'::regprocedure)
    like '%vereinsfunktion_an%'                        as erinnerung_fragt_vereinsschalter,
  pg_get_functiondef('public.run_duty_gap_check()'::regprocedure)
    like '%team_meldung_erlaubt%'                      as dienst_fragt_mannschaftsschalter,
  pg_get_functiondef('public.run_carpool_gap_check()'::regprocedure)
    like '%team_meldung_erlaubt%'                      as mitfahrt_fragt_mannschaftsschalter,
  pg_get_functiondef('public.run_duty_gap_check()'::regprocedure)
    like '%from public.team_members tm%'               as dienst_bleibt_am_kader,
  pg_get_functiondef('public.run_carpool_gap_check()'::regprocedure)
    like '%from public.team_members tm%'               as mitfahrt_bleibt_am_kader,
  not has_function_privilege('authenticated',
    'public.vereinsfunktion_an(uuid,text)', 'execute')  as schalter_nicht_fuer_angemeldete,
  (not has_function_privilege('authenticated', 'public.run_duty_gap_check()', 'execute')
   and not has_function_privilege('authenticated', 'public.run_carpool_gap_check()', 'execute')
   and not has_function_privilege('authenticated', 'public.run_bewirtung_erinnerung()', 'execute'))
                                                        as waechter_nicht_fuer_angemeldete,
  (select count(*) from cron.job
    where jobname in ('duty-gap-check', 'carpool-gap-check', 'bewirtung-erinnerung')
      and active)                                       as auftraege_laufen,
  (select count(*) from public.team_benachrichtigungen tb
     join public.team_members tm
       on tm.membership_id = tb.membership_id and tm.team_id = tb.team_id
    where not tb.aktiv)                                 as stumme_im_kader;
