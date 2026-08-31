-- Fremde Tipps erst, wenn das Ergebnis feststeht.
--
-- "members read predictions" liess jedes Mitglied jeden Tipp lesen — auch vor
-- dem Spiel. Wer die Rangliste ernst nimmt, schaut vorher nach, was die
-- anderen getippt haben, und tippt daneben. Aufgefallen ist das nie, weil die
-- Tabelle bis heute leer war: Die Tipps lagen im Arbeitsspeicher.
--
-- Die Rangliste braucht die fremden Tipps trotzdem — nur eben erst dann, wenn
-- gerechnet wird, und das ist genau der Moment, in dem das Ergebnis eingetragen
-- ist.

drop policy if exists "members read predictions" on public.predictions;
create policy "members read predictions" on public.predictions for select to authenticated using (
  exists (select 1 from public.events e where e.id = predictions.event_id and public.is_club_member(e.club_id))
  and (
    predictions.profile_id = auth.uid()
    or exists (select 1 from public.event_results r where r.event_id = predictions.event_id)
  )
);

-- Und ein Tipp nach dem Abpfiff ist kein Tipp.
drop policy if exists "members manage own predictions" on public.predictions;
create policy "members manage own predictions" on public.predictions for all to authenticated
using (profile_id = auth.uid())
with check (
  profile_id = auth.uid()
  and not exists (select 1 from public.event_results r where r.event_id = predictions.event_id)
);
