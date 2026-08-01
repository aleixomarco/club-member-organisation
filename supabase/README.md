# Supabase-Einrichtung

1. Im Supabase-Projekt den **SQL Editor** öffnen.
2. **New query** wählen.
3. Den gesamten Inhalt von
   `migrations/20260801160000_initial_schema.sql` einfügen.
4. **Run** drücken.

Die Migration erstellt die Tabellen, Rollen, Sicherheitsregeln, ERG Iserlohn
und die fünf Mannschaften. Sie legt keine Demo-Passwörter oder künstlichen
Benutzerkonten an.

Nach erfolgreicher Ausführung unter **Table Editor** prüfen, ob unter anderem
`clubs`, `profiles`, `club_memberships`, `teams`, `events`, `fee_records`,
`family_links`, `sponsors`, `polls`, `channels` und `messages` vorhanden sind.

