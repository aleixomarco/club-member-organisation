-- Ziel im Repo: supabase/migrations/20261001180000_bewirtungsplan_nachbessern.sql
--
-- Vier Maengel am Bewirtungsplan vom selben Tag, gefunden in der Durchsicht.
--
-- Die Durchsicht lief mit sechs unabhaengigen Pruefern, jeder Fund wurde
-- anschliessend von einem zweiten Lauf angegriffen, der ihn widerlegen sollte.
-- Achtzehn Funde sind dabei gefallen, neun haben standgehalten; vier davon
-- liegen in der Datenbank und stehen hier. Die uebrigen fuenf sind in der App
-- behoben.
--
-- ------------------------------------------------------------------ 1
-- FEHLER KOMMEN JETZT ALS SCHLUESSELWORT
-- bewirtungsplan_anwenden warf deutsche Saetze: 'Zeitraum unvollstaendig',
-- 'Zeitraum zu lang'. Die App zeigte sie unveraendert an - und zwar als
-- einzige Stelle in 18.900 Zeilen. Wer die App auf Tuerkisch stellt und
-- versehentlich "Bis" vor "Von" setzt, las woertlich "Zeitraum
-- unvollstaendig", ohne Umlaut, mitten in einer tuerkischen Oberflaeche.
-- Der Bestand macht es seit dem 26.09. umgekehrt (20260926100000:58-67):
-- Die Funktion wirft ein Schluesselwort, die App haelt den Satz dazu bereit,
-- in jeder Sprache. Genau so jetzt auch hier:
--   zeitraum_falsch       kein Datum, oder bis liegt vor von
--   zeitraum_zu_lang      mehr als zwei Jahre
--   satz_ohne_stationen   das Set hat gar keine Posten (siehe 2)
--   fremdes_set           das Set gehoert einem anderen Verein
--
-- ------------------------------------------------------------------ 2
-- EIN LEERES SET GALT ALS "SCHON VOLLSTAENDIG"
-- apply_duty_template liefert 0 zurueck, wenn nichts hinzukam - und zwar aus
-- ZWEI Gruenden: Entweder lag das Set dort schon an, oder es hat ueberhaupt
-- keine Stationen (20260930090000:216). bewirtungsplan_anwenden deutete jede
-- 0 als "lag schon an". Ein frisch angelegtes, noch leeres Set auf siebzehn
-- Heimspiele angewendet meldete deshalb: "17 Heimspiele bearbeitet, 0
-- Stationen neu angelegt. 17 davon hatten das Set schon vollstaendig." An
-- keinem einzigen Spiel stand etwas.
--
-- Dieselbe Zweideutigkeit war am Einzeltermin schon einmal ein Fehler und ist
-- dort behoben (app/page.tsx:9631-9637, Text "Dieses Set enthaelt noch keine
-- Stationen."). Der Mengenweg fiel dahinter zurueck. Jetzt prueft die
-- Funktion VOR der Schleife und wirft satz_ohne_stationen.
--
-- ------------------------------------------------------------------ 3
-- EIN VERSCHOBENES SPIEL VERLOR SEINE ERINNERUNG
-- erinnert_am wurde gesetzt und nirgends je wieder geloest. Heimspiel am
-- 02.10., Erinnerung geht am 01.10. um 18 Uhr raus. Abends wird das Spiel auf
-- den 09.10. verschoben. Am 08.10. ueberspringt der Lauf die Zeile, weil
-- erinnert_am gesetzt ist - die einzige Erinnerung, die die Eingeteilten je
-- bekommen, nannte dann das falsche Datum, und danach kam keine mehr.
-- Ein Ausloeser setzt die Sperre jetzt zurueck, sobald sich der Beginn
-- aendert. Und ebenso, wenn ein abgesagter Termin wieder angesetzt wird -
-- sonst bliebe dort eine Sperre aus der Zeit vor der Absage stehen.
--
-- ------------------------------------------------------------------ 4
-- EIN KOMMENTAR BEHAUPTETE ETWAS FALSCHES
-- In run_bewirtung_erinnerung stand: "Einzeln gesetzt, nicht am Ende in einem
-- Rutsch: Bricht der Lauf in der Mitte ab, sind die bereits Benachrichtigten
-- vermerkt." Das stimmt nicht. Eine plpgsql-Funktion ist EINE Transaktion -
-- bricht sie ab, fallen alle erinnert_am UND alle Meldungen zurueck. Der
-- Kommentar beschrieb einen Schutz, den es nicht gab.
-- Jetzt gibt es ihn: Jeder Empfaenger steht in einem eigenen Block mit
-- exception-Zweig. Scheitert einer, laeuft der Rest weiter - und der
-- Fehlschlag steht als Warnung im Protokoll, statt still zu verschwinden.
--
-- Geprueft am 01.10.2026 (nur lesend, PROD): bewirtungsplan_anwenden wirft
-- bisher 'Zeitraum unvollstaendig'; kein Ausloeser auf events setzt
-- erinnert_am zurueck.
--
-- MUSS zusammen mit der App ausgeliefert werden.

create or replace function public.bewirtungsplan_anwenden(
  target_club uuid, target_template uuid, von date, bis date)
returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare
  ev            record;
  v_posten      int;
  v_spiele      int := 0;
  v_neu         int := 0;
  v_ohne_neue   int := 0;
  v_vergangen   int := 0;
  v_abgesagt    int := 0;
  v_dazu        int;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.can_manage_duty_templates(target_club) then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;
  if von is null or bis is null or bis < von then
    raise exception 'zeitraum_falsch' using errcode = 'P0001';
  end if;
  /* Zwei Jahre sind reichlich fuer jede Saison. Die Grenze steht nicht gegen
     Boeswilligkeit - wer das Set pflegen darf, darf es anwenden -, sondern
     gegen den Vertipper: "1.10.2026 bis 1.10.2206" liefe sonst ueber jeden
     Termin, den der Verein je anlegt. */
  if bis - von > 730 then
    raise exception 'zeitraum_zu_lang' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.duty_task_templates t
                  where t.id = target_template and t.club_id = target_club) then
    raise exception 'fremdes_set' using errcode = 'P0001';
  end if;

  /* Ein leeres Set wuerde siebzehn Spiele anfassen und nichts anlegen - und
     weil apply_duty_template dafuer dieselbe 0 liefert wie fuer "lag schon
     an", haette die Rueckmeldung dem Betreiber gesagt, alles sei in Ordnung.
     Lieber gar nicht anfangen. */
  select count(*) into v_posten from public.duty_task_template_items
   where template_id = target_template;
  if v_posten = 0 then
    raise exception 'satz_ohne_stationen' using errcode = 'P0001';
  end if;

  /* Was uebergangen wird, und warum - VOR dem Anwenden gezaehlt, damit die
     Zahlen denselben Zeitraum beschreiben. */
  select
    count(*) filter (where e.status = 'scheduled' and e.starts_at < now()),
    count(*) filter (where e.status = 'cancelled')
    into v_vergangen, v_abgesagt
    from public.events e
   where e.club_id = target_club and e.type = 'spiel' and e.home_away = 'heim'
     and (e.starts_at at time zone 'Europe/Berlin')::date between von and bis;

  for ev in
    select e.id
      from public.events e
     where e.club_id = target_club and e.type = 'spiel' and e.home_away = 'heim'
       and e.status = 'scheduled' and e.starts_at >= now()
       and (e.starts_at at time zone 'Europe/Berlin')::date between von and bis
     order by e.starts_at
  loop
    v_spiele := v_spiele + 1;
    v_dazu := public.apply_duty_template(ev.id, target_template);
    v_neu := v_neu + coalesce(v_dazu, 0);
    /* Jetzt eindeutig: Das Set hat Stationen (oben geprueft), also heisst 0
       hier wirklich "lag an diesem Spieltag schon vollstaendig an". */
    if coalesce(v_dazu, 0) = 0 then v_ohne_neue := v_ohne_neue + 1; end if;
  end loop;

  return jsonb_build_object(
    'spiele', v_spiele, 'stationen_neu', v_neu, 'schon_vollstaendig', v_ohne_neue,
    'uebergangen_vergangen', v_vergangen, 'uebergangen_abgesagt', v_abgesagt);
