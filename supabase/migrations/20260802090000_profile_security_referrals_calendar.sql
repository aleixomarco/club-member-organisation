-- Extended profiles, notification preferences, club referrals and calendar feeds.

alter table public.profiles
  add column if not exists academic_title text,
  add column if not exists first_name text,
  add column if not exists last_name text,
  add column if not exists contact_emails text[] not null default '{}',
  add column if not exists contact_phones text[] not null default '{}',
  add column if not exists gender text,
  add column if not exists nationality text,
  add column if not exists street text,
  add column if not exists postal_code text,
  add column if not exists city text,
  add column if not exists country_code text,
  add column if not exists notification_master boolean not null default true,
  add column if not exists notification_preferences jsonb not null default '{"training_created":true,"training_cancelled":true,"game_created":true,"game_changed":true,"news":true,"chat":true,"membership":true,"payments":true}'::jsonb,
  add column if not exists auto_logout_days integer,
  add column if not exists calendar_sync_interval text not null default 'never',
  add column if not exists calendar_last_synced_at timestamptz;

alter table public.profiles drop constraint if exists profiles_gender_check;
alter table public.profiles add constraint profiles_gender_check
  check (gender is null or gender in ('weiblich','maennlich','divers','keine_angabe'));
alter table public.profiles drop constraint if exists profiles_auto_logout_days_check;
alter table public.profiles add constraint profiles_auto_logout_days_check
  check (auto_logout_days is null or auto_logout_days in (30,60,90));
alter table public.profiles drop constraint if exists profiles_calendar_sync_interval_check;
alter table public.profiles add constraint profiles_calendar_sync_interval_check
  check (calendar_sync_interval in ('never','daily','weekly','monthly'));

alter table public.clubs
  add column if not exists register_number text,
  add column if not exists currency char(3) not null default 'EUR',
  add column if not exists referral_code text,
  add column if not exists referral_credit_months integer not null default 0;

create unique index if not exists clubs_referral_code_unique
  on public.clubs (upper(referral_code)) where referral_code is not null;

create table if not exists public.club_referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_club_id uuid not null references public.clubs(id) on delete cascade,
  referred_club_id uuid not null unique references public.clubs(id) on delete cascade,
  referred_by_profile_id uuid references public.profiles(id) on delete set null,
  code text not null,
  credit_months integer not null default 3 check (credit_months > 0),
  status text not null default 'redeemed' check (status in ('pending','redeemed','cancelled')),
  redeemed_at timestamptz,
  created_at timestamptz not null default now(),
  check (referrer_club_id <> referred_club_id)
);

create table if not exists public.club_referral_codes (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  code text not null unique,
  used_by_club_id uuid unique references public.clubs(id) on delete set null,
  redeemed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  club_id uuid references public.clubs(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  source_event_id uuid references public.events(id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.calendar_subscriptions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  token uuid not null default gen_random_uuid() unique,
  sync_interval text not null default 'never' check (sync_interval in ('never','daily','weekly','monthly')),
  enabled boolean not null default true,
  last_synced_at timestamptz,
  next_sync_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (profile_id, club_id)
);

create sequence if not exists public.support_ticket_number_seq start 1000;
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_number text not null unique default ('CMO-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.support_ticket_number_seq')::text, 6, '0')),
  profile_id uuid references public.profiles(id) on delete set null,
  club_id uuid references public.clubs(id) on delete set null,
  status text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  created_at timestamptz not null default now()
);

alter table public.club_referrals enable row level security;
alter table public.club_referral_codes enable row level security;
alter table public.user_notifications enable row level security;
alter table public.calendar_subscriptions enable row level security;
alter table public.support_tickets enable row level security;

create policy "members read their club referral" on public.club_referrals for select using (
  public.is_club_member(referrer_club_id) or public.is_club_member(referred_club_id)
);
create policy "users read own referral code" on public.club_referral_codes for select using (profile_id = auth.uid());
create policy "users read own notifications" on public.user_notifications for select using (profile_id = auth.uid());
create policy "users update own notifications" on public.user_notifications for update using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "users manage own calendar subscription" on public.calendar_subscriptions for all
  using (profile_id = auth.uid()) with check (profile_id = auth.uid() and public.is_club_member(club_id));
create policy "users read own support tickets" on public.support_tickets for select using (profile_id = auth.uid());
create policy "users create support tickets" on public.support_tickets for insert with check (profile_id = auth.uid());

create or replace function public.update_own_profile_settings(
  target_membership uuid,
  new_academic_title text,
  new_first_name text,
  new_last_name text,
  new_contact_emails text[],
  new_contact_phones text[],
  new_birthdate date,
  new_gender text,
  new_nationality text,
  new_street text,
  new_postal_code text,
  new_city text,
  new_country_code text,
  new_membership_number text,
  new_notification_master boolean,
  new_notification_preferences jsonb,
  new_auto_logout_days integer,
  new_calendar_sync_interval text
) returns void language plpgsql security definer set search_path = '' as $$
declare
  membership public.club_memberships;
  display text;
