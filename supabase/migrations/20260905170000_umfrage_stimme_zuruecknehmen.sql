-- Eigene Umfrage-Stimme zuruecknehmen duerfen.
--
-- Die Regel gab es bereits - ich hatte sie beim Nachsehen uebersehen, weil ich
-- die Ausgabe abgeschnitten hatte. Diese Migration stellt sie nur sicher, statt
-- sie neu zu erfinden: Auf einer frischen Datenbank muss sie entstehen, auf der
-- bestehenden darf sie nicht kollidieren.
--
-- Warum sie zaehlt: Bei eingeschalteter Zeilensicherheit heisst "keine Regel"
-- nicht "erlaubt", sondern "verboten". Ohne sie haette ein DELETE nichts
-- getroffen - ohne Fehler. Die App haette "Stimme entfernt" gemeldet, und beim
-- naechsten Laden waere die Stimme wieder da gewesen: der unangenehmste aller
-- Fehler, weil er wie ein Anzeigefehler aussieht und keiner ist.
--
-- Bedingung wie beim Aendern (profile_id = auth.uid()): Wer seine Stimme
-- aendern darf, darf sie auch zuruecknehmen. Fremde Stimmen bleiben unerreichbar.
drop policy if exists "members withdraw own vote" on public.poll_votes;
create policy "members withdraw own vote" on public.poll_votes
  for delete using (profile_id = auth.uid());

select polcmd, polname from pg_policy where polrelid='public.poll_votes'::regclass order by polcmd;
