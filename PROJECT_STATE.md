# CMO App — Projektstatus

_Letzte Aktualisierung: 2026-08-06 (Vormittag) — via Claude Code, direkt im Terminal_

## Build-Status
**Buildfähig.** `npm run build` läuft fehlerfrei durch (zuletzt verifiziert 2026-08-06, nach Ergänzung des Self-Claim-Buttons). Der Helferdienst-Patch war zwischenzeitlich (Vormittag) in einem kaputten Zwischenstand mit fehlenden Komponentendefinitionen — das ist behoben, siehe Abschnitt "HELFERDIENST" unten.

**⚠️ Eine SQL-Migration steht noch aus, bevor "Ich übernehme das" live funktioniert:** Die Frontend-Seite des Self-Claim-Buttons ist fertig, aber die dafür nötige RPC `claim_duty_task` existiert noch nicht in der DB — das Anlegen von Datenbankfunktionen wurde von Claude Code automatisch geblockt (Sicherheitsklassifikator für schreibende/sicherheitsrelevante DB-Änderungen), genau wie es dieses Projekt ohnehin immer handhabt ("SQL-Migrationen werden manuell im Supabase SQL-Editor eingespielt"). Das exakte SQL steht unten im Helferdienst-Abschnitt — bitte im Supabase SQL-Editor (Projekt kymokcqebfruhlvcyqnw) einspielen, dann funktioniert der Button. Bis dahin würde ein Klick auf "Ich übernehme das" einen Fehler werfen.

**Noch offen, bevor gepusht wird:** `app/page.tsx` hat unpushte Änderungen (Helferdienst-Komponenten + AdminView-Fix), plus drei ungetrackte Patch-Skripte (`patch-duty-1.mjs`, `patch-duty-1b.mjs`, `patch-home-away.mjs`). Noch nicht committet/gepusht — bewusst, um erst hier den aktuellen Stand zu dokumentieren. Committen/Pushen erfolgt erst nach expliziter Freigabe.

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
mitglied, spieler, eltern, trainer, kapitaen, teammanager, redakteur, sponsorenmanager, finanzmanager, geschaeftsfuehrung, vorstand, sysadmin, vereinsadmin, **organisator** (neu, für Helferdienst-Sätze)

## Roadmap-Status
1. Beitrittsanfragen-System — fertig
2. Vorstand-Migration geprüft (set_managed_player_teams inkl. vorstand) — war bereits eingespielt
3. Umlaute/Tippfehler korrigiert — fertig
4. Strafen: paid_at/paid_by, Saison-Reset (run_season_reset), Saison-Historie — fertig
5. Aufgaben (club_tasks/club_task_signups) + echte DB-Fahrgemeinschaften (carpools/carpool_passengers) + 70%-Erinnerungsbanner — fertig
6. Vorstand-Mitglieder-Detailseite (MemberDetailPanel, klickbar aus BoardMemberOverview) — fertig
7. Push-Benachrichtigungen — komplett fertig (siehe eigener Abschnitt unten)
8. Neue Entität: Vereinsfahrzeuge — fertig (siehe eigener Abschnitt unten)
9. Helferdienst-Erinnerung — **Frontend fertig, Feature bereit zum Testen** (siehe eigener Abschnitt unten)

Aufräumarbeiten: .gitignore für supabase/.temp/ erledigt. "Untitled query"-Tabs im Supabase-Dashboard sind rein kosmetisch, nicht angegangen (nicht nötig).

**Hinweis zu Punkten 10/11 (Sicherheitshinweis neues Gerät, Einzelgerät-Login-Sperre):** In dieser Session nicht angefasst und nicht verifiziert. Es existiert bereits eine Tabelle `known_devices` in der DB, aber der Umsetzungsstand wurde hier nicht geprüft — bei Bedarf separat nachschauen (`git log`, DB-Trigger auf `auth.sessions` prüfen), bevor darauf aufgebaut wird.

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

## HELFERDIENST — Backend fertig (bereits vor dieser Session live), Frontend jetzt fertig

### Konzept
Rolle `organisator` (+ vorstand/vereinsadmin) legt wiederverwendbare "Sätze" (Vorlagen) mit Stationen an, z. B. "Standard Heimspieltag" mit Theke/Kasse/Grill/Zeitnahme. Beim Anlegen/Ansehen eines **Heimspiels** kann ein Satz vorgeladen werden → erzeugt echte `duty_tasks`-Zeilen für diesen Termin. Nur bei Heimspielen (`ev.type === "spiel" && ev.home === true`), nicht bei Training/Auswärtsspiel.

