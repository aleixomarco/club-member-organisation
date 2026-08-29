-- Chat: Sichtbarkeit je Rolle auch in der Datenbank durchsetzen
--
-- Die Regel zum Lesen von Nachrichten prüfte bisher nur die Mitgliedschaft im
-- Verein. Das Feld visible_roles am Kanal wurde ausschließlich in der
-- Oberfläche berücksichtigt - wer den Eltern-Kanal nicht sehen sollte, bekam
-- ihn dort nicht angezeigt, hätte die Nachrichten über eine direkte Abfrage
-- aber lesen können.
--
-- Solange der Chat nichts speicherte, war das folgenlos. Ab jetzt stehen dort
-- echte Unterhaltungen, und die Sperre gehört dorthin, wo sie nicht zu umgehen
-- ist.
--
-- Leeres visible_roles heißt weiterhin "alle Vereinsmitglieder" - so sind die
-- bestehenden Kanäle angelegt, und daran ändert sich nichts.

drop policy if exists "members read messages" on public.messages;

create policy "members read messages" on public.messages for select using (
  exists (
    select 1 from public.channels c
    where c.id = channel_id
      and public.is_club_member(c.club_id)
      and (
        cardinality(c.visible_roles) = 0
        or public.has_club_role(c.club_id, c.visible_roles)
      )
  )
);

-- Dieselbe Einschränkung für die Kanalliste: Ein Kanal, dessen Nachrichten man
-- nicht lesen darf, soll auch nicht in der Übersicht auftauchen.
drop policy if exists "members read channels" on public.channels;

create policy "members read channels" on public.channels for select using (
  public.is_club_member(club_id)
  and (
    cardinality(visible_roles) = 0
    or public.has_club_role(club_id, visible_roles)
  )
);

-- Kontrolle: die beiden Regeln müssen erscheinen
select tablename, policyname
from pg_policies
where schemaname = 'public' and tablename in ('channels','messages')
order by tablename, policyname;
