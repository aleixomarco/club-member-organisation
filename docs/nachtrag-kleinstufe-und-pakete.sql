-- Nachtrag: kostenlose Kleinstufe und vier Zusatzpakete.
--
-- Aenderungen gegenueber der bisher eingespielten Fassung:
--   1. Ohne Abo gilt nicht mehr Grenze 0, sondern drei kostenlose Zugaenge.
--   2. Statt eines Pakets ueber 100 gibt es vier ueber 500 bis 2000.
--   3. Zusatzpakete gelten nur zusammen mit dem Pro-Tarif.
--
-- Nur in der TEST-Datenbank ausfuehren.

-- Alte Pakete stilllegen statt loeschen: zu ihnen koennen Zeilen in
-- club_subscriptions gehoeren, und ein Fremdschluessel verweist darauf.
update public.subscription_plans set active = false
where code in ('club_addon_100_monthly', 'club_addon_250_monthly');

insert into public.subscription_plans (code, name, interval, price_cents) values
  ('club_addon_500_monthly',  'Zusatzpaket – 500 weitere Zugänge',  'month',  4999),
  ('club_addon_1000_monthly', 'Zusatzpaket – 1000 weitere Zugänge', 'month',  8999),
  ('club_addon_1500_monthly', 'Zusatzpaket – 1500 weitere Zugänge', 'month', 12999),
  ('club_addon_2000_monthly', 'Zusatzpaket – 2000 weitere Zugänge', 'month', 16999)
on conflict (code) do update set
  name = excluded.name, price_cents = excluded.price_cents, active = true;

-- Kostenlose Kleinstufe: drei Zugaenge ohne Abo.
create or replace function public.club_account_limit(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case public.club_subscription_tier(target_club)
    when 'basic' then 100
    when 'plus'  then 350
    when 'pro'   then 1000
    else 3
  end + public.club_account_addon(target_club);
$$;

-- Zusatzpakete nur mit Pro, und immer nur das groesste.
create or replace function public.club_account_addon(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case when public.club_subscription_tier(target_club) <> 'pro' then 0 else coalesce(
    (
      select case p.code
        when 'club_addon_500_monthly'  then 500
        when 'club_addon_1000_monthly' then 1000
        when 'club_addon_1500_monthly' then 1500
        when 'club_addon_2000_monthly' then 2000
      end
      from public.club_subscriptions s
      join public.subscription_plans p on p.id = s.plan_id
      where s.club_id = target_club
        and s.status = 'active'
        and (s.current_period_end is null or s.current_period_end > now())
        and p.code like 'club_addon_%'
      order by case p.code
        when 'club_addon_2000_monthly' then 0
        when 'club_addon_1500_monthly' then 1
        when 'club_addon_1000_monthly' then 2
        else 3
      end
      limit 1
    ),
    0
  ) end;
$$;

grant execute on function public.club_account_limit(uuid) to authenticated;
grant execute on function public.club_account_addon(uuid) to authenticated;

-- Kontrolle: vier aktive Pakete, und je Verein die neue Grenze.
select code, price_cents from public.subscription_plans
where code like 'club_addon_%' and active order by price_cents;

select c.name,
       public.club_subscription_tier(c.id) as tarif,
       public.club_account_count(c.id)     as belegt,
       public.club_account_limit(c.id)     as grenze
from public.clubs c order by c.name limit 10;
