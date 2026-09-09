/* Zwei Kleinigkeiten, die der Datenbank-Pruefer meldet.

 * 1. ZWEI IDENTISCHE INDIZES AUF events(series_id)
 *    events_series_idx      -- aus 20260902130000
 *    events_series_id_idx   -- in keiner Migration; von Hand angelegt
 *    Beide sind bis aufs Zeichen gleich:
 *      btree (series_id) WHERE (series_id IS NOT NULL)
 *    Jede Zeile in events wird damit zweimal indiziert - bei jedem Anlegen,
 *    jeder Aenderung, jeder Absage. Eine Serie legt bis zu 85 Zeilen in einer
 *    Anweisung an; das ist die Stelle, an der es sich am ehesten bemerkbar
 *    macht.
 *    Entfernt wird der, den KEINE Migration kennt. Danach beschreiben die
 *    Migrationen den Stand wieder vollstaendig.
 *
 * 2. FESTER SUCHPFAD FUER abgeschaffte_rolle_ablehnen
 *    Die einzige Funktion im Schema ohne "set search_path". Sie ist nicht
 *    SECURITY DEFINER, das Risiko ist also gering - aber sie ist der einzige
 *    Ausreisser, und ein fester Suchpfad kostet nichts. Wer eine Funktion
 *    ohne ihn laesst, muss sich bei jeder Aenderung neu fragen, ob es hier
 *    Absicht war. Mit ihm nicht mehr.
 *    Der Rumpf bleibt bis auf EINE Stelle woertlich: Die Meldung nannte
 *    Vorstand, Geschaeftsfuehrung und Finanzmanager, nicht aber "eltern" -
 *    obwohl die Pruefung darueber genauso stolpert. Wer die Rolle Eltern zu
 *    vergeben versucht, las bisher eine Begruendung, die seinen Fall nicht
 *    erwaehnt. Jetzt steht sie mit drin.
 */

drop index if exists public.events_series_id_idx;

create or replace function public.abgeschaffte_rolle_ablehnen()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.role in ('vorstand', 'geschaeftsfuehrung', 'finanzmanager', 'eltern') then
    raise exception 'Die Rolle % wurde abgeschafft. Vorstand, Geschaeftsfuehrung und Finanzmanager sind im Vereins-Administrator aufgegangen; Eltern gibt es als Rolle nicht mehr.', new.role
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;
