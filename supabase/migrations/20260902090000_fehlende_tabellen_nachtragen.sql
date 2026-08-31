-- Sieben Tabellen, die es nur in der Produktivdatenbank gab.
--
-- club_tasks, club_task_signups, carpools, carpool_passengers,
-- duty_task_templates, duty_task_template_items und team_penalty_assignments
-- werden von der App benutzt, standen aber in keiner Migration. Sie sind
-- irgendwann direkt in der Datenbank angelegt worden.
--
-- Das ist kein Schönheitsfehler. Aufgefallen ist es beim Abgleich der App gegen
-- das Schema: Eine Migration vom 30.08. ändert club_tasks per ALTER TABLE — auf
-- einer frisch aus diesen Dateien aufgebauten Datenbank wäre sie mit "relation
-- does not exist" abgebrochen. Die Daten liegen sicher in der Datenbank; was
-- fehlte, war die Beschreibung, wo sie liegen. Aus einer Sicherung
-- zurückspielen kann man nur in ein Schema, das man auch herstellen kann.
--
-- Die Definitionen hier sind aus der laufenden Datenbank ausgelesen und geben
-- sie wieder; auf ihr sind alle Anweisungen wirkungslos.

create table if not exists public.club_tasks (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  team_id uuid references public.teams(id) on delete cascade,
  title text not null,
  description text,
  due_date date,
  slots_needed integer not null default 1,
  created_by uuid references public.club_memberships(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.club_task_signups (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.club_tasks(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  signed_up_at timestamptz not null default now(),
  unique (task_id, membership_id)
);

create table if not exists public.carpools (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  driver_membership_id uuid not null references public.club_memberships(id) on delete cascade,
  seats_available integer not null check (seats_available > 0),
  note text,
  departure text,
  created_at timestamptz not null default now()
);

create table if not exists public.carpool_passengers (
  id uuid primary key default gen_random_uuid(),
  carpool_id uuid not null references public.carpools(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  joined_at timestamptz not null default now(),
  unique (carpool_id, membership_id)
);

create table if not exists public.duty_task_templates (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  name text not null,
  created_by uuid references public.club_memberships(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.duty_task_template_items (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.duty_task_templates(id) on delete cascade,
  title text not null,
  sort_order integer not null default 0
);

create table if not exists public.team_penalty_assignments (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  rule_id uuid not null references public.team_penalty_rules(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  assigned_by uuid default auth.uid() references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  note text,
  paid_at timestamptz,
  paid_by uuid,
  archived_season text,
  archived_at timestamptz
);

alter table public.club_tasks enable row level security;
alter table public.club_task_signups enable row level security;
alter table public.carpools enable row level security;
alter table public.carpool_passengers enable row level security;
alter table public.duty_task_templates enable row level security;
alter table public.duty_task_template_items enable row level security;
alter table public.team_penalty_assignments enable row level security;

grant select, insert, update, delete on
  public.club_tasks, public.club_task_signups, public.carpools, public.carpool_passengers,
  public.duty_task_templates, public.duty_task_template_items, public.team_penalty_assignments
to authenticated;
