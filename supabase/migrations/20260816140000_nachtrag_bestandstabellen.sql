-- Nachtrag: vier Tabellen, die in der Produktionsdatenbank existieren,
-- aber in keiner Migration standen
--
-- duty_tasks, club_vehicles, vehicle_bookings und club_feature_toggles wurden
-- seinerzeit direkt im SQL-Editor angelegt. Das Repository konnte die
-- Produktionsdatenbank dadurch nicht reproduzieren: Eine frisch aufgesetzte
-- Umgebung haette Helferdienst-Aufgaben, Fahrzeuge, Fahrzeugbuchungen und die
-- Funktionsschalter nicht gehabt - die zugehoerigen Features waeren dort ohne
-- erkennbaren Grund tot gewesen.
--
-- Alle Anweisungen sind "if not exists". In der bestehenden Produktion
-- passiert damit NICHTS; die Migration wirkt ausschliesslich beim Aufbau
-- einer neuen Umgebung.
--
-- Die Spalten sind aus den tatsaechlich funktionierenden Schreibzugriffen
-- abgeleitet (docs/demo-verein.sql hat in alle vier Tabellen erfolgreich
-- eingefuegt) sowie aus den Abfragen in app/page.tsx.

-- Helferdienst-Aufgaben zu einem Heimspiel (Theke, Grill, Kasse, Zeitnahme …).
create table if not exists public.duty_tasks (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  event_id uuid references public.events(id) on delete cascade,
  title text not null,
  assignee_membership_id uuid references public.club_memberships(id) on delete set null,
  created_by uuid references public.club_memberships(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists duty_tasks_club_idx on public.duty_tasks(club_id);
create index if not exists duty_tasks_event_idx on public.duty_tasks(event_id);

-- Vereinsfahrzeuge (Bus, Anhaenger …), je nach Sportart anders benannt.
create table if not exists public.club_vehicles (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  label text not null,
  license_plate text,
  seats integer,
  created_by uuid references public.club_memberships(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists club_vehicles_club_idx on public.club_vehicles(club_id);

-- Buchungen dieser Fahrzeuge. team_id und private_label schliessen sich in der
-- Praxis aus: Entweder faehrt eine Mannschaft oder jemand privat.
create table if not exists public.vehicle_bookings (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  vehicle_id uuid not null references public.club_vehicles(id) on delete cascade,
  membership_id uuid references public.club_memberships(id) on delete set null,
  team_id uuid references public.teams(id) on delete set null,
  private_label text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists vehicle_bookings_vehicle_idx on public.vehicle_bookings(vehicle_id);
create index if not exists vehicle_bookings_zeitraum_idx on public.vehicle_bookings(club_id, starts_at);

-- Funktionsschalter je Verein. Fehlt eine Zeile, gilt die Funktion als
-- aktiviert - genauso wertet es featureEnabled() in app/page.tsx.
create table if not exists public.club_feature_toggles (
  club_id uuid not null references public.clubs(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (club_id, feature_key)
);

alter table public.duty_tasks enable row level security;
alter table public.club_vehicles enable row level security;
alter table public.vehicle_bookings enable row level security;
alter table public.club_feature_toggles enable row level security;

-- Lesen darf, wer Mitglied des Vereins ist. Schreiben regeln die bestehenden
-- Policies in der Produktion; hier werden bewusst nur Lesepolicies angelegt,
-- damit diese Migration keine schaerferen oder laxeren Rechte setzt als die,
-- die dort bereits gelten.
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'duty_tasks' and policyname = 'members read duty tasks') then
    create policy "members read duty tasks" on public.duty_tasks for select using (public.is_club_member(club_id));
  end if;
  if not exists (select 1 from pg_policies where tablename = 'club_vehicles' and policyname = 'members read vehicles') then
    create policy "members read vehicles" on public.club_vehicles for select using (public.is_club_member(club_id));
  end if;
  if not exists (select 1 from pg_policies where tablename = 'vehicle_bookings' and policyname = 'members read vehicle bookings') then
    create policy "members read vehicle bookings" on public.vehicle_bookings for select using (public.is_club_member(club_id));
  end if;
  if not exists (select 1 from pg_policies where tablename = 'club_feature_toggles' and policyname = 'members read feature toggles') then
    create policy "members read feature toggles" on public.club_feature_toggles for select using (public.is_club_member(club_id));
  end if;
end $$;
