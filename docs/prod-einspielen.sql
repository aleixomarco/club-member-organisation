-- PROD-Einspielung des neuen Tarifmodells.
--
-- ERST AUSFÜHREN, wenn die laufende Apple-Prüfung abgeschlossen ist und die
-- sechs neuen Produkte in App Store Connect freigegeben sind. Vorher würde ein
-- Verein Tarife sehen, die er nicht kaufen kann.
--
-- Diese Datei ist identisch mit der Migration
-- supabase/migrations/20260817190000_groessenstaffel.sql. Wer die Migration
-- über die Supabase-CLI einspielt, braucht sie nicht.
--
-- Reihenfolge in PROD:
--   1. dieses SQL
--   2. tarifmodell nach main, Vercel baut neu
--   3. Kontrollabfrage unten

-- ---------------------------------------------------------------- Tarife

insert into public.subscription_plans (code, name, interval, price_cents) values
  ('club_basic_monthly', 'Basic – Monatsabo', 'month',   2499),
  ('club_basic_yearly',  'Basic – Jahresabo', 'year',   23999),
  ('club_plus_monthly',  'Plus – Monatsabo',  'month',   4999),
  ('club_plus_yearly',   'Plus – Jahresabo',  'year',   47999),
  ('club_pro_monthly',   'Pro – Monatsabo',   'month',   9999),
  ('club_pro_yearly',    'Pro – Jahresabo',   'year',   95999)
on conflict (code) do update set
  name = excluded.name,
  interval = excluded.interval,
  price_cents = excluded.price_cents,
  active = true;

-- Die beiden Mitglieds-Abos werden nicht gelöscht: Zu ihnen können in der
-- Produktion noch Zeilen in user_subscriptions gehören, und ein Fremdschlüssel
-- verweist darauf. Sie werden nur stillgelegt.
update public.subscription_plans set active = false
where code in ('member_monthly', 'member_yearly', 'club_monthly', 'club_yearly')
   or code like 'club_addon_%';

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

-- Obergrenze: Grundstufe plus Paket.
--
-- Ohne Abo gilt eine kostenlose Kleinstufe von drei Zugängen. Ein kleiner
-- Verein kann die App damit dauerhaft nutzen, ohne zu zahlen; wächst er
-- darüber hinaus, wird daraus ein Angebot statt einer Mauer.
create or replace function public.club_account_limit(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case public.club_subscription_tier(target_club)
    when 'basic' then 100
    when 'plus'  then 350
    when 'pro'   then 1000
    else 3
  end;
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
            hint = 'Der Verein braucht einen größeren Tarif.';
  end if;

  return new;
end;
$$;

drop trigger if exists club_memberships_account_limit on public.club_memberships;
create trigger club_memberships_account_limit
  before insert or update on public.club_memberships
  for each row execute function public.enforce_club_account_limit();

-- Kontrolle nach dem Einspielen.
select code, price_cents, active from public.subscription_plans
where code like 'club_%' or code like 'member_%' order by active desc, price_cents;

select c.name,
       public.club_subscription_tier(c.id) as tarif,
       public.club_account_count(c.id)     as belegt,
       public.club_account_limit(c.id)     as grenze
from public.clubs c order by c.name;
