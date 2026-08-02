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

## Weitere Migrationen

Wenn die initiale Migration bereits ausgeführt wurde, danach die neueren Dateien
in zeitlicher Reihenfolge ebenfalls einmal im SQL Editor ausführen:

1. `migrations/20260802015000_tipp_results.sql`
2. `migrations/20260802023000_subscriptions.sql`
3. `migrations/20260802030000_club_subscriptions.sql`
4. `migrations/20260802033000_club_logos.sql`
5. `migrations/20260802040000_membership_approvals.sql`
6. `migrations/20260802043000_trainer_captains.sql`
7. `migrations/20260802050000_family_links_complete.sql`
8. `migrations/20260802053000_fee_management_complete.sql`
9. `migrations/20260802060000_news_storage_complete.sql`
10. `migrations/20260802063000_admin_state_complete.sql`
11. `migrations/20260802064500_trainer_multiple_teams.sql`
12. `migrations/20260802070000_update_club_subscription_prices.sql`
13. `migrations/20260802071500_team_penalty_catalog.sql`
14. `migrations/20260802073000_team_directory.sql`
15. `migrations/20260802074500_trainer_self_service.sql`
