-- Wer zahlt was, seit wann, worüber.
--
-- In PROD ausführen, ändert nichts. Diese Abfrage ist deine
-- betriebswirtschaftliche Sicht - NICHT die Buchhaltung.
--
-- Buchhalterisch hast du einen Vorgang pro Monat: Apples Auszahlung. Die
-- Vereine zahlen an Apple, nicht an dich; du stellst ihnen keine Rechnung.
-- Diese Liste beantwortet die andere Frage: Welcher Verein bringt welchen
-- Umsatz, und wie viele Zugänge nutzt er dafür.

select
  c.name                                   as verein,
  p.name                                   as tarif,
  case s.provider
    when 'apple'  then 'App Store'
    when 'google' then 'Play Store'
    when 'paypal' then 'PayPal'
    when 'manual' then 'manuell (kein Umsatz)'
    else s.provider::text
  end                                      as weg,
  (p.price_cents / 100.0)                  as betrag_brutto,
  case p.interval
    when 'month' then round(p.price_cents / 100.0, 2)
    when 'year'  then round(p.price_cents / 1200.0, 2)
  end                                      as pro_monat,
  s.status,
  s.current_period_start::date             as laeuft_seit,
  s.current_period_end::date               as laeuft_bis,
  s.cancel_at_period_end                   as gekuendigt,
  public.club_account_count(c.id)          as zugaenge_belegt,
  public.club_account_limit(c.id)          as zugaenge_erlaubt
from public.club_subscriptions s
join public.clubs c              on c.id = s.club_id
join public.subscription_plans p on p.id = s.plan_id
order by s.status, c.name;

-- Monatlicher Rohertrag aller laufenden Abos, ohne die Anteile der Stores.
-- Apple behält 15 Prozent (Small Business Program) oder 30 Prozent, PayPal
-- rund 2,49 Prozent plus 0,35 EUR je Zahlung.
select
  count(*)                                                   as laufende_abos,
  round(sum(case p.interval
    when 'month' then p.price_cents / 100.0
    when 'year'  then p.price_cents / 1200.0
  end), 2)                                                   as brutto_pro_monat
from public.club_subscriptions s
join public.subscription_plans p on p.id = s.plan_id
where s.status = 'active'
  and s.provider <> 'manual'
  and (s.current_period_end is null or s.current_period_end > now());
