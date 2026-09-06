-- Neue Rolle: Fan.
--
-- Wer einem Verein folgen will, ohne Mitglied zu sein - Angehoerige,
-- Ehemalige, Zuschauer. Sie sollen Termine und News sehen, aber nicht in
-- Kadern, Helferplaenen oder Beitragslisten auftauchen.
--
-- ABGRENZUNG ZU "MITGLIED": Ein Fan ist KEIN formales Mitglied. Ueberall, wo
-- die App "Mitglieder" zaehlt - Beitraege, Mitgliederzahl, Helferpflicht -
-- gehoert er nicht dazu. Das steuert in der App das Merkmal formalMember;
-- hier in der Datenbank ist der Wert nur ein weiterer Rolleneintrag.
--
-- Der Wert wird ans ENDE des Aufzaehlungstyps gehaengt. Postgres erlaubt das
-- ohne Umbau der Tabelle; eine Einordnung mittendrin waere nur Kosmetik und
-- wuerde bestehende Sortierungen verschieben.

alter type public.club_role add value if not exists 'fan';

select string_agg(e.enumlabel, ', ' order by e.enumsortorder) as werte
from pg_type t join pg_enum e on e.enumtypid = t.oid where t.typname = 'club_role';
