-- =====================================================================
-- 20260803100000_club_subscription_credits.sql
-- Generisches Freimonate-/Guthaben-System für Vereinsabos. Da es aktuell
-- noch keine Rabatt-/Gutschrift-Logik gibt, wird hier ein eigenständiger,
-- von der genauen `club_subscriptions`-Struktur unabhängiger Mechanismus
-- angelegt: Gutschriften werden gesammelt und von der bestehenden
-- Billing-/PayPal-Logik "konsumiert", statt Spalten in eine unbekannte
-- Tabelle zu raten.
-- =====================================================================

create table public.club_subscription_credits (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id),
  months int not null check (months > 0),
  reason text not null check (reason in ('referral', 'promo', 'manual', 'goodwill')),
  source_type text,          -- z. B. 'club_referrals'
  source_id uuid,            -- z. B. club_referrals.id
  applied boolean not null default false,
  applied_at timestamptz,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create index idx_club_subscription_credits_club on public.club_subscription_credits(club_id) where not applied;

alter table public.club_subscription_credits enable row level security;

-- Club-Admin/Vorstand/Sys-Admin des betroffenen Vereins dürfen die eigenen
-- Gutschriften sehen (für die Anzeige "Du hast noch X Freimonate offen").
create policy club_subscription_credits_select_own_club
  on public.club_subscription_credits for select
  to authenticated
  using (
    club_id = (select club_id from public.profiles where id = auth.uid())
    or public.is_sys_admin(auth.uid())
  );
-- Kein direktes INSERT/UPDATE für Nutzer -- ausschließlich über die
-- folgenden SECURITY DEFINER Funktionen.

-- ---------------------------------------------------------------------
-- Gutschrift anlegen (generisch nutzbar, nicht nur für Empfehlungen)
-- ---------------------------------------------------------------------
create or replace function public.credit_club_subscription_months(
  p_club_id uuid,
  p_months int,
  p_reason text,
  p_source_type text default null,
  p_source_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.club_subscription_credits (club_id, months, reason, source_type, source_id, created_by)
  values (p_club_id, p_months, p_reason, p_source_type, p_source_id, auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- Offene (noch nicht verbrauchte) Freimonate anzeigen, ohne sie zu verbrauchen
-- -> für die UI-Anzeige im Vereinsabo-Bereich
-- ---------------------------------------------------------------------
create or replace function public.get_pending_credit_months(p_club_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(months), 0)::int
  from public.club_subscription_credits
  where club_id = p_club_id and not applied;
$$;

-- ---------------------------------------------------------------------
-- Freimonate verbrauchen: von der bestehenden Billing-/PayPal-Logik
-- aufzurufen, BEVOR die nächste Abrechnung ausgelöst/angezeigt wird.
-- Gibt die Anzahl zu überspringender Monate zurück und markiert sie
-- als verbraucht (idempotent pro Aufruf -- ein zweiter Aufruf ohne neue
-- Gutschrift liefert 0).
-- ---------------------------------------------------------------------
create or replace function public.consume_club_subscription_credit(p_club_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total int;
begin
  select coalesce(sum(months), 0) into v_total
  from public.club_subscription_credits
  where club_id = p_club_id and not applied;

  if v_total > 0 then
    update public.club_subscription_credits
    set applied = true, applied_at = now()
    where club_id = p_club_id and not applied;
  end if;

  return v_total;
end;
$$;

-- ---------------------------------------------------------------------
-- Empfehlungscode-Einlösung jetzt tatsächlich verbuchen (ersetzt den
-- Kommentar-Platzhalter aus 20260803093000_club_referrals_and_registration.sql)
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

  perform public.credit_club_subscription_months(
    v_row.referring_club_id, v_row.reward_months, 'referral', 'club_referrals', v_row.id
  );

  return true;
end;
$$;

comment on function public.consume_club_subscription_credit(uuid) is
  'Vom bestehenden PayPal-/Billing-Code beim Verlängern eines Vereinsabos aufzurufen: gibt zu überspringende Monate zurück und markiert Gutschriften als verbraucht.';
