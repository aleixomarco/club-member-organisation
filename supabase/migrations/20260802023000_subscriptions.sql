-- Plattformübergreifende Abonnements: PayPal Web und Apple StoreKit

create type public.subscription_provider as enum ('paypal', 'apple', 'manual');
create type public.subscription_interval as enum ('month', 'year');
create type public.subscription_status as enum ('pending', 'active', 'past_due', 'suspended', 'cancelled', 'expired', 'refunded');

create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  interval public.subscription_interval not null,
  price_cents integer not null check (price_cents > 0),
  currency text not null default 'EUR' check (currency = 'EUR'),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
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

create table public.payment_events (
  id uuid primary key default gen_random_uuid(),
  provider public.subscription_provider not null,
  provider_event_id text not null,
  event_type text not null,
  provider_subscription_id text,
  verified boolean not null default false,
  payload jsonb not null,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (provider, provider_event_id)
);

create trigger subscriptions_touch before update on public.user_subscriptions
for each row execute function public.touch_updated_at();

alter table public.subscription_plans enable row level security;
alter table public.user_subscriptions enable row level security;
alter table public.payment_events enable row level security;

create policy "authenticated users read active plans" on public.subscription_plans
for select to authenticated using (active);
create policy "users read own subscriptions" on public.user_subscriptions
for select to authenticated using (profile_id = auth.uid());

insert into public.subscription_plans (code, name, interval, price_cents) values
  ('member_monthly', 'Monatsabo', 'month', 299),
  ('member_yearly', 'Jahresabo', 'year', 1188)
on conflict (code) do update set
  name = excluded.name,
  interval = excluded.interval,
  price_cents = excluded.price_cents,
  active = true;

create index subscriptions_profile_status_idx on public.user_subscriptions(profile_id, status);
create index payment_events_subscription_idx on public.payment_events(provider_subscription_id);

create or replace function public.has_active_subscription(target_profile uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.user_subscriptions s
    where s.profile_id = target_profile
      and s.status = 'active'
      and (s.current_period_end is null or s.current_period_end > now())
  );
$$;

grant execute on function public.has_active_subscription(uuid) to authenticated;

