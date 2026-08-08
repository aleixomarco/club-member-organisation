-- Athlet/innen ohne eigenes Konto direkt in einer Mannschaft anlegen (z. B.
-- Kindermannschaften, deren Mitglieder keine eigenen Handys/Konten haben).
-- Trainer/Verwaltung legen das Profil (Vorname/Nachname, optional Mitgliedsnr.)
-- direkt an; die Verknüpfung mit einem Elternteil erfolgt separat über die
-- bestehenden Familienprofil-Funktionen (create_family_link).
create or replace function public.create_team_player(
  target_club uuid,
  player_name text,
  membership_number text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  new_id uuid;
  normalized_name text := nullif(trim(player_name), '');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if normalized_name is null then raise exception 'Player name required'; end if;

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

  insert into public.club_memberships (
    club_id, profile_id, display_name, member_since, status, is_managed_profile, membership_number, created_by
  ) values (
    target_club, null, normalized_name, extract(year from current_date)::integer, 'active', true,
    nullif(trim(membership_number), ''), auth.uid()
  ) returning id into new_id;

  insert into public.membership_roles (membership_id, role, granted_by)
  values (new_id, 'mitglied', auth.uid()), (new_id, 'spieler', auth.uid());

  return new_id;
end;
$$;

revoke all on function public.create_team_player(uuid, text, text) from public;
grant execute on function public.create_team_player(uuid, text, text) to authenticated;

-- Späteres Zusammenführen: wenn ein ohne Konto angelegter Spieler (is_managed_profile)
-- später sein eigenes echtes Konto erhält, übernimmt dieses Konto Rollen,
-- Mannschaftszuordnungen, Familienverknüpfungen, Beiträge, Aufgaben, Saison-Stimmen
-- und Helferdienste des Platzhalter-Profils. Das Platzhalter-Profil wird danach
-- gelöscht. Es werden dabei KEINE Rollen automatisch neu vergeben, die es vorher
-- nicht gab — nur was am Platzhalter-Profil hing, wandert auf das echte Konto.
create or replace function public.claim_managed_membership(
  target_club uuid,
  managed_membership_id uuid,
  new_membership_id uuid
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  managed_is_managed boolean;
  managed_club uuid;
  new_profile uuid;
  new_is_managed boolean;
  new_club uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.has_club_role(target_club, array['sysadmin','vereinsadmin']::public.club_role[]) then
    raise exception 'Club administrator role required';
  end if;
  if managed_membership_id = new_membership_id then raise exception 'Invalid selection'; end if;

  select club_id, is_managed_profile into managed_club, managed_is_managed
  from public.club_memberships where id = managed_membership_id;
  if managed_club is null or managed_club <> target_club or not coalesce(managed_is_managed, false) then
    raise exception 'Source membership must be a managed profile without account in this club';
  end if;

  select club_id, profile_id, is_managed_profile into new_club, new_profile, new_is_managed
  from public.club_memberships where id = new_membership_id;
  if new_club is null or new_club <> target_club or new_profile is null or coalesce(new_is_managed, false) then
    raise exception 'Target membership must be a real, non-managed account in this club';
  end if;

  insert into public.membership_roles (membership_id, role, granted_by)
  select new_membership_id, role, granted_by
  from public.membership_roles where membership_id = managed_membership_id
  on conflict (membership_id, role) do nothing;

  insert into public.team_members (team_id, membership_id, function)
  select team_id, new_membership_id, function
  from public.team_members where membership_id = managed_membership_id
  on conflict do nothing;

  update public.family_links set first_membership_id = new_membership_id
  where first_membership_id = managed_membership_id;
  update public.family_links set second_membership_id = new_membership_id
  where second_membership_id = managed_membership_id;

  update public.fee_records set membership_id = new_membership_id
  where membership_id = managed_membership_id;
  update public.fee_people set membership_id = new_membership_id
  where membership_id = managed_membership_id;
  update public.protocol_tasks set assignee_membership_id = new_membership_id
  where assignee_membership_id = managed_membership_id;
  update public.season_votes set candidate_membership_id = new_membership_id
  where candidate_membership_id = managed_membership_id;
  update public.duty_assignments set membership_id = new_membership_id
  where membership_id = managed_membership_id;

  delete from public.club_memberships where id = managed_membership_id;
end;
$$;

revoke all on function public.claim_managed_membership(uuid, uuid, uuid) from public;
grant execute on function public.claim_managed_membership(uuid, uuid, uuid) to authenticated;
