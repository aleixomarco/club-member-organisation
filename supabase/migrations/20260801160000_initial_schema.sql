-- Club Member Organisation – initial Supabase schema
-- Run once in the Supabase SQL editor on a new project.

create extension if not exists pgcrypto;

create type public.membership_status as enum ('pending', 'active', 'inactive', 'blocked');
create type public.club_role as enum (
  'mitglied', 'spieler', 'eltern', 'trainer', 'kapitaen', 'teammanager',
  'redakteur', 'sponsorenmanager', 'finanzmanager', 'geschaeftsfuehrung',
  'vorstand', 'sysadmin', 'vereinsadmin'
);
create type public.event_type as enum ('training', 'spiel', 'event');
create type public.event_status as enum ('scheduled', 'cancelled');
create type public.fee_type as enum ('Mitgliedsbeitrag', 'Familienbeitrag');
create type public.payment_status as enum ('offen', 'bezahlt');
create type public.family_relation as enum ('eltern', 'kind', 'partner', 'grosseltern', 'sonstige');

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name text not null,
  short_name text not null,
  city text,
  founded_year integer check (founded_year between 1800 and 2200),
  logo_url text,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  birthdate date,
  avatar_url text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.club_memberships (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  display_name text not null,
  email text,
  member_since integer check (member_since between 1800 and 2200),
  membership_number text,
  status public.membership_status not null default 'pending',
  is_managed_profile boolean not null default false,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_id, profile_id),
  unique (club_id, membership_number)
);

create table public.membership_roles (
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  role public.club_role not null,
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (membership_id, role)
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  name text not null,
  category text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (club_id, name)
);

create table public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  function public.club_role not null check (function in ('spieler', 'trainer', 'kapitaen', 'teammanager')),
  created_at timestamptz not null default now(),
  primary key (team_id, membership_id, function)
);

create unique index one_captain_per_team on public.team_members(team_id) where function = 'kapitaen';
create unique index one_teammanager_per_team on public.team_members(team_id) where function = 'teammanager';

create table public.family_links (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  first_membership_id uuid not null references public.club_memberships(id) on delete cascade,
  second_membership_id uuid not null references public.club_memberships(id) on delete cascade,
  first_to_second public.family_relation not null,
  second_to_first public.family_relation not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (first_membership_id <> second_membership_id),
  unique (club_id, first_membership_id, second_membership_id)
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  team_id uuid references public.teams(id) on delete set null,
  type public.event_type not null,
  status public.event_status not null default 'scheduled',
  title text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  home_away text check (home_away is null or home_away in ('heim', 'auswaerts')),
  opponent text,
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.fee_records (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  year integer not null check (year between 2000 and 2200),
  type public.fee_type not null,
  amount numeric(10,2) not null check (amount >= 0),
  payment_status public.payment_status not null default 'offen',
  invoice_number text,
  person_count integer not null default 1 check (person_count > 0),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_id, invoice_number)
);

create table public.fee_people (
  id uuid primary key default gen_random_uuid(),
  fee_record_id uuid not null references public.fee_records(id) on delete cascade,
  membership_id uuid references public.club_memberships(id) on delete set null,
  manual_name text,
  check (membership_id is not null or nullif(trim(manual_name), '') is not null)
);

