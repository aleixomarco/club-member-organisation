# CMO App — Projektstatus

_Letzte Aktualisierung: 2026-08-06 (Vormittag) — via Claude Code, direkt im Terminal_

## Build-Status
**Buildfähig, alle offenen SQL-Migrationen eingespielt.** `npm run build` läuft fehlerfrei durch (zuletzt verifiziert 2026-08-06). Sowohl `claim_duty_task` (Helferdienst-Self-Claim) als auch die drei Vereinsfahrzeuge-Statements (Rollen-Erweiterung, UPDATE-Policy, Telefon-RPC) wurden erfolgreich im Supabase SQL-Editor ausgeführt und sind live.

**Zuletzt ergänzt (2026-08-06, Nachmittag):**
- Speicher-Bestätigung bei „Persönliche Daten" (und „Benachrichtigungen") erscheint jetzt oben direkt unter dem Bildschirmtitel statt unten nach dem Scrollen — betraf `ProfileDataSettings` und `NotificationSettings`, beides lange Formulare unter `ProfileUnderlay`. Die drei kurzen Formulare (Passwort, Sicherheit, Kalender-Sync) waren davon nicht betroffen, da dort ohnehin nichts zum Scrollen da ist.
- In der Fahrzeug-Buchungsdetailansicht gibt es neben jeder Telefonnummer jetzt einen Kopieren-Button (kurzes ✓-Feedback beim Klick).

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
10. Sicherheitshinweis neues Gerät — **fertig, live verifiziert** (siehe eigener Abschnitt unten)
11. Einzelgerät-Login-Sperre — **bestätigt: nicht gebaut**, nur Konzept (siehe eigener Abschnitt unten)
12. Sportartspezifische Vereinsfeatures (Ringen, Schwimmen, Fußball, Tennis) — **Frontend fertig, eine SQL-Migration steht aus** (siehe eigener Abschnitt unten)

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
- vehicle_bookings (vehicle_id, team_id ODER private_label, membership_id, starts_at, ends_at) — Exclude-Constraint (btree_gist) verhindert überlappende Buchungen pro Fahrzeug auf DB-Ebene (nicht nur UI-Check, gilt auch beim Bearbeiten einer Buchung). Check-Constraint erzwingt volle Stunden.
- Helper-Funktionen can_manage_fleet() (vorstand/vereinsadmin/geschaeftsfuehrung) und can_book_vehicles() (**seit 2026-08-06 auch vorstand/vereinsadmin**, davor nur trainer/teammanager/kapitaen/finanzmanager/geschaeftsfuehrung — s. u.)

### Frontend
- VehiclesView-Komponente, erreichbar über neue Dashboard-Kachel "Vereinsfahrzeuge"
- Echtes Kalenderraster (Monatsansicht, Mo-So-Spalten), Fahrzeugliste, Buchungsformular (Datum+volle-Stunde von/bis, Mannschaft oder "Privat" mit Namen)
- Stornieren: eigene Buchung immer, fremde nur Vorstand/Vereinsadmin/GF
- **Bearbeiten (neu, 2026-08-06):** dieselbe Berechtigung wie Stornieren (eigene Buchung immer, fremde nur Vorstand/Vereinsadmin/GF) — Button "Bearbeiten" öffnet das Buchungsformular vorausgefüllt, Speichern macht ein `update` statt `insert`
- Bei Fremd-Stornierung: Push-Benachrichtigung an ursprünglichen Buchenden
- **Telefonnummer-Pflicht zum Buchen (neu, 2026-08-06):** Neue Buchung nur möglich, wenn `currentUser.contactPhones` mindestens eine Nummer enthält (Klick zeigt sonst einen Hinweis statt des Formulars). Gilt nur fürs Neu-Anlegen, nicht fürs Bearbeiten (ein Vorstand ohne eigene Telefonnummer soll fremde Buchungen trotzdem bearbeiten dürfen).
- **Buchungsdetails per Klick (neu, 2026-08-06):** Klick auf eine Buchung in der Monatsliste öffnet eine Detailansicht mit Fahrzeug, Zeitraum, Mannschaft/Zweck, Name des Buchenden und dessen Telefonnummer(n) als `tel:`-Links zum direkten Anrufen. Sichtbar für alle aktiven Vereinsmitglieder (nicht nur Fuhrpark-Verwalter), da der Zweck ist, bei Rückfragen anrufen zu können.

