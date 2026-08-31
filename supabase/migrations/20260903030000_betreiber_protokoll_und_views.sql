-- Zwei Nachbesserungen aus der Prüfung der Betreiber-Oberfläche.

/* 1. Wer hat was freigeschaltet oder gesperrt?
 *
 * Bisher: niemand weiß es. Eine Freischaltung hinterlässt immerhin mittelbar
 * eine Spur (club_subscriptions mit provider='manual' und Belegnummer), das
 * Sperren praktisch keine — verein_sperren() setzt nur Zustände um. Wenn ein
 * Verein anruft, weil er plötzlich auf drei Zugänge zurückgefallen ist, gibt
 * es nichts nachzusehen.
 *
 * Das ist keine Überwachung des Betreibers durch sich selbst. Es ist die
 * Gegenprobe zu einem einzigen Passwort, das jeden Verein kontrolliert: Wenn
 * es einmal in falsche Hände gerät, ist der Unterschied zwischen "wir wissen,
 * was passiert ist" und "wir ahnen etwas" genau diese Tabelle. */
create table if not exists public.betreiber_protokoll (
  id uuid primary key default gen_random_uuid(),
  zeitpunkt timestamptz not null default now(),
  aktion text not null,
  club_id uuid references public.clubs(id) on delete set null,
  club_name text,
  einzelheiten jsonb not null default '{}'::jsonb,
  -- Woher der Aufruf kam. Auf Vercel setzt die Plattform diesen Wert selbst;
  -- er ist deshalb belastbarer als ein vom Absender geschriebener Kopf.
  herkunft text
);

create index if not exists betreiber_protokoll_zeit_idx on public.betreiber_protokoll(zeitpunkt desc);
create index if not exists betreiber_protokoll_club_idx on public.betreiber_protokoll(club_id, zeitpunkt desc);

alter table public.betreiber_protokoll enable row level security;
-- Keine Policy für anon oder authenticated: Diese Tabelle geht die Vereine
-- nichts an, und nur der Dienstschlüssel schreibt hinein.
revoke all on public.betreiber_protokoll from anon, authenticated;
grant select, insert on public.betreiber_protokoll to service_role;

/* 2. Der Schutz der Betreiber-Views war ein einmaliger Flicken.
 *
 * Beide Views laufen ohne security_invoker mit den Rechten ihres Eigentümers
 * und umgehen damit jede Sicherheitsregel auf clubs, club_memberships und
 * club_subscriptions. Davor stand bisher nur ein einziges revoke — und genau
 * das überlebt kein "drop view ... create view". Dass das passiert, muss man
 * nicht vermuten: offene_freischaltungen wurde in diesem Verzeichnis bereits
 * dreimal neu angelegt.
 *
 * Mit security_invoker = true laufen die Views mit den Rechten des Aufrufers.
 * Der Dienstschlüssel umgeht Sicherheitsregeln ohnehin, für ihn ändert sich
 * nichts. Aber falls ein künftiges Neuanlegen die Rechte wieder aufmacht,
 * sieht ein Vereinskonto dann nur noch seinen eigenen Verein statt aller.
 * Aus einem einzelnen Riegel wird damit ein zweiter Boden. */
alter view public.betreiber_uebersicht set (security_invoker = true);
alter view public.offene_freischaltungen set (security_invoker = true);

revoke all on public.betreiber_uebersicht from anon, authenticated;
revoke all on public.offene_freischaltungen from anon, authenticated;
grant select on public.betreiber_uebersicht to service_role;
grant select on public.offene_freischaltungen to service_role;
