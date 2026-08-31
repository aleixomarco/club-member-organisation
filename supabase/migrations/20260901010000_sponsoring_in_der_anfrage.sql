-- Der Sponsorenzusatz gehört in die Anfrage.
--
-- Sonst steht er nirgends: Der Verein kreuzt ihn auf der Website oder in der
-- App an, und beim Betreiber landet eine Anfrage, die davon nichts weiß. Die
-- Rechnung wäre dann um fünf Euro im Monat zu niedrig, und der Verein fragt
-- eine Woche später nach, warum die Sponsorenverwaltung leer bleibt.

alter table public.club_access_requests
  add column if not exists sponsoring_gewuenscht boolean not null default false;

comment on column public.club_access_requests.sponsoring_gewuenscht is
  'Der Verein möchte eigene Sponsoren zeigen — 5 €/Monat über dem Tarif.';