### ✅ Eingespielt: Rollen-Erweiterung + UPDATE-Policy + Telefonnummer-RPC (2026-08-06, bestätigt erfolgreich)
Anlass Teil 1: wer ein Fahrzeug neu anlegen kann (Vorstand/Vereinsadmin/GF), sollte es auch buchen und bestehende Buchungen bearbeiten können — bisher konnten Vorstand/Vereinsadmin zwar Fahrzeuge anlegen, aber nicht buchen (nur GF war in beiden Rollengruppen), und eine UPDATE-Policy für Buchungen fehlte komplett (nur `insert`/`delete` waren erlaubt, kein "Bearbeiten" für irgendjemanden).

Anlass Teil 2 (Telefonnummer): `profiles` hat RLS `id = auth.uid()` — ein Mitglied kann grundsätzlich NUR sein eigenes Profil lesen, auch nicht über einen Join von `vehicle_bookings` aus. Damit die Kontakt-Funktion ("Buchung anklicken → Person anrufen, Nummer kopieren") trotzdem funktioniert, ohne die `profiles`-Tabelle allgemein zu öffnen, gibt es eine eng zugeschnittene SECURITY DEFINER-RPC, die ausschließlich die Telefonnummer(n) des Buchenden einer konkreten `vehicle_bookings`-Zeile herausgibt, und auch nur an aktive Mitglieder desselben Vereins.

Nachfolgend zur Referenz, falls die Funktionen mal neu aufgesetzt werden müssen:

```sql
create or replace function public.can_book_vehicles(target_club uuid)
returns boolean
language sql
stable
security definer
set search_path = 'public'
as $$
  select exists (
    select 1 from public.membership_roles r
    join public.club_memberships m on m.id = r.membership_id
    where m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
      and r.role in ('vorstand', 'vereinsadmin', 'geschaeftsfuehrung', 'trainer', 'teammanager', 'kapitaen', 'finanzmanager')
  );
$$;

create policy "owner or fleet admin updates booking" on public.vehicle_bookings
  for update
  using (
    membership_id in (select id from public.club_memberships where profile_id = auth.uid())
    or public.can_manage_fleet(club_id)
  )
  with check (
    membership_id in (select id from public.club_memberships where profile_id = auth.uid())
    or public.can_manage_fleet(club_id)
  );

create or replace function public.get_booking_contact_phone(target_booking uuid)
returns text[]
language sql
stable
security definer
set search_path = 'public'
as $$
  select p.contact_phones
  from public.vehicle_bookings vb
  join public.club_memberships m on m.id = vb.membership_id
  join public.profiles p on p.id = m.profile_id
  where vb.id = target_booking
    and exists (
      select 1 from public.club_memberships viewer
      where viewer.club_id = vb.club_id and viewer.profile_id = auth.uid() and viewer.status = 'active'
    );
$$;

grant execute on function public.get_booking_contact_phone(uuid) to authenticated;
```

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

### ✅ Eingespielt: RPC `claim_duty_task` (2026-08-06, bestätigt erfolgreich)
Nachfolgend zur Referenz, falls die Funktion mal neu aufgesetzt werden muss:

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
1. Im Vercel-Preview für `paypal-sandbox-test` testen: als Organisator/Vorstand einen Satz mit Stationen anlegen, als Trainer/Vorstand ein Heimspiel anlegen, Satz vorladen, Station zuweisen + Frist setzen, als Mitglied eine freie Station übernehmen/zurückziehen, als Frist erledigt markieren.
2. Nach erfolgreichem Test: nach `main` mergen.

