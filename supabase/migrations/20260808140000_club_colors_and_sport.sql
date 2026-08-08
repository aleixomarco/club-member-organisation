-- Vereinsfarben (Primär/Sekundär), frei wählbar bei Vereinsregistrierung und
-- später in den Vereinseinstellungen änderbar (z. B. "Schwarz & Gelb" wie
-- BVB, "Blau & Weiß" wie Schalke, "Rot & Weiß" wie Bayern). Standardwerte
-- entsprechen der bisherigen festen App-Farbe, bestehende Vereine sind also
-- unverändert.
--
-- Ergänzt außerdem die fehlende sport-Spalte: das Frontend liest/schreibt
-- clubs.sport bereits (SPORT_CONFIG, register_new_club-Aufruf mit
-- club_sport), aber keine bisherige Migration hat die Spalte je angelegt
-- bzw. die Funktion je um den Parameter erweitert — dadurch schlug die
-- Registrierung eines neuen Vereins bislang mit einem PostgREST-Fehler fehl
-- ("Could not find the function ... with these parameters").

alter table public.clubs
  add column if not exists primary_color text not null default '#C8102E',
  add column if not exists secondary_color text not null default '#14151A',
  add column if not exists sport text not null default 'rollhockey';

create or replace function public.register_new_club(
  club_name text, club_short_name text, club_city text, club_register_number text,
  club_currency text default 'EUR', referral text default null,
  member_name text default '', member_birthdate date default null,
  club_sport text default 'rollhockey',
  club_primary_color text default '#C8102E', club_secondary_color text default '#14151A'
) returns table(club_id uuid, membership_id uuid)
language plpgsql security definer set search_path = '' as $$
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
    coalesce(nullif(trim(club_sport),''),'rollhockey'),
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
$$;
