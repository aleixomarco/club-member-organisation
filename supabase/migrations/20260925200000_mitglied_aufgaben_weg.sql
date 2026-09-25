-- Ziel im Repo: supabase/migrations/20260925200000_mitglied_aufgaben_weg.sql
--
-- Nimmt 20260925180000_mitglied_aufgaben.sql wieder zurueck.
--
-- WARUM
-- Der Verein weist Personen schon heute zu, und zwar dort, wo die Aufgabe
-- entsteht: ueber "Jemanden eintragen" an den Helferstationen eines Termins
-- (duty_tasks / duty_assignments, Station als Freitext). Eine zweite Liste
-- an der Person waere ein zweiter Ort fuer dieselbe Frage gewesen - genau
-- das, was in diesem Projekt schon einmal auseinandergelaufen ist
-- (JoinRequestsManager neben MembershipApprovalsPanel).
--
-- Entschieden vom Betreiber am 25.09.2026, keine zwei Stunden nach dem
-- Einspielen. Die Tabelle war zu diesem Zeitpunkt leer (nachgezaehlt, nur
-- lesend gegen PROD: 0 Zeilen) - es geht also nichts verloren.
--
-- Die Migration 20260925180000 bleibt als Datei stehen: Sie ist in PROD
-- gelaufen und steht im Migrationsverzeichnis der Datenbank. Wer sie
-- entfernte, brauchte beim naechsten Abgleich eine Ausrede dafuer, dass die
-- Datenbank eine Migration kennt, die es im Repo nicht gibt.
--
-- Die Oberflaeche dazu (MitgliedAufgabenPanel, fuenfter Reiter in der
-- Benutzerverwaltung, Nur-Lese-Anzeige im Mitglieds-Detail, die Schluessel
-- zust.*) ist im selben Zug aus app/page.tsx und lib/sprachen.ts entfernt.

drop table if exists public.mitglied_aufgaben;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: tabelle_weg = 0, regeln_weg = 0.
select (select count(*) from information_schema.tables
         where table_schema = 'public' and table_name = 'mitglied_aufgaben')  as tabelle_weg,
       (select count(*) from pg_policies
         where schemaname = 'public' and tablename = 'mitglied_aufgaben')     as regeln_weg;
