-- Die Übersicht des Betreibers.
--
-- Bisher gab es sie nicht: Wer wissen wollte, wie viele Vereine es gibt, wer
-- freigeschaltet ist und wo die Grenze schon erreicht ist, musste sich das im
-- SQL-Editor zusammensuchen. Für ein Geschäft, das darauf beruht, Vereine
-- einzeln freizuschalten, ist das die falsche Grundlage.
--
-- Bewusst eine View und keine Tabelle: Es gibt hier nichts zu speichern, nur
-- zusammenzustellen, was ohnehin dasteht.
--
-- Und bewusst ohne Rechte für anon und authenticated. Diese View zeigt jeden
-- Verein mit seiner Größe und seinem Zahlungsstand — das geht die Vereine
-- gegenseitig nichts an. Lesen darf sie nur der Dienstschlüssel, und der liegt
-- ausschließlich auf dem Server.

drop view if exists public.betreiber_uebersicht;
create view public.betreiber_uebersicht as
select
  c.id,
  c.name,
  c.short_name,
  c.city,
  c.sport::text as sport,
  c.created_at,
  c.vereinbarte_zugaenge,
  c.sponsoring_freigeschaltet,
  public.club_subscription_tier(c.id) as tarif,
  public.club_account_limit(c.id) as grenze,
  public.club_account_count(c.id) as konten,
  (select max(s.current_period_end)
     from public.club_subscriptions s
    where s.club_id = c.id and s.status = 'active') as laeuft_bis,
  (select s.provider_subscription_id
     from public.club_subscriptions s
    where s.club_id = c.id and s.status = 'active'
    order by s.current_period_end desc nulls last limit 1) as beleg,
  (select count(*) from public.club_memberships m
    where m.club_id = c.id and m.status = 'active') as mitglieder,
  (select count(*) from public.club_memberships m
    where m.club_id = c.id and m.status = 'pending') as offene_aufnahmen,
  (select count(*) from public.anzeigen a
    where a.club_id = c.id and a.aktiv) as eigene_sponsoren,
  -- Wer im Verein ansprechbar ist. Ohne das müsste der Betreiber bei jeder
  -- Rückfrage erst in der Mitgliederliste suchen.
  (select m.display_name || ' <' || coalesce(m.email, '—') || '>'
     from public.club_memberships m
     join public.membership_roles r on r.membership_id = m.id
    where m.club_id = c.id and m.status = 'active' and r.role = 'vereinsadmin'
    order by m.created_at limit 1) as ansprechpartner
from public.clubs c;

revoke all on public.betreiber_uebersicht from anon, authenticated;
grant select on public.betreiber_uebersicht to service_role;

-- Dasselbe für die Anfragenliste: Sie enthält Namen, E-Mail-Adressen und
-- Telefonnummern von Menschen, die noch gar nicht in der App sind.
revoke all on public.offene_freischaltungen from anon, authenticated;
grant select on public.offene_freischaltungen to service_role;