create table public.sponsors (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  name text not null,
  title text not null,
  description text,
  image_url text,
  landing_page_url text,
  active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sponsor_placements (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  sponsor_id uuid not null references public.sponsors(id) on delete cascade,
  slot_key text not null,
  starts_on date,
  ends_on date,
  impressions bigint not null default 0,
  clicks bigint not null default 0,
  unique (club_id, slot_key)
);

create table public.polls (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  title text not null,
  active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references public.polls(id) on delete cascade,
  label text not null,
  position integer not null default 0
);

create table public.poll_votes (
  poll_id uuid not null references public.polls(id) on delete cascade,
  option_id uuid not null references public.poll_options(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (poll_id, profile_id)
);

create table public.channels (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  name text not null,
  emoji text,
  team_id uuid references public.teams(id) on delete cascade,
  write_roles public.club_role[] not null default '{}',
  visible_roles public.club_role[] not null default '{}',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 5000),
  created_at timestamptz not null default now()
);

create table public.protocols (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  title text not null,
  meeting_date date not null,
  raw_text text,
  attendee_membership_ids uuid[] not null default '{}',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.protocol_tasks (
  id uuid primary key default gen_random_uuid(),
  protocol_id uuid not null references public.protocols(id) on delete cascade,
  text text not null,
  assignee_membership_id uuid references public.club_memberships(id) on delete set null,
  due_date date,
  done boolean not null default false
);

create table public.season_votes (
  club_id uuid not null references public.clubs(id) on delete cascade,
  season text not null,
  voter_profile_id uuid not null references public.profiles(id) on delete cascade,
  candidate_membership_id uuid not null references public.club_memberships(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (club_id, season, voter_profile_id)
);

create table public.predictions (
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  home_score integer not null check (home_score >= 0),
  away_score integer not null check (away_score >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

create table public.duty_assignments (
  event_id uuid not null references public.events(id) on delete cascade,
  station text not null,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, station, membership_id)
);

create table public.club_settings (
  club_id uuid primary key references public.clubs(id) on delete cascade,
  maintenance_mode boolean not null default false,
  welcome_automation boolean not null default true,
  billing_automation boolean not null default true,
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end;
$$;

create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger memberships_touch before update on public.club_memberships for each row execute function public.touch_updated_at();
create trigger events_touch before update on public.events for each row execute function public.touch_updated_at();
create trigger fees_touch before update on public.fee_records for each row execute function public.touch_updated_at();
create trigger sponsors_touch before update on public.sponsors for each row execute function public.touch_updated_at();
create trigger predictions_touch before update on public.predictions for each row execute function public.touch_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_club_member(target_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_memberships m
    where m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
  );
$$;

create or replace function public.has_club_role(target_club uuid, allowed public.club_role[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_memberships m
    join public.membership_roles r on r.membership_id = m.id
    where m.club_id = target_club and m.profile_id = auth.uid()
      and m.status = 'active' and r.role = any(allowed)
  );
$$;

create or replace function public.can_manage_team(target_team uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.team_members tm
    join public.club_memberships m on m.id = tm.membership_id
    where tm.team_id = target_team and m.profile_id = auth.uid()
      and m.status = 'active' and tm.function in ('trainer', 'kapitaen', 'teammanager')
  );
$$;

create or replace function public.register_for_club(
  target_club uuid,
  member_name text,
  account_role public.club_role default 'mitglied',
  member_birthdate date default null
)
returns table (membership_id uuid, membership_status public.membership_status)
language plpgsql security definer set search_path = '' as $$
declare
  new_membership_id uuid;
  new_status public.membership_status;
  first_member boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if account_role not in ('mitglied', 'spieler', 'eltern') then raise exception 'Invalid self-service role'; end if;
  if nullif(trim(member_name), '') is null then raise exception 'Name required'; end if;

  perform 1 from public.clubs where id = target_club for update;
  if not found then raise exception 'Club not found'; end if;

  select not exists (
    select 1 from public.club_memberships m
    where m.club_id = target_club and m.status = 'active'
  ) into first_member;
  new_status := case when first_member then 'active'::public.membership_status else 'pending'::public.membership_status end;

  update public.profiles set full_name = trim(member_name), birthdate = member_birthdate
  where id = auth.uid();

  insert into public.club_memberships (club_id, profile_id, display_name, email, member_since, status, created_by)
  select target_club, auth.uid(), trim(member_name), u.email, extract(year from now())::integer, new_status, auth.uid()
  from auth.users u where u.id = auth.uid()
  on conflict (club_id, profile_id) do update
    set display_name = excluded.display_name, email = excluded.email, updated_at = now()
  returning id into new_membership_id;

  insert into public.membership_roles (membership_id, role, granted_by)
  values (new_membership_id, 'mitglied', auth.uid()) on conflict do nothing;
  if account_role <> 'mitglied' then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, account_role, auth.uid()) on conflict do nothing;
  end if;
  if first_member then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, 'vereinsadmin', auth.uid()), (new_membership_id, 'sysadmin', auth.uid())
    on conflict do nothing;
  end if;

  return query select new_membership_id, new_status;
end;
$$;

alter table public.clubs enable row level security;
alter table public.profiles enable row level security;
alter table public.club_memberships enable row level security;
alter table public.membership_roles enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.family_links enable row level security;
alter table public.events enable row level security;
alter table public.fee_records enable row level security;
alter table public.fee_people enable row level security;
alter table public.sponsors enable row level security;
alter table public.sponsor_placements enable row level security;
alter table public.polls enable row level security;
alter table public.poll_options enable row level security;
alter table public.poll_votes enable row level security;
alter table public.channels enable row level security;
alter table public.messages enable row level security;
alter table public.protocols enable row level security;
alter table public.protocol_tasks enable row level security;
alter table public.season_votes enable row level security;
alter table public.predictions enable row level security;
alter table public.duty_assignments enable row level security;
alter table public.club_settings enable row level security;

create policy "clubs are discoverable" on public.clubs for select using (true);
create policy "users read own profile" on public.profiles for select using (id = auth.uid());
create policy "users update own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy "members read club memberships" on public.club_memberships for select
using (public.is_club_member(club_id) or profile_id = auth.uid());
create policy "users request membership" on public.club_memberships for insert
with check (profile_id = auth.uid() and status = 'pending');
create policy "admins manage memberships" on public.club_memberships for all
using (public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[]));

create policy "members read roles" on public.membership_roles for select using (
  exists (select 1 from public.club_memberships m where m.id = membership_id and public.is_club_member(m.club_id))
);
create policy "admins manage roles" on public.membership_roles for all using (
  exists (select 1 from public.club_memberships m where m.id = membership_id and public.has_club_role(m.club_id, array['sysadmin','vereinsadmin']::public.club_role[]))
) with check (
  exists (select 1 from public.club_memberships m where m.id = membership_id and public.has_club_role(m.club_id, array['sysadmin','vereinsadmin']::public.club_role[]))
);

create policy "members read teams" on public.teams for select using (public.is_club_member(club_id));
create policy "admins manage teams" on public.teams for all
using (public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[]));
create policy "members read team assignments" on public.team_members for select using (
  exists (select 1 from public.teams t where t.id = team_id and public.is_club_member(t.club_id))
);
create policy "admins manage team assignments" on public.team_members for all using (
  exists (select 1 from public.teams t where t.id = team_id and public.has_club_role(t.club_id, array['sysadmin','vereinsadmin']::public.club_role[]))
) with check (
  exists (select 1 from public.teams t where t.id = team_id and public.has_club_role(t.club_id, array['sysadmin','vereinsadmin']::public.club_role[]))
);

create policy "family members read links" on public.family_links for select using (
  public.is_club_member(club_id) and (
    exists (select 1 from public.club_memberships m where m.id in (first_membership_id, second_membership_id) and m.profile_id = auth.uid())
    or public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[])
  )
);
create policy "users create own family links" on public.family_links for insert with check (
  public.is_club_member(club_id) and exists (
    select 1 from public.club_memberships m where m.id in (first_membership_id, second_membership_id) and m.profile_id = auth.uid()
  )
);
create policy "users delete own family links" on public.family_links for delete using (
  exists (select 1 from public.club_memberships m where m.id in (first_membership_id, second_membership_id) and m.profile_id = auth.uid())
  or public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[])
);

