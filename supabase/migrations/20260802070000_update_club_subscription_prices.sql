-- Aktualisierte Vereinspreise: 29,99 EUR monatlich oder 299,88 EUR jährlich.
update public.subscription_plans set price_cents = 2999, name = 'Vereinsaccount – Monatsabo', active = true
where code = 'club_monthly';
update public.subscription_plans set price_cents = 29988, name = 'Vereinsaccount – Jahresabo', active = true
where code = 'club_yearly';
