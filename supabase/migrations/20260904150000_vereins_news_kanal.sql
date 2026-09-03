-- Vereins-News als Kanal, den jedes Mitglied sieht
--
-- Bisher gab es im Chat nur Mannschaftskanäle. Für eine Mitteilung an den
-- ganzen Verein war damit kein Ort da: Wer alle erreichen wollte, musste sie
-- in jeden Mannschaftskanal einzeln schreiben - und Mitglieder ohne
-- Mannschaft, etwa Fördermitglieder oder der Vorstand, standen in gar keinem
-- Kanal und sahen einen leeren Chat.
--
-- Die Sichtbarkeitsregel aus 20260825230000_chat_je_mannschaft.sql kennt den
-- vereinsweiten Kanal bereits:
--   (team_id is null and (cardinality(visible_roles) = 0 or ...))
-- Ein leeres visible_roles heißt dort ausdrücklich "alle". Genau das wird
-- hier benutzt - es braucht keine neue Regel, nur den Kanal.
--
-- Schreiben dürfen die, die ohnehin für den Verein sprechen: Redaktion,
-- Vorstand, Geschäftsführung und die Vereinsverwaltung. Alle anderen lesen
-- mit. Das entspricht dem Reiter "Redaktion", der die News verfasst.

-- ---------------------------------------------------------- Bestehende Vereine

insert into public.channels (club_id, name, emoji, team_id, write_roles, visible_roles)
select c.id, 'Vereins-News', '📣', null,
       array['redakteur','vorstand','geschaeftsfuehrung','vereinsadmin','sysadmin']::public.club_role[],
       '{}'::public.club_role[]
from public.clubs c
where not exists (
  select 1 from public.channels ch
  where ch.club_id = c.id and ch.team_id is null and ch.name = 'Vereins-News'
);

-- -------------------------------------------------------------- Neue Vereine

/* Neue Vereine bekommen den Kanal automatisch. Sonst müsste jemand daran
   denken, und irgendwann fehlt er - genau wie bei den Mannschaftskanälen. */
create or replace function public.kanal_fuer_neuen_verein()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.channels (club_id, name, emoji, team_id, write_roles, visible_roles)
  values (new.id, 'Vereins-News', '📣', null,
          array['redakteur','vorstand','geschaeftsfuehrung','vereinsadmin','sysadmin']::public.club_role[],
          '{}'::public.club_role[])
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists clubs_newskanal_anlegen on public.clubs;
create trigger clubs_newskanal_anlegen
  after insert on public.clubs
  for each row execute function public.kanal_fuer_neuen_verein();

/* Zwei News-Kanäle je Verein wären ein Fehler, kein Zustand. Der Index macht
   das unmöglich - auch für einen späteren zweiten Durchlauf dieser Datei. */
create unique index if not exists ein_newskanal_je_verein
  on public.channels (club_id)
  where team_id is null and name = 'Vereins-News';

-- Kontrolle
select c.name as verein, ch.name as kanal, ch.emoji, ch.write_roles, ch.visible_roles
from public.clubs c
left join public.channels ch on ch.club_id = c.id and ch.team_id is null
order by c.name;
