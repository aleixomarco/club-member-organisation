/* Wer eine Aufgabe aus einem Protokoll bekommt, muss sie auch sehen koennen.
 *
 * Die Leseregel auf protocol_tasks haengt am Protokoll:
 *
 *   exists (select 1 from protocols p where p.id = protocol_tasks.protocol_id)
 *
 * Dieses select unterliegt selbst der Regel auf protocols - lesbar ist ein
 * Protokoll fuer den Vorstand, fuer die eingetragenen Teilnehmer und fuer
 * alle, wenn es oeffentlich geschaltet ist.
 *
 * Damit fiel ein Fall heraus, und ausgerechnet der wichtigste: Jemand bekommt
 * in einer Sitzung eine Aufgabe zugewiesen, war aber selbst nicht dabei. Er
 * steht dann in keiner Teilnehmerliste, das Protokoll ist nicht oeffentlich -
 * und seine eigene Aufgabe ist fuer ihn unsichtbar. Er kann sie weder sehen
 * noch abhaken; abhaken duerfte er sie laut der UPDATE-Regel sogar, nur
 * bekommt er die Zeile nie zu Gesicht.
 *
 * Die eigene Aufgabe wird deshalb unabhaengig vom Protokoll lesbar. Das
 * oeffnet nichts weiter: Es ist genau die eine Zeile, die ohnehin an die
 * Person adressiert ist, und der uebrige Inhalt der Sitzung bleibt
 * verschlossen.
 */

drop policy if exists "protokollaufgaben lesen" on public.protocol_tasks;
create policy "protokollaufgaben lesen" on public.protocol_tasks for select
  using (
    exists (select 1 from public.protocols p where p.id = protocol_tasks.protocol_id)
    or exists (
      select 1 from public.club_memberships m
      where m.id = protocol_tasks.assignee_membership_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );
