-- Was noch keine Tabelle hatte — und eine, die ich zu viel gebaut habe.
--
-- Für fast alles, was im gemeinsamen Zustandsblock lag, gibt es seit dem
-- Ursprungsschema eine Tabelle: predictions, season_votes, duty_assignments,
-- protocols, protocol_tasks, polls, club_settings. Benutzt hat sie nie jemand.
-- Der Umbau besteht deshalb überwiegend daraus, die App daran anzuschliessen.
--
-- tipp_predictions war meine eigene Dopplung von predictions und fliegt wieder
-- raus, bevor Daten darin liegen. tipp_results bleibt, heisst aber jetzt
-- event_results: Es ist das Ergebnis einer Begegnung, nicht eine Eigenschaft
-- des Tippspiels.

drop table if exists public.tipp_predictions;

alter table if exists public.tipp_results rename to event_results;
comment on table public.event_results is
  'Das Endergebnis einer Begegnung. Traegt die Vereinsleitung ein; das Tippspiel rechnet daran seine Punkte aus.';

/* Verschickte Zahlungserinnerungen.
 *
 * Lag als { mitgliedsId: true } im Zustandsblock. Zwei Folgen: Der Merker ging
 * verloren, sobald ein anderer Administrator speicherte, und niemand konnte
 * sehen, wann erinnert wurde. Eine Erinnerung ist ein Vorgang mit Zeitpunkt,
 * kein Haken. */
create table if not exists public.fee_reminders (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  jahr integer not null default extract(year from now())::integer,
  gesendet_am timestamptz not null default now(),
  gesendet_von uuid references public.club_memberships(id) on delete set null,
  unique (membership_id, jahr)
);

create index if not exists fee_reminders_club_idx on public.fee_reminders(club_id, jahr);

alter table public.fee_reminders enable row level security;

drop policy if exists "erinnerungen lesbar" on public.fee_reminders;
create policy "erinnerungen lesbar" on public.fee_reminders
for select to authenticated using (
  public.has_club_role(club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','finanzmanager']::public.club_role[])
);

drop policy if exists "erinnerungen setzen" on public.fee_reminders;
create policy "erinnerungen setzen" on public.fee_reminders
for all to authenticated
using (public.has_club_role(club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','finanzmanager']::public.club_role[]))
with check (public.has_club_role(club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','finanzmanager']::public.club_role[]));

/* Die Reihenfolge der Kacheln auf der Startseite.
 *
 * Sie lag im Zustandsblock des VEREINS - eine persoenliche Vorliebe, die jeder
 * Administrator fuer alle anderen mitgeaendert hat. Sie gehoert ans Profil. */
alter table public.profiles
  add column if not exists dashboard_tile_order text[];

comment on column public.profiles.dashboard_tile_order is
  'Persoenliche Reihenfolge der Kacheln auf der Startseite. Null bedeutet: die Voreinstellung.';

/* Der Mannschaftsfilter im Terminkalender.
 *
 * Lag im Geraetespeicher. Er gehoert zur Mitgliedschaft, nicht zum Geraet: Wer
 * auf dem Telefon "U15" eingestellt hat, will das auf dem Tablet auch. */
alter table public.club_memberships
  add column if not exists team_filter text;

/* Wen jemand im Chat nicht mehr sehen will.
 *
 * Lag als Namensliste im Geraetespeicher. Damit war die Sperre nach einer
 * Neuinstallation weg, galt nicht auf dem zweiten Geraet, und sie traf ueber
 * den Namen - zwei Mitglieder mit demselben Namen liessen sich nicht trennen,
 * eine Umbenennung hob sie auf.
 *
 * Apple verlangt bei nutzergenerierten Inhalten Melden UND Blockieren
 * (Richtlinie 1.2). Eine Sperre, die beim naechsten Start verdunstet, erfuellt
 * das nicht.
 *
 * Es bleibt dabei, dass die Sperre nur die eigene Ansicht betrifft - sie ist
 * kein Vereinsausschluss. Deshalb sieht sie auch niemand ausser dem, der sie
 * gesetzt hat. */
create table if not exists public.blocked_authors (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  blocked_membership_id uuid not null references public.club_memberships(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (profile_id, blocked_membership_id)
);

create index if not exists blocked_authors_profil_idx on public.blocked_authors(profile_id, club_id);

alter table public.blocked_authors enable row level security;

drop policy if exists "eigene sperrliste lesbar" on public.blocked_authors;
create policy "eigene sperrliste lesbar" on public.blocked_authors
for select to authenticated using (profile_id = auth.uid());

drop policy if exists "eigene sperrliste pflegen" on public.blocked_authors;
create policy "eigene sperrliste pflegen" on public.blocked_authors
for all to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid() and public.is_club_member(club_id));

-- Die vorhandenen Tabellen hatten Regeln, aber keine ausdruecklichen Rechte.
-- In Supabase greifen zwar Standardrechte fuer public; sich darauf zu
-- verlassen, waere aber eine Wette auf eine Voreinstellung.
grant select, insert, update, delete on
  public.predictions, public.event_results, public.season_votes,
  public.duty_assignments, public.protocols, public.protocol_tasks,
  public.club_settings, public.polls, public.poll_options, public.poll_votes,
  public.fee_reminders, public.blocked_authors
to authenticated;
