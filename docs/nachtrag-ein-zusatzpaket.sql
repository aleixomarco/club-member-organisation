-- Nachtrag: Pro auf 1.000 Zugänge, nur noch ein Zusatzpaket.
--
-- Ersetzt die bisherigen Fassungen. Die nicht mehr angebotenen Pakete werden
-- stillgelegt statt gelöscht - zu ihnen können Zeilen in club_subscriptions
-- gehören, und ein Fremdschlüssel verweist darauf.
--
-- Der Preis des Zusatzpakets ist bewusst hoch: Die Aufpreise zwischen den
-- Stufen liegen bei 25 EUR (Basic auf Plus) und 50 EUR (Plus auf Pro). Ein
-- Paket für 49,99 EUR ist damit überall das schlechtere Geschäft, solange es
-- noch eine größere Stufe gibt - sinnvoll wird es erst oberhalb von Pro.
--
-- Nur in der TEST-Datenbank ausführen.

update public.subscription_plans set active = false
where code in ('club_addon_250_monthly', 'club_addon_500_monthly');

insert into public.subscription_plans (code, name, interval, price_cents) values
  ('club_addon_100_monthly', 'Zusatzpaket – 100 weitere Zugänge', 'month', 4999)
on conflict (code) do update set
  name = excluded.name,
  price_cents = excluded.price_cents,
  active = true;

-- Pro auf 1.000.
create or replace function public.club_account_limit(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case public.club_subscription_tier(target_club)
    when 'basic' then 100
    when 'plus'  then 350
    when 'pro'   then 1000
    else 0
  end + public.club_account_addon(target_club);
$$;

-- Nur noch ein Paket.
create or replace function public.club_account_addon(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(
    (
      select case p.code when 'club_addon_100_monthly' then 100 end
      from public.club_subscriptions s
      join public.subscription_plans p on p.id = s.plan_id
      where s.club_id = target_club
        and s.status = 'active'
        and (s.current_period_end is null or s.current_period_end > now())
        and p.code like 'club_addon_%'
      limit 1
    ),
    0
  );
$$;

grant execute on function public.club_account_limit(uuid) to authenticated;
grant execute on function public.club_account_addon(uuid) to authenticated;

-- Kontrolle: ein aktives Zusatzpaket, und je Verein die neue Grenze.
select code, price_cents, active from public.subscription_plans
where code like 'club_addon_%' order by code;

select c.name,
       public.club_subscription_tier(c.id) as tarif,
       public.club_account_count(c.id)     as belegt,
       public.club_account_limit(c.id)     as grenze
from public.clubs c order by c.name limit 10;
