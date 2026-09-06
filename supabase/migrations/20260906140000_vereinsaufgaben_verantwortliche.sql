-- Vereinsaufgaben: Mannschaft waehlbar, mehrere Verantwortliche.
--
-- BISHER gab es zwei getrennte Begriffe, und beide reichten nicht:
--   team_id            ergab sich daraus, ueber welchen Knopf man anlegte -
--                      waehlen konnte man sie nicht.
--   club_task_signups  sind FREIWILLIGE Eintragungen. Wer sich eintraegt, hilft
--                      mit. Das ist etwas anderes als jemand, der die Aufgabe
--                      verantwortet.
--
-- Beide Begriffe nebeneinander sind richtig: Eine Aufgabe kann Verantwortliche
-- haben UND offene Plaetze, in die sich andere eintragen. "Kuchenverkauf" hat
-- eine Verantwortliche und braucht drei Helfer.
--
-- MEHRERE VERANTWORTLICHE, deshalb eine eigene Tabelle statt einer Spalte. Eine
-- Spalte assignee_membership_id waere die dritte Stelle, an der wir spaeter
-- merken, dass eine nicht reicht.

create table if not exists public.club_task_assignees (
  task_id       uuid not null references public.club_tasks(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  assigned_at   timestamptz not null default now(),
  primary key (task_id, membership_id)
);

create index if not exists club_task_assignees_task_idx on public.club_task_assignees (task_id);

alter table public.club_task_assignees enable row level security;

drop policy if exists "club members read task assignees" on public.club_task_assignees;
create policy "club members read task assignees" on public.club_task_assignees
  for select using (
    exists (select 1 from public.club_tasks t where t.id = task_id and public.is_club_member(t.club_id))
  );

/* Verantwortliche bestimmt, wer die Aufgabe verwaltet - Vereinsleitung und
   Organisatoren. Anders als bei der Zu- und Absage zu einem Termin ist das
   keine Aussage ueber die eigene Person, sondern eine Zuteilung. */
drop policy if exists "leaders manage task assignees" on public.club_task_assignees;
create policy "leaders manage task assignees" on public.club_task_assignees
  for all using (
    exists (select 1 from public.club_tasks t where t.id = task_id
            and public.has_club_role(t.club_id, array['vereinsadmin','sysadmin','organisator']::club_role[]))
  ) with check (
    exists (select 1 from public.club_tasks t where t.id = task_id
            and public.has_club_role(t.club_id, array['vereinsadmin','sysadmin','organisator']::club_role[]))
  );

/* Wer verantwortlich gemacht wird, erfaehrt es - dieselbe Meldung wie bei den
   Helferstationen, damit beide Aufgabenarten sich gleich anfuehlen. */
create or replace function public.vereinsaufgabe_zuweisung_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare v_profil uuid; v_club uuid; v_titel text; v_wer text;
begin
  select t.club_id, t.title into v_club, v_titel from public.club_tasks t where t.id = new.task_id;
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = v_club limit 1;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  values (v_profil, v_club, 'task', 'Neue Aufgabe',
          coalesce(v_wer, 'Die Vereinsleitung') || ' hat dir eine Aufgabe zugewiesen.');
  return new;
end;
$$;

drop trigger if exists club_task_assignees_melden on public.club_task_assignees;
create trigger club_task_assignees_melden
  after insert on public.club_task_assignees
  for each row execute function public.vereinsaufgabe_zuweisung_melden();

/* Die Erinnerung am Vortag geht jetzt an die Verantwortlichen, wenn es welche
   gibt - sonst wie bisher an die Mannschaft beziehungsweise den Verein. Eine
   Erinnerung an fuenfzig Leute, von denen zwei zustaendig sind, liest niemand. */
create or replace function public.aufgaben_erinnerung_senden()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select t.id, t.club_id, t.title, m.profile_id
    from public.duty_tasks t
    join public.club_memberships m on m.id = t.assignee_membership_id
    where t.due_date = (current_date + 1)
      and t.reminded_at is null and t.done is not true
      and m.profile_id is not null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select f.profile_id, f.club_id, 'task', 'Erinnerung', 'Erinnerung für morgen: ' || f.title
    from faellig f returning 1
  )
  update public.duty_tasks set reminded_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;

  with faellig2 as (
    select t.id, t.club_id, t.team_id, t.title,
           exists (select 1 from public.club_task_assignees a where a.task_id = t.id) as hat_verantwortliche
    from public.club_tasks t
    where t.due_date = (current_date + 1) and t.reminded_at is null
  ), empfaenger as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select distinct m.profile_id, f.club_id, 'task', 'Erinnerung', 'Erinnerung für morgen: ' || f.title
    from faellig2 f
    join public.club_memberships m on m.club_id = f.club_id and m.status = 'active'
    left join public.team_members tm on tm.membership_id = m.id and tm.team_id = f.team_id
    left join public.club_task_assignees a on a.task_id = f.id and a.membership_id = m.id
    where m.profile_id is not null
      and (case when f.hat_verantwortliche then a.membership_id is not null
                when f.team_id is not null  then tm.membership_id is not null
                else true end)
    returning 1
  )
  update public.club_tasks set reminded_at = now() where id in (select id from faellig2);

  return v_anzahl;
end;
$$;

select
  (select count(*) from information_schema.tables where table_schema='public' and table_name='club_task_assignees') as tabelle,
  (select count(*) from pg_policy where polrelid='public.club_task_assignees'::regclass) as regeln,
  (select count(*) from pg_trigger where tgname='club_task_assignees_melden') as ausloeser;
