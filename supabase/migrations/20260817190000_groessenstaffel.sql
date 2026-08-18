-- Neues Tarifmodell: Staffelung nach Zahl der Zugänge statt nach Funktionen
--
-- Bisher unterschieden sich Basic und Premium im Funktionsumfang, und jedes
-- Mitglied zahlte zusätzlich einen eigenen Basis-Zugang. Beides entfällt.
-- Künftig zahlt nur der Verein, alle zahlenden Vereine bekommen denselben
-- Funktionsumfang, und der Preis richtet sich danach, wie viele Personen sich
-- tatsächlich anmelden können.
--
--   Basic  bis 100 Zugänge
--   Plus   bis 350 Zugänge
--   Pro    bis 1000 Zugänge, erweiterbar um 100 weitere
--
-- Gezählt wird jedes selbst angemeldete Konto. Wer ohne eigenen Login
-- eingetragen wird - ein Kind etwa, das der Vater anlegt - zählt nicht;
-- solche Datensätze tragen is_managed_profile = true.

-- ---------------------------------------------------------------- Tarife

insert into public.subscription_plans (code, name, interval, price_cents) values
  ('club_basic_monthly',    'Basic – Monatsabo',              'month',  2499),
  ('club_basic_yearly',     'Basic – Jahresabo',              'year',  23999),
  ('club_plus_monthly',     'Plus – Monatsabo',               'month',  4999),
  ('club_plus_yearly',      'Plus – Jahresabo',               'year',  47999),
  ('club_pro_monthly',      'Pro – Monatsabo',                'month',  9999),
  ('club_pro_yearly',       'Pro – Jahresabo',                'year',  95999),
  ('club_addon_100_monthly','Zusatzpaket – 100 weitere Zugänge', 'month', 4999)
on conflict (code) do update set
  name = excluded.name,
  interval = excluded.interval,
  price_cents = excluded.price_cents,
  active = true;

-- Die beiden Mitglieds-Abos werden nicht gelöscht: Zu ihnen können in der
-- Produktion noch Zeilen in user_subscriptions gehören, und ein Fremdschlüssel
-- verweist darauf. Sie werden nur stillgelegt.
update public.subscription_plans set active = false
where code in ('member_monthly', 'member_yearly', 'club_monthly', 'club_yearly');

-- ------------------------------------------------------- Effektiver Tarif

-- Reihenfolge zählt: Wer mehrere aktive Abos hat, bekommt das höchste.
-- club_premium_% und club_monthly/yearly sind Altbestand aus dem vorherigen
-- Modell und werden auf die nächstliegende neue Stufe abgebildet.
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
        and p.code not like 'club_addon_%'
      order by case
        when p.code like 'club_pro_%'     then 0
        when p.code like 'club_premium_%' then 1
        when p.code like 'club_plus_%'    then 1
        else 2
      end
      limit 1
    ),
    -- Während des Testzeitraums gilt die höchste Stufe.
    (
      select 'pro'
      from public.clubs c
      where c.id = target_club and c.created_at + public.trial_period() > now()
    ),
    'none'
  );
$$;

grant execute on function public.club_subscription_tier(uuid) to authenticated;

-- ------------------------------------------------- Mitglieder zahlen nicht

-- Der persönliche Zugang entfällt ersatzlos. Die Funktion bleibt bestehen,
-- weil member_entitlement_tier und die Oberfläche sie aufrufen; sie liefert
-- ab jetzt immer wahr.
--
-- Würde man stattdessen nur die beiden Produkte aus dem Verkauf nehmen,
-- verlöre jedes Mitglied vierzehn Tage nach seiner Anlage sämtliche
-- Funktionen - der Testzeitraum wäre dann die einzige Quelle des Zugangs.
create or replace function public.member_has_access(target_membership uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select true;
$$;

grant execute on function public.member_has_access(uuid) to authenticated;

-- ------------------------------------------------------ Zugänge und Grenze

-- Zählt die Konten eines Vereins: aktiv, mit eigenem Login, nicht verwaltet.
create or replace function public.club_account_count(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer
  from public.club_memberships m
  where m.club_id = target_club
    and m.status = 'active'
    and m.profile_id is not null
    and m.is_managed_profile = false;
$$;

grant execute on function public.club_account_count(uuid) to authenticated;

-- Zusätzliche Zugänge aus einem gebuchten Paket. Es kann immer nur eines
-- aktiv sein - Apple erlaubt pro Abo-Gruppe genau ein Abonnement.
create or replace function public.club_account_addon(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(
    (
      select case p.code
        when 'club_addon_100_monthly' then 100
      end
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

grant execute on function public.club_account_addon(uuid) to authenticated;

-- Obergrenze: Grundstufe plus Paket. Ohne Abo wächst kein Verein mehr -
-- bestehende Konten bleiben nutzbar, neue kommen nicht hinzu.
create or replace function public.club_account_limit(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case public.club_subscription_tier(target_club)
    when 'basic' then 100
    when 'plus'  then 350
    when 'pro'   then 1000
    else 0
  end + public.club_account_addon(target_club);
$$;

grant execute on function public.club_account_limit(uuid) to authenticated;

-- Für die Anzeige in der App: verbraucht, erlaubt, Tarif.
create or replace function public.club_account_usage(target_club uuid)
returns table(used integer, allowed integer, tier text)
language sql stable security definer set search_path = '' as $$
  select public.club_account_count(target_club),
         public.club_account_limit(target_club),
         public.club_subscription_tier(target_club);
$$;

grant execute on function public.club_account_usage(uuid) to authenticated;

-- ------------------------------------------------------------ Durchsetzung

-- Die Grenze wird in der Datenbank durchgesetzt, nicht in der Oberfläche.
-- So greift sie auf jedem Weg: über die App, über register_for_club, über
-- eine Einladung oder über den SQL-Editor.
create or replace function public.enforce_club_account_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  wird_zum_konto boolean;
  grenze integer;
  belegt integer;
begin
  -- Nur wenn diese Zeile durch die Änderung neu zu einem zählenden Konto
  -- wird. Bestehende aktive Konten dürfen jederzeit bearbeitet werden.
  wird_zum_konto :=
    new.status = 'active'
    and new.profile_id is not null
    and new.is_managed_profile = false
    and (
      tg_op = 'INSERT'
      or old.status <> 'active'
      or old.profile_id is null
      or old.is_managed_profile = true
    );

  if not wird_zum_konto then
    return new;
  end if;

  grenze := public.club_account_limit(new.club_id);
  belegt := public.club_account_count(new.club_id);

  if belegt >= grenze then
    raise exception 'club_account_limit_reached'
      using detail = format('%s von %s Zugängen belegt', belegt, grenze),
            hint = 'Der Verein braucht einen größeren Tarif oder ein Zusatzpaket.';
  end if;

  return new;
end;
$$;

drop trigger if exists club_memberships_account_limit on public.club_memberships;
create trigger club_memberships_account_limit
  before insert or update on public.club_memberships
  for each row execute function public.enforce_club_account_limit();
