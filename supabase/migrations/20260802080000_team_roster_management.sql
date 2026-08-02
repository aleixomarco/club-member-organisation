-- Vereinsadministration und Trainer dürfen aktive Spieler/innen einem oder
-- mehreren Teams zuweisen. Pro Spielerprofil sind höchstens drei Teams erlaubt.
create or replace function public.set_managed_player_teams(
  target_club uuid,
  target_membership uuid,
  target_team_ids uuid[] default array[]::uuid[]
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  clean_team_ids uuid[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  if not exists (
    select 1
    from public.club_memberships acting_membership
    join public.membership_roles acting_role
      on acting_role.membership_id = acting_membership.id
     and acting_role.role in ('vereinsadmin', 'sysadmin', 'trainer')
    where acting_membership.club_id = target_club
      and acting_membership.profile_id = auth.uid()
      and acting_membership.status = 'active'
  ) then raise exception 'Club administrator or trainer role required'; end if;

  if not exists (
    select 1
    from public.club_memberships player_membership
    join public.membership_roles player_role
      on player_role.membership_id = player_membership.id
     and player_role.role = 'spieler'
    where player_membership.id = target_membership
      and player_membership.club_id = target_club
      and player_membership.status = 'active'
  ) then raise exception 'Active player membership required'; end if;

  select coalesce(array_agg(distinct selected_id), array[]::uuid[])
  into clean_team_ids
  from unnest(coalesce(target_team_ids, array[]::uuid[])) selected_id;

  if cardinality(clean_team_ids) > 3 then
    raise exception 'A player can belong to at most three teams';
  end if;

  if exists (
    select 1
    from unnest(clean_team_ids) selected_id
    left join public.teams team on team.id = selected_id
    where team.id is null or team.club_id <> target_club or not team.active
  ) then raise exception 'Invalid team selection'; end if;

  delete from public.team_members
  where membership_id = target_membership and function = 'spieler';

  insert into public.team_members (team_id, membership_id, function)
  select selected_id, target_membership, 'spieler'::public.club_role
  from unnest(clean_team_ids) selected_id
  on conflict do nothing;
end;
$$;

revoke all on function public.set_managed_player_teams(uuid, uuid, uuid[]) from public;
grant execute on function public.set_managed_player_teams(uuid, uuid, uuid[]) to authenticated;
