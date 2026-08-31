-- Der Schutz der eigenen Mitgliedschaft darf den Beitritt nicht blockieren.
--
-- register_for_club() legt die Mitgliedschaft an und aktualisiert sie bei einer
-- erneuten Anfrage: display_name, email, requested_team und status. Die
-- Funktion läuft mit erhöhten Rechten, behält aber die Anmeldung des Aufrufers
-- — der Trigger aus der vorigen Migration hätte also jeden Beitritt und jede
-- erneute Anfrage abgebrochen.
--
-- Gelockert wird der Schutz deshalb nicht. Stattdessen setzt die Funktion für
-- die Dauer ihrer Transaktion eine Marke, und der Trigger achtet darauf. Eine
-- solche Marke lässt sich von außen nicht setzen: PostgREST reicht kein
-- beliebiges SQL durch, und set_config steht nicht im offengelegten Schema.

create or replace function public.eigene_mitgliedschaft_schuetzen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null
     or auth.role() = 'service_role'
     -- Die Marke der vertrauenswürdigen Funktionen.
     or coalesce(current_setting('app.mitgliedschaft_pflege', true), '') = 'ja'
     or public.has_club_role(new.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
  then
    return new;
  end if;

  if new.profile_id = auth.uid() then
    if new.status is distinct from old.status
       or new.club_id is distinct from old.club_id
       or new.profile_id is distinct from old.profile_id
       or new.membership_number is distinct from old.membership_number
       or new.display_name is distinct from old.display_name
       or new.email is distinct from old.email
       or new.member_since is distinct from old.member_since
    then
      raise exception 'An der eigenen Mitgliedschaft laesst sich nur die gespeicherte Ansicht aendern.' using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

-- register_for_club unverändert bis auf die Marke.
create or replace function public.register_for_club(
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
  bisher public.membership_status;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if account_role not in ('mitglied', 'spieler', 'eltern') then raise exception 'Invalid self-service role'; end if;
  if nullif(trim(member_name), '') is null then raise exception 'Name required'; end if;

  perform set_config('app.mitgliedschaft_pflege', 'ja', true);

  perform 1 from public.clubs where id = target_club for update;
  if not found then raise exception 'Club not found'; end if;

  select m.status into bisher
    from public.club_memberships m
   where m.club_id = target_club and m.profile_id = auth.uid();

  if bisher = 'blocked' then
    raise exception 'Blocked from this club' using errcode = 'P0001';
  end if;
  if bisher = 'active' then
    return query
      select m.id, m.status from public.club_memberships m
       where m.club_id = target_club and m.profile_id = auth.uid();
    return;
  end if;

  select not exists (
    select 1 from public.club_memberships m
    where m.club_id = target_club and m.status = 'active'
  ) into first_member;
  new_status := case when first_member then 'active'::public.membership_status else 'pending'::public.membership_status end;

  update public.profiles
     set full_name = trim(member_name),
         birthdate = coalesce(member_birthdate, birthdate)
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
        status = excluded.status,
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
