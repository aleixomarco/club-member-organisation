-- Nachtrag: drei Tarifstufen, keine Zusatzpakete, keine vierte Stufe.
--
--   ohne Abo      3 Zugänge kostenlos
--   Basic       100
--   Plus        350
--   Pro       1.000      darüber auf Anfrage
--
-- Nur in der TEST-Datenbank ausführen.

update public.subscription_plans set active = false
where code like 'club_addon_%' or code like 'club_max_%';

create or replace function public.club_subscription_tier(target_club uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(
    (
      select case
        when p.code like 'club_pro_%'     then 'pro'
        when p.code like 'club_premium_%' then 'plus'
        when p.code like 'club_plus_%'    then 'plus'
        when p.code like 'club_basic_%'   then 'basic'
        when p.code in ('club_monthly', 'club_yearly') then 'basic'
      end
      from public.club_subscriptions s
      join public.subscription_plans p on p.id = s.plan_id
      where s.club_id = target_club
        and s.status = 'active'
        and (s.current_period_end is null or s.current_period_end > now())
      order by case
        when p.code like 'club_pro_%'     then 0
        when p.code like 'club_premium_%' then 1
        when p.code like 'club_plus_%'    then 1
        else 2
      end
      limit 1
    ),
    (
      select 'pro'
      from public.clubs c
      where c.id = target_club and c.created_at + public.trial_period() > now()
    ),
    'none'
  );
$$;

create or replace function public.club_account_limit(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case public.club_subscription_tier(target_club)
    when 'basic' then 100
    when 'plus'  then 350
    when 'pro'   then 1000
    else 3
  end;
$$;

drop function if exists public.club_account_addon(uuid);

grant execute on function public.club_subscription_tier(uuid) to authenticated;
grant execute on function public.club_account_limit(uuid) to authenticated;

-- Kontrolle: sechs aktive Tarife, und die Grenzen je Verein.
select code, price_cents from public.subscription_plans
where active and code like 'club_%' order by price_cents;

select c.name,
       public.club_subscription_tier(c.id) as tarif,
       public.club_account_count(c.id)     as belegt,
       public.club_account_limit(c.id)     as grenze
from public.clubs c order by c.name limit 10;