### DB-Schema (live verifiziert gegen Projekt kymokcqebfruhlvcyqnw, 2026-08-06)
- `duty_task_templates(id, club_id → clubs.id, name, created_by → club_memberships.id, created_at)`
- `duty_task_template_items(id, template_id → duty_task_templates.id, title, sort_order)`
- `duty_tasks(id, event_id → events.id, club_id → clubs.id, title, assignee_membership_id → club_memberships.id NULL, due_date, done bool, reminded_at, created_by → club_memberships.id, created_at)`
- Funktionen: `can_manage_duty_templates(target_club uuid) returns boolean` (organisator/vorstand/vereinsadmin), `can_manage_duty_task(target_event uuid) returns boolean` (= can_manage_duty_templates ODER can_manage_team des Team der Veranstaltung, also auch trainer/kapitaen/teammanager des jeweiligen Teams), `apply_duty_template(target_event uuid, target_template uuid) returns void` (SECURITY DEFINER, kopiert Vorlagen-Items als neue duty_tasks-Zeilen)
- Cron: `duty-task-due-reminders` (`0 7 * * *` → `run_duty_task_due_reminders()`), `duty-gap-check` (`0 9 * * *` → `run_duty_gap_check()`) — beide aktiv in `cron.job`, verifiziert.
- **RLS-Verhalten:** INSERT/UPDATE/DELETE auf `duty_tasks` erfordern grundsätzlich `can_manage_duty_task(event_id)` — d.h. nur Organisatoren/Vorstand/Vereinsadmin oder der Trainer/Kapitän/Teammanager des jeweiligen Teams können Stationen zuweisen, Fristen setzen, löschen oder als erledigt markieren. Für die Selbst-Eintragung durch normale Mitglieder ("Ich übernehme das") gibt es bewusst eine schmale, zusätzliche RPC `claim_duty_task` (SECURITY DEFINER, s. u.) statt einer generellen RLS-Lockerung — sie lässt ausschließlich das (Zurück-)Setzen der eigenen Zuweisung auf eine bislang unzugewiesene bzw. selbst gehaltene Station zu, alle anderen Felder bleiben geschützt.

### ⚠️ Noch einzuspielen: RPC `claim_duty_task` (SQL-Editor, Projekt kymokcqebfruhlvcyqnw)
Das Frontend ruft `supabase.rpc("claim_duty_task", { target_task })` bereits auf; die Funktion existiert aber noch nicht in der DB. Claude Code hat das automatisierte Einspielen bewusst nicht versucht (vom Sicherheits-Klassifikator geblockt, wie bei allen schreibenden/sicherheitsrelevanten DB-Änderungen) — bitte manuell einspielen:

```sql
create or replace function public.claim_duty_task(target_task uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_membership uuid;
  current_assignee uuid;
  task_club uuid;
begin
  select dt.assignee_membership_id, dt.club_id into current_assignee, task_club
  from public.duty_tasks dt where dt.id = target_task;
  if task_club is null then
    raise exception 'Task not found';
  end if;

  select id into acting_membership from public.club_memberships
  where profile_id = auth.uid() and club_id = task_club and status = 'active';
  if acting_membership is null then
    raise exception 'Not authorized';
  end if;

  if current_assignee is null then
    update public.duty_tasks set assignee_membership_id = acting_membership where id = target_task;
  elsif current_assignee = acting_membership then
    update public.duty_tasks set assignee_membership_id = null where id = target_task;
  else
    raise exception 'Task already assigned to someone else';
  end if;
end;
$$;

grant execute on function public.claim_duty_task(uuid) to authenticated;
```

Bis das eingespielt ist, wirft ein Klick auf "Ich übernehme das" einen Fehler ("Aktion nicht möglich.") — der Rest des Features (Sätze, Vorlage anwenden, Zuweisen durch Verwalter, Fristen, Löschen) funktioniert unabhängig davon bereits.

