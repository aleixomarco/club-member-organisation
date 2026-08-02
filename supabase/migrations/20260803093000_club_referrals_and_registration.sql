-- =====================================================================
-- 20260803093000_club_referrals_and_registration.sql
-- "Vereine werben Vereine" (einmalig, 3 Freimonate) + zusätzliche
-- Pflichtfelder bei der Vereinsregistrierung (Registernummer, Währung).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Vereinsregistrierung: Registernummer + Währung
-- ---------------------------------------------------------------------
alter table public.clubs
  add column if not exists registration_number text,
  add column if not exists currency char(3) not null default 'EUR';

comment on column public.clubs.registration_number is 'Vereinsregisternummer, Pflichtfeld im Registrierungsformular (Frontend-Validierung)';
comment on column public.clubs.currency is 'ISO 4217, Default EUR. Vereinslogo/logo_url siehe bestehende Migration.';

-- ---------------------------------------------------------------------
-- 2) Empfehlungscodes: ein Verein kann genau EINEN Code erzeugen,
--    der genau EINMAL von einem neuen Verein eingelöst werden kann.
-- ---------------------------------------------------------------------
create table public.club_referrals (
  id uuid primary key default gen_random_uuid(),
  referring_club_id uuid not null unique references public.clubs(id), -- "nur 1 Verein werben möglich"
  referral_code text not null unique,
  reward_months int not null default 3,
  used_by_club_id uuid unique references public.clubs(id),
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_club_referrals_code on public.club_referrals(referral_code);

alter table public.club_referrals enable row level security;

-- Jeder eingeloggte Nutzer darf den eigenen Empfehlungsstatus lesen (für Tab-5-Sichtbarkeit)
create policy club_referrals_select_own
  on public.club_referrals for select
  to authenticated
  using (
    referring_club_id = (select club_id from public.profiles where id = auth.uid())
    or used_by_club_id = (select club_id from public.profiles where id = auth.uid())
    or public.is_sys_admin(auth.uid())
  );

-- Erzeugen/Einlösen ausschließlich über die unten stehenden SECURITY DEFINER
-- Funktionen (kein direktes INSERT/UPDATE durch Nutzer) -> keine weitere Policy nötig.

-- ---------------------------------------------------------------------
-- 3) Code generieren (einmalig pro Verein)
-- ---------------------------------------------------------------------
create or replace function public.generate_club_referral_code()
returns text
language plpgsql
as $$
declare
  v_code text;
begin
  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
    exit when not exists (select 1 from public.club_referrals where referral_code = v_code);
  end loop;
  return v_code;
end;
$$;

create or replace function public.create_club_referral_code(p_club_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing text;
  v_new_code text;
begin
  select referral_code into v_existing from public.club_referrals where referring_club_id = p_club_id;
  if v_existing is not null then
    return v_existing; -- bereits vorhanden -> denselben Code zurückgeben statt Fehler
  end if;

  v_new_code := public.generate_club_referral_code();
  insert into public.club_referrals (referring_club_id, referral_code) values (p_club_id, v_new_code);
  return v_new_code;
end;
$$;

-- ---------------------------------------------------------------------
-- 4) Code bei Vereinsregistrierung einlösen
--    (aus dem Registrierungsformular aufzurufen, BEVOR/NACHDEM der
--    neue Verein in `clubs` angelegt wurde)
-- ---------------------------------------------------------------------
create or replace function public.redeem_club_referral(p_code text, p_new_club_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.club_referrals%rowtype;
begin
  select * into v_row from public.club_referrals where referral_code = upper(trim(p_code)) for update;

  if v_row.id is null then
    raise exception 'Empfehlungscode ungültig.';
  end if;
  if v_row.used_by_club_id is not null then
    raise exception 'Empfehlungscode wurde bereits eingelöst.';
  end if;
  if v_row.referring_club_id = p_new_club_id then
    raise exception 'Ein Verein kann seinen eigenen Code nicht einlösen.';
  end if;

  update public.club_referrals
  set used_by_club_id = p_new_club_id, used_at = now()
  where id = v_row.id;

  -- INTEGRATIONSPUNKT: Gutschrift von reward_months auf das Abo des
  -- WERBENDEN Vereins (v_row.referring_club_id) verbuchen. Da die genaue
  -- Struktur von club_subscriptions hier nicht vorliegt, an dieser Stelle
  -- den bestehenden Aufruf ergänzen, z. B.:
  --   perform public.credit_club_subscription_months(v_row.referring_club_id, v_row.reward_months);
  -- Diese Funktion existiert noch nicht -- siehe Hinweis in der Spec-Datei.

  return true;
end;
$$;

-- ---------------------------------------------------------------------
-- 5) Sichtbarkeits-Helfer für Tab 5 ("Vereine werben Vereine")
--    Frontend ruft diese Funktion; false = Tab ausblenden (außer Sys-Admin)
-- ---------------------------------------------------------------------
create or replace function public.club_referral_tab_visible(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.club_referrals
    where referring_club_id = p_club_id and used_by_club_id is not null
  );
$$;
