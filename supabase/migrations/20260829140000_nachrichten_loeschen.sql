-- Gemeldete Nachrichten müssen entfernt werden können.
--
-- Auf messages gab es bisher nur select und insert. Niemand konnte eine
-- Nachricht löschen - auch der Vorstand nicht, und auch nicht der Verfasser
-- selbst. Der Meldeknopf im Chat öffnete also eine E-Mail, auf die hin nichts
-- geschehen konnte.
--
-- Apple verlangt unter Richtlinie 1.2 bei nutzergenerierten Inhalten vier
-- Dinge: Filtern, Melden, Blockieren und eine erreichbare Kontaktadresse. Die
-- vier waren erfüllt. Was fehlte, war die Möglichkeit, auf eine Meldung auch zu
-- reagieren - "timely responses to concerns" bleibt ohne Löschrecht eine
-- Zusage, die niemand einhalten kann.
--
-- Zwei Wege, bewusst getrennt:
--   1. Wer etwas geschrieben hat, darf es zurücknehmen.
--   2. Die Vereinsleitung darf jede Nachricht ihres Vereins entfernen.
-- Trainer und Kapitäne bleiben aussen vor: Sie dürfen in ihrem Kanal schreiben,
-- aber die Moderation gehört zur Vereinsverantwortung, sonst löscht der Kapitän
-- die unbequeme Nachricht seines Trainers.

drop policy if exists "authors delete own messages" on public.messages;
create policy "authors delete own messages" on public.messages for delete to authenticated using (
  author_id = auth.uid()
);

drop policy if exists "club leadership deletes messages" on public.messages;
create policy "club leadership deletes messages" on public.messages for delete to authenticated using (
  exists (
    select 1 from public.channels c
    where c.id = channel_id
      and public.has_club_role(
        c.club_id,
        array['vorstand', 'geschaeftsfuehrung', 'vereinsadmin', 'sysadmin']::public.club_role[]
      )
  )
);

-- Damit die Löschung bei allen anderen Geräten ankommt und nicht nur beim
-- Löschenden verschwindet, muss die Zeile im Realtime-Ereignis vollständig
-- mitgeschickt werden. Ohne "replica identity full" enthält ein DELETE nur den
-- Primärschlüssel - die Oberfläche wüsste dann nicht, aus welchem Kanal die
-- Nachricht kam.
alter table public.messages replica identity full;

-- Kontrolle: sollte vier Regeln zeigen (lesen, schreiben, zwei mal löschen).
select policyname, cmd from pg_policies
where schemaname = 'public' and tablename = 'messages'
order by cmd, policyname;
