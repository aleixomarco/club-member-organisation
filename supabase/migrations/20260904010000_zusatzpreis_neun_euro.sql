-- Der Sponsorenzusatz kostet 9 € im Monat oder 80 € im Jahr.
--
-- Bis heute standen fünf Euro in der Spaltenbeschreibung. Der Betreiber hat den
-- Preis geändert; die Beschreibung wird nachgezogen, damit sie nicht später als
-- Beleg für den alten Preis herhält.
--
-- Jährlich ist günstiger als zwölf Monatsbeiträge (80 statt 108) — dieselbe
-- Logik wie bei den Stufen selbst.

comment on column public.club_access_requests.sponsoring_gewuenscht is
  'Der Verein möchte eigene Sponsoren zeigen — 9 €/Monat oder 80 €/Jahr über dem Tarif.';

comment on column public.clubs.sponsoring_freigeschaltet is
  'Zusatz für 9 € im Monat oder 80 € im Jahr: Der Verein darf eigene Sponsoren auf den Werbeplätzen zeigen. Wird vom Betreiber gesetzt.';
