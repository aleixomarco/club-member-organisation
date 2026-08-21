-- Findet Konten, die als Demo-Zugang für die Apple-Prüfung taugen.
--
-- In PROD ausführen. Es wird nichts geändert.
--
-- Ein tauglicher Zugang erfüllt drei Bedingungen:
--   1. aktive Mitgliedschaft, sonst kommt der Prüfer nicht hinein
--   2. eine Rolle, die den Kaufbereich sichtbar macht - er ist bewusst nur
--      für Mitglieder sichtbar, die den Verein wirtschaftlich vertreten
--   3. der Verein hat noch kein Abo, damit der Prüfer den Kauf durchspielen
--      kann statt nur "Tarif aktiv" zu sehen

select
  m.email,
  m.display_name                          as name,
  c.name                                  as verein,
  string_agg(r.role::text, ', ')          as rollen,
  public.club_subscription_tier(c.id)     as tarif,
  public.club_account_count(c.id)         as belegt,
  public.club_account_limit(c.id)         as grenze,
  case
    when public.club_subscription_tier(c.id) = 'none'
      then 'BESTE WAHL - Prüfer sieht die Tarifauswahl und kann kaufen'
    else 'brauchbar, aber Kauf nicht testbar (Tarif läuft bereits)'
  end                                     as eignung
from public.club_memberships m
join public.clubs c on c.id = m.club_id
join public.membership_roles r on r.membership_id = m.id
where m.status = 'active'
  and m.email is not null
  and m.profile_id is not null
group by m.email, m.display_name, c.name, c.id
having bool_or(r.role in ('vorstand', 'vereinsadmin', 'geschaeftsfuehrung', 'sysadmin'))
order by (public.club_subscription_tier(c.id) = 'none') desc, c.name;

-- Nimm eine Zeile mit "BESTE WAHL". Deren E-Mail-Adresse trägst du in App
-- Store Connect unter App-Prüfungsinformationen ein, zusammen mit dem
-- Passwort.
--
-- Kennst du das Passwort nicht mehr: In der App abmelden, "Passwort
-- vergessen" nutzen und ein neues setzen. Danach unbedingt selbst anmelden
-- und prüfen, ob unter Profil, Einstellungen, Abo & Empfehlungen der
-- Kaufbereich erscheint.