---

## SICHERHEITSHINWEIS NEUES GERÄT — fertig, live verifiziert (2026-08-06)

Live gegen die Datenbank geprüft (nicht nur aus alten Chat-Notizen übernommen):

- Trigger `on_new_session_check_device` (AFTER INSERT auf `auth.sessions`) → Funktion `notify_new_device()`
- Geräte-Fingerabdruck: `md5(user_agent || '|' || ip)`
- Tabelle `known_devices(profile_id, device_hash, user_agent, first_seen_at, last_seen_at)`, Primary Key `(profile_id, device_hash)` — passt exakt zum `on conflict` im Trigger, kein Fehlerrisiko beim Upsert
- Bei neuem Gerät: `notify(member.id, 'security', 'Neues Gerät angemeldet', ...)` für **alle aktiven Mitgliedschaften** des Profils (ein Profil kann in mehreren Vereinen Mitglied sein) — Kategorie `security`, in `NOTIFICATION_OPTIONS` im Frontend bereits vorhanden und togglebar

Kein Code-/DB-Handlungsbedarf, funktioniert wie ursprünglich konzipiert.

---

## EINZELGERÄT-LOGIN-SPERRE — bestätigt: nicht gebaut, nur Konzept

Live gegen die Datenbank geprüft: keine Funktionen, Tabellen oder Trigger mit Bezug zu Session-Sperren, Geräte-Bestätigung oder Fremd-Logout gefunden. Der Stand entspricht exakt der ursprünglichen Einschätzung — bewusst vertagt, weil ein Fehler darin ALLE Nutzer aussperren könnte.

**Konzept (falls später umgesetzt):**
- Login auf einem zweiten Gerät wird standardmäßig blockiert ("Dein Account ist noch mit einem anderen Gerät verbunden.")
- Notfall-Button "Trotzdem hier anmelden" → E-Mail-Bestätigung → altes Gerät wird automatisch abgemeldet
- Braucht: eigenen E-Mail-Versand (aktuell nur Supabases Standard-Mailer mit niedrigem Rate-Limit), Session-Check bei praktisch jeder App-Aktion (nicht nur beim Login), gründliches Testen mit zwei echten Geräten parallel

**Empfehlung:** als eigene, fokussierte Session angehen, nicht nebenbei — höheres Blast-Radius-Risiko als alle anderen Punkte in diesem Dokument, da es den Login-Mechanismus selbst verändert statt nur neue, isolierte Funktionen hinzuzufügen.

---

## SPORTARTSPEZIFISCHE VEREINSFEATURES — Frontend fertig, eine SQL-Migration steht aus (2026-08-06)

### Konzept
Bei der Vereinsregistrierung wird jetzt eine Sportart gewählt (Rollhockey, Fußball, Tennis, Schwimmen, Ringen). Die App hatte bisher genau zwei wiederverwendbare Vereinsfunktions-Bausteine, beide ursprünglich Rollhockey-benannt: den Helferdienst (Stationen für Heimspiele) und die Vereinsfahrzeuge (Kalenderbuchung). Beide werden jetzt sportartspezifisch umbenannt und sind pro Verein einzeln an-/abschaltbar:

| Sportart | Helferdienst heißt … | Stationen-Beispiele | Vereinsfahrzeuge heißt … |
|---|---|---|---|
| Rollhockey | Helferdienst | Theke, Kasse, Grill, Zeitnahme | Vereinsfahrzeuge |
| Fußball | Kioskdienst | Kiosk, Kasse, Grill, Ordnungsdienst, Parkplatzeinweisung | Mannschaftsbus |
| Tennis | Vereinsheimdienst | Kuchenbuffet, Getränke, Platzherrichtung, Aufbau | Vereinsbus |
| Schwimmen | Wettkampfhelfer | Zeitnahme, Kampfrichter, Startblock-Aufsicht, Kiosk | Vereinsbus |
| Ringen | Kampfrichter & Helfer | Kampftisch, Zeitnahme, Verpflegung, Auf-/Abbau der Matten | Vereinsbus |

