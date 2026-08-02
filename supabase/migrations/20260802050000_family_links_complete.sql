-- Persistente, beidseitige Familienverknüpfungen und verwaltete Kinderprofile.

create or replace function public.create_family_link(
  target_club uuid,
  acting_membership uuid,
  related_membership uuid,
  acting_relation public.family_relation
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  acting_is_owner boolean;
  acting_is_sysadmin boolean;
  opposite_relation public.family_relation;
  first_id uuid;
  second_id uuid;
  first_relation public.family_relation;
  second_relation public.family_relation;
  result_id uuid;
begin
  if auth.uid() is null or acting_membership = related_membership then
    raise exception 'Not authorized';
  end if;

  select exists (
    select 1 from public.club_memberships m
    where m.id = acting_membership and m.club_id = target_club and m.profile_id = auth.uid()
  ) into acting_is_owner;
  select public.has_club_role(target_club, array['sysadmin']::public.club_role[]) into acting_is_sysadmin;

  if not acting_is_owner and not acting_is_sysadmin then raise exception 'Not authorized'; end if;
  if not exists (
    select 1 from public.club_memberships m
    where m.id = related_membership and m.club_id = target_club and m.status in ('active', 'pending')
  ) then raise exception 'Related membership not found'; end if;

  opposite_relation := case acting_relation
    when 'eltern' then 'kind'::public.family_relation
    when 'kind' then 'eltern'::public.family_relation
    when 'partner' then 'partner'::public.family_relation
    when 'grosseltern' then 'kind'::public.family_relation
    else 'sonstige'::public.family_relation
  end;

  if acting_membership::text < related_membership::text then
    first_id := acting_membership; second_id := related_membership;
    first_relation := acting_relation; second_relation := opposite_relation;
  else
    first_id := related_membership; second_id := acting_membership;
    first_relation := opposite_relation; second_relation := acting_relation;
  end if;

  insert into public.family_links (
    club_id, first_membership_id, second_membership_id,
    first_to_second, second_to_first, created_by
  ) values (
    target_club, first_id, second_id, first_relation, second_relation, auth.uid()
  )
  on conflict (club_id, first_membership_id, second_membership_id)
  do update set first_to_second = excluded.first_to_second, second_to_first = excluded.second_to_first
  returning id into result_id;

  return result_id;
end;
$$;

create or replace function public.delete_family_link(target_link uuid, acting_membership uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  link_club uuid;
  acting_is_owner boolean;
begin
  select club_id into link_club from public.family_links where id = target_link;
  if link_club is null then raise exception 'Family link not found'; end if;

  select exists (
    select 1 from public.club_memberships m
    where m.id = acting_membership and m.club_id = link_club and m.profile_id = auth.uid()
  ) into acting_is_owner;

  if not acting_is_owner and not public.has_club_role(link_club, array['sysadmin']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;

  if not exists (
    select 1 from public.family_links f
    where f.id = target_link and acting_membership in (f.first_membership_id, f.second_membership_id)
  ) and not public.has_club_role(link_club, array['sysadmin']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;

  delete from public.family_links where id = target_link;
end;
$$;

create or replace function public.create_managed_child(
  target_club uuid,
  parent_membership uuid,
  child_name text,
  child_birthdate date default null,
  child_team text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_is_owner boolean;
  child_id uuid;
  team_id uuid;
  link_id uuid;
begin
  if auth.uid() is null or nullif(trim(child_name), '') is null then raise exception 'Invalid child profile'; end if;
  select exists (
    select 1 from public.club_memberships m
    where m.id = parent_membership and m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
  ) into parent_is_owner;
  if not parent_is_owner and not public.has_club_role(target_club, array['sysadmin']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;

  insert into public.club_memberships (
    club_id, profile_id, display_name, member_since, status, is_managed_profile, created_by
  ) values (
    target_club, null, trim(child_name), extract(year from current_date)::integer, 'active', true, auth.uid()
  ) returning id into child_id;

  insert into public.membership_roles (membership_id, role, granted_by)
  values (child_id, 'mitglied', auth.uid()), (child_id, 'spieler', auth.uid());

  if nullif(trim(child_team), '') is not null then
    select id into team_id from public.teams where club_id = target_club and name = trim(child_team) and active limit 1;
    if team_id is not null then
      insert into public.team_members (team_id, membership_id, function) values (team_id, child_id, 'spieler');
    end if;
  end if;

  link_id := public.create_family_link(target_club, parent_membership, child_id, 'eltern');
  return jsonb_build_object('membership_id', child_id, 'family_link_id', link_id, 'birthdate', child_birthdate);
end;
$$;

revoke all on function public.create_family_link(uuid, uuid, uuid, public.family_relation) from public;
revoke all on function public.delete_family_link(uuid, uuid) from public;
revoke all on function public.create_managed_child(uuid, uuid, text, date, text) from public;
grant execute on function public.create_family_link(uuid, uuid, uuid, public.family_relation) to authenticated;
grant execute on function public.delete_family_link(uuid, uuid) to authenticated;
grant execute on function public.create_managed_child(uuid, uuid, text, date, text) to authenticated;
