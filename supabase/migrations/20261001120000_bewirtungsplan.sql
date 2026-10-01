-- Ziel im Repo: supabase/migrations/20261001120000_bewirtungsplan.sql
--
-- Der Bewirtungsplan: ein Helferset auf eine ganze Saison anwenden, und wer
-- eingeteilt ist, wird am Vorabend erinnert.
--
-- WUNSCH DES BETREIBERS (01.10.2026): "ich brauche noch die entitaet
-- bewirtungsplan komplett mit in der app ... ja, an den Heimspielen, bau das".
--
-- WARUM KEINE NEUE TABELLE
-- Die Durchsicht desselben Tages hat gezeigt: Fachlich ist der Bewirtungsplan
-- schon gebaut, er heisst nur "Helferdienst". Posten je Spieltag (Theke,
-- Grill, Kasse), Platzzahlen, Eintragen und Austragen, Helfersets zum
-- Vorladen, Meldung samt Push, Vereinspunkte, Sperre bei abgesagten Terminen
-- - alles vorhanden. Eine eigene Tabelle "bewirtungsplaene" waere ein ZWEITER
-- ORT FUER DIESELBE FRAGE gewesen. Genau diese Konstruktion hat der Betreiber
-- am 25.09.2026 nach keinen zwei Stunden zuruecknehmen lassen
-- (20260925200000_mitglied_aufgaben_weg.sql:5-15) - und damals ging es
-- woertlich um den Bewirtungsplan (20260925180000:4).
--
-- Wer am Termin in die Station eingetragen ist, steht im Plan. Wer im Plan
-- steht, ist am Termin eingetragen. Es gibt nur eine Wahrheit.
--
-- WAS WIRKLICH FEHLTE, waren drei Dinge:
--
--   1. MENGENARBEIT. apply_duty_template wirkt auf EINEN Termin. Siebzehn
--      Heimspiele waren siebzehn Handgriffe, jeder in einer anderen
--      aufgeklappten Terminkarte. Dafuer ist bewirtungsplan_anwenden da.
--
--   2. DIE PLANANSICHT. Es gab keine Tabelle Termin x Posten, die man
--      ueberblickt. Die steht in der App (app/page.tsx), nicht hier.
--
--   3. ERINNERUNG AN DIE EINGETEILTEN. Bisher kam genau EINE Meldung, im
--      Moment der Eintragung (helferdienst_einteilung_melden, 20260916120000).
--      Wer sich im August fuer den 14. Maerz eintraegt, hoert danach nichts
--      mehr. run_duty_gap_check meldet drei Tage vorher - aber an die ganze
--      Mannschaft, dass noch Plaetze FREI sind, nicht an die Eingeteilten,
--      dass sie dran sind. Dafuer ist run_bewirtung_erinnerung da.
--
-- WARUM DIE ERINNERUNG FUER ALLE DIENSTE GILT, NICHT NUR FUER DIE BEWIRTUNG
-- Die Datenbank weiss nicht, welche Station "Bewirtung" ist - "Theke" und
-- "Kiosk" und "Kuchen" sind Freitext, und beim Golf heisst dieselbe Sache
-- "Empfang" (app/page.tsx:603). Eine Erinnerung nur fuer bestimmte Namen
-- waere eine Liste deutscher Woerter in einer Funktion. Wer an der Zeitnahme
-- steht, vergisst den Termin genauso. Also wird jeder Dienst erinnert.
--
-- VERGANGENE UND ABGESAGTE SPIELE
-- bewirtungsplan_anwenden fasst nur kuenftige, angesetzte Heimspiele an und
-- sagt in der Rueckmeldung, wie viele es aus welchem Grund uebergangen hat.
-- Stillschweigen waere hier schaedlich: Wer einen Zeitraum waehlt, der zur
-- Haelfte in der Vergangenheit liegt, soll das erfahren und nicht glauben,
-- der Plan stehe.
--
-- Geprueft am 01.10.2026 (nur lesend, PROD): Weder bewirtungsplan_anwenden
-- noch run_bewirtung_erinnerung vorhanden; duty_assignments hat keine Spalte
-- erinnert_am; cron.job kennt keinen Auftrag "bewirtung-erinnerung".
--
-- MUSS zusammen mit der App ausgeliefert werden.

