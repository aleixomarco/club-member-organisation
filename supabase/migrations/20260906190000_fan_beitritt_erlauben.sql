-- register_for_club muss die Rolle "fan" akzeptieren.
--
-- Die Funktion pruefte account_role gegen eine feste Liste
-- ('mitglied','spieler','eltern'). Ein Beitritt als Fan waere mit
-- "Invalid self-service role" abgewiesen worden - und zwar erst NACH dem
-- Ausfuellen des Formulars.
--
-- Die Liste ist richtig so: Sie verhindert, dass sich jemand ueber die
-- Selbstanmeldung zum Vereinsadmin macht. Nur "fan" gehoert hinein, "eltern"
-- heraus - die Rolle ist abgeschafft, und ein Ausloeser weist sie ohnehin ab.

create or replace function public.register_for_club(
  target_club uuid,
  member_name text,
  account_role public.club_role default 'mitglied',
  member_birthdate date default null,
  member_team text default null)
returns table (membership_id uuid, membership_status public.membership_status)
language plpgsql security definer set search_path = 'public' as $$
declare
  new_membership_id uuid;
  vorhandene_id uuid;
  vorhandener_status public.membership_status;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if account_role not in ('mitglied', 'spieler', 'fan') then
    raise exception 'Invalid self-service role';
  end if;

  select m.id, m.status into vorhandene_id, vorhandener_status
  from public.club_memberships m
  where m.club_id = target_club and m.profile_id = auth.uid();

  if vorhandene_id is not null then
    if vorhandener_status = 'blocked' then raise exception 'blocked'; end if;
    return query select vorhandene_id, vorhandener_status;
    return;
  end if;

  insert into public.club_memberships (club_id, profile_id, display_name, status, requested_team, birthdate)
  values (target_club, auth.uid(), member_name, 'pending', member_team, member_birthdate)
  returning id into new_membership_id;

  /* Ein Fan ist KEIN formales Mitglied - er bekommt nur die Fan-Rolle.
     Alle anderen bekommen "mitglied", Athletinnen zusaetzlich "spieler". */
  if account_role = 'fan' then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, 'fan', auth.uid()) on conflict do nothing;
  else
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, 'mitglied', auth.uid()) on conflict do nothing;
    if account_role <> 'mitglied' then
      insert into public.membership_roles (membership_id, role, granted_by)
      values (new_membership_id, account_role, auth.uid()) on conflict do nothing;
    end if;
  end if;

  return query select new_membership_id, 'pending'::public.membership_status;
end;
$$;

grant execute on function public.register_for_club(uuid, text, public.club_role, date, text) to authenticated, service_role;

select proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname='register_for_club';
