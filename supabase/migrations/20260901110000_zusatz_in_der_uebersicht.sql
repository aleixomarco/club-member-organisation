-- Der Sponsorenzusatz gehört in die Übersicht des Betreibers.
--
-- Er steht seit heute in der Anfrage, aber nicht in offene_freischaltungen —
-- also genau dort nicht, wo er gebraucht wird: beim Schreiben der Rechnung.
-- Fünf Euro im Monat, die niemand sieht, sind fünf Euro im Monat, die niemand
-- berechnet.

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
  r.sponsoring_gewuenscht,
  r.note,
  r.status,
  case when c.id is null then null else public.club_account_count(c.id) end as konten_jetzt,
  case when c.id is null then null else public.club_subscription_tier(c.id) end as tarif_jetzt,
  case when c.id is null then null else c.sponsoring_freigeschaltet end as sponsoren_jetzt
from public.club_access_requests r
left join public.clubs c on c.id = r.club_id
where r.status in ('offen', 'berechnet')
order by r.created_at;
