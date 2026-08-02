-- Mannschaftsverzeichnis: berechtigte Rollen können Teams anlegen und
-- Spieler verwalten ihre eigenen Zuordnungen (maximal drei) selbst.

create or replace function public.create_club_team(
  target_club uuid,
  team_name text,
  team_category text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  acting_membership uuid;
  created_team uuid;
  normalized_name text := nullif(trim(team_name), '');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if normalized_name is null then raise exception 'Team name required'; end if;
  if char_length(normalized_name) > 80 then raise exception 'Team name too long'; end if;

  select membership.id into acting_membership
  from public.club_memberships membership
  where membership.club_id = target_club
    and membership.profile_id = auth.uid()
    and membership.status = 'active';
  if acting_membership is null then raise exception 'Active membership required'; end if;

  if not public.has_club_role(target_club, array['sysadmin','vereinsadmin','trainer']::public.club_role[]) then
    raise exception 'Not allowed to create teams';
  end if;

  insert into public.teams (club_id, name, category, active)
  values (target_club, normalized_name, nullif(trim(team_category), ''), true)
  on conflict (club_id, name) do nothing
  returning id into created_team;
  if created_team is null then raise exception 'Team already exists'; end if;

  -- Ein Trainer, der ein Team erstellt, wird diesem Team direkt zugeordnet.
  if public.has_club_role(target_club, array['trainer']::public.club_role[]) then
    insert into public.team_members (team_id, membership_id, function)
    values (created_team, acting_membership, 'trainer')
    on conflict do nothing;
  end if;
  return created_team;
end;
$$;

create or replace function public.set_my_player_teams(
  target_club uuid,
  target_team_ids uuid[] default array[]::uuid[]
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  acting_membership uuid;
  clean_team_ids uuid[];
  selected_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select membership.id into acting_membership
  from public.club_memberships membership
  join public.membership_roles role on role.membership_id = membership.id and role.role = 'spieler'
  where membership.club_id = target_club
    and membership.profile_id = auth.uid()
    and membership.status = 'active';
  if acting_membership is null then raise exception 'Active player membership required'; end if;

  select coalesce(array_agg(distinct selected_id), array[]::uuid[])
  into clean_team_ids
  from unnest(coalesce(target_team_ids, array[]::uuid[])) selected_id;
  selected_count := coalesce(array_length(clean_team_ids, 1), 0);
  if selected_count > 3 then raise exception 'Maximum of three teams allowed'; end if;

  if exists (
    select 1 from unnest(clean_team_ids) selected_id
    left join public.teams team on team.id = selected_id
    where team.id is null or team.club_id <> target_club or not team.active
  ) then raise exception 'Invalid team selection'; end if;

  delete from public.team_members
  where membership_id = acting_membership and function = 'spieler';

  insert into public.team_members (team_id, membership_id, function)
  select selected_id, acting_membership, 'spieler'::public.club_role
  from unnest(clean_team_ids) selected_id
  on conflict do nothing;
end;
$$;

grant execute on function public.create_club_team(uuid, text, text) to authenticated;
grant execute on function public.set_my_player_teams(uuid, uuid[]) to authenticated;
