-- Ein Verein fällt nicht dem nächsten Fremden zu.
--
-- register_for_club() macht den ersten Beitretenden zum Vereinsadmin UND
-- Sysadmin. Das ist richtig für einen frisch angelegten Verein — irgendwer muss
-- anfangen. Die Bedingung dafür lautet aber „es gibt kein aktives Mitglied",
-- und die trifft auch auf einen Verein zu, der einmal welche hatte:
--
--   Jemand legt einen Verein an und löscht danach sein Konto. Der Verein bleibt
--   stehen, ist über die Suche für jeden sichtbar („clubs are discoverable"),
--   und der nächste Beitretende ist ohne jede Rückfrage sein Sysadmin — mit
--   allen Mitgliederdaten, Protokollen und Beiträgen, die noch darin liegen.
--
-- Das ist kein erdachter Fall: Genau diesen Weg geht ein App-Store-Prüfer, der
-- einen Testverein anlegt und anschließend die Kontolöschung prüft.
--
-- Die Unterscheidung, auf die es ankommt, ist nicht „gibt es aktive
-- Mitglieder", sondern „hat dieser Verein jemals welche gehabt".

alter table public.clubs
  add column if not exists uebergabe_offen boolean not null default false;

comment on column public.clubs.uebergabe_offen is
  'Nur wahr, solange der Verein noch nie ein aktives Mitglied hatte. Danach kann niemand mehr durch blossen Beitritt die Leitung uebernehmen.';

-- Bestehende Vereine: Wer schon Mitglieder hat oder hatte, ist vergeben.
update public.clubs c
   set uebergabe_offen = not exists (
     select 1 from public.club_memberships m where m.club_id = c.id
   );

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

  /* Der entscheidende Unterschied: Nicht "gerade niemand aktiv", sondern
     "noch nie jemand da gewesen". Ein verwaister Verein bleibt verwaist,
     bis der Betreiber ihn uebergibt - das ist eine Absprache, keine
     Selbstbedienung. */
  select c.uebergabe_offen into first_member from public.clubs c where c.id = target_club;
  first_member := coalesce(first_member, false)
                  and not exists (select 1 from public.club_memberships m where m.club_id = target_club);

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
    -- Ab jetzt ist der Verein vergeben.
    update public.clubs set uebergabe_offen = false where id = target_club;
  end if;

  return query select new_membership_id, new_status;
end;
$$;

grant execute on function public.register_for_club(uuid, text, public.club_role, date, text) to authenticated;

-- register_new_club legt den Gruender selbst an; der Verein ist damit sofort
-- vergeben. Der Standardwert false sorgt dafuer, ohne dass die Funktion
-- angefasst werden muss.
