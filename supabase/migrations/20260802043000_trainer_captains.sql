-- Trainer dürfen für ihre eigenen Mannschaften genau einen Kapitän bestimmen.

create or replace function public.set_team_captain(
  target_team uuid,
  target_membership uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  if not exists (
    select 1
    from public.team_members tm
    join public.club_memberships membership on membership.id = tm.membership_id
    where tm.team_id = target_team
      and tm.function = 'trainer'
      and membership.profile_id = auth.uid()
      and membership.status = 'active'
  ) then
    raise exception 'Only a trainer assigned to this team can set its captain';
  end if;

  if not exists (
    select 1
    from public.team_members player
    join public.club_memberships membership on membership.id = player.membership_id
    where player.team_id = target_team
      and player.membership_id = target_membership
      and player.function = 'spieler'
      and membership.status = 'active'
  ) then
    raise exception 'Captain must be an active player of this team';
  end if;

  delete from public.team_members
  where team_id = target_team and function = 'kapitaen';

  insert into public.team_members (team_id, membership_id, function)
  values (target_team, target_membership, 'kapitaen');
end;
$$;

grant execute on function public.set_team_captain(uuid, uuid) to authenticated;
