-- Rolle "Organisator/in" im Datenbank-Enum nachtragen
--
-- Das Frontend kennt die Rolle seit Langem: ROLE_META in app/page.tsx fuehrt
-- sie auf, ASSIGNABLE_ROLES bietet sie in der Rollenvergabe zur Auswahl an, und
-- canManageDuty raeumt ihr die Helferplanung ein. Im Enum public.club_role
-- fehlte sie jedoch.
--
-- Folge: Wer die Rolle zuweisen wollte, bekam einen Datenbankfehler. Und die
-- Helferplanung war faktisch auf Administratoren beschraenkt, obwohl sie
-- ausdruecklich auch fuer Organisator/innen gedacht ist - genauso die Sicht auf
-- die Abo-Einstellungen (SUBSCRIPTION_ROLES).
--
-- Ein Enum-Wert laesst sich nicht in einer Transaktion mit anderen Anweisungen
-- hinzufuegen und danach sofort verwenden; deshalb steht diese Migration
-- bewusst allein. "if not exists" macht sie mehrfach ausfuehrbar.

alter type public.club_role add value if not exists 'organisator';
