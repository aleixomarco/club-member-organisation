-- Die Sperrliste hängt am Profil, nicht an der Mitgliedschaft.
--
-- Eine Nachricht im Chat trägt die Kennung ihres Verfassers als Profil
-- (messages.author_id -> profiles.id). Eine Sperrliste, die Mitgliedschaften
-- führt, müsste bei jeder Nachricht erst übersetzen — und scheitert bei jedem,
-- der inzwischen aus dem Verein ausgetreten ist, denn dann gibt es die
-- Mitgliedschaft nicht mehr, seine alten Nachrichten aber schon.
--
-- Der Verein bleibt trotzdem dabei: Wer jemanden im einen Verein nicht mehr
-- sehen will, meint damit nicht zwangsläufig den anderen.

alter table public.blocked_authors drop column if exists blocked_membership_id;
alter table public.blocked_authors
  add column if not exists blocked_profile_id uuid references public.profiles(id) on delete cascade;

-- Erst nach dem Hinzufügen: Die Spalte muss existieren, bevor sie Pflicht wird.
update public.blocked_authors set blocked_profile_id = profile_id where blocked_profile_id is null;
alter table public.blocked_authors alter column blocked_profile_id set not null;

alter table public.blocked_authors drop constraint if exists blocked_authors_profile_id_blocked_membership_id_key;
create unique index if not exists blocked_authors_einmalig
  on public.blocked_authors(profile_id, club_id, blocked_profile_id);

-- Sich selbst zu sperren ergibt keinen Sinn und würde nur die eigene Ansicht
-- halbieren.
alter table public.blocked_authors drop constraint if exists blocked_authors_nicht_selbst;
alter table public.blocked_authors
  add constraint blocked_authors_nicht_selbst check (blocked_profile_id <> profile_id);