end;
$function$;

revoke all on function public.bewirtungsplan_anwenden(uuid, uuid, date, date) from public, anon;
grant execute on function public.bewirtungsplan_anwenden(uuid, uuid, date, date) to authenticated;

-- ------------------------------------------------- Erinnerung: Fehler je Zeile
create or replace function public.run_bewirtung_erinnerung()
returns void
language plpgsql security definer set search_path to 'public' as $function$
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
$function$;

revoke execute on function public.run_bewirtung_erinnerung() from public, anon, authenticated;

-- ------------------------------------------------- Verschoben? Sperre faellt
create or replace function public.erinnerung_zuruecksetzen()
returns trigger
language plpgsql security definer set search_path to 'public' as $function$
begin
  update public.duty_assignments
     set erinnert_am = null
   where event_id = new.id and erinnert_am is not null;
  return new;
end;
$function$;

drop trigger if exists events_erinnerung_zuruecksetzen on public.events;
/* AFTER, nicht BEFORE: Der Termin soll erst feststehen, dann wird aufgeraeumt.
   Die Bedingung steht im when und nicht im Rumpf, damit der Ausloeser bei
   jeder anderen Aenderung am Termin gar nicht erst laeuft - Titel, Ort und
   Beschreibung aendern sich oft, der Beginn selten.
   Der zweite Zweig faengt den wieder angesetzten Termin: Ohne ihn bliebe dort
   eine Sperre aus der Zeit vor der Absage stehen und verschluckte die
   Erinnerung. */
