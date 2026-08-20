-- Prüft, ob ein Konto als Demo-Zugang für die Apple-Prüfung taugt.
--
-- Oben die Adresse eintragen, dann in PROD ausführen. Es wird nichts geändert.
--
-- Apple lehnt am häufigsten ab, weil der Prüfer sich nicht anmelden kann oder
-- den Kaufbereich nicht findet. Beides hängt an den drei Zeilen unten.

with kandidat as (
  select 'marco@cmo.app'::text as adresse   -- <<< hier eintragen
)
select
  m.display_name                                as name,
  c.name                                        as verein,
  m.status                                      as mitgliedschaft,
  coalesce(string_agg(r.role::text, ', '), '—') as rollen,
  case when bool_or(r.role in ('vorstand', 'vereinsadmin', 'geschaeftsfuehrung', 'sysadmin'))
       then 'JA - Kaufbereich sichtbar'
       else 'NEIN - Prüfer sieht den Kaufbereich nicht' end as kaufbereich,
  public.club_subscription_tier(c.id)           as tarif,
  public.club_account_count(c.id)               as belegt,
  public.club_account_limit(c.id)               as grenze
from kandidat k
join public.club_memberships m on lower(m.email) = lower(k.adresse)
join public.clubs c            on c.id = m.club_id
left join public.membership_roles r on r.membership_id = m.id
group by m.display_name, c.name, m.status, c.id;

-- So liest du das Ergebnis:
--
--   Keine Zeile        Das Konto gibt es in dieser Datenbank nicht.
--                      Bist du in PROD? Stimmt die Adresse?
--
--   mitgliedschaft     muss 'active' sein, sonst kommt der Prüfer nicht rein
--
--   kaufbereich        muss JA sein. Sonst sieht der Prüfer nur den Hinweis,
--                      dass der Verein zahlt - und meldet "In-App-Kauf nicht
--                      auffindbar"
--
--   tarif              'none' ist in Ordnung: Dann sieht der Prüfer die
--                      Tarifauswahl und kann den Kauf testen. Läuft schon ein
--                      Abo, sieht er stattdessen "Tarif aktiv" - dann kann er
--                      den Kaufvorgang nicht durchspielen.
