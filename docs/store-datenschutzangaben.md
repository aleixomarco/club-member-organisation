# Datenschutz-Angaben für App Store und Play Store

Ausfüllhilfe für Apples „App Privacy" und Googles „Data Safety". Die Angaben
stammen aus dem tatsächlichen Datenmodell (`supabase/migrations/`) und den
eingebundenen Diensten — nicht aus einer Vorlage.

**Grundsatz für beide Formulare:** Es gibt kein Analyse- oder Tracking-Werkzeug in
der App, keine Standorterfassung und keine Weitergabe an Werbenetzwerke. Alle
erhobenen Daten dienen ausschließlich dem Betrieb des Vereinskontos.

---

## Apple — App Privacy

Für jeden Punkt fragt Apple drei Dinge: Wird der Datentyp erhoben? Ist er mit der
Identität verknüpft? Wird er zum Tracking genutzt?

**Zum Tracking wird bei uns nichts genutzt — diese Frage ist überall „Nein".**

| Datentyp | Erhoben | Mit Identität verknüpft | Zweck |
|---|---|---|---|
| Name | Ja | Ja | App-Funktionalität |
| E-Mail-Adresse | Ja | Ja | App-Funktionalität, Kontoverwaltung |
| Telefonnummer | Ja | Ja | App-Funktionalität |
| Physische Adresse | Ja | Ja | App-Funktionalität (Vereinsmitgliedschaft) |
| Weitere Kontaktdaten | Ja | Ja | App-Funktionalität |
| Weitere Nutzerdaten | Ja | Ja | Geburtsdatum, Geschlecht, Nationalität, akademischer Titel, Mitgliedsnummer |
| Fotos oder Videos | Ja | Ja | Nutzerinhalte (Vereinslogo, Bilder in News-Beiträgen) |
| Andere Nutzerinhalte | Ja | Ja | Chat-Nachrichten, News-Beiträge, Aufgaben, Abstimmungen |
| Einkäufe | Ja | Ja | Abo-Status (Kaufabwicklung über Apple/PayPal, keine Zahlungsdaten bei uns) |
| Nutzer-ID | Ja | Ja | Kontozuordnung |
| Geräte-ID | Ja | Ja | Push-Token für Benachrichtigungen |

**Nicht erhoben:** Standort, Kontakte, Gesundheits- und Fitnessdaten, Browserverlauf,
Suchverlauf, Nutzungsdaten, Diagnosedaten, Werbedaten, Zahlungsdaten
(Kartennummern/IBAN liegen bei Apple bzw. PayPal, nie bei uns).

### Export-Compliance
Bereits in `ios/App/App/Info.plist` hinterlegt: `ITSAppUsesNonExemptEncryption = false`.
Die App nutzt ausschließlich Standard-TLS zu Vercel, Supabase und Firebase.

### Kontolöschung
Apple verlangt seit 2022 eine Löschmöglichkeit **in** der App, wenn dort Konten
angelegt werden können. Vorhanden: Profil → Einstellungen → Konto löschen
(zusätzlich weiterhin über Profil → Konto & Sicherheit → Kontoeinstellungen).
Wartet die Aufnahme noch auf Freigabe, steht die Löschung direkt auf dem
Hinweisbildschirm nach der Anmeldung
(Route `app/api/account/delete`, Seite `/konto-loeschen`).

---

## Google — Data Safety

Google fragt je Datentyp: erhoben, geteilt, zwingend erforderlich, Zweck.

**„Geteilt" ist überall „Nein"** — Daten gehen ausschließlich an
Auftragsverarbeiter (Supabase, Vercel, Google Firebase, RevenueCat, PayPal), was
Google ausdrücklich nicht als „Teilen" wertet.

| Kategorie | Datentyp | Erhoben | Erforderlich | Zweck |
|---|---|---|---|---|
| Personenbezogene Daten | Name | Ja | Ja | App-Funktionalität, Kontoverwaltung |
| Personenbezogene Daten | E-Mail-Adresse | Ja | Ja | App-Funktionalität, Kontoverwaltung |
| Personenbezogene Daten | Adresse | Ja | Nein | App-Funktionalität |
| Personenbezogene Daten | Telefonnummer | Ja | Nein | App-Funktionalität |
| Personenbezogene Daten | Weitere Infos | Ja | Nein | Geburtsdatum, Geschlecht, Nationalität, Mitgliedsnummer |
| Fotos und Videos | Fotos | Ja | Nein | App-Funktionalität (Vereinslogo, News-Bilder) |
| Nachrichten | Andere In-App-Nachrichten | Ja | Nein | App-Funktionalität (Vereinschat) |
| Finanzdaten | Kaufhistorie | Ja | Nein | App-Funktionalität (Abo-Status) |
| App-Aktivität | Andere Aktionen | Ja | Nein | Zu-/Absagen, Abstimmungen, Helferdienste |
| Geräte-IDs | Geräte- oder andere IDs | Ja | Nein | Push-Benachrichtigungen |

**Sicherheitsangaben:**
- Verschlüsselte Übertragung: **Ja** (durchgängig HTTPS/TLS)
- Löschung anfordern möglich: **Ja** (in der App unter Profil → Konto & Sicherheit)
- Verpflichtung auf Play-Families-Richtlinie: prüfen, falls die App auch Kinder
  adressiert.

  **Achtung, hier stand bis zum 29.08.2026 etwas Falsches:** „bei
  Kindermannschaften legt der Verein Platzhalterprofile an, die Kinder selbst
  haben kein eigenes Konto." Das trifft nicht zu, und wer es so in die Stores
  einträgt, gibt eine unzutreffende Datenschutzerklärung ab.

  Richtig ist: Platzhalterprofile ohne Konto gibt es, aber sie sind nur **eine**
  Möglichkeit. Die Registrierung kennt keine Altersschranke — ein Jugendlicher
  kann sich ein eigenes Konto anlegen. Die Verwaltung sieht den Übergang sogar
  ausdrücklich vor: „Wenn ein ohne Konto angelegter Spieler (z. B. aus einer
  Kindermannschaft) später sein eigenes Konto registriert, hier das
  Platzhalter-Profil mit dem neuen echten Konto verknüpfen."

  Was stattdessen zutrifft und die Angabe trägt: Minderjährige können lesen,
  aber im Chat **nicht schreiben**. Die Mannschaftskanäle erlauben das Schreiben
  nur Trainern, Kapitänen, Teammanagern und der Vereinsleitung, durchgesetzt per
  Datenbankregel (`write_roles`), nicht nur in der Oberfläche.

  Zu entscheiden bleibt, ob die App als „auch für Kinder" eingestuft wird. Das
  ist eine Entscheidung des Betreibers, keine technische — sie zieht bei Apple
  die Kids-Kategorie und bei Google die Families-Richtlinie nach sich.

---

## Datenschutzerklärung

Beide Stores verlangen eine öffentlich erreichbare URL:
`https://club-member-organisation.vercel.app/datenschutz`

Die Seite existiert bereits (`app/datenschutz/page.tsx`).

---

## Offener Punkt vor der Einreichung

Diese Aufstellung beschreibt den technischen Ist-Zustand korrekt. Ob die
Datenschutzerklärung und die Widerrufsbelehrung inhaltlich ausreichen, ist eine
Rechtsfrage — bei einem Abo-Geschäft mit Verbrauchern sollte das anwaltlich
geprüft werden. Falsche Angaben in diesen Formularen führen bei Apple und Google
regelmäßig zur Ablehnung oder nachträglichen Sperrung.