-- ------------------------------------------------- 1. Sperre gegen Doppelversand
alter table public.duty_assignments
  add column if not exists erinnert_am timestamptz;

comment on column public.duty_assignments.erinnert_am is
  'Wann an diesen Dienst erinnert wurde. Sperre gegen Mehrfachversand: run_bewirtung_erinnerung laeuft taeglich, und ohne diese Spalte bekaeme jemand, der am Vortag eingeteilt ist, die Erinnerung bei jedem Lauf erneut. Dieselbe Begruendung wie bei club_tasks.reminded_at (20260905200000).';

-- ------------------------------------------------- 2. Ein Set auf einen Zeitraum
--
-- Rumpf ist apply_duty_template (20260930090000:178-226) - absichtlich
-- aufgerufen und nicht abgeschrieben. Diese Funktion traegt die
-- Herkunftsspur (event_duty_station_source), die Pruefung auf den richtigen
-- Verein und die Absage-Sperre. Eine zweite Fassung davon waere die naechste
-- Stelle, die beim naechsten Umbau vergessen wird.
create or replace function public.bewirtungsplan_anwenden(
  target_club uuid, target_template uuid, von date, bis date)
returns jsonb
language plpgsql security definer set search_path to 'public' as $function$
declare
  ev            record;
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
    raise exception 'Zeitraum unvollstaendig' using errcode = '22007', hint = 'bad_range';
  end if;
  /* Zwei Jahre sind reichlich fuer jede Saison. Die Grenze steht nicht gegen
     Boeswilligkeit - wer das Set pflegen darf, darf es anwenden -, sondern
     gegen den Vertipper: "1.10.2026 bis 1.10.2206" liefe sonst ueber jeden
     Termin, den der Verein je anlegt. */
  if bis - von > 730 then
    raise exception 'Zeitraum zu lang' using errcode = '22023', hint = 'range_too_long';
  end if;
  if not exists (select 1 from public.duty_task_templates t
                  where t.id = target_template and t.club_id = target_club) then
    raise exception 'Template belongs to a different club' using errcode = '42501';
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
    /* Null neue Stationen heisst: Das Set lag hier schon an. Kein Fehler,
       aber der Betreiber soll die Zahl sehen - sonst wundert er sich, warum
       "17 Spiele" und "0 Stationen" zugleich dastehen. */
    if coalesce(v_dazu, 0) = 0 then v_ohne_neue := v_ohne_neue + 1; end if;
  end loop;

  return jsonb_build_object(
    'spiele', v_spiele, 'stationen_neu', v_neu, 'schon_vollstaendig', v_ohne_neue,
    'uebergangen_vergangen', v_vergangen, 'uebergangen_abgesagt', v_abgesagt);
end;
$function$;

revoke all on function public.bewirtungsplan_anwenden(uuid, uuid, date, date) from public, anon;
grant execute on function public.bewirtungsplan_anwenden(uuid, uuid, date, date) to authenticated;

-- ------------------------------------------------- 3. Erinnerung am Vorabend
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
    perform public.notify_uebersetzt(d.membership_id, 'duty',
      'helfer.erinnerung.titel', 'helfer.erinnerung.text',
      jsonb_build_object('titel', d.title, 'station', d.station,
                         'datum', jsonb_build_object('zeit', d.starts_at, 'uhrzeit', true)),
      jsonb_build_object('ziel_art', 'termin', 'ziel_id', d.event_id));
    /* Einzeln gesetzt, nicht am Ende in einem Rutsch: Bricht der Lauf in der
       Mitte ab, sind die bereits Benachrichtigten vermerkt und bekommen die
       Meldung beim naechsten Lauf nicht ein zweites Mal. */
    update public.duty_assignments set erinnert_am = now() where id = d.id;
  end loop;
end;
$function$;

-- pg_cron ruft sie als postgres auf, die App nie. Vorbild: 20260914110000:380-388.
revoke execute on function public.run_bewirtung_erinnerung() from public, anon, authenticated;

/* Um 18 Uhr, wie die Aufgaben-Erinnerung (20260905200000:187-191): frueh
   genug, um am Abend vorher noch zu tauschen, spaet genug, um nicht im
   Morgentrubel unterzugehen.
   Der Auftrag steht ABSICHTLICH in der Migration. Die beiden
   Helferdienst-Auftraege wurden seinerzeit von Hand in PROD angelegt und
   stehen nur in PROJECT_STATE.md:377 - wer die Datenbank neu aufsetzt,
   bekommt sie nicht mit. */
select cron.unschedule('bewirtung-erinnerung')
 where exists (select 1 from cron.job where jobname = 'bewirtung-erinnerung');
select cron.schedule('bewirtung-erinnerung', '0 18 * * *',
  $$select public.run_bewirtung_erinnerung();$$);

-- ------------------------------------------------- 4. Die Meldungstexte
insert into public.meldungstexte (schluessel, sprache, text) values
  ('helfer.erinnerung.titel','de','Morgen bist du eingeteilt'),
  ('helfer.erinnerung.titel','en','You are on duty tomorrow'),
  ('helfer.erinnerung.titel','es','Mañana te toca'),
  ('helfer.erinnerung.titel','pt','Amanhã é a tua vez'),
  ('helfer.erinnerung.titel','it','Domani tocca a te'),
  ('helfer.erinnerung.titel','tr','Yarın görevlisin'),
  ('helfer.erinnerung.titel','fr','Tu es de service demain'),
  ('helfer.erinnerung.text','de','„{titel}“ am {datum} – du stehst an der Station „{station}“.'),
  ('helfer.erinnerung.text','en','“{titel}” on {datum} – you are assigned to “{station}”.'),
  ('helfer.erinnerung.text','es','«{titel}» el {datum}: te corresponde el puesto «{station}».'),
  ('helfer.erinnerung.text','pt','«{titel}» no dia {datum} – estás no posto «{station}».'),
  ('helfer.erinnerung.text','it','«{titel}» il {datum}: sei alla postazione «{station}».'),
  ('helfer.erinnerung.text','tr','{datum} tarihindeki „{titel}“ – „{station}“ görevindesin.'),
  ('helfer.erinnerung.text','fr','« {titel} » le {datum} – tu es au poste « {station} ».')
on conflict (schluessel, sprache) do update set text = excluded.text;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: anwenden_da = true, erinnerung_da = true, spalte_da = true,
--           auftrag_da = 1, texte_vollstaendig = 14,
--           anwenden_nutzt_vorlage = true, erinnerung_sperrt = true,
--           anwenden_fuer_angemeldete = true, erinnerung_nur_cron = true.
--
-- Der Nachweis, dass die Anwendung WIRKT, ist der Lauf gegen PROD: Zeitraum
-- ueber die Heimspiele waehlen, Rueckmeldung lesen, Stationen am Termin
-- nachzaehlen. Die Kontrolle hier liest nur - sie kann nicht sehen, ob die
-- Schleife laeuft. (Lektion vom 28.09.: "Die Kontrolle liest, der Nachweis
-- laeuft.")
select
  (select count(*) = 1 from pg_proc where proname = 'bewirtungsplan_anwenden') as anwenden_da,
  (select count(*) = 1 from pg_proc where proname = 'run_bewirtung_erinnerung') as erinnerung_da,
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'duty_assignments'
      and column_name = 'erinnert_am') as spalte_da,
  (select count(*) from cron.job where jobname = 'bewirtung-erinnerung') as auftrag_da,
  (select count(*) from public.meldungstexte
    where schluessel in ('helfer.erinnerung.titel','helfer.erinnerung.text')) as texte_vollstaendig,
  /* Ruft sie wirklich die vorhandene Funktion auf, statt sie abzuschreiben? */
  (select pg_get_functiondef(oid) like '%apply_duty_template%'
     from pg_proc where proname = 'bewirtungsplan_anwenden') as anwenden_nutzt_vorlage,
  /* Setzt die Erinnerung die Sperre? Ohne sie kaeme sie taeglich erneut. */
  (select pg_get_functiondef(oid) like '%erinnert_am = now()%'
     from pg_proc where proname = 'run_bewirtung_erinnerung') as erinnerung_sperrt,
  /* Die Rechte: anwenden darf die angemeldete Leitung, erinnern nur pg_cron. */
  has_function_privilege('authenticated',
    'public.bewirtungsplan_anwenden(uuid,uuid,date,date)', 'execute') as anwenden_fuer_angemeldete,
  not has_function_privilege('authenticated',
    'public.run_bewirtung_erinnerung()', 'execute') as erinnerung_nur_cron;
