-- Google Play als eigener Zahlungsanbieter neben 'apple' — beide laufen über
-- RevenueCat, aber getrennt geführt (z. B. für die Anzeige "über den App
-- Store" vs. "über Google Play" in "Meine Abonnements").
alter type public.subscription_provider add value if not exists 'google_play';