create policy "members read events" on public.events for select using (public.is_club_member(club_id));
create policy "authorized roles create events" on public.events for insert with check (
  public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[])
  or (team_id is not null and public.can_manage_team(team_id))
);
create policy "authorized roles update events" on public.events for update using (
  public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[])
  or (team_id is not null and public.can_manage_team(team_id))
) with check (
  public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[])
  or (team_id is not null and public.can_manage_team(team_id))
);

create policy "finance reads fees" on public.fee_records for select using (
  public.has_club_role(club_id, array['finanzmanager','geschaeftsfuehrung']::public.club_role[])
  or exists (select 1 from public.club_memberships m where m.id = membership_id and m.profile_id = auth.uid())
);
create policy "finance manages fees" on public.fee_records for all
using (public.has_club_role(club_id, array['finanzmanager','geschaeftsfuehrung']::public.club_role[]))
with check (public.has_club_role(club_id, array['finanzmanager','geschaeftsfuehrung']::public.club_role[]));
create policy "fee people follow fee access" on public.fee_people for select using (
  exists (select 1 from public.fee_records f where f.id = fee_record_id and (
    public.has_club_role(f.club_id, array['finanzmanager','geschaeftsfuehrung']::public.club_role[])
    or exists (select 1 from public.club_memberships m where m.id = f.membership_id and m.profile_id = auth.uid())
  ))
);
create policy "finance manages fee people" on public.fee_people for all using (
  exists (select 1 from public.fee_records f where f.id = fee_record_id and public.has_club_role(f.club_id, array['finanzmanager','geschaeftsfuehrung']::public.club_role[]))
) with check (
  exists (select 1 from public.fee_records f where f.id = fee_record_id and public.has_club_role(f.club_id, array['finanzmanager','geschaeftsfuehrung']::public.club_role[]))
);

