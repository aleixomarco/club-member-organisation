-- Gestaffelte Vereinsabos (Basic/Premium) + Entitlement-Funktionen.
--
-- Modell:
--   - Verein: 2 Wochen Trial ab Registrierung (clubs.created_at), danach Basic
--     oder Premium nötig, sonst nur Training/Spiele-Ansicht.
--   - Basic  (34,99 €/Monat oder 24,99 €/Monat bei Jahreszahlung):
--     Training/Spiele anlegen funktioniert, alles andere gesperrt.
--   - Premium (39,99 €/Monat oder 29,99 €/Monat bei Jahreszahlung): alles frei.
--   - Jeder Nutzer bekommt zusätzlich einen eigenen, rein persönlichen
--     2-Wochen-Trial ab Mitgliedschaftsbeginn (club_memberships.created_at),
--     unabhängig vom Vereinsstatus — danach zählt der Vereinstarif.
--   - Das bisherige Einzel-Mitglieder-Abo (member_monthly/member_yearly)
--     entfällt ersatzlos.

-- Alte Pläne deaktivieren (nicht löschen — bestehende Subscriptions referenzieren sie).
update public.subscription_plans set active = false
where code in ('club_monthly', 'club_yearly', 'member_monthly', 'member_yearly');

-- Neue gestaffelte Vereinspläne.
insert into public.subscription_plans (code, name, interval, price_cents) values
  ('club_basic_monthly',   'Verein Basic – Monatsabo',   'month', 3499),
  ('club_basic_yearly',    'Verein Basic – Jahresabo',   'year',  29988),
  ('club_premium_monthly', 'Verein Premium – Monatsabo', 'month', 3999),
  ('club_premium_yearly',  'Verein Premium – Jahresabo', 'year',  35988)
on conflict (code) do update set
  name = excluded.name,
  interval = excluded.interval,
  price_cents = excluded.price_cents,
  active = true;

-- Trial-Länge zentral als Konstante über eine Hilfsfunktion, damit sie sich
-- an einer Stelle ändern lässt.
create or replace function public.trial_period()
returns interval language sql immutable set search_path = '' as $$
  select interval '14 days';
$$;

-- Effektiver Vereinstarif JETZT: 'premium' während des Vereins-Trials oder bei
-- aktivem Premium-Abo, 'basic' bei aktivem Basic-Abo, sonst 'none'.
create or replace function public.club_subscription_tier(target_club uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(
    (
      select case
        when p.code like 'club_premium_%' then 'premium'
        when p.code like 'club_basic_%' then 'basic'
      end
      from public.club_subscriptions s
      join public.subscription_plans p on p.id = s.plan_id
      where s.club_id = target_club
        and s.status = 'active'
        and (s.current_period_end is null or s.current_period_end > now())
      order by case when p.code like 'club_premium_%' then 0 else 1 end
      limit 1
    ),
    (
      select 'premium'
      from public.clubs c
      where c.id = target_club and c.created_at + public.trial_period() > now()
    ),
    'none'
  );
$$;

grant execute on function public.club_subscription_tier(uuid) to authenticated;

-- Info fürs Trial-Countdown-UI auf Vereinsebene.
create or replace function public.club_trial_info(target_club uuid)
returns table(trialing boolean, trial_ends_at timestamptz) language sql stable security definer set search_path = '' as $$
  select (c.created_at + public.trial_period() > now()), (c.created_at + public.trial_period())
  from public.clubs c where c.id = target_club;
$$;

grant execute on function public.club_trial_info(uuid) to authenticated;

-- Persönlicher Nutzer-Trial: 2 Wochen ab Mitgliedschaftsbeginn, unabhängig
-- vom Vereinsstatus.
create or replace function public.member_trial_active(target_membership uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (m.created_at + public.trial_period() > now())
  from public.club_memberships m where m.id = target_membership;
$$;

grant execute on function public.member_trial_active(uuid) to authenticated;

create or replace function public.member_trial_info(target_membership uuid)
returns table(trialing boolean, trial_ends_at timestamptz) language sql stable security definer set search_path = '' as $$
  select (m.created_at + public.trial_period() > now()), (m.created_at + public.trial_period())
  from public.club_memberships m where m.id = target_membership;
$$;

grant execute on function public.member_trial_info(uuid) to authenticated;

-- Effektive Berechtigungsstufe für ein einzelnes Mitglied JETZT: eigener
-- Trial übersteuert den Vereinstarif, danach gilt der Vereinstarif.
create or replace function public.member_entitlement_tier(target_membership uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when public.member_trial_active(target_membership) then 'premium'
    else (
      select public.club_subscription_tier(m.club_id)
      from public.club_memberships m where m.id = target_membership
    )
  end;
$$;

grant execute on function public.member_entitlement_tier(uuid) to authenticated;
