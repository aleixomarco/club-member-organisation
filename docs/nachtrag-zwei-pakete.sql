-- Nachtrag: nur noch zwei Zusatzpakete, +100 und +500.
--
-- Die erste Fassung legte drei Pakete an (100 / 250 / 500). Das mittlere
-- entfällt. Es wird nicht gelöscht, sondern stillgelegt - zu einem Plan können
-- Zeilen in club_subscriptions gehören, und ein Fremdschlüssel verweist darauf.
--
-- Nur in der TEST-Datenbank ausführen.

update public.subscription_plans
set active = false
where code = 'club_addon_250_monthly';

-- Zuordnung ohne das mittlere Paket neu schreiben.
create or replace function public.club_account_addon(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(
    (
      select case p.code
        when 'club_addon_100_monthly' then 100
        when 'club_addon_500_monthly' then 500
      end
      from public.club_subscriptions s
      join public.subscription_plans p on p.id = s.plan_id
      where s.club_id = target_club
        and s.status = 'active'
        and (s.current_period_end is null or s.current_period_end > now())
        and p.code like 'club_addon_%'
      order by case p.code
        when 'club_addon_500_monthly' then 0
        else 1
      end
      limit 1
    ),
    0
  );
$$;

grant execute on function public.club_account_addon(uuid) to authenticated;

-- Kontrolle: muss genau zwei aktive Zusatzpakete zeigen.
select code, name, price_cents, active
from public.subscription_plans
where code like 'club_addon_%'
order by price_cents;
