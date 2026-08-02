-- Mannschaftsbezogener Strafenkatalog. Lesen dürfen alle Vereinsmitglieder;
-- verwalten dürfen ausschließlich zugeordnete Trainer, Teammanager und Kapitäne.
create table if not exists public.team_penalty_rules (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 120),
  amount numeric(10,2) not null check (amount >= 0),
  created_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists team_penalty_rules_team_id_idx on public.team_penalty_rules(team_id);

alter table public.team_penalty_rules enable row level security;

drop policy if exists "members read team penalty rules" on public.team_penalty_rules;
create policy "members read team penalty rules" on public.team_penalty_rules for select to authenticated
using (
  exists (
    select 1 from public.teams team
    where team.id = team_id and public.is_club_member(team.club_id)
  )
);

drop policy if exists "team leaders create penalty rules" on public.team_penalty_rules;
create policy "team leaders create penalty rules" on public.team_penalty_rules for insert to authenticated
with check (public.can_manage_team(team_id) and created_by = auth.uid());

drop policy if exists "team leaders update penalty rules" on public.team_penalty_rules;
create policy "team leaders update penalty rules" on public.team_penalty_rules for update to authenticated
using (public.can_manage_team(team_id))
with check (public.can_manage_team(team_id));

drop policy if exists "team leaders delete penalty rules" on public.team_penalty_rules;
create policy "team leaders delete penalty rules" on public.team_penalty_rules for delete to authenticated
using (public.can_manage_team(team_id));

grant select, insert, update, delete on public.team_penalty_rules to authenticated;
