-- Konten auf der ganzen Plattform und die Obergrenze, für die Betreiberkonsole
--
-- Die Kachel "Konten" in der Konsole zählt Mitgliedschaften in Vereinen
-- (betreiber_kennzahlen -> club_account_count). Die Obergrenze aus
-- 20260911010000_konten_obergrenze.sql zählt dagegen jedes Konto in
-- auth.users - auch solche ohne Verein, wartende und unbestätigte. Wie nah die
-- Plattform an der Sperre ist, ließ sich deshalb nirgends ablesen.
--
-- Eigene Funktion statt einer Spalte mehr in betreiber_kennzahlen: Deren
-- Rückgabetyp zu ändern hieße drop und create, und genau dabei ging hier
-- schon einmal eine Spalte verloren (20260910060000_aktionszeitraum_zurueck.sql).
--
-- Gezählt wird wie im Trigger: nicht gelöschte Zeilen in auth.users. Beide
-- Stellen müssen dieselbe Zahl liefern, sonst zeigt die Konsole "noch Platz",
-- während die Registrierung schon gesperrt ist.

create or replace function public.betreiber_konten_stand()
returns table (belegt bigint, grenze integer)
language sql
stable
security definer
set search_path = ''
as $$
  select (select count(*) from auth.users u where u.deleted_at is null),
         public.konten_obergrenze();
$$;

-- Nur mit dem Dienstschlüssel (Route /api/betreiber/daten). Supabase gibt neuen
-- Funktionen in public sonst automatisch Ausführungsrechte für anon und
-- authenticated (siehe 20260907110000_ausfuehrungsrechte_schliessen.sql).
revoke execute on function public.betreiber_konten_stand() from public, anon, authenticated;
grant execute on function public.betreiber_konten_stand() to service_role;
