# CMO App — Projektstatus

_Letzte Aktualisierung: 2026-08-05 (Abend)_

## Kontext
- **Repo**: aleixomarco/club-member-organisation
- **Branches**: main (PRODUKTION), paypal-sandbox-test (Preview/Test) — neue Änderungen immer zuerst in paypal-sandbox-test, nach Test manuell via GitHub Desktop nach main mergen. Stand heute: paypal-sandbox-test liegt mehrere Commits vor main, noch nicht gemerged.
- **Stack**: Next.js 16, React 19, TypeScript, Tailwind, Supabase, Vercel, PayPal Sandbox, Firebase Cloud Messaging (Push)
- **Supabase-Projekt-Ref**: kymokcqebfruhlvcyqnw
- **Firebase-Projekt**: club-member-organisation-acbf3 (privates Google-Konto, NICHT das Geschäftskonto — Workspace-Policy blockierte Service-Account-Schlüssel)
- **Hauptdatei**: app/page.tsx (monolithisch, mehrere tausend Zeilen)
- **Lokaler Pfad**: /Users/marcoaleixo/Documents/Codex/2026-08-01/er/club-member-organisation
- **SQL-Migrationen**: werden manuell im Supabase SQL-Editor eingespielt (kein supabase db push)
- **Node-Version-Hinweis**: Node v24.16.0 lokal. Falls npm run build ohne jede Ausgabe "erfolgreich" durchläuft (stiller Fehler, .next-Ordner fehlt) → rm -rf node_modules package-lock.json && npm install (defektes semver-Paket war die Ursache, kann bei Neuinstallationen wieder auftreten)

## Demo-Accounts (Passwort: demo)
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
| + 9 Spieler-Batch | spieler, mitglied | diverse (adrian, sandro, cristiano, tobias, finn, christopher, yannik, alexander, phillip @cmo.app) |

Teams: Damen 1 (Erwachsene), Herren 1 (Erwachsene), Herren 2, U11, U15.

## Rollen-Enum
mitglied, spieler, eltern, trainer, kapitaen, teammanager, redakteur, sponsorenmanager, finanzmanager, geschaeftsfuehrung, vorstand, sysadmin, vereinsadmin

## Roadmap-Status — ALLE URSPRÜNGLICHEN PUNKTE FERTIG
1. Beitrittsanfragen-System — fertig
2. Vorstand-Migration geprüft (set_managed_player_teams inkl. vorstand) — war bereits eingespielt
3. Umlaute/Tippfehler korrigiert — fertig
4. Strafen: paid_at/paid_by, Saison-Reset (run_season_reset), Saison-Historie — fertig
5. Aufgaben (club_tasks/club_task_signups) + echte DB-Fahrgemeinschaften (carpools/carpool_passengers) + 70%-Erinnerungsbanner — fertig
6. Vorstand-Mitglieder-Detailseite (MemberDetailPanel, klickbar aus BoardMemberOverview) — fertig
7. Push-Benachrichtigungen — komplett fertig (siehe eigener Abschnitt unten)
8. Neue Entität: Vereinsfahrzeuge — fertig (siehe eigener Abschnitt unten)

Aufräumarbeiten: .gitignore für supabase/.temp/ erledigt. "Untitled query"-Tabs im Supabase-Dashboard sind rein kosmetisch, nicht angegangen (nicht nötig).

---

## PUSH-BENACHRICHTIGUNGEN — Vollständige Dokumentation

### Architektur
Web Push über Firebase Cloud Messaging (FCM), funktioniert auf Android (nativ) und iPhone (nach "Zum Home-Bildschirm hinzufügen" wegen iOS-Systembeschränkung — PWA-Manifest dafür vorhanden). Bei künftigem Wechsel zu nativen Store-Apps (Capacitor) bleibt die komplette Infrastruktur (DB, Edge Function, FCM) unverändert nutzbar — nur eine native Hülle kommt dazu.

### Firebase-Zugangsdaten (öffentlich, unkritisch)
apiKey: AIzaSyAj_dLdMdXCk-T5hO9TXMcIakPSych-mb0
authDomain: club-member-organisation-acbf3.firebaseapp.com
projectId: club-member-organisation-acbf3
storageBucket: club-member-organisation-acbf3.firebasestorage.app
messagingSenderId: 852910274539
appId: 1:852910274539:web:bf5bb6eebd3fc61ffecbae
VAPID_KEY: BJUz40s_jQFx67i9o2h-hkLyFMY9Q9hWWxUekLYavTcz9LImbdHqPYkfa-OCfPC7safypanAE-8gYv2UzSyElhI

Diese Werte stehen in public/firebase-messaging-sw.js und lib/firebase-push.ts. Der private Firebase-Service-Account-Schlüssel liegt NICHT im Code, sondern als Supabase-Secret FIREBASE_SERVICE_ACCOUNT (Edge Functions → Secrets).

### Supabase-Secrets (Edge Functions → Secrets)
- FIREBASE_SERVICE_ACCOUNT — kompletter JSON-Inhalt des Firebase-Service-Account-Schlüssels
- SERVICE_ROLE_KEY — Supabase Secret Key (sb_secret_..., aus Project Settings → API Keys → Secret keys). Wichtig: Name ist SERVICE_ROLE_KEY, NICHT SUPABASE_SERVICE_ROLE_KEY — das SUPABASE_-Präfix ist reserviert und lässt sich nicht manuell vergeben.

### DB-Schema
- push_subscriptions (membership_id, fcm_token, platform, unique pro membership+token)
- notification_queue (club_id, membership_id, notif_type, title, body, data, processed_at)
- profiles.notification_master (bool) + profiles.notification_preferences (jsonb, Kategorien) — bestehende Spalten, wiederverwendet statt neuer Tabelle
- Zentrale Funktion public.notify(membership_id, notif_type, title, body, data) — prüft automatisch Master-Schalter + Kategorie-Einstellung, schreibt in notification_queue
- Hilfsfunktionen public.notify_club(club_id, type, title, body, exclude_profile) und public.notify_many(membership_ids[], type, title, body) für Massen-Versand
- profiles.show_birthday (bool, default true) — Datenschutz-Opt-out für Geburtstags-Sichtbarkeit

### Edge Function send-push
- Liest notification_queue, holt push_subscriptions des Empfängers, sendet via firebase-admin/messaging
- Wichtig: verarbeitet bei Trigger-Aufruf NUR die eine übergebene id (per Request-Body {id}), nicht die ganze Warteschlange — das verhindert Duplikate bei vielen gleichzeitigen Inserts (Race-Condition-Fix vom 05.08., ursprüngliche Version verschickte Nachrichten teils 5-23x doppelt)
- Nutzt .update(...).is("processed_at", null) als atomaren "Lock" — nur ein gleichzeitiger Aufruf kann eine Nachricht erfolgreich reservieren
- Braucht grant select, update on notification_queue to service_role; und grant select, delete on push_subscriptions to service_role; (RLS+service_role braucht explizite Grants, nicht automatisch)

### DB-Trigger für automatischen Versand
create trigger on_notification_queued after insert on notification_queue for each row execute function trigger_send_push();

trigger_send_push() ruft per net.http_post die Edge Function mit {id: new.id} auf (pg_net Extension nötig, war bereits aktiv).

### Frontend
- public/firebase-messaging-sw.js — Service Worker (Hintergrund-Push, App geschlossen)
- lib/firebase-push.ts — enablePushNotifications(), disablePushNotifications(), listenForForegroundMessages() (Vordergrund-Push, Tab offen — wichtig: ohne diesen Listener kommt bei offenem Tab GAR KEINE Nachricht an, weder Service Worker noch Foreground)
- app/layout.tsx — PWA-Manifest-Verknüpfung + appleWebApp-Meta für iOS-Installation
- public/manifest.json — PWA-Manifest
- NotificationSettings-Komponente (Profil → Benachrichtigungen): "Push aktivieren/deaktivieren"-Button, 19 Kategorien-Toggles
- ProfileDataSettings: neuer Toggle "Geburtstag im Verein anzeigen"

### 21 aktive Benachrichtigungstypen
DB-Trigger (ereignisbasiert): Beitrittsanfrage neu/entschieden, neuer Termin, Termin abgesagt/geändert, Strafe zugewiesen/bezahlt/zurückgezogen, Fahrgemeinschaft beigetreten, News veröffentlicht, Team-Aufnahme (Willkommen), Familienverknüpfung erstellt

Frontend-Aufrufe (JSON-Blob-Daten): Chat-Nachricht (an berechtigte Kanal-Mitglieder), neue Umfrage, neues Vorstandsprotokoll, Tippspiel-Ergebnis eingetragen

pg_cron (zeitgesteuert): Geburtstage (täglich 7 Uhr, nur wenn show_birthday=true), Beitragserinnerung (montags 8 Uhr, alle 14 Tage pro offenem Beitrag), Fahrgemeinschafts-Engpass (täglich 9 Uhr, 3 Tage vor Auswärtsspiel ohne Fahrgemeinschaft)

Bewusst ausgelassen (bräuchten Strukturumbau): Helferdienst-Erinnerung (Daten nur im JSON-Blob), Sicherheitshinweis neues Gerät (keine Login-Historie vorhanden)

### Bekannte Fallstricke (falls Push wieder nicht ankommt)
1. Browser/OS-Benachrichtigungseinstellungen — z.B. macOS Systemeinstellungen → Benachrichtigungen → Chrome muss erlaubt sein (unabhängig vom Code)
2. iOS: nur wenn als PWA installiert ("Zum Home-Bildschirm hinzufügen" in Safari, dann von dort öffnen)
3. Tab offen vs. geschlossen: beide Fälle sind jetzt abgedeckt (Foreground-Listener + Service Worker), aber falls einer der beiden Teile fehlt, kommt bei genau einem der zwei Zustände nichts an
4. Doppelte Geräte-Tokens: können sich ansammeln, wenn "Push aktivieren" mehrfach geklickt wird ohne vorheriges Deaktivieren. Aufräum-SQL: delete from push_subscriptions a using push_subscriptions b where a.membership_id=b.membership_id and a.platform=b.platform and a.created_at<b.created_at;
5. Bei "permission denied for table X" in Edge-Function-Logs → fehlendes grant ... to service_role

---

## NEUE ENTITÄT: Vereinsfahrzeuge

### DB-Schema
- club_vehicles (label, license_plate, seats)
- vehicle_bookings (vehicle_id, team_id ODER private_label, membership_id, starts_at, ends_at) — Exclude-Constraint (btree_gist) verhindert überlappende Buchungen pro Fahrzeug auf DB-Ebene (nicht nur UI-Check). Check-Constraint erzwingt volle Stunden.
- Helper-Funktionen can_manage_fleet() (vorstand/vereinsadmin/geschaeftsfuehrung) und can_book_vehicles() (trainer/teammanager/kapitaen/finanzmanager/geschaeftsfuehrung)

### Frontend
- VehiclesView-Komponente, erreichbar über neue Dashboard-Kachel "Vereinsfahrzeuge"
- Echtes Kalenderraster (Monatsansicht, Mo-So-Spalten), Fahrzeugliste, Buchungsformular (Datum+volle-Stunde von/bis, Mannschaft oder "Privat" mit Namen)
- Stornieren: eigene Buchung immer, fremde nur Vorstand/Vereinsadmin/GF
- Bei Fremd-Stornierung: Push-Benachrichtigung an ursprünglichen Buchenden

---

## Workflow-Konventionen
- Patch-Skripte (.mjs) werden nach erfolgreichem npm run build + Commit immer gelöscht
- Reihenfolge: SQL-Migration → Frontend-Patch-Skript → npm run build → Skript löschen → committen → push nach paypal-sandbox-test → in Preview testen → erst dann nach main mergen
- Bei unklarer DB-Struktur immer per SQL-Editor-Abfrage verifizieren statt zu raten
- Bei String-Ersetzungs-Patches: bei Nichteindeutigkeit (0x oder 2x gefunden) auf Zeilennummer-basierte Splice-Methode wechseln statt exaktem Textvergleich — robuster gegen Whitespace-Abweichungen beim Kopieren
- Große Patch-Skripte immer als EIN zusammenhängender Codeblock zum Kopieren geben, nicht mehrteilig — sonst bricht das Terminal beim Einfügen ab (heredoc>-Hänger). Bei sehr langen Skripten (>150 Zeilen) lieber VS Code direkt nutzen statt Terminal-Heredoc.