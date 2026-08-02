# CMO – Addendum zum Projektstand (2. August 2026)

> Diese Datei ergänzt `CMO_PROJEKTSTAND_2026-08-02.md`, ersetzt sie nicht.
> Bitte den Inhalt nach Umsetzung in die Haupt-Übergabedatei überführen
> (Abschnitt „Phase 7" in Kapitel 14 ergänzen).

## Migrationen (in dieser Reihenfolge nach `20260802083000` einspielen)

1. `20260803090000_profile_extended_settings.sql`
2. `20260803093000_club_referrals_and_registration.sql`
3. `20260803100000_club_subscription_credits.sql`

**Vor dem Einspielen:** In Migration 1 sind alle `ALTER TABLE profiles ADD COLUMN`
defensiv mit `IF NOT EXISTS`, aber die tatsächlichen Spaltennamen (z. B. ob
`member_number` schon existiert) bitte per `\d profiles` im Supabase SQL-Editor
gegenprüfen, bevor produktiv ausgeführt wird.

## Neue Dateien für den Code

- `lib/countries.ts` — vollständige Länderliste (DE-Bezeichnung + ISO-Code) für das Land-Suchfeld
- `lib/currencies.ts` — Währungsliste, EUR als Standard

Beide sind eigenständig und ohne Abhängigkeit zu bestehendem Code — einfach unter `lib/` ablegen.

---

## 1. Profil → Kontoeinstellungen: neue Unterseiten

Alle Formulare erhalten oben rechts einen **„Speichern"**-Button (sticky/fixiert im Header der jeweiligen Unterseite).

### 1.1 Persönliche Daten
Felder: `member_number`, `academic_title`, `first_name`, `last_name` (Namensfelder vermutlich bereits vorhanden — nur ergänzen, was fehlt).

### 1.2 Kontaktdaten
- E-Mail-Liste aus `profile_emails` (eine davon `is_primary`), „+"-Button fügt Zeile hinzu, Insert via RLS-geschütztem Owner-Zugriff.
- Telefon-Liste analog aus `profile_phones`.
- Achtung: Die **Login-E-Mail** (auth.users.email) ist etwas anderes als die Kontakt-E-Mails hier — laut Projektstand Kap. 7 (Sys-Admin-Bereich) bleibt die Login-E-Mail generell geschützt/unverändert. Diese Zusatz-E-Mails sind reine Kontaktinfos, keine Login-Änderung.

### 1.3 Weitere Angaben
`date_of_birth` (falls noch nicht vorhanden ergänzen), `gender` (Dropdown: weiblich/männlich/divers/keine Angabe), `nationality_country_code` (Land-Suchfeld aus `countries.ts`).

### 1.4 Adresse
`street`, `postal_code`, `city`, `country_code` (Land-Suchfeld). Beispiel-Komponente (React, Grundgerüst — an eure UI-Bibliothek/Tailwind-Klassen anpassen):

```tsx
// components/profile/CountryCombobox.tsx
"use client";
import { useState } from "react";
import { filterCountries, type Country } from "@/lib/countries";

export function CountryCombobox({ value, onChange }: { value: string; onChange: (code: string) => void }) {
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const results = filterCountries(query).slice(0, 20);
  const selected = filterCountries(value).find((c) => c.code === value);

  return (
    <div className="relative">
      <input
        value={open ? query : selected?.name ?? ""}
        onChange={(e) => { setQuery(e.target.value); setOpen(true); }}
        onFocus={() => setOpen(true)}
        placeholder="Land eingeben..."
        className="w-full rounded-lg border px-3 py-2 text-sm"
      />
      {open && (
        <ul className="absolute z-10 mt-1 max-h-56 w-full overflow-y-auto rounded-lg border bg-white shadow-lg">
          {results.map((c: Country) => (
            <li key={c.code}>
              <button
                type="button"
                className="w-full px-3 py-2 text-left text-sm hover:bg-gray-100"
                onClick={() => { onChange(c.code); setQuery(""); setOpen(false); }}
              >
                {c.name}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

---

## 2. Benachrichtigungen

Quelle: `notification_types` (Referenztabelle) + `notification_preferences` (pro Nutzer).

```ts
// Laden
const { data: types } = await supabase.from("notification_types").select("*").order("sort_order");
const { data: prefs } = await supabase.from("notification_preferences").select("*").eq("profile_id", userId);
// Fehlt ein Eintrag in prefs für einen Typ -> Default true anzeigen (siehe get_notification_enabled RPC)

// Speichern (Upsert je Zeile beim Umschalten)
await supabase.from("notification_preferences").upsert(
  { profile_id: userId, notification_key: key, enabled: newValue },
  { onConflict: "profile_id,notification_key" }
);
```

„Voreingestellt alles ja, wenn Handy-Einstellung auf ja": Das ist Frontend-seitig zu prüfen (`Notification.permission` im Browser bzw. natives Push-Permission-Ergebnis) — die DB liefert immer `true` als Default, das Gerät entscheidet zusätzlich, ob überhaupt zugestellt wird.

## 3. Passwort ändern

Kein neues Datenbankschema nötig — läuft über Supabase Auth:

```ts
// Altes Passwort prüfen: erneut einloggen (reauthenticate)
await supabase.auth.signInWithPassword({ email: currentEmail, password: oldPassword });
// Neues Passwort setzen
await supabase.auth.updateUser({ password: newPassword });
// Optional: Audit-Eintrag
await supabase.from("profile_security_events").insert({ profile_id: userId, event_type: "password_changed" });

// Toggle "von allen Geräten ausloggen"
if (logoutAllDevices) {
  await supabase.auth.signOut({ scope: "others" }); // beendet alle Sessions außer der aktuellen
  await supabase.from("profile_security_events").insert({ profile_id: userId, event_type: "logout_all_devices" });
}
```

## 4. Sicherheit — automatischer Logout

`user_security_settings.auto_logout_days` (NULL | 30 | 60 | 90). Durchsetzung: beim App-Start `last_login_at` bzw. letzten Aktivitäts-Zeitstempel gegen `auto_logout_days` prüfen und bei Überschreitung `supabase.auth.signOut()` aufrufen (Middleware oder Layout-Check).

## 5. Vereine werben Vereine

```ts
// Eigenen Code anzeigen/erzeugen (Vereins-Admin)
const { data: code } = await supabase.rpc("create_club_referral_code", { p_club_id: myClubId });

// Sichtbarkeit von Tab 5 prüfen (für alle Rollen außer Sys-Admin)
const { data: visible } = await supabase.rpc("club_referral_tab_visible", { p_club_id: myClubId });
// isSysAdmin || visible === true  -> Tab anzeigen

// Im Registrierungsformular für einen NEUEN Verein: optionales Feld "Empfehlungscode"
// Nach erfolgreichem Anlegen des neuen Vereins in `clubs`:
if (referralCodeInput) {
  await supabase.rpc("redeem_club_referral", { p_code: referralCodeInput, p_new_club_id: newClubId });
}
```

**Freimonate-Verbuchung ist jetzt fertig** (Migration 3, da es bislang keine
Rabatt-/Gutschrift-Logik gab): `redeem_club_referral()` ruft automatisch
`credit_club_subscription_months()` auf und schreibt 3 Monate für den
werbenden Verein in `club_subscription_credits` gut. Zwei Stellen im
bestehenden PayPal-/Billing-Code müssen das neue System noch **konsumieren**:

```ts
// A) Anzeige im Vereinsabo-Bereich (z. B. "Du hast noch 3 Freimonate")
const { data: pendingMonths } = await supabase.rpc("get_pending_credit_months", { p_club_id: clubId });

// B) Bevor die nächste Abrechnung/Verlängerung ausgelöst wird (PayPal-Webhook
//    oder Renewal-Job): Freimonate abziehen statt zu berechnen.
const { data: monthsToSkip } = await supabase.rpc("consume_club_subscription_credit", { p_club_id: clubId });
if (monthsToSkip > 0) {
  // bestehende Logik: nächste `monthsToSkip` Abrechnungszyklen überspringen
  // bzw. `next_billing_date` um `monthsToSkip` Monate nach hinten verschieben
}
```

Der Mechanismus ist bewusst **unabhängig von der genauen `club_subscriptions`-
Struktur** gehalten (eigene Tabelle `club_subscription_credits` statt Raten
an unbekannten Spalten) — B) ist der einzige verbleibende Integrationsschritt
in eurem tatsächlichen PayPal-Code.

## 6. Feedback (App-Store-Bewertung)

Reiner Frontend-Deeplink, kein DB-Objekt nötig:

```ts
const isIOS = /iPhone|iPad/.test(navigator.userAgent);
const url = isIOS
  ? process.env.NEXT_PUBLIC_APP_STORE_URL   // z. B. https://apps.apple.com/app/id<APPID>?action=write-review
  : process.env.NEXT_PUBLIC_PLAY_STORE_URL; // z. B. https://play.google.com/store/apps/details?id=<PACKAGE>
window.open(url, "_blank");
```

**Neue Environment Variables (Vercel):** `NEXT_PUBLIC_APP_STORE_URL`, `NEXT_PUBLIC_PLAY_STORE_URL` (bis zum echten App-Store-Launch Platzhalter/Store-Landingpage).

## 7. Fehler melden

```ts
function buildBugReportMailto() {
  const ticket = `${Date.now().toString(36).toUpperCase()}`; // einfache, aufsteigende Ticket-Kennung
  const subject = encodeURIComponent(`Fehlermeldung - CMO App #${ticket}`);
  return `mailto:info@idbranding.de?subject=${subject}`;
}
// <a href={buildBugReportMailto()}>Fehler melden</a> öffnet die native Mail-App
```

Falls die Ticket-Nummer eindeutiger/serverseitig erzeugt werden soll (z. B. fortlaufend statt Timestamp-basiert), eine kleine Postgres-Sequence + RPC `generate_bug_ticket_number()` ergänzen — bei Bedarf sag Bescheid, dann liefere ich das nach.

---

## 8. Vereinsregistrierung: neue Pflichtfelder

Formular ergänzen um:
- **Vereinsregisternummer** (Textfeld, Pflicht) → `clubs.registration_number`
- **Währung** (Dropdown aus `currencies.ts`, Standard EUR) → `clubs.currency`
- **Vereinslogo** (optional bei Registrierung; falls leer, kann Vereins-Admin/Vorstand es später unter „Vereinslogo" nachtragen — Feature laut Projektstand Kap. 8 bereits vorhanden, keine neue Migration nötig)

---

## 9. Kurz-Checkliste zum Abhaken

- [ ] Migration 1 + 2 + 3 gegen Zielprojekt-Schema geprüft und eingespielt
- [ ] `lib/countries.ts`, `lib/currencies.ts` ins Repo übernommen
- [ ] Profil → Kontoeinstellungen: 7 neue Unterseiten verdrahtet
- [ ] RLS aller neuen Tabellen mit echtem Testkonto verifiziert
- [ ] `consume_club_subscription_credit()` in den PayPal-/Renewal-Code eingebaut
- [ ] `NEXT_PUBLIC_APP_STORE_URL` / `NEXT_PUBLIC_PLAY_STORE_URL` in Vercel gesetzt
- [ ] `npm run build` lokal erfolgreich
- [ ] Commit + Push auf `main` → Vercel-Deployment prüfen
