-- Die Push-Registrierung, ebenfalls nur in der Produktivdatenbank vorhanden.
--
-- Hier stehen die Gerätekennungen, an die Benachrichtigungen gehen. Sie sind
-- kein Beiwerk: Ohne diese Tabelle nimmt die App zwar Registrierungen entgegen,
-- schreibt sie aber ins Leere — und niemand bekäme je eine Benachrichtigung,
-- ohne dass irgendwo ein Fehler sichtbar würde.

create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  fcm_token text not null,
  platform text not null default 'web',
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (membership_id, fcm_token)
);

alter table public.push_subscriptions enable row level security;

-- Jeder verwaltet nur seine eigenen Geraete.
drop policy if exists "members manage own push subscriptions" on public.push_subscriptions;
create policy "members manage own push subscriptions" on public.push_subscriptions for all to authenticated
using (membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid()))
with check (membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid()));

grant select, insert, update, delete on public.push_subscriptions to authenticated;
