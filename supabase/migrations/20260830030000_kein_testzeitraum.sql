-- Der befristete Testzeitraum entfällt.
--
-- club_subscription_tier() gab einem Verein in den ersten vierzehn Tagen nach
-- seiner Anlage den höchsten Tarif ('pro'), ohne dass je ein Abo bestand. Das
-- war der stille Teil des Testzeitraums.
--
-- Er ist ersatzlos gestrichen: Ein Verein ohne Abonnement hat 'none' und damit
-- die kostenlose Stufe mit ihren Zugängen. Es gibt keine Frist mehr, nach deren
-- Ablauf Funktionen wegbrechen — der kostenlose Umfang gilt dauerhaft.
--
-- Kein Verein ist davon betroffen: Zum Zeitpunkt dieser Migration lag bei allen
-- fünf Vereinen die Anlage länger als der Testzeitraum zurück, keiner bezog
-- seinen Tarif aus dem Rückfall.
--
-- trial_period(), club_trial_info() und member_trial_info() bleiben bestehen.
-- Sie werden von der Oberfläche nicht mehr aufgerufen, und ein DROP würde
-- Migrationen brechen, die sie voraussetzen. Sie gewähren nichts.

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
    'none'
  );
$$;

grant execute on function public.club_subscription_tier(uuid) to authenticated;

-- Kontrolle: Kein Verein darf seinen Tarif verlieren, der ein echtes Abo hat.
select c.name, public.club_subscription_tier(c.id) as tarif,
       (select count(*) from public.club_subscriptions s
        where s.club_id = c.id and s.status = 'active') as aktive_abos
from public.clubs c
order by c.name;
