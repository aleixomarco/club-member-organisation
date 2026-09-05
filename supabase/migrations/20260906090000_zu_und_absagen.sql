-- Zu- und Absagen je Termin.
--
-- Bisher wusste niemand, wer zum Training kommt. Ein Trainer konnte einen
-- Termin anlegen und absagen - aber nicht sehen, ob zwei oder zwanzig Leute
-- erscheinen. Genau das ist die Frage, die vor jedem Training im Chat steht.
--
-- KEINE ZEILE HEISST "ZUGESAGT"
-- Die naheliegende Loesung waere, beim Anlegen eines Termins fuer jedes
-- Mannschaftsmitglied eine Zeile mit "zugesagt" zu schreiben. Bei einem Verein
-- mit acht Mannschaften und woechentlichem Training waeren das Tausende
-- Zeilen, die nur sagen: nichts Besonderes. Und sie muessten mitwandern, wenn
-- jemand die Mannschaft wechselt.
--
-- Stattdessen bedeutet das FEHLEN einer Zeile "zugesagt". Geschrieben wird nur,
-- wer absagt - oder wer nach einer Absage doch wieder zusagt. Die Liste in der
-- App rechnet das zusammen: Mannschaftsmitglieder minus Absagen.
--
-- Das hat eine Folge, die man kennen muss: Man kann nicht unterscheiden
-- zwischen "hat zugesagt" und "hat noch nichts gesagt". Fuer den Zweck - wer
-- kommt zum Training - ist das richtig herum: Wer nichts sagt, wird erwartet.

create table if not exists public.event_attendance (
  event_id      uuid not null references public.events(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  status        text not null check (status in ('zugesagt', 'abgesagt')),
  note          text,
  updated_at    timestamptz not null default now(),
  primary key (event_id, membership_id)
);

create index if not exists event_attendance_event_idx on public.event_attendance (event_id);

alter table public.event_attendance enable row level security;

/* Lesen darf jedes aktive Mitglied des Vereins. Wer im Verein ist, darf wissen,
   wer zum Training kommt - das ist keine schuetzenswerte Information, sondern
   die Grundlage jeder Planung. */
drop policy if exists "club members read attendance" on public.event_attendance;
create policy "club members read attendance" on public.event_attendance
  for select using (
    exists (
      select 1 from public.events e
      join public.club_memberships m on m.club_id = e.club_id
      where e.id = event_attendance.event_id
        and m.profile_id = auth.uid() and m.status = 'active'
    )
  );

/* Schreiben darf jeder NUR fuer sich selbst. Bewusst keine Ausnahme fuer die
   Vereinsleitung: Eine Absage ist eine Aussage ueber die eigene Person. Wer
   fuer andere absagt, erzeugt eine Liste, der niemand mehr glaubt. */
drop policy if exists "members set own attendance" on public.event_attendance;
create policy "members set own attendance" on public.event_attendance
  for all using (
    membership_id in (select id from public.club_memberships where profile_id = auth.uid())
  ) with check (
    membership_id in (select id from public.club_memberships where profile_id = auth.uid())
  );

/* Wer die Liste einsehen darf: Trainer, Kapitaen und Teammanager der
   Mannschaft, dazu Organisator und Vereinsleitung. Dieselbe Regel wie beim
   Absagen eines Termins - wer den Termin verantwortet, darf wissen, wer kommt. */
create or replace function public.darf_anwesenheit_sehen(target_event uuid)
returns boolean language plpgsql stable security definer set search_path = 'public' as $$
declare ev_team uuid; ev_club uuid;
begin
  select team_id, club_id into ev_team, ev_club from public.events where id = target_event;
  if ev_club is null then return false; end if;
  if public.has_club_role(ev_club, array['vereinsadmin','sysadmin','organisator']::club_role[]) then return true; end if;
  if ev_team is not null and public.can_manage_team(ev_team) then return true; end if;
  return false;
end;
$$;

grant execute on function public.darf_anwesenheit_sehen(uuid) to authenticated, service_role;

/* Die Liste selbst - Mannschaft plus Status, in einem Aufruf.
   Ohne diese Funktion muesste die App zwei Abfragen stellen und sie im Geraet
   zusammenrechnen; bei einem Verein mit vielen Mitgliedern waere die zweite
   davon eine Liste, die den Betrachter nichts angeht. */
create or replace function public.anwesenheit_fuer_termin(target_event uuid)
returns table (membership_id uuid, name text, status text)
language plpgsql stable security definer set search_path = 'public' as $$
declare ev_team uuid; ev_club uuid;
begin
  if not public.darf_anwesenheit_sehen(target_event) then raise exception 'Not authorized'; end if;
  select e.team_id, e.club_id into ev_team, ev_club from public.events e where e.id = target_event;

  return query
  select m.id, m.display_name,
         coalesce(a.status, 'zugesagt')::text
  from public.club_memberships m
  left join public.team_members tm on tm.membership_id = m.id and tm.team_id = ev_team
  left join public.event_attendance a on a.event_id = target_event and a.membership_id = m.id
  where m.club_id = ev_club and m.status = 'active'
    and (ev_team is null or tm.membership_id is not null)
  order by coalesce(a.status,'zugesagt'), m.display_name;
end;
$$;

grant execute on function public.anwesenheit_fuer_termin(uuid) to authenticated, service_role;

select
  (select count(*) from information_schema.tables where table_schema='public' and table_name='event_attendance') as tabelle,
  (select count(*) from pg_policy where polrelid='public.event_attendance'::regclass) as regeln,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('darf_anwesenheit_sehen','anwesenheit_fuer_termin')) as funktionen;
