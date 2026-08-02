-- Dauerhafter Vereinszustand für verbleibende Verwaltungsoberflächen.
create table if not exists public.club_app_state (
  club_id uuid primary key references public.clubs(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.club_app_state enable row level security;
create policy "club members read app state" on public.club_app_state for select to authenticated
using (public.is_club_member(club_id));
create policy "club managers update app state" on public.club_app_state for all to authenticated
using (public.has_club_role(club_id, array['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[]));

create or replace function public.save_club_app_state(target_club uuid, new_state jsonb) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_club_role(target_club, array['vorstand','geschaeftsfuehrung','sponsorenmanager','sysadmin','vereinsadmin']::public.club_role[])
    then raise exception 'Not authorized'; end if;
  if new_state is null or jsonb_typeof(new_state) <> 'object' then raise exception 'Invalid state'; end if;
  insert into public.club_app_state (club_id,state,updated_by,updated_at) values (target_club,new_state,auth.uid(),now())
  on conflict (club_id) do update set state=excluded.state,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
end; $$;

create or replace function public.set_membership_role(target_membership uuid, target_role public.club_role, role_enabled boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare target_club uuid;
begin
  select club_id into target_club from public.club_memberships where id=target_membership;
  if target_club is null or auth.uid() is null or not public.has_club_role(target_club,array['sysadmin','vereinsadmin']::public.club_role[])
    then raise exception 'Not authorized'; end if;
  if target_role='mitglied' and not role_enabled then raise exception 'Base role cannot be removed'; end if;
  if role_enabled then
    insert into public.membership_roles(membership_id,role,granted_by) values(target_membership,target_role,auth.uid()) on conflict do nothing;
  else
    delete from public.membership_roles where membership_id=target_membership and role=target_role;
    if target_role in ('trainer','kapitaen','teammanager') then
      delete from public.team_members where membership_id=target_membership and function=target_role;
    end if;
  end if;
end; $$;

create or replace function public.set_teammanager_team(target_membership uuid, target_team_name text) returns void
language plpgsql security definer set search_path = '' as $$
declare target_club uuid; target_team uuid; displaced uuid;
begin
  select club_id into target_club from public.club_memberships where id=target_membership;
  if target_club is null or auth.uid() is null or not public.has_club_role(target_club,array['sysadmin','vereinsadmin']::public.club_role[])
    then raise exception 'Not authorized'; end if;
  delete from public.team_members where membership_id=target_membership and function='teammanager';
  if nullif(trim(target_team_name),'') is null then return; end if;
  select id into target_team from public.teams where club_id=target_club and name=trim(target_team_name) and active limit 1;
  if target_team is null then raise exception 'Team not found'; end if;
  select membership_id into displaced from public.team_members where team_id=target_team and function='teammanager' limit 1;
  delete from public.team_members where team_id=target_team and function='teammanager';
  if displaced is not null and not exists(select 1 from public.team_members where membership_id=displaced and function='teammanager') then
    delete from public.membership_roles where membership_id=displaced and role='teammanager';
  end if;
  insert into public.membership_roles(membership_id,role,granted_by) values(target_membership,'teammanager',auth.uid()) on conflict do nothing;
  insert into public.team_members(team_id,membership_id,function) values(target_team,target_membership,'teammanager');
end; $$;

revoke all on function public.save_club_app_state(uuid,jsonb) from public;
revoke all on function public.set_membership_role(uuid,public.club_role,boolean) from public;
revoke all on function public.set_teammanager_team(uuid,text) from public;
grant execute on function public.save_club_app_state(uuid,jsonb) to authenticated;
grant execute on function public.set_membership_role(uuid,public.club_role,boolean) to authenticated;
grant execute on function public.set_teammanager_team(uuid,text) to authenticated;
