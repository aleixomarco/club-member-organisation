-- Anfragen von der Website aufnehmen.
--
-- club_access_requests war für Vereine gedacht, die es schon gibt: Die
-- Vereinsleitung fragt aus der App heraus den Vollzugang an. Von der Website
-- kommt der andere Fall — jemand hat noch gar keinen Verein angelegt und will
-- erst wissen, woran er ist.
--
-- Beide gehören in dieselbe Tabelle, sonst schaut der Betreiber an zwei
-- Stellen nach und übersieht eine. Deshalb wird club_id optional und der
-- Vereinsname als Text mitgeführt; welcher Weg es war, sagt die Spalte quelle.

alter table public.club_access_requests alter column club_id drop not null;

alter table public.club_access_requests
  add column if not exists club_name text,
  add column if not exists quelle text not null default 'app' check (quelle in ('app', 'website'));

-- Entweder ein vorhandener Verein oder ein Name — irgendetwas muss dastehen,
-- sonst weiß niemand, um wen es geht.
alter table public.club_access_requests
  drop constraint if exists club_access_requests_verein_benannt;
alter table public.club_access_requests
  add constraint club_access_requests_verein_benannt
  check (club_id is not null or nullif(trim(coalesce(club_name, '')), '') is not null);

-- Der eindeutige Index galt "eine offene Anfrage je Verein". Ohne club_id
-- greift er nicht mehr, deshalb neu gefasst: Er gilt weiterhin für Vereine, die
-- es gibt. Website-Anfragen ohne Verein bleiben davon unberührt - dort kann
-- dieselbe Person durchaus zweimal schreiben, und das soll der Betreiber sehen.
drop index if exists public.club_access_requests_eine_offene;
create unique index if not exists club_access_requests_eine_offene
  on public.club_access_requests(club_id) where status = 'offen' and club_id is not null;

comment on column public.club_access_requests.club_name is
  'Nur bei Anfragen von der Website: der genannte Vereinsname, solange es den Verein in der Datenbank noch nicht gibt.';
comment on column public.club_access_requests.quelle is
  'app = aus der Vereinsleitung heraus, website = über das Formular auf der Website.';

-- Die Übersicht muss beide Fälle zeigen.
--
-- Erst löschen, dann neu anlegen: "create or replace view" verlangt dieselbe
-- Spaltenreihenfolge wie zuvor, und hier kommt eine Spalte dazwischen.
drop view if exists public.offene_freischaltungen;
create view public.offene_freischaltungen as
select
  r.id,
  r.created_at,
  r.quelle,
  coalesce(c.name, r.club_name) as verein,
  r.club_id,
  r.contact_name,
  r.contact_email,
  r.contact_phone,
  r.expected_accounts,
  r.note,
  r.status,
  case when c.id is null then null else public.club_account_count(c.id) end as konten_jetzt,
  case when c.id is null then null else public.club_subscription_tier(c.id) end as tarif_jetzt
from public.club_access_requests r
left join public.clubs c on c.id = r.club_id
where r.status in ('offen', 'berechnet')
order by r.created_at;
