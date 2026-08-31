-- Umfragen: die vorhandenen Tabellen endlich benutzen.
--
-- polls, poll_options und poll_votes stehen seit dem Ursprungsschema in der
-- Datenbank — nur hat die App sie nie angefasst. Umfragen samt Stimmen lagen
-- stattdessen im gemeinsamen Zustandsblock, und der wird ausschließlich von
-- Administratoren geschrieben. Ein Mitglied konnte also abstimmen, seine
-- Stimme landete im Arbeitsspeicher und war beim nächsten Öffnen weg. Eine
-- Mitmach-Umfrage, bei der das Mitmachen nicht ankommt.
--
-- Hier wird deshalb nichts neu erfunden, sondern nachgezogen, was an den
-- vorhandenen Tabellen fehlt.

-- 1. Eine Stimme muss zu einer Antwort DIESER Umfrage gehören.
--
-- Die Insert-Regel prüfte bisher nur, dass die Umfrage läuft und der Abstimmende
-- Mitglied ist - nicht aber, dass option_id zu poll_id passt. Damit liess sich
-- fuer eine fremde Umfrage abstimmen: Die Stimme zählte dort, wo die Antwort
-- hingehört, und blieb in der eigenen Umfrage unsichtbar.
drop policy if exists "members cast own vote" on public.poll_votes;
create policy "members cast own vote" on public.poll_votes for insert to authenticated with check (
  profile_id = auth.uid()
  and exists (select 1 from public.polls p where p.id = poll_votes.poll_id and p.active and public.is_club_member(p.club_id))
  and exists (select 1 from public.poll_options o where o.id = poll_votes.option_id and o.poll_id = poll_votes.poll_id)
);

-- 2. Seine Meinung darf man ändern.
--
-- Bisher gab es nur DELETE und INSERT. Der Schlüssel (poll_id, profile_id)
-- laesst genau eine Zeile zu, ein zweiter Versuch scheiterte also - und ohne
-- UPDATE-Regel blieb nur "loeschen und neu abstimmen". Das ist ein Umweg, den
-- niemand braucht.
drop policy if exists "members change own vote" on public.poll_votes;
create policy "members change own vote" on public.poll_votes for update to authenticated
using (profile_id = auth.uid())
with check (
  profile_id = auth.uid()
  and exists (select 1 from public.poll_options o where o.id = poll_votes.option_id and o.poll_id = poll_votes.poll_id)
);

drop policy if exists "members withdraw own vote" on public.poll_votes;
create policy "members withdraw own vote" on public.poll_votes for delete to authenticated
using (profile_id = auth.uid());

-- 3. Reste des ersten, verworfenen Anlaufs entfernen.
--
-- polls hat keine Spalte updated_at; der Trigger haette bei jeder Aenderung
-- einen Fehler geworfen.
drop trigger if exists polls_touch on public.polls;
drop policy if exists "umfragen lesbar" on public.polls;
drop policy if exists "umfragen pflegen" on public.polls;
drop policy if exists "antworten lesbar" on public.poll_options;
drop policy if exists "antworten pflegen" on public.poll_options;
drop policy if exists "stimmen lesbar" on public.poll_votes;
drop policy if exists "eigene stimme abgeben" on public.poll_votes;
drop policy if exists "eigene stimme aendern" on public.poll_votes;
drop policy if exists "eigene stimme zuruecknehmen" on public.poll_votes;
drop index if exists public.polls_club_idx;
drop index if exists public.poll_options_poll_idx;
drop index if exists public.poll_votes_poll_idx;

create index if not exists polls_club_created_idx on public.polls(club_id, created_at desc);
create index if not exists poll_options_reihenfolge_idx on public.poll_options(poll_id, position);
create index if not exists poll_votes_umfrage_idx on public.poll_votes(poll_id);

grant select, insert, update, delete on public.polls to authenticated;
grant select, insert, update, delete on public.poll_options to authenticated;
grant select, insert, update, delete on public.poll_votes to authenticated;
