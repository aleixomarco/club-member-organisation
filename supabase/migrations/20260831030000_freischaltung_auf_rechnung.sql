-- Freischaltung auf Rechnung statt In-App-Kauf.
--
-- Bisher kaufte die Vereinsleitung das Abo im Store. Das passte nicht zum
-- Produkt: Ein Apple-Abo gehört einer Person, nicht einem Verein. Wechselt der
-- Kassenwart, geht das Abo mit ihm; wer zwei Vereine betreut, kann für den
-- zweiten nicht zahlen; und der Verein bekommt keine Rechnung, sondern eine
-- Belastung auf einem privaten Konto - für einen eingetragenen Verein mit
-- Kassenprüfung kaum verbuchbar.
--
-- Stattdessen fragt der Verein den Vollzugang in der App an, der Betreiber
-- stellt eine Rechnung, und nach Zahlungseingang wird freigeschaltet. Die
-- Freischaltung selbst bleibt unverändert: ein Eintrag in club_subscriptions,
-- den club_subscription_tier auswertet. Nur der Weg dorthin ist ein anderer.

create table if not exists public.club_access_requests (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  requested_by uuid references public.club_memberships(id) on delete set null,
  -- Angaben, die der Verein selbst macht. Sie ersetzen keine Prüfung, sie
  -- ersparen dem Betreiber die Rückfrage.
  contact_name text not null,
  contact_email text not null,
  contact_phone text,
  expected_accounts integer,
  note text,
  -- offen -> in Rechnung gestellt -> freigeschaltet, oder abgelehnt.
  status text not null default 'offen' check (status in ('offen', 'berechnet', 'freigeschaltet', 'abgelehnt')),
  handled_at timestamptz,
  handled_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists club_access_requests_club_idx on public.club_access_requests(club_id, created_at desc);
-- Nur eine offene Anfrage je Verein. Ohne das sammelt sich beim Betreiber
-- derselbe Wunsch mehrfach, weil in der App mehrere Berechtigte sitzen.
create unique index if not exists club_access_requests_eine_offene
  on public.club_access_requests(club_id) where status = 'offen';

create trigger club_access_requests_touch before update on public.club_access_requests
for each row execute function public.touch_updated_at();

alter table public.club_access_requests enable row level security;

-- Lesen darf die Vereinsleitung ihre eigenen Anfragen.
create policy "club leaders read own access requests" on public.club_access_requests
for select to authenticated using (
  public.has_club_role(club_id, array['sysadmin','vereinsadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
);

-- Stellen darf sie die Vereinsleitung ebenfalls - aber nur für den eigenen
-- Verein und nur im Zustand 'offen'. Über alles Weitere entscheidet der
-- Betreiber, und der arbeitet mit dem Dienstschlüssel.
create policy "club leaders create access requests" on public.club_access_requests
for insert to authenticated with check (
  status = 'offen'
  and public.has_club_role(club_id, array['sysadmin','vereinsadmin','geschaeftsfuehrung']::public.club_role[])
);

-- Zurückziehen darf die Vereinsleitung eine noch offene Anfrage.
create policy "club leaders withdraw open access requests" on public.club_access_requests
for delete to authenticated using (
  status = 'offen'
  and public.has_club_role(club_id, array['sysadmin','vereinsadmin','geschaeftsfuehrung']::public.club_role[])
);

grant select, insert, delete on public.club_access_requests to authenticated;
grant all on public.club_access_requests to service_role;

-- Übersicht für den Betreiber: was liegt an, seit wann, und wie groß ist der
-- Verein inzwischen. Wird mit dem Dienstschlüssel gelesen.
create or replace view public.offene_freischaltungen as
select
  r.id,
  r.created_at,
  c.name as verein,
  c.id as club_id,
  r.contact_name,
  r.contact_email,
  r.contact_phone,
  r.expected_accounts,
  r.note,
  r.status,
  public.club_account_count(c.id) as konten_jetzt,
  public.club_subscription_tier(c.id) as tarif_jetzt
from public.club_access_requests r
join public.clubs c on c.id = r.club_id
where r.status in ('offen', 'berechnet')
order by r.created_at;
