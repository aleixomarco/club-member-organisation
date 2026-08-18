-- Nachtrag: Zugangsgrenzen von 250/500 auf 350/700 anheben.
--
-- Die erste Fassung von club_account_limit lief bereits in der TEST-Datenbank
-- und kannte 100/250/500. Hier wird nur diese eine Funktion ersetzt; alles
-- andere bleibt unveraendert.
--
-- Nur in der TEST-Datenbank ausführen.

create or replace function public.club_account_limit(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case public.club_subscription_tier(target_club)
    when 'basic' then 100
    when 'plus'  then 350
    when 'pro'   then 700
    else 0
  end + public.club_account_addon(target_club);
$$;

grant execute on function public.club_account_limit(uuid) to authenticated;

-- Kontrolle: zeigt je Verein den Tarif und die daraus folgende Grenze.
select c.name,
       public.club_subscription_tier(c.id) as tarif,
       public.club_account_count(c.id)     as belegt,
       public.club_account_limit(c.id)     as grenze
from public.clubs c
order by c.name
limit 10;