begin
  select * into membership from public.club_memberships where id = target_membership and profile_id = auth.uid();
  if not found then raise exception 'Membership not found'; end if;
  display := trim(concat_ws(' ', nullif(trim(new_first_name), ''), nullif(trim(new_last_name), '')));
  if display = '' then raise exception 'Name required'; end if;

  update public.profiles set
    full_name = display, academic_title = nullif(trim(new_academic_title), ''),
    first_name = trim(new_first_name), last_name = trim(new_last_name),
    contact_emails = coalesce(new_contact_emails, '{}'), contact_phones = coalesce(new_contact_phones, '{}'),
    birthdate = new_birthdate, gender = new_gender, nationality = nullif(trim(new_nationality), ''),
    street = nullif(trim(new_street), ''), postal_code = nullif(trim(new_postal_code), ''),
    city = nullif(trim(new_city), ''), country_code = nullif(upper(trim(new_country_code)), ''),
    notification_master = coalesce(new_notification_master, true),
    notification_preferences = coalesce(new_notification_preferences, '{}'::jsonb),
    auto_logout_days = new_auto_logout_days,
    calendar_sync_interval = coalesce(new_calendar_sync_interval, 'never'), updated_at = now()
  where id = auth.uid();

  update public.club_memberships set display_name = display,
    membership_number = nullif(trim(new_membership_number), ''), updated_at = now()
  where id = target_membership;
end;
$$;

create or replace function public.configure_calendar_subscription(target_club uuid, requested_interval text)
returns table(token uuid, last_synced_at timestamptz, next_sync_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare next_run timestamptz;
begin
  if not public.is_club_member(target_club) then raise exception 'Membership required'; end if;
  if requested_interval not in ('never','daily','weekly','monthly') then raise exception 'Invalid interval'; end if;
  next_run := case requested_interval
    when 'daily' then now() + interval '1 day'
    when 'weekly' then date_trunc('week', now()) + interval '6 days 20 hours'
    when 'monthly' then date_trunc('month', now()) + interval '1 month'
    else null end;
  return query
    insert into public.calendar_subscriptions(profile_id, club_id, sync_interval, last_synced_at, next_sync_at)
    values(auth.uid(), target_club, requested_interval, now(), next_run)
    on conflict(profile_id, club_id) do update set sync_interval=excluded.sync_interval,
      last_synced_at=now(), next_sync_at=excluded.next_sync_at, updated_at=now()
    returning calendar_subscriptions.token, calendar_subscriptions.last_synced_at, calendar_subscriptions.next_sync_at;
end;
$$;

create or replace function public.create_support_ticket(target_club uuid default null)
returns text language plpgsql security definer set search_path = '' as $$
declare result text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.support_tickets(profile_id, club_id) values(auth.uid(), target_club)
  returning ticket_number into result;
  return result;
end;
$$;

create or replace function public.ensure_club_referral_code(target_club uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare result text;
begin
  if auth.uid() is null or not public.is_club_member(target_club) then raise exception 'Membership required'; end if;
  select code into result from public.club_referral_codes where profile_id=auth.uid();
  if result is not null then return result; end if;
  insert into public.club_referral_codes(profile_id,club_id,code)
  select auth.uid(),target_club,'CMO-' || upper(substr(replace(short_name,' ',''),1,5)) || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,7))
  from public.clubs where id=target_club returning code into result;
  return result;
end;
$$;

create or replace function public.register_new_club(
  club_name text, club_short_name text, club_city text, club_register_number text,
  club_currency text default 'EUR', referral text default null,
  member_name text default '', member_birthdate date default null
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
  insert into public.clubs(slug,name,short_name,city,founded_year,register_number,currency)
  values(lower(regexp_replace(trim(club_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6),trim(club_name),upper(trim(club_short_name)),nullif(trim(club_city),''),extract(year from now())::int,trim(club_register_number),upper(club_currency)) returning id into new_club;
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

create or replace function public.notify_event_audience() returns trigger
language plpgsql security definer set search_path = '' as $$
declare notice_kind text;
begin
  notice_kind := case
    when new.type='training' and new.status='cancelled' then 'training_cancelled'
    when new.type='training' then 'training_created'
    when new.type='spiel' and tg_op='UPDATE' then 'game_changed'
    when new.type='spiel' then 'game_created'
    else 'news' end;
  insert into public.user_notifications(profile_id,club_id,kind,title,body,source_event_id)
  select distinct audience.profile_id, new.club_id, notice_kind,
    case when new.status='cancelled' then new.title || ' wurde abgesagt' else new.title end,
    new.description, new.id
  from (
    select m.profile_id
    from public.club_memberships m left join public.team_members tm on tm.membership_id=m.id
    where m.club_id=new.club_id and m.status='active' and m.profile_id is not null
      and (new.team_id is null or tm.team_id=new.team_id)
    union
    select parent.profile_id
    from public.family_links f
    join public.club_memberships child on child.id=f.second_membership_id
    join public.club_memberships parent on parent.id=f.first_membership_id
    left join public.team_members child_team on child_team.membership_id=child.id
    where f.club_id=new.club_id and f.first_to_second='eltern' and parent.profile_id is not null
      and (new.team_id is null or child_team.team_id=new.team_id)
    union
    select parent.profile_id
    from public.family_links f
    join public.club_memberships child on child.id=f.first_membership_id
    join public.club_memberships parent on parent.id=f.second_membership_id
    left join public.team_members child_team on child_team.membership_id=child.id
    where f.club_id=new.club_id and f.second_to_first='eltern' and parent.profile_id is not null
      and (new.team_id is null or child_team.team_id=new.team_id)
  ) audience
  join public.profiles p on p.id=audience.profile_id
  where p.notification_master
    and coalesce((p.notification_preferences ->> notice_kind)::boolean, true);
  return new;
end;
$$;

drop trigger if exists events_notify_audience on public.events;
create trigger events_notify_audience after insert or update on public.events
for each row execute function public.notify_event_audience();
