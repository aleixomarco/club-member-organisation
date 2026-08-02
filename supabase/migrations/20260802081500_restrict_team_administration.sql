-- Nur Vereinsadministration und Sys-Administration dürfen Mannschaften
-- anlegen oder Trainerzuordnungen verändern. Trainer verwalten weiterhin
-- Spieler und Kapitän innerhalb ihrer bereits zugewiesenen Teams.
create or replace function public.create_club_team(
  target_club uuid,
  team_name text,
  team_category text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  created_team uuid;
  normalized_name text := nullif(trim(team_name), '');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if normalized_name is null then raise exception 'Team name required'; end if;
  if char_length(normalized_name) > 80 then raise exception 'Team name too long'; end if;

  if not public.has_club_role(
    target_club,
    array['sysadmin','vereinsadmin']::public.club_role[]
  ) then raise exception 'Club administrator role required'; end if;

  insert into public.teams (club_id, name, category, active)
  values (target_club, normalized_name, nullif(trim(team_category), ''), true)
  on conflict (club_id, name) do nothing
  returning id into created_team;

  if created_team is null then raise exception 'Team already exists'; end if;
  return created_team;
end;
$$;

revoke all on function public.create_club_team(uuid, text, text) from public;
grant execute on function public.create_club_team(uuid, text, text) to authenticated;

-- Die frühere Trainer-Selbstzuordnung bleibt als Migration nachvollziehbar,
-- ist für App-Benutzer aber nicht mehr aufrufbar.
revoke all on function public.set_my_trainer_teams(uuid, uuid[]) from public;
revoke execute on function public.set_my_trainer_teams(uuid, uuid[]) from authenticated;
