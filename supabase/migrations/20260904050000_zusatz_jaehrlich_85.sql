-- Der Sponsorenzusatz kostet jährlich 85 € statt 80 €.
--
-- Die Spaltenbeschreibungen sind die einzige Stelle, an der der Preis in der
-- Datenbank steht — verkauft wird hier nichts. Sie werden trotzdem nachgezogen:
-- Eine Beschreibung, die einen überholten Preis nennt, wird sonst irgendwann
-- als Beleg für ihn herangezogen.
--
-- Monatlich bleibt es bei 9 €. Jährlich ist damit weiterhin günstiger als zwölf
-- Monatsbeiträge (85 statt 108).

comment on column public.club_access_requests.sponsoring_gewuenscht is
  'Der Verein möchte eigene Sponsoren zeigen — 9 €/Monat oder 85 €/Jahr über dem Tarif.';

comment on column public.clubs.sponsoring_freigeschaltet is
  'Zusatz für 9 € im Monat oder 85 € im Jahr: Der Verein darf eigene Sponsoren auf den Werbeplätzen zeigen. Wird vom Betreiber gesetzt.';