create trigger events_erinnerung_zuruecksetzen
  after update on public.events
  for each row
  when (new.starts_at is distinct from old.starts_at
        or (old.status = 'cancelled' and new.status = 'scheduled'))
  execute function public.erinnerung_zuruecksetzen();

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: schluesselwoerter = true, leeres_set_geprueft = true,
--           erinnerung_faengt_fehler = true, ausloeser_da = 1,
--           ausloeser_auf_beginn = true, deutsche_saetze_weg = true.
select
  (select pg_get_functiondef(oid) like '%zeitraum_falsch%'
      and pg_get_functiondef(oid) like '%zeitraum_zu_lang%'
      and pg_get_functiondef(oid) like '%fremdes_set%'
     from pg_proc where proname = 'bewirtungsplan_anwenden') as schluesselwoerter,
  (select pg_get_functiondef(oid) like '%satz_ohne_stationen%'
     from pg_proc where proname = 'bewirtungsplan_anwenden') as leeres_set_geprueft,
  (select pg_get_functiondef(oid) like '%exception when others%'
     from pg_proc where proname = 'run_bewirtung_erinnerung') as erinnerung_faengt_fehler,
  (select count(*) from pg_trigger
    where tgname = 'events_erinnerung_zuruecksetzen' and not tgisinternal) as ausloeser_da,
  (select pg_get_triggerdef(oid) like '%starts_at%'
     from pg_trigger where tgname = 'events_erinnerung_zuruecksetzen') as ausloeser_auf_beginn,
  /* Die deutschen Saetze duerfen nicht mehr geworfen werden. */
  (select pg_get_functiondef(oid) not like '%Zeitraum unvollstaendig%'
      and pg_get_functiondef(oid) not like '%Zeitraum zu lang%'
     from pg_proc where proname = 'bewirtungsplan_anwenden') as deutsche_saetze_weg;
