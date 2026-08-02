-- Vereinsadmin und Sysadmin können einen Trainer mehreren Mannschaften zuordnen.
create or replace function public.set_trainer_teams(target_membership uuid, target_team_names text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_club uuid;
  team_name text;
  resolved_team uuid;
begin
  select club_id into target_club from public.club_memberships where id = target_membership;
  if target_club is null or auth.uid() is null or not public.has_club_role(
    target_club, array['sysadmin','vereinsadmin']::public.club_role[]
  ) then raise exception 'Not authorized'; end if;

  insert into public.membership_roles (membership_id, role, granted_by)
  values (target_membership, 'trainer', auth.uid()) on conflict do nothing;
  delete from public.team_members where membership_id = target_membership and function = 'trainer';

  foreach team_name in array coalesce(target_team_names, array[]::text[]) loop
    select id into resolved_team from public.teams
    where club_id = target_club and name = trim(team_name) and active limit 1;
    if resolved_team is null then raise exception 'Team not found: %', team_name; end if;
    insert into public.team_members (team_id, membership_id, function)
    values (resolved_team, target_membership, 'trainer') on conflict do nothing;
  end loop;
end;
$$;

revoke all on function public.set_trainer_teams(uuid, text[]) from public;
grant execute on function public.set_trainer_teams(uuid, text[]) to authenticated;
