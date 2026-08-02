-- =====================================================================
-- 20260803090000_profile_extended_settings.sql
-- Erweiterte Profildaten (persönliche Daten, Adresse), Mehrfach-E-Mail/
-- Telefon, Benachrichtigungspräferenzen, Sicherheitseinstellungen.
--
-- WICHTIG: Vor dem Einspielen die tatsächliche `profiles`-Tabelle prüfen
-- (\d profiles im SQL-Editor). Alle ALTER TABLE-Befehle sind defensiv
-- mit IF NOT EXISTS geschrieben, greifen aber nur, wenn die Spaltennamen
-- nicht bereits unter anderem Namen existieren (z. B. member_number).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Persönliche Daten + Adresse direkt an profiles
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists academic_title text,
  add column if not exists gender text check (gender in ('weiblich', 'männlich', 'divers', 'keine Angabe')),
  add column if not exists nationality_country_code char(2),
  add column if not exists street text,
  add column if not exists postal_code text,
  add column if not exists city text,
  add column if not exists country_code char(2);

comment on column public.profiles.nationality_country_code is 'ISO 3166-1 alpha-2, z. B. DE, AT, CH';
comment on column public.profiles.country_code is 'ISO 3166-1 alpha-2 des Wohnsitzlands';

-- Mitgliederausweisnr.: falls noch nicht als member_number vorhanden anlegen
alter table public.profiles
  add column if not exists member_number text;

-- ---------------------------------------------------------------------
-- 2) Mehrere E-Mail-Adressen / Telefonnummern pro Profil ("+"-Button)
-- ---------------------------------------------------------------------
create table if not exists public.profile_emails (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  email text not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  constraint profile_emails_unique unique (profile_id, email)
);
create unique index if not exists idx_profile_emails_one_primary
  on public.profile_emails(profile_id) where is_primary;

create table if not exists public.profile_phones (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  phone text not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  constraint profile_phones_unique unique (profile_id, phone)
);
create unique index if not exists idx_profile_phones_one_primary
  on public.profile_phones(profile_id) where is_primary;

alter table public.profile_emails enable row level security;
alter table public.profile_phones enable row level security;

create policy profile_emails_owner
  on public.profile_emails for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy profile_phones_owner
  on public.profile_phones for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------
-- 3) Benachrichtigungspräferenzen (Ein/Aus je Typ, Default: an)
-- ---------------------------------------------------------------------
create table if not exists public.notification_types (
  key text primary key,
  label text not null,
  sort_order int not null default 0
);

insert into public.notification_types (key, label, sort_order) values
  ('training_cancelled', 'Trainingsabsage',              10),
  ('event_reminder',     'Termin-Erinnerung',             20),
  ('new_news',           'Neue Vereins-News',             30),
  ('chat_message',       'Neue Chat-Nachricht',           40),
  ('fee_due',            'Beitrag fällig',                50),
  ('membership_approved','Mitgliedschaft freigegeben',    60),
  ('role_changed',       'Rollenänderung',                70),
  ('tipp_results',       'Tippspiel-Auswertung',          80),
  ('poll_new',           'Neue Umfrage',                  90),
  ('sponsor_offer',      'Neues Sponsoren-Angebot',      100)
on conflict (key) do nothing;

create table if not exists public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  notification_key text not null references public.notification_types(key),
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint notification_preferences_unique unique (profile_id, notification_key)
);

create trigger trg_notification_preferences_updated_at
  before update on public.notification_preferences
  for each row execute function public.set_updated_at();

alter table public.notification_types enable row level security;
alter table public.notification_preferences enable row level security;

create policy notification_types_select_all
  on public.notification_types for select
  to authenticated
  using (true);

create policy notification_preferences_owner
  on public.notification_preferences for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- Hilfsfunktion: liefert Präferenz inkl. Default true, falls noch kein Datensatz existiert
create or replace function public.get_notification_enabled(p_profile_id uuid, p_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select enabled from public.notification_preferences where profile_id = p_profile_id and notification_key = p_key),
    true
  );
$$;

-- ---------------------------------------------------------------------
-- 4) Sicherheit: automatischer Logout nach Inaktivität
-- ---------------------------------------------------------------------
create table if not exists public.user_security_settings (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  auto_logout_days int check (auto_logout_days in (30, 60, 90)), -- NULL = "Nie"
  updated_at timestamptz not null default now()
);

create trigger trg_user_security_settings_updated_at
  before update on public.user_security_settings
  for each row execute function public.set_updated_at();

alter table public.user_security_settings enable row level security;

create policy user_security_settings_owner
  on public.user_security_settings for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- Leichtgewichtiges Audit für Passwortänderung / "von allen Geräten ausloggen"
create table if not exists public.profile_security_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null check (event_type in ('password_changed', 'logout_all_devices')),
  created_at timestamptz not null default now()
);
alter table public.profile_security_events enable row level security;
create policy profile_security_events_owner_select
  on public.profile_security_events for select
  to authenticated
  using (profile_id = auth.uid());
create policy profile_security_events_owner_insert
  on public.profile_security_events for insert
  to authenticated
  with check (profile_id = auth.uid());
