-- Einzelne Termine liessen sich nie loeschen
--
-- Auf public.events ist RLS eingeschaltet (20260801160000_initial_schema.sql:377),
-- es gibt aber nur Regeln fuer select, insert und update — KEINE fuer delete.
-- Unter RLS heisst "keine Regel" nicht "erlaubt", sondern "verboten". Ein
-- `delete from events` vom Client loescht deshalb grundsaetzlich null Zeilen,
-- und zwar ohne Fehler: PostgREST liefert eine leere Antwort, kein Problem.
--
-- Aufgefallen ist es nie, weil die Oberflaeche den Termin trotzdem aus ihrer
-- Liste nahm. Er war weg — bis zum naechsten Laden. Die Mannschaft sah ihn
-- die ganze Zeit.
--
-- Die Regel ist wortgleich zur bestehenden update-Regel (Zeile 449): Wer einen
-- Termin absagen darf, darf ihn auch loeschen. Das ist bewusst dieselbe
-- Schwelle und keine neue — die Serie loescht ueber public.delete_event_series
-- schon lange mit genau dieser Bedingung (20260902190000, Zeile 208-213).
-- Ohne diese Regel waere das Loeschen einer ganzen Serie erlaubt, das eines
-- einzelnen Termins aber nicht.

drop policy if exists "authorized roles delete events" on public.events;
create policy "authorized roles delete events" on public.events for delete using (
  public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[])
  or (team_id is not null and public.can_manage_team(team_id))
);

-- Kontrolle: es muessen jetzt vier Regeln stehen (select, insert, update, delete)
select cmd, policyname from pg_policies
where schemaname = 'public' and tablename = 'events'
order by cmd;
