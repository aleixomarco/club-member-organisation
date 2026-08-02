-- Sys-Admins können die Vereinsstammdaten anderer Mitgliedschaften pflegen.
-- Authentifizierungs-E-Mail, Passwort und Zahlungsdaten bleiben unberührt.
create or replace function public.sysadmin_update_member_profile(
  target_membership uuid,
  new_display_name text,
  new_contact_email text,
  new_birthdate date,
  new_member_since integer,
  new_status public.membership_status
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  target_club uuid;
  target_profile uuid;
  acting_membership uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if nullif(trim(new_display_name), '') is null then raise exception 'Display name required'; end if;
  if new_member_since is not null and (new_member_since < 1800 or new_member_since > 2200) then
    raise exception 'Invalid membership year';
  end if;

  select club_id, profile_id into target_club, target_profile
  from public.club_memberships where id = target_membership;
  if target_club is null then raise exception 'Membership not found'; end if;

  select membership.id into acting_membership
  from public.club_memberships membership
  join public.membership_roles role
    on role.membership_id = membership.id and role.role = 'sysadmin'
  where membership.club_id = target_club
    and membership.profile_id = auth.uid()
    and membership.status = 'active';
  if acting_membership is null then raise exception 'Active sysadmin membership required'; end if;
  if acting_membership = target_membership and new_status <> 'active' then
    raise exception 'Sysadmin cannot deactivate own active membership';
  end if;

  update public.club_memberships
  set display_name = trim(new_display_name),
      email = nullif(trim(new_contact_email), ''),
      member_since = new_member_since,
      status = new_status
  where id = target_membership;

  if target_profile is not null then
    update public.profiles
    set full_name = trim(new_display_name), birthdate = new_birthdate
    where id = target_profile;
  end if;
end;
$$;

revoke all on function public.sysadmin_update_member_profile(uuid, text, text, date, integer, public.membership_status) from public;
grant execute on function public.sysadmin_update_member_profile(uuid, text, text, date, integer, public.membership_status) to authenticated;