### Frontend — vollständig, inkl. Self-Claim (app/page.tsx)
- `eventDraft.isHome`, Heimspiel-Checkbox, `home_away` wird korrekt gespeichert (Bug-Fix von vorher)
- `ROLE_META.organisator`, `canManageDuty()`-Helper, `baseTabs()` zeigt "Verwaltung"-Tab auch für reine Organisatoren
- **`DutyTasksSection({ ev, currentUser })`** (vor `PlayerDataCard` eingefügt): lädt `duty_tasks` fürs jeweilige Event, prüft per RPC `can_manage_duty_task`, ob der aktuelle Nutzer verwalten darf. Verwalter sehen: Vorlage-Dropdown ("Satz vorladen" → `apply_duty_template`), Zuweisen (Dropdown mit allen aktiven Vereinsmitgliedern), Fristdatum setzen, "Erledigt"-Toggle, Löschen. Alle anderen sehen die Liste lesend (Titel, Zugewiesen an, Frist, erledigt-Status) plus bei freien Stationen den Button **"Ich übernehme das"** (ruft `claim_duty_task` auf) bzw. bei eigener Zuweisung **"Zurückziehen"**.
- **`DutyTemplatesPanel({ currentUser })`**: Sätze anlegen/löschen, Stationen pro Satz hinzufügen/entfernen (aufklappbar), analog zum bestehenden `TasksView`/`CarpoolSection`-Stil.
- **`AdminView`-Lücke gefunden und behoben:** Der ursprüngliche Patch hatte zwar `panel === "duty-templates"` verdrahtet, aber es gab **keinen Tab-Button**, der dieses Panel erreichbar machte, und **keinen `organisatorOnly`-Modus** (reine Organisatoren ohne Vorstandsrolle hätten das volle, für sie unpassende Verwaltungsmenü gesehen). Jetzt: `restrictedOnly`-Logik (verallgemeinerte Version des bisherigen `sponsorOnly`-Patterns, unterstützt auch die Kombination Sponsor+Organisator), plus fester Tab "Helferdienst-Sätze" im normalen Verwaltungsmenü für Vorstand/Sysadmin.
- **Bug beim Selbst-Review gefunden und behoben:** In `DutyTemplatesPanel` bestimmte die Farbe der Statusmeldung ursprünglich per `message.includes("angelegt")`, ob grün (Erfolg) oder rot (Fehler) angezeigt wird. Die Fehlermeldung „Satz **konnte nicht angelegt** werden.“ enthält aber ebenfalls das Wort „angelegt“ und wäre fälschlich grün erschienen. Jetzt über einen expliziten `messageOk`-Status statt Text-Teilstring-Vergleich gelöst.

### Verifikation in dieser Session
- `npm run build` — erfolgreich, keine Fehler (zuletzt nach dem Message-Farb-Fix erneut geprüft)
- `npm run dev` lokal gestartet, Login-Bildschirm lädt fehlerfrei und reagiert korrekt auf Klicks (per JS-Ausführung im Browser-Tool verifiziert, da die visuelle Klick-Simulation in dieser Session an einer Panel-Sichtbarkeits-Einschränkung des Tools scheiterte — Tool-seitig, nicht Code-seitig)
- **Kein echter authentifizierter Durchklick möglich** ohne `.env.local`-Zugangsdaten UND ohne ein echtes Passwort einzugeben — Letzteres tut Claude Code grundsätzlich nicht, auch nicht mit Demo-Zugangsdaten. Der Login-Screen selbst wurde erreicht und interagiert fehlerfrei; alles danach (Satz anlegen → Heimspiel → vorladen → zuweisen/übernehmen) ist nur mit echtem Login testbar.
- DB-Schema/RLS/Funktionssignaturen wurden direkt gegen die verlinkte Live-Datenbank per `echo "<sql>" | npx supabase db query --linked` abgefragt (funktioniert ohne Docker, im Gegensatz zu `supabase db dump`) — kein Rätselraten anhand alter Chat-Notizen nötig. Schreibender Zugriff (DDL) über denselben Weg wurde vom Sicherheits-Klassifikator blockiert (siehe oben) — das ist beabsichtigtes Verhalten, keine Fehlfunktion.

### Nächste Schritte
1. **SQL oben im Supabase SQL-Editor einspielen** (`claim_duty_task`) — ohne das wirft der Self-Claim-Button einen Fehler.
2. Mit echten `.env.local`-Werten (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`) lokal oder im Vercel-Preview testen: als Organisator/Vorstand einen Satz mit Stationen anlegen, als Trainer/Vorstand ein Heimspiel anlegen, Satz vorladen, Station zuweisen + Frist setzen, als Mitglied eine freie Station übernehmen/zurückziehen, als Frist erledigt markieren.
3. Patch-Skripte `patch-duty-1.mjs`, `patch-duty-1b.mjs`, `patch-home-away.mjs` nach erfolgreichem Test + Commit löschen (Workflow-Konvention).

---

## Workflow-Konventionen
- Patch-Skripte (.mjs) werden nach erfolgreichem npm run build + Commit immer gelöscht
- Reihenfolge: SQL-Migration → Frontend-Patch-Skript → npm run build → Skript löschen → committen → push nach paypal-sandbox-test → in Preview testen → erst dann nach main mergen
- Bei unklarer DB-Struktur immer per SQL-Editor-Abfrage verifizieren statt zu raten
- Bei String-Ersetzungs-Patches: bei Nichteindeutigkeit (0x oder 2x gefunden) auf Zeilennummer-basierte Splice-Methode wechseln statt exaktem Textvergleich — robuster gegen Whitespace-Abweichungen beim Kopieren
- Große Patch-Skripte immer als EIN zusammenhängender Codeblock zum Kopieren geben, nicht mehrteilig — sonst bricht das Terminal beim Einfügen ab (heredoc>-Hänger). Bei sehr langen Skripten (>150 Zeilen) lieber VS Code direkt nutzen statt Terminal-Heredoc.