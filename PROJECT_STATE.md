# CMO App — Projektstatus

_Letzte Aktualisierung: 2026-08-05_

## Kontext
- **Repo**: `aleixomarco/club-member-organisation`
- **Branches**: `main` (PRODUKTION), `paypal-sandbox-test` (Preview/Test) — neue Änderungen immer zuerst in `paypal-sandbox-test`, nach Test manuell via GitHub Desktop nach `main` mergen
- **Stack**: Next.js 16, React 19, TypeScript, Tailwind, Supabase, Vercel, PayPal Sandbox
- **Supabase-Projekt-Ref**: `kymokcqebfruhlvcyqnw`
- **Hauptdatei**: `app/page.tsx` (monolithisch, mehrere tausend Zeilen)
- **Lokaler Pfad**: `/Users/marcoaleixo/Documents/Codex/2026-08-01/er/club-member-organisation`
- **SQL-Migrationen**: werden manuell im Supabase SQL-Editor eingespielt (kein `supabase db push`), Migrationsdateien im Repo dienen nur als Dokumentation

## Demo-Accounts (Passwort: `demo`)
| E-Mail | Rollen | Teams |
|---|---|---|
| marco@cmo.app | sysadmin, vorstand, spieler, mitglied | Herren 1 (spieler) |
| marco.kapitaen@cmo.app | kapitaen, spieler, mitglied | Herren 1 |
| sergio@cmo.app | spieler, teammanager, mitglied | Herren 1, U11 |
| dirk@cmo.app | vorstand, mitglied | — |
| rodrigo@cmo.app | spieler, mitglied | U11 |
| maria@cmo.app | mitglied | — |
| simone@cmo.app | geschaeftsfuehrung, mitglied | — |
| guido@cmo.app | redakteur, sponsorenmanager, mitglied | — |
| simone.finanzen@cmo.app | finanzmanager, mitglied | — |
| jose@cmo.app | trainer, mitglied | Herren 1, U15 |
| + 9 Spieler-Batch | spieler, mitglied | diverse |

Teams: Damen 1 (Erwachsene), Herren 1 (Erwachsene), Herren 2, U11, U15.

## Rollen-Enum
`mitglied, spieler, eltern, trainer, kapitaen, teammanager, redakteur, sponsorenmanager, finanzmanager, geschaeftsfuehrung, vorstand, sysadmin, vereinsadmin`

## Roadmap-Status
1. ✅ Beitrittsanfragen-System (Backend + Frontend, inkl. Live-Mitgliederübersicht via `BoardMemberOverview`)
2. ✅ Vorstand-Migration (`set_managed_player_teams` inkl. `vorstand`-Rolle) geprüft — war bereits eingespielt
3. ✅ Umlaute/Tippfehler korrigiert
4. ✅ Strafen: `paid_at`/`paid_by`-Tracking, Saison-Reset (`run_season_reset` RPC, nur Vorstand/Finanzmanager/Sysadmin/Vereinsadmin), Saison-Historie pro Team
5. ✅ Aufgaben (`club_tasks`/`club_task_signups`, Vereins- und Mannschaftsaufgaben) + echte DB-Fahrgemeinschaften (`carpools`/`carpool_passengers`, gekoppelt an alle Termine außer Heimspielen) + 70%-Erinnerungsbanner (`check_task_reminder_threshold`, `get_task_signup_ratio`)
6. ✅ Vorstand-Mitglieder-Detailseite (`MemberDetailPanel`, klickbar aus `BoardMemberOverview`): zeigt Strafen (offen/bezahlt/Historie), Aufgaben, Fahrgemeinschaften (als Fahrer + Mitfahrer)

**Noch offen (priorisiert):**
7. ⬜ Push-Benachrichtigungen — Service Worker, Subscriptions-Tabelle, Versandlogik für ~12 Benachrichtigungstypen. Größtes verbleibendes Thema.

**Niedrige Priorität / Aufräumarbeiten:**
- `supabase/.temp/` ist fälschlicherweise im Repo committed — sollte in `.gitignore`
- Viele "Untitled query"-Tabs im Supabase SQL-Editor-Dashboard (rein kosmetisch)

## DB-Schema-Ergänzungen (chronologisch, alle im SQL-Editor eingespielt)
- Kernschema aus den Repo-Migrationsdateien (`20260801160000_initial_schema.sql` bis `20260802*`)
- `team_penalty_assignments`: Spalten `paid_at`, `paid_by`, `archived_season`, `archived_at` ergänzt; View `team_penalty_totals` zeigt nur unarchivierte Strafen; RPCs `mark_penalty_paid`, `run_season_reset`
- Neue Tabellen: `club_tasks`, `club_task_signups`, `carpools`, `carpool_passengers`, `club_task_reminders`
- Neue RPCs: `check_task_reminder_threshold`, `get_task_signup_ratio`, `has_beyond_basic_role`
- Neue RLS-Policy: „club leaders read all penalty assignments" (Vorstand/Finanzmanager/Sysadmin/Vereinsadmin dürfen alle Strafen des Vereins lesen, nicht nur eigene Teams)

## Frontend-Komponenten (neu/erweitert in dieser Session)
- `BoardMemberOverview` — lädt Mitglieder live aus DB, Karten klickbar → öffnet `MemberDetailPanel`
- `MemberDetailPanel` (neu) — Strafen/Aufgaben/Fahrgemeinschaften-Historie pro Mitglied
- `TeamPenaltyCatalog` — Bezahlt/Offen-Toggle, Saison-Historie-Ansicht, Saison-Reset-Formular (nur für berechtigte Rollen)
- `CarpoolSection` (neu) — ersetzt alten simplen Ja/Nein-Toggle; echte Sitzplatzverwaltung pro Termin, nur bei `ev.home !== true`
- `TasksView` (neu) — Vereinsaufgaben (Ersteller braucht Rolle jenseits spieler/mitglied) + Mannschaftsaufgaben (Ersteller: Trainer/Kapitän/Teammanager des Teams), Ein-/Austragen für alle
- `Dashboard` — neue Kachel "Aufgaben", 70%-Erinnerungsbanner (`taskReminder`-State)
- `JoinRequestsManager` — Beitrittsanfragen annehmen/ablehnen mit Rollenwahl

## Workflow-Konventionen
- Patch-Skripte (`.mjs`) werden nach erfolgreichem `npm run build` + Commit **immer gelöscht** (`rm patch-*.mjs`)
- Reihenfolge pro Änderung: SQL-Migration im Dashboard einspielen → Frontend-Patch-Skript schreiben & ausführen → `npm run build` prüfen → Skript löschen → committen → nach `paypal-sandbox-test` pushen → in Preview testen → erst danach nach `main` mergen
- Bei unklarer DB-Struktur immer erst per SQL-Editor-Abfrage (`information_schema.columns`, `pg_policies`, `pg_proc`) verifizieren statt zu raten
