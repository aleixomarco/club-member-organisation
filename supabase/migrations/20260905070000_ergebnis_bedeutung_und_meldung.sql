-- Spielergebnisse: festhalten, was die Spalten bedeuten - und daraus melden.
--
-- ANLASS
-- Im Formular der Vereinsleitung standen zwei nackte Zahlenfelder ohne
-- Beschriftung: Der Code las dort match.home und match.away, Eigenschaften, die
-- es auf dem Objekt gar nicht gibt (tippBegegnungen liefert id, titel, team,
-- heim, date). Wer ein Ergebnis eintrug, musste raten, welches Feld welches ist,
-- und die Vorlesehilfe sagte "Tore undefined".
--
-- Der Betreiber hat die gelebte Praxis bestaetigt: LINKS stehen immer die
-- eigenen Tore, RECHTS die des Gegners - unabhaengig davon, ob heim oder
-- auswaerts gespielt wurde.
--
-- Die Spaltennamen sagen etwas anderes. Sie stammen aus der Zeit, als die
-- Tabelle noch tipp_results hiess (20260901130000, Zeile 32-33) und spaeter in
-- event_results umbenannt wurde (20260901170000, Zeile 15). "heim" und
-- "auswaerts" liest jeder als Heimmannschaft und Gastmannschaft - gemeint ist
-- aber wir und der Gegner.
--
-- UMBENANNT WERDEN SIE TROTZDEM NICHT. Ein Spaltenumbenennen in der laufenden
-- Datenbank bricht sofort das Lesen in app/page.tsx (select event_id,heim,
-- auswaerts) und das Schreiben beim Speichern eines Ergebnisses. Die Wahrheit
-- gehoert deshalb in einen Kommentar an die Spalte, wo sie jeder findet, der
-- das Schema liest - und in die Beschriftung im Formular, wo sie der braucht,
-- der das Ergebnis eintraegt.

comment on column public.event_results.heim is
  'Unsere Tore. ACHTUNG: NICHT die Tore der Heimmannschaft. Der Name stammt aus der Vorgaengertabelle tipp_results und ist irrefuehrend. Ob heim oder auswaerts gespielt wurde, steht an events.home_away.';
comment on column public.event_results.auswaerts is
  'Die Tore des Gegners. ACHTUNG: NICHT die Tore der Gastmannschaft. Siehe Kommentar an der Spalte heim.';

/* --------------------------------------------------------------------------
   Meldung beim Eintragen eines Ergebnisses.

   Empfaenger ist, wer diese Mannschaft als seine Ansicht gespeichert hat -
   club_memberships.team_filter (angelegt 20260901170000, Zeile 66; vom Mitglied
   selbst pflegbar seit 20260901230000). Der Betreiber hat entschieden, dieses
   vorhandene Feld wiederzuverwenden, statt eine zweite Einstellung daneben zu
   stellen: Wofuer man sich beim Filtern interessiert, ist in aller Regel genau
   die Mannschaft, deren Ergebnis man wissen will. Ein Feld, das man an einer
   Stelle pflegt.

   Heim oder auswaerts kommt aus events.home_away (initial_schema, Zeile 109),
   einem Textfeld mit genau zwei erlaubten Werten. Sieg, Unentschieden und
   Niederlage kommen aus dem Vergleich heim/auswaerts - also wir gegen Gegner.

   Die Zahlenfolge im Text ist Absicht und folgt der Vorgabe des Betreibers:
   Beim Sieg steht unser Ergebnis vorn, bei der Niederlage das des Gegners. So
   steht in beiden Faellen die hoehere Zahl vorn, wie man es beim Erzaehlen
   auch sagt.

   Der Trigger laeuft auf INSERT und auf UPDATE, aber beim UPDATE nur, wenn sich
   an den Toren wirklich etwas geaendert hat. Sonst schickte jede Korrektur an
   einer Nebensache - und jedes blosse Neuspeichern - noch einmal dieselbe
   Nachricht.

   public.notify(...) wird hier bewusst aufgerufen und NICHT neu definiert: Die
   Funktion existiert nur in der Live-Datenbank und ist in keiner Migration
   festgehalten. Sie zu ueberschreiben, ohne ihren Rumpf lesen zu koennen,
   wuerde die heute funktionierenden Meldungen (Chat, Mitgliedschaft) gefaehrden.
   Dass sie fehlt, bleibt eine offene Baustelle - ein Aufbau allein aus diesen
   Dateien laeuft deshalb nicht durch.
   -------------------------------------------------------------------------- */

create or replace function public.ergebnis_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_event      record;
  v_vereinsname text;
  v_mannschaft text;
  v_spielart   text;
  v_titel      text;
  v_empfaenger record;
begin
  -- Nur wenn sich die Tore geaendert haben.
  if tg_op = 'UPDATE'
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  select e.team_id, e.home_away, e.club_id
    into v_event
    from public.events e
   where e.id = new.event_id;
  -- "not found" statt "v_event is null": Ein Datensatz gilt nur dann als null,
  -- wenn ALLE seine Felder null sind - home_away darf aber null sein.
  if not found then return new; end if;

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

  -- Ohne Mannschaft am Termin gibt es niemanden, der sie als Ansicht
  -- gespeichert haben koennte - dann ist hier nichts zu tun.
  if v_mannschaft is null then return new; end if;

  v_spielart := case when v_event.home_away = 'heim' then 'Heimspiel' else 'Auswärtsspiel' end;

  v_titel := case
    when new.heim > new.auswaerts then
      coalesce(v_vereinsname, 'Verein') || ': Das ' || v_spielart || ' der ' || v_mannschaft
        || ' haben wir mit ' || new.heim || ':' || new.auswaerts || ' gewonnen!'
    when new.heim = new.auswaerts then
      coalesce(v_vereinsname, 'Verein') || ': Das ' || v_spielart || ' der ' || v_mannschaft
        || ' geht mit einem ' || new.heim || ':' || new.auswaerts || ' unentschieden aus!'
    else
      coalesce(v_vereinsname, 'Verein') || ': Das ' || v_spielart || ' der ' || v_mannschaft
        || ' haben wir mit ' || new.auswaerts || ':' || new.heim || ' verloren!'
  end;

  for v_empfaenger in
    select m.id
      from public.club_memberships m
     where m.club_id = new.club_id
       and m.status = 'active'
       and m.profile_id is not null
       and m.team_filter = v_mannschaft
  loop
    perform public.notify(v_empfaenger.id, 'results'::text, v_titel::text, null::text);
  end loop;

  return new;
end;
$$;

drop trigger if exists event_results_melden on public.event_results;
create trigger event_results_melden after insert or update on public.event_results
for each row execute function public.ergebnis_melden();

-- Kontrolle: Der Trigger muss stehen.
select tgname from pg_trigger
where tgrelid = 'public.event_results'::regclass and not tgisinternal
order by tgname;
