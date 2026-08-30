-- Einen neuen Verein anlegen war unmoeglich.
--
-- register_new_club schreibt den Sportart-Parameter als text in die Spalte
-- clubs.sport, die vom Aufzaehlungstyp public.club_sport ist. Postgres bricht
-- das mit 42804 ab: "column sport is of type public.club_sport but expression
-- is of type text".
--
-- Die Folge: JEDE Vereinsregistrierung scheiterte, fuer jeden, immer. In der
-- App erschien "Das Konto wurde erstellt, aber das Vereinsprofil konnte nicht
-- angelegt werden" - das Benutzerkonto entstand also, der Verein nie.
--
-- Aufgefallen ist es erst, als der Weg am 31.08.2026 zum ersten Mal wirklich
-- durchgespielt wurde. Kein Build und keine Codepruefung meldet so etwas: Der
-- Fehler steckt in einer Datenbankfunktion, die nur zur Laufzeit auffaellt.
--
-- Ein unbekannter Sportart-Wert faellt jetzt auf rollhockey zurueck, statt die
-- Registrierung erneut scheitern zu lassen.

CREATE OR REPLACE FUNCTION public.register_new_club(club_name text, club_short_name text, club_city text, club_register_number text, club_currency text DEFAULT 'EUR'::text, referral text DEFAULT NULL::text, member_name text DEFAULT ''::text, member_birthdate date DEFAULT NULL::date, club_sport text DEFAULT 'rollhockey'::text, club_primary_color text DEFAULT '#C8102E'::text, club_secondary_color text DEFAULT '#14151A'::text)
 RETURNS TABLE(club_id uuid, membership_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare new_club uuid; new_membership uuid; referrer uuid; referrer_profile uuid; referral_code_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if nullif(trim(club_name),'') is null or nullif(trim(club_short_name),'') is null or nullif(trim(club_register_number),'') is null then
    raise exception 'Required club data missing';
  end if;
  if upper(club_currency) not in ('EUR','USD','GBP','CHF','DKK','NOK','SEK','PLN','CZK') then raise exception 'Unsupported currency'; end if;
  if referral is not null and nullif(trim(referral),'') is not null then
    select id,club_id,profile_id into referral_code_id,referrer,referrer_profile
    from public.club_referral_codes where upper(code)=upper(trim(referral)) and redeemed_at is null;
    if referral_code_id is null then raise exception 'Invalid or already used referral code'; end if;
  end if;
  insert into public.clubs(slug,name,short_name,city,founded_year,register_number,currency,sport,primary_color,secondary_color)
  values(
    lower(regexp_replace(trim(club_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6),
    trim(club_name),upper(trim(club_short_name)),nullif(trim(club_city),''),extract(year from now())::int,
    trim(club_register_number),upper(club_currency),
    -- Umwandlung in den Aufzaehlungstyp. Ohne sie bricht das Anlegen eines
    -- Vereins mit 42804 ab: "column sport is of type public.club_sport but
    -- expression is of type text". Ein unbekannter Wert faellt auf rollhockey
    -- zurueck, statt die Registrierung erneut scheitern zu lassen.
    case when coalesce(nullif(trim(club_sport),''),'rollhockey') = any (enum_range(null::public.club_sport)::text[])
         then coalesce(nullif(trim(club_sport),''),'rollhockey')::public.club_sport
         else 'rollhockey'::public.club_sport end,
    coalesce(nullif(trim(club_primary_color),''),'#C8102E'),
    coalesce(nullif(trim(club_secondary_color),''),'#14151A')
  ) returning id into new_club;
  update public.profiles set full_name=trim(member_name),birthdate=member_birthdate where id=auth.uid();
  insert into public.club_memberships(club_id,profile_id,display_name,email,member_since,status,created_by)
  select new_club,auth.uid(),trim(member_name),email,extract(year from now())::int,'active',auth.uid() from auth.users where id=auth.uid() returning id into new_membership;
  insert into public.membership_roles(membership_id,role,granted_by) values
    (new_membership,'mitglied',auth.uid()),(new_membership,'vereinsadmin',auth.uid()),(new_membership,'sysadmin',auth.uid());
  if referrer is not null then
    insert into public.club_referrals(referrer_club_id,referred_club_id,referred_by_profile_id,code,status,redeemed_at)
    values(referrer,new_club,referrer_profile,trim(referral),'redeemed',now());
    update public.club_referral_codes set used_by_club_id=new_club,redeemed_at=now() where id=referral_code_id;
    update public.clubs set referral_credit_months=referral_credit_months+3 where id=referrer;
  end if;
  return query select new_club,new_membership;
end;
$function$
;

grant execute on function public.register_new_club(text,text,text,text,text,text,text,date,text,text,text) to authenticated;