Auch der Begriff "Heimspiel" wird sportgerecht ersetzt (Tennis: Heim-Medenspiel, Schwimmen: Heimwettkampf, Ringen: Heimkampf), z. B. in den Platzhaltertexten beim Anlegen eines Helferdienst-Satzes.

**Bewusste Scope-Entscheidung — was NICHT gebaut wurde:** Eine dritte, genuin neue Ressourcenart (Tennis-Platzbuchung, Schwimmbahnen-Buchung, Matten-Belegung für Ringen) wäre inhaltlich naheliegend, hätte aber jeweils ein komplett neues DB-Schema gebraucht (eigene Tabelle, eigene RLS, eigene UI — analog zum bisherigen `club_vehicles`/`vehicle_bookings`-Aufwand, nur 3× wiederholt). Das in einer einzigen, nicht live testbaren Session zu bauen wäre unverantwortlich gewesen. Stattdessen: dieselben zwei bewährten Rollhockey-Bausteine sportspezifisch umbenannt — genau wie in der Aufgabenstellung "wie bei Rollhockey, nur sportspezifisch" beschrieben. Eine echte Platzbuchung für Tennis ist ein sinnvoller, klar abgegrenzter Folgeauftrag.

### Feature-Toggle-System (neu, generisch)
- Tabelle `club_feature_toggles(club_id, feature_key, enabled, updated_at)`, Primary Key `(club_id, feature_key)`. Fehlt ein Eintrag → Feature gilt als **an** (sicherer Default, siehe unten).
- Zwei Feature-Keys: `duty_roster` (Helferdienst/Kioskdienst/…) und `vehicle_booking` (Vereinsfahrzeuge/Mannschaftsbus/…).
- `can_manage_club_settings(target_club)` — vereinsadmin/vorstand/sysadmin.
- **Nach der Vereinsregistrierung:** neue Komponente `ClubFeatureOnboarding` — Ganzbildschirm-Assistent, fragt beide Features nacheinander per Ja/Nein ab (sportspezifischer Fragetext, z. B. bei Rollhockey: „Hat euer Verein ein Fahrzeug (Vereinsfahrzeuge), das über die App gebucht werden soll?"), schreibt danach beide Zeilen in `club_feature_toggles`. Erscheint nur direkt nach einer NEUEN Vereinsregistrierung (lokaler State `featureOnboardingClubId`, nicht aus der DB abgeleitet) — bestehende Vereine werden dadurch nicht rückwirkend zu einem Assistenten gezwungen.
- **Danach jederzeit änderbar:** neuer Reiter „Funktionen" in der Vereinsverwaltung (nur vereinsadmin/vorstand/sysadmin), Komponente `ClubFeatureSettingsPanel`, nutzt die bestehende `ToggleCard`-Komponente.
- **Gating:** `featureEnabled(key)` (App-Ebene) steuert: Dashboard-Kachel "Vereinsfahrzeuge"/Äquivalent nur bei `vehicle_booking`, `subView==="vehicles"`-Route defensiv mitgegatet, `DutyTasksSection` in `EventCard` nur bei `duty_roster`, der Verwaltungs-Reiter "…-Sätze" nur bei `duty_roster`. Beispiel aus der Aufgabenstellung (Rollhockey ohne KFZ) funktioniert also direkt: Toggle aus → Kachel verschwindet, Buchen ist nicht mehr erreichbar.
- **Bekannte Einschränkung:** Wird der Onboarding-Assistent abgebrochen (Tab geschlossen, bevor beide Fragen beantwortet sind), bleiben beide Features einfach auf dem sicheren Standard "an" — er erscheint beim nächsten Login NICHT automatisch erneut (kein DB-Flag dafür, bewusst einfach gehalten). Der Vereinsadmin kann es jederzeit über den neuen "Funktionen"-Reiter nachholen.

### ⚠️ Noch einzuspielen (SQL-Editor, Projekt kymokcqebfruhlvcyqnw)
**Wichtig:** Der erste Block (`create type`) MUSS als eigener, isolierter Schritt VOR dem Rest laufen (sonst Postgres-Fehler "unsafe use of new value", siehe Workflow-Konvention unten).

```sql
create type public.club_sport as enum ('rollhockey', 'fussball', 'tennis', 'schwimmen', 'ringen');
```

Danach den Rest (neue Spalte, neue Tabelle, RLS, aktualisierte `register_new_club`-Funktion mit zusätzlichem `club_sport`-Parameter):

```sql
alter table public.clubs add column if not exists sport public.club_sport not null default 'rollhockey';

create table if not exists public.club_feature_toggles (
  club_id uuid not null references public.clubs(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (club_id, feature_key)
);
alter table public.club_feature_toggles enable row level security;

create or replace function public.can_manage_club_settings(target_club uuid)
returns boolean language sql stable security definer set search_path = 'public'
as $$
  select exists (
    select 1 from public.membership_roles r
    join public.club_memberships m on m.id = r.membership_id
    where m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
      and r.role in ('vereinsadmin', 'vorstand', 'sysadmin')
  );
$$;

create policy "club members read feature toggles" on public.club_feature_toggles
  for select using (
    exists (select 1 from public.club_memberships m where m.club_id = club_feature_toggles.club_id and m.profile_id = auth.uid() and m.status = 'active')
  );

create policy "admins manage feature toggles" on public.club_feature_toggles
  for all using (public.can_manage_club_settings(club_id)) with check (public.can_manage_club_settings(club_id));

create or replace function public.register_new_club(club_name text, club_short_name text, club_city text, club_register_number text, club_currency text DEFAULT 'EUR'::text, referral text DEFAULT NULL::text, member_name text DEFAULT ''::text, member_birthdate date DEFAULT NULL::date, club_sport text DEFAULT 'rollhockey'::text)
 RETURNS TABLE(club_id uuid, membership_id uuid)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
declare new_club uuid; new_membership uuid; referrer uuid; referrer_profile uuid; referral_code_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if nullif(trim(club_name),'') is null or nullif(trim(club_short_name),'') is null or nullif(trim(club_register_number),'') is null then
    raise exception 'Required club data missing';
  end if;
  if upper(club_currency) not in ('EUR','USD','GBP','CHF','DKK','NOK','SEK','PLN','CZK') then raise exception 'Unsupported currency'; end if;
  if referral is not null and nullif(trim(referral),'') is not null then
    select id,club_id,profile_id into referral_code_id,referrer,referrer_profile
    from public.club_referral_codes where upper(code)=upper(trim(referral)) and redeemed_at is null;
    if referral_code_id is null then raise exception 'Invalid or already used referral code'; end if;
  end if;
  insert into public.clubs(slug,name,short_name,city,founded_year,register_number,currency,sport)
  values(lower(regexp_replace(trim(club_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6),trim(club_name),upper(trim(club_short_name)),nullif(trim(club_city),''),extract(year from now())::int,trim(club_register_number),upper(club_currency),coalesce(club_sport,'rollhockey')::public.club_sport) returning id into new_club;
  update public.profiles set full_name=trim(member_name),birthdate=member_birthdate where id=auth.uid();
  insert into public.club_memberships(club_id,profile_id,display_name,email,member_since,status,created_by)
  select new_club,auth.uid(),trim(member_name),email,extract(year from now())::int,'active',auth.uid() from auth.users where id=auth.uid() returning id into new_membership;
  insert into public.membership_roles(membership_id,role,granted_by) values
    (new_membership,'mitglied',auth.uid()),(new_membership,'vereinsadmin',auth.uid()),(new_membership,'sysadmin',auth.uid());
  if referrer is not null then
    insert into public.club_referrals(referrer_club_id,referred_club_id,referred_by_profile_id,code,status,redeemed_at)
    values(referrer,new_club,referrer_profile,trim(referral),'redeemed',now());
    update public.club_referral_codes set used_by_club_id=new_club,redeemed_at=now() where id=referral_code_id;
    update public.clubs set referral_credit_months=referral_credit_months+3 where id=referrer;
  end if;
  return query select new_club,new_membership;
end;
$function$;
```

Bis das eingespielt ist: der Sportart-Dropdown bei der Vereinsregistrierung ist zwar sichtbar, aber `register_new_club` kennt den neuen `club_sport`-Parameter noch nicht (Supabase ignoriert unbekannte RPC-Parameter nicht automatisch — der Aufruf würde fehlschlagen) und weder `clubs.sport` noch `club_feature_toggles` existieren. **Vor dem Testen unbedingt einspielen.**

### Frontend — Bugfix beim Selbst-Review
Zwei der drei `register_new_club`-Aufrufstellen (Login-schließt-Registrierung-ab-Pfad, Sofort-Registrierung-Pfad) haben den `clubs`-State nie mit dem echten, neu angelegten Vereinsdatensatz aktualisiert — `currentClub` wäre nach der Registrierung `undefined` gewesen (falscher Vereinsname im Header, und der neue Feature-Onboarding-Assistent hätte mangels `club.id` beim Speichern der Antworten gar nichts geschrieben). Beim Selbst-Review gefunden und in beiden Pfaden behoben (dritter, häufigster Pfad — automatischer Effekt nach E-Mail-Bestätigung — hatte das schon immer korrekt gemacht).

### Verifikation in dieser Session
- `npm run build` — erfolgreich nach jeder Änderungsrunde
- Registrierungsformular im Browser-Preview durchgetestet (JS-gesteuert, siehe frühere Abschnitte zur Browser-Tool-Einschränkung): Sportart-Dropdown zeigt alle 5 Sportarten korrekt, Formular lässt sich mit „Tennis" ausfüllen und absenden, führt fehlerfrei zur Kontoerstellung, keine Konsolenfehler
- **Nicht testbar ohne echte `.env.local`-Zugangsdaten:** der komplette DB-gestützte Teil (echte Registrierung, Feature-Onboarding-Assistent, Funktionen-Reiter, Gating der Kacheln) — gleiche strukturelle Einschränkung wie bei allen anderen DB-Features dieser Session.

### Nächste Schritte
1. **SQL oben einspielen** (zwei Schritte: erst `create type`, dann den Rest).
2. Im Vercel-Preview mit allen 5 Sportarten je einen Testverein registrieren, Onboarding-Assistent durchklicken, Funktionen-Reiter prüfen, Toggle aus- und wieder einschalten und beobachten, dass die jeweilige Kachel/der Reiter verschwindet bzw. wiederkommt.
3. Falls gewünscht: echte Platzbuchung für Tennis (und analog Bahnen/Matten) als eigenes, neues Feature nachziehen — bewusst nicht in dieser Session gebaut (siehe Scope-Entscheidung oben).

---

## Workflow-Konventionen
- Patch-Skripte (.mjs) werden nach erfolgreichem npm run build + Commit immer gelöscht
- Reihenfolge: SQL-Migration → Frontend-Patch-Skript → npm run build → Skript löschen → committen → push nach paypal-sandbox-test → in Preview testen → erst dann nach main mergen
- Bei unklarer DB-Struktur immer per SQL-Editor-Abfrage verifizieren statt zu raten
- Bei String-Ersetzungs-Patches: bei Nichteindeutigkeit (0x oder 2x gefunden) auf Zeilennummer-basierte Splice-Methode wechseln statt exaktem Textvergleich — robuster gegen Whitespace-Abweichungen beim Kopieren
- Große Patch-Skripte immer als EIN zusammenhängender Codeblock zum Kopieren geben, nicht mehrteilig — sonst bricht das Terminal beim Einfügen ab (heredoc>-Hänger). Bei sehr langen Skripten (>150 Zeilen) lieber VS Code direkt nutzen statt Terminal-Heredoc.