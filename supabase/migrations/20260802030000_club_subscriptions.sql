-- Vereins-Abonnements: 29,99 EUR monatlich oder 299,88 EUR jährlich.

insert into public.subscription_plans (code, name, interval, price_cents) values
  ('club_monthly', 'Vereinsaccount – Monatsabo', 'month', 2999),
  ('club_yearly', 'Vereinsaccount – Jahresabo', 'year', 29988)
on conflict (code) do update set
  name = excluded.name,
  interval = excluded.interval,
  price_cents = excluded.price_cents,
  active = true;

create table public.club_subscriptions (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  provider public.subscription_provider not null,
  provider_subscription_id text not null,
  status public.subscription_status not null default 'pending',
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  cancelled_at timestamptz,
  last_payment_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_subscription_id)
);

create trigger club_subscriptions_touch before update on public.club_subscriptions
for each row execute function public.touch_updated_at();

alter table public.club_subscriptions enable row level security;

create policy "club admins read club subscriptions" on public.club_subscriptions
for select to authenticated using (
  public.has_club_role(club_id, array['sysadmin','vereinsadmin','geschaeftsfuehrung']::public.club_role[])
);

create index club_subscriptions_club_status_idx on public.club_subscriptions(club_id, status);

create or replace function public.club_has_active_subscription(target_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.club_subscriptions s
    where s.club_id = target_club
      and s.status = 'active'
      and (s.current_period_end is null or s.current_period_end > now())
  );
$$;

grant execute on function public.club_has_active_subscription(uuid) to authenticated;
