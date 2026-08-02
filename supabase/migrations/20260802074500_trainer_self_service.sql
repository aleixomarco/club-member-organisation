-- Trainer verwalten ihre eigenen Mannschaftszuordnungen. Andere Rollen und
-- Zuordnungen des Profils werden dabei nicht verändert.
create or replace function public.set_my_trainer_teams(
  target_club uuid,
  target_team_ids uuid[] default array[]::uuid[]
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  acting_membership uuid;
  clean_team_ids uuid[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select membership.id into acting_membership
  from public.club_memberships membership
  join public.membership_roles role on role.membership_id = membership.id and role.role = 'trainer'
  where membership.club_id = target_club
    and membership.profile_id = auth.uid()
    and membership.status = 'active';
  if acting_membership is null then raise exception 'Active trainer membership required'; end if;

  select coalesce(array_agg(distinct selected_id), array[]::uuid[])
  into clean_team_ids
  from unnest(coalesce(target_team_ids, array[]::uuid[])) selected_id;

  if exists (
    select 1 from unnest(clean_team_ids) selected_id
    left join public.teams team on team.id = selected_id
    where team.id is null or team.club_id <> target_club or not team.active
  ) then raise exception 'Invalid team selection'; end if;

  delete from public.team_members
  where membership_id = acting_membership and function = 'trainer';

  insert into public.team_members (team_id, membership_id, function)
  select selected_id, acting_membership, 'trainer'::public.club_role
  from unnest(clean_team_ids) selected_id
  on conflict do nothing;
end;
$$;

revoke all on function public.set_my_trainer_teams(uuid, uuid[]) from public;
grant execute on function public.set_my_trainer_teams(uuid, uuid[]) to authenticated;

-- Die teambezogene Kapitänszuordnung und die sichtbare Profilrolle werden
-- gemeinsam gepflegt. Eine Kapitänsrolle bleibt bestehen, solange die Person
-- noch in mindestens einer anderen Mannschaft Kapitän/in ist.
create or replace function public.set_team_captain(
  target_team uuid,
  target_membership uuid
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  previous_captains uuid[];
  previous_membership uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.team_members assignment
    join public.club_memberships membership on membership.id = assignment.membership_id
    where assignment.team_id = target_team and assignment.function = 'trainer'
      and membership.profile_id = auth.uid() and membership.status = 'active'
  ) then raise exception 'Only a trainer assigned to this team can set its captain'; end if;
  if not exists (
    select 1 from public.team_members assignment
    join public.club_memberships membership on membership.id = assignment.membership_id
    where assignment.team_id = target_team and assignment.membership_id = target_membership
      and assignment.function = 'spieler' and membership.status = 'active'
  ) then raise exception 'Captain must be an active player of this team'; end if;

  select coalesce(array_agg(membership_id), array[]::uuid[]) into previous_captains
  from public.team_members where team_id = target_team and function = 'kapitaen';
  delete from public.team_members where team_id = target_team and function = 'kapitaen';
  insert into public.team_members (team_id, membership_id, function)
  values (target_team, target_membership, 'kapitaen');
  insert into public.membership_roles (membership_id, role, granted_by)
  values (target_membership, 'kapitaen', auth.uid()) on conflict do nothing;

  foreach previous_membership in array previous_captains loop
    if previous_membership <> target_membership and not exists (
      select 1 from public.team_members
      where membership_id = previous_membership and function = 'kapitaen'
    ) then
      delete from public.membership_roles
      where membership_id = previous_membership and role = 'kapitaen';
    end if;
  end loop;
end;
$$;

grant execute on function public.set_team_captain(uuid, uuid) to authenticated;