create policy "members read sponsors" on public.sponsors for select using (public.is_club_member(club_id));
create policy "sponsor managers manage sponsors" on public.sponsors for all
using (public.has_club_role(club_id, array['sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]));
create policy "members read sponsor placements" on public.sponsor_placements for select using (public.is_club_member(club_id));
create policy "sponsor managers manage placements" on public.sponsor_placements for all
using (public.has_club_role(club_id, array['sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]));

create policy "members read polls" on public.polls for select using (public.is_club_member(club_id));
create policy "poll managers manage polls" on public.polls for all
using (public.has_club_role(club_id, array['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]));
create policy "members read poll options" on public.poll_options for select using (
  exists (select 1 from public.polls p where p.id = poll_id and public.is_club_member(p.club_id))
);
create policy "poll managers manage options" on public.poll_options for all using (
  exists (select 1 from public.polls p where p.id = poll_id and public.has_club_role(p.club_id, array['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]))
) with check (
  exists (select 1 from public.polls p where p.id = poll_id and public.has_club_role(p.club_id, array['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]))
);
create policy "members read votes" on public.poll_votes for select using (
  exists (select 1 from public.polls p where p.id = poll_id and public.is_club_member(p.club_id))
);
create policy "members cast own vote" on public.poll_votes for insert with check (
  profile_id = auth.uid() and exists (select 1 from public.polls p where p.id = poll_id and p.active and public.is_club_member(p.club_id))
);
create policy "members change own vote" on public.poll_votes for delete using (profile_id = auth.uid());

create policy "members read channels" on public.channels for select using (public.is_club_member(club_id));
create policy "admins create channels" on public.channels for insert with check (
  public.has_club_role(club_id, array['trainer','sysadmin','vereinsadmin']::public.club_role[])
);
create policy "members read messages" on public.messages for select using (
  exists (select 1 from public.channels c where c.id = channel_id and public.is_club_member(c.club_id))
);
create policy "authorized members write messages" on public.messages for insert with check (
  author_id = auth.uid() and exists (
    select 1 from public.channels c where c.id = channel_id and public.is_club_member(c.club_id)
      and (cardinality(c.write_roles) = 0 or public.has_club_role(c.club_id, c.write_roles))
  )
);

create policy "board reads protocols" on public.protocols for select using (
  public.has_club_role(club_id, array['vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[])
);
create policy "board manages protocols" on public.protocols for all
using (public.has_club_role(club_id, array['vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]));
create policy "protocol tasks follow protocol access" on public.protocol_tasks for all using (
  exists (select 1 from public.protocols p where p.id = protocol_id and public.has_club_role(p.club_id, array['vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]))
) with check (
  exists (select 1 from public.protocols p where p.id = protocol_id and public.has_club_role(p.club_id, array['vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin']::public.club_role[]))
);

create policy "members read season votes" on public.season_votes for select using (public.is_club_member(club_id));
create policy "members cast season vote" on public.season_votes for insert with check (voter_profile_id = auth.uid() and public.is_club_member(club_id));
create policy "members manage own predictions" on public.predictions for all
using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "members read predictions" on public.predictions for select using (
  exists (select 1 from public.events e where e.id = event_id and public.is_club_member(e.club_id))
);
create policy "members read duties" on public.duty_assignments for select using (
  exists (select 1 from public.events e where e.id = event_id and public.is_club_member(e.club_id))
);
create policy "members manage own duties" on public.duty_assignments for all using (
  exists (select 1 from public.club_memberships m where m.id = membership_id and m.profile_id = auth.uid())
) with check (
  exists (select 1 from public.club_memberships m where m.id = membership_id and m.profile_id = auth.uid())
);
create policy "members read settings" on public.club_settings for select using (public.is_club_member(club_id));
create policy "admins manage settings" on public.club_settings for all
using (public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[]));

insert into public.clubs (id, slug, name, short_name, city, founded_year)
values ('00000000-0000-4000-8000-000000000001', 'erg-iserlohn', 'ERG Iserlohn', 'ERGI', 'Iserlohn', 1965)
on conflict (slug) do update set name = excluded.name, short_name = excluded.short_name;

insert into public.teams (club_id, name, category) values
  ('00000000-0000-4000-8000-000000000001', 'Herren 1', 'Herren'),
  ('00000000-0000-4000-8000-000000000001', 'Herren 2', 'Herren'),
  ('00000000-0000-4000-8000-000000000001', 'Damen 1', 'Damen'),
  ('00000000-0000-4000-8000-000000000001', 'U15', 'Jugend'),
  ('00000000-0000-4000-8000-000000000001', 'U11', 'Jugend')
on conflict (club_id, name) do nothing;

insert into public.club_settings (club_id)
values ('00000000-0000-4000-8000-000000000001')
on conflict (club_id) do nothing;

create index memberships_club_idx on public.club_memberships(club_id);
create index memberships_profile_idx on public.club_memberships(profile_id);
create index team_members_membership_idx on public.team_members(membership_id);
create index events_club_start_idx on public.events(club_id, starts_at);
create index events_team_start_idx on public.events(team_id, starts_at);
create index fees_member_year_idx on public.fee_records(membership_id, year desc);
create index messages_channel_created_idx on public.messages(channel_id, created_at desc);
create index family_links_first_idx on public.family_links(first_membership_id);
create index family_links_second_idx on public.family_links(second_membership_id);
