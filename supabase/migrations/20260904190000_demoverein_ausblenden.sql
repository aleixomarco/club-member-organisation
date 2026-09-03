-- Der Demo-Verein verschwindet aus der Vereinssuche
--
-- Ausgangslage: Die Leseregel lautet
--   create policy "clubs are discoverable" on public.clubs for select using (true)
-- Jeder Verein steht damit in der Auswahlliste - auch "SV Musterstadt", der
-- allein für die Prüfung durch Apple existiert. Ein echter Verein, der sich
-- registriert, sieht ihn zwischen den echten stehen.
--
-- Warum ausblenden und nicht löschen: Der Zugang demo@idbranding.de steht in
-- den App-Prüfungsinformationen. Apple prüft damit JEDES künftige Update.
-- Wäre der Verein gelöscht, meldete der Prüfer sich an und sähe eine leere
-- App - genau der Zustand, der schon einmal zur Ablehnung nach Richtlinie 1.2
-- geführt hat (siehe 20260904130000_demoverein_chat.sql).
--
-- Die Regel bleibt deshalb unangetastet: Wer im Verein Mitglied ist, liest ihn
-- weiter, und der Prüfer kommt hinein, ohne suchen zu müssen. Nur die
-- Suchansicht überspringt gekennzeichnete Vereine.
--
-- Umkehrbar mit einer Zeile:
--   update public.clubs set hidden = false where id = 'd0000000-0000-4000-a000-000000000001';

alter table public.clubs
  add column if not exists hidden boolean not null default false;

comment on column public.clubs.hidden is
  'true = erscheint nicht in der Vereinssuche. Mitglieder und die Prüfung erreichen den Verein weiterhin.';

update public.clubs
   set hidden = true
 where id = 'd0000000-0000-4000-a000-000000000001';

-- Kontrolle: welche Vereine sind sichtbar, welcher nicht
select name, short_name, hidden
  from public.clubs
 order by hidden, name;
