-- Nutzer-Abo "Basis" wieder einführen — diesmal ZUSÄTZLICH zum Vereinsabo, nicht
-- als Ersatz.
--
-- Modell:
--   * Der Verein zahlt weiterhin Basic (34,99 €) oder Premium (39,99 €) und gibt
--     damit vor, WELCHE Funktionen im Verein überhaupt zur Verfügung stehen.
--   * Jedes Mitglied zahlt zusätzlich 2,99 €/Monat (oder 14,28 € im Jahr, also
--     1,19 €/Monat) für seinen persönlichen Zugang. Ohne dieses Abo sieht das
--     Mitglied nur Training und Spiele — unabhängig davon, was der Verein zahlt.
--   * Beim Mitglied gibt es nur zwei Stufen: kostenlos und Basis. Kein Premium.
--     Was ein Mitglied mit Basis tun darf, ergibt sich aus seinen Rollen.
--   * Die persönlichen 2 Wochen ab Beitritt zählen wie ein bezahltes Basis-Abo.

-- Mitglieder-Tarife wieder aktivieren und auf die aktuellen Preise setzen.
insert into public.subscription_plans (code, name, interval, price_cents) values
  ('member_monthly', 'Basis – Monatsabo', 'month', 299),
  ('member_yearly',  'Basis – Jahresabo', 'year',  1428)
on conflict (code) do update set
  name = excluded.name,
  interval = excluded.interval,
  price_cents = excluded.price_cents,
  active = true;

-- Läuft für dieses Profil gerade ein bezahltes Basis-Abo?
create or replace function public.member_plan_active(target_profile uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.user_subscriptions s
    join public.subscription_plans p on p.id = s.plan_id
    where s.profile_id = target_profile
      and p.code like 'member\_%'
      and s.status = 'active'
      and (s.current_period_end is null or s.current_period_end > now())
  );
$$;

grant execute on function public.member_plan_active(uuid) to authenticated;

-- Hat das Mitglied persönlichen Zugang? Entweder läuft der 2-Wochen-Zeitraum ab
-- Beitritt, oder es hat ein bezahltes Basis-Abo. Verwaltete Profile ohne eigenes
-- Konto (z. B. Kinder ohne Handy) haben kein Profil und damit keinen eigenen
-- Zugang — sie werden über die Eltern eingesehen.
create or replace function public.member_has_access(target_membership uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
    public.member_trial_active(target_membership)
    or (
      select public.member_plan_active(m.profile_id)
      from public.club_memberships m
      where m.id = target_membership and m.profile_id is not null
    ),
    false
  );
$$;

grant execute on function public.member_has_access(uuid) to authenticated;

-- Effektive Stufe für ein Mitglied JETZT.
--
-- Beides muss stimmen: Ohne persönlichen Zugang bleibt es bei 'none', auch wenn
-- der Verein Premium zahlt. Und mit persönlichem Zugang gilt höchstens das, was
-- der Verein gebucht hat — ein Mitglied kann nicht mehr freischalten als sein
-- Verein bereitstellt.
create or replace function public.member_entitlement_tier(target_membership uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when not public.member_has_access(target_membership) then 'none'
    else coalesce(
      (select public.club_subscription_tier(m.club_id)
       from public.club_memberships m where m.id = target_membership),
      'none'
    )
  end;
$$;

grant execute on function public.member_entitlement_tier(uuid) to authenticated;

-- Für die Anzeige in "Meine Abonnements": Zustand des persönlichen Zugangs.
create or replace function public.member_access_info(target_membership uuid)
returns table(
  has_access boolean,
  trialing boolean,
  trial_ends_at timestamptz,
  plan_code text,
  period_end timestamptz
) language sql stable security definer set search_path = '' as $$
  select
    public.member_has_access(target_membership),
    (m.created_at + public.trial_period() > now()),
    (m.created_at + public.trial_period()),
    (select p.code
     from public.user_subscriptions s
     join public.subscription_plans p on p.id = s.plan_id
     where s.profile_id = m.profile_id
       and p.code like 'member\_%'
       and s.status = 'active'
       and (s.current_period_end is null or s.current_period_end > now())
     order by s.current_period_end desc nulls last
     limit 1),
    (select s.current_period_end
     from public.user_subscriptions s
     join public.subscription_plans p on p.id = s.plan_id
     where s.profile_id = m.profile_id
       and p.code like 'member\_%'
       and s.status = 'active'
     order by s.current_period_end desc nulls last
     limit 1)
  from public.club_memberships m
  where m.id = target_membership;
$$;

grant execute on function public.member_access_info(uuid) to authenticated;
