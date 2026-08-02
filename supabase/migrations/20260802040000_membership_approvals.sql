-- Vollständiger Freigabeprozess inklusive gewünschter Mannschaft.

alter table public.club_memberships
add column if not exists requested_team text;

drop function if exists public.register_for_club(uuid, text, public.club_role, date);

create function public.register_for_club(
  target_club uuid,
  member_name text,
  account_role public.club_role default 'mitglied',
  member_birthdate date default null,
  member_team text default null
)
returns table (membership_id uuid, membership_status public.membership_status)
language plpgsql security definer set search_path = '' as $$
declare
  new_membership_id uuid;
  new_status public.membership_status;
  first_member boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if account_role not in ('mitglied', 'spieler', 'eltern') then raise exception 'Invalid self-service role'; end if;
  if nullif(trim(member_name), '') is null then raise exception 'Name required'; end if;

  perform 1 from public.clubs where id = target_club for update;
  if not found then raise exception 'Club not found'; end if;

  select not exists (
    select 1 from public.club_memberships m
    where m.club_id = target_club and m.status = 'active'
  ) into first_member;
  new_status := case when first_member then 'active'::public.membership_status else 'pending'::public.membership_status end;

  update public.profiles set full_name = trim(member_name), birthdate = member_birthdate
  where id = auth.uid();

  insert into public.club_memberships (
    club_id, profile_id, display_name, email, member_since, status, requested_team, created_by
  )
  select target_club, auth.uid(), trim(member_name), u.email, extract(year from now())::integer,
    new_status, nullif(trim(member_team), ''), auth.uid()
  from auth.users u where u.id = auth.uid()
  on conflict (club_id, profile_id) do update
    set display_name = excluded.display_name,
        email = excluded.email,
        requested_team = excluded.requested_team,
        updated_at = now()
  returning id into new_membership_id;

  insert into public.membership_roles (membership_id, role, granted_by)
  values (new_membership_id, 'mitglied', auth.uid()) on conflict do nothing;
  if account_role <> 'mitglied' then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, account_role, auth.uid()) on conflict do nothing;
  end if;
  if first_member then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, 'vereinsadmin', auth.uid()), (new_membership_id, 'sysadmin', auth.uid())
    on conflict do nothing;
  end if;

  return query select new_membership_id, new_status;
end;
$$;

grant execute on function public.register_for_club(uuid, text, public.club_role, date, text) to authenticated;
