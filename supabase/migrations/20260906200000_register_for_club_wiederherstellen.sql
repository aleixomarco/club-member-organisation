-- register_for_club wiederherstellen - meine Fassung war kaputt.
--
-- WAS PASSIERT IST
-- Um die Rolle "fan" zuzulassen, habe ich die Funktion NEU GESCHRIEBEN, statt
-- nur die eine Zeile mit der Rollenliste zu aendern. Dabei ging fast alles
-- verloren, was sie sonst noch tat:
--
--   die E-Mail aus auth.users             -> Mitgliederliste ohne Adresse
--   member_since (Beitrittsjahr)          -> fehlte
--   created_by                            -> fehlte
--   die Aktualisierung von profiles        -> Name und Geburtsdatum kamen nie an
--   das ON CONFLICT auf (club_id, profile_id) -> ein zweiter Versuch schlug fehl
--   die Regel "erstes Mitglied ist sofort aktiv" -> der Gruender eines neuen
--     Vereins waere auf 'pending' stehen geblieben und haette sich selbst
--     freigeben muessen, wozu er keine Rechte hat
--
-- Und ich habe eine Spalte "birthdate" eingefuegt, die es in club_memberships
-- gar nicht gibt - das Geburtsdatum steht in profiles. Deshalb brach jede
-- Beitrittsanfrage mit "column birthdate does not exist" ab; in der App stand
-- nur "Die Anfrage konnte nicht gesendet werden."
--
-- LEHRE: Eine Funktion, die man nicht ganz kennt, aendert man an der einen
-- Zeile, um die es geht - man schreibt sie nicht aus dem Gedaechtnis neu.
--
-- Diese Migration nimmt das Original aus 20260903130000 und aendert daran
-- genau zwei Dinge: 'eltern' wird zu 'fan' in der erlaubten Liste, und ein Fan
-- bekommt nur die Fan-Rolle statt zusaetzlich "mitglied".

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
  if account_role not in ('mitglied', 'spieler', 'fan') then raise exception 'Invalid self-service role'; end if;
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

  /* Ein Fan bekommt NUR die Fan-Rolle - kein "mitglied" daneben. Sonst zaehlte
     er als formales Mitglied, und der Verein wuerde ihm Beitraege berechnen. */
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
