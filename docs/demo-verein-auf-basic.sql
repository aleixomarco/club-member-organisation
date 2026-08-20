-- Demo-Verein auf den Tarif umstellen, der tatsächlich verkauft wird.
--
-- Zweck: Der Prüfer soll denselben Tarif sehen, den ein Kunde kaufen kann.
-- Derzeit läuft ERG Iserlohn auf einem manuellen Premium-Abo, das die
-- Übergangsregel auf 'plus' abbildet - eine Stufe, die im App Store gar nicht
-- angeboten wird.
--
-- Danach zeigt die App: "Basic, 23 von 100 Zugängen belegt".
--
-- In PROD ausführen (Projekt Club Member Organisation, Branch main).

do $$
declare
  ziel_club uuid;
  ziel_name text;
  plan_basic uuid;
  geaendert integer;
begin
  select c.id, c.name into ziel_club, ziel_name
  from public.clubs c
  where c.name = 'ERG Iserlohn'
  limit 1;

  if ziel_club is null then
    raise exception 'Verein ERG Iserlohn nicht gefunden - Namen prüfen';
  end if;

  select id into plan_basic
  from public.subscription_plans where code = 'club_basic_yearly';

  if plan_basic is null then
    raise exception 'club_basic_yearly fehlt - lief die Migration in dieser Datenbank?';
  end if;

  update public.club_subscriptions
  set plan_id = plan_basic, updated_at = now()
  where club_id = ziel_club
    and status = 'active'
    and provider = 'manual';

  get diagnostics geaendert = row_count;

  if geaendert = 0 then
    raise exception 'Kein manuelles Abo für % gefunden - nichts geändert', ziel_name;
  end if;

  raise notice '% Abo(s) für % auf Basic umgestellt', geaendert, ziel_name;
end $$;

-- Kontrolle: muss basic und Grenze 100 zeigen.
select c.name,
       public.club_subscription_tier(c.id) as tarif,
       public.club_account_count(c.id)     as belegt,
       public.club_account_limit(c.id)     as grenze
from public.clubs c
where c.name = 'ERG Iserlohn';
