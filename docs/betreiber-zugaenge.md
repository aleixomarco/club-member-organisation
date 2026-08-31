# Zugänge des Betreibers

Was Sie brauchen, um die App zu betreiben — und was passiert, wenn Sie eines
davon verlieren. Aufgeschrieben am 03.09.2026.

---

## Die kurze Antwort

**Sie können sich aus der Betreiber-Konsole nicht aussperren.** Das Passwort
liegt nicht in einer Datenbank, aus der man es zurückholen müsste, sondern als
Umgebungsvariable in Ihrem Vercel-Projekt. Vergessen Sie es, setzen Sie ein
neues — zwei Minuten, kein Support, keine Wartezeit.

Es gibt deshalb bewusst **keine „Passwort vergessen"-Funktion** in der Konsole.
Sie wäre nur eine weitere Tür in dasselbe Haus, und jede weitere Tür ist eine
weitere Möglichkeit, hineinzukommen.

---

## Passwort neu setzen

1. <https://vercel.com> → Projekt `club-member-organisation`
2. **Settings → Environment Variables**
3. Bei `BETREIBER_PASSWORT` das `···`-Menü → **Edit**
4. Neuen Wert eintragen (mindestens 16 Zeichen), **Production**, speichern
5. **Deployments → das oberste → `···` → Redeploy**

Ohne Schritt 5 passiert nichts: Vercel backt Umgebungsvariablen beim Bauen in
ein Deployment ein. Ein laufendes Deployment merkt die Änderung nicht.

Nach dem Redeploy sind alle offenen Sitzungen beendet — der Signaturschlüssel
für das Cookie wird aus dem Passwort mit abgeleitet. Das ist gewollt: Ein
Passwortwechsel soll auch den Zugang beenden, der jemand anderes vielleicht
gerade offen hat.

### Der Test danach

Ein falsches Passwort muss `Das Passwort stimmt nicht` liefern:

```bash
curl -s -X POST https://club-member-organisation.vercel.app/api/betreiber/anmelden \
  -H "Content-Type: application/json" -d '{"passwort":"absichtlich-falsch"}'
```

Kommt stattdessen `Der Betreiberzugang ist nicht eingerichtet` mit einem Grund
dahinter, sagt der Grund, was fehlt — meist: Das Passwort ist zu kurz.

---

## Warum Vercel kein Nachschlagewerk ist

Neben Ihren Variablen steht ein Schloss-Symbol. Das heißt: **überschreibbar,
aber nicht mehr lesbar.** Öffnen Sie den Bearbeiten-Dialog, ist das Wertfeld
leer — nicht weil nichts drinsteht, sondern weil Vercel es nicht mehr
herausgibt.

Vercel ist also der Ort, an dem Sie ein Passwort *ersetzen*, nicht der, an dem
Sie es *nachsehen*. Zum Nachsehen brauchen Sie eine eigene Ablage.

---

## Wohin mit Link und Passwort

**In einen Passwortmanager, als Login-Eintrag mit hinterlegter Adresse.** Dann
schlägt der Browser das Passwort auf `/betreiber` von selbst vor, und Sie
müssen es nie tippen und nie erinnern.

Auf einem Mac ist das ohne Zusatzprogramm möglich: **Systemeinstellungen →
Passwörter** (bzw. die App „Passwörter"). Der Eintrag synchronisiert über
iCloud auf iPhone und iPad und ist genau dann verfügbar, wenn Sie ihn brauchen.
Wer lieber etwas Eigenständiges will: **Bitwarden** (kostenlos) oder
**1Password**.

Der Eintrag sollte enthalten:

| Feld | Inhalt |
|---|---|
| Website | `https://club-member-organisation.vercel.app/betreiber` |
| Benutzername | *(leer — die Konsole kennt keinen)* |
| Passwort | das Betreiber-Passwort |
| Notiz | „Zurücksetzen: Vercel → Settings → Environment Variables → BETREIBER_PASSWORT → Redeploy" |

**Nicht** als einzige Ablage geeignet: eine Notiz auf dem Schreibtisch, eine
Textdatei im Projektordner (die landet sonst irgendwann in Git), ein
Chatverlauf.

---

## Die eigentliche Wurzel: Ihr Vercel-Konto

Die Kette ist kurz und es lohnt, sie einmal auszusprechen:

```
Betreiber-Konsole  ←  BETREIBER_PASSWORT  ←  Vercel-Konto  ←  E-Mail + 2FA
```

Das Passwort können Sie jederzeit neu setzen — **solange Sie in Vercel
hineinkommen.** Damit ist nicht das Konsolen-Passwort das, was Sie am besten
schützen müssen, sondern der Vercel-Zugang.

Konkret:

- **Zwei-Faktor-Anmeldung** bei Vercel einschalten.
- Die **Wiederherstellungscodes** ausdrucken oder in den Passwortmanager legen —
  nicht auf dasselbe Telefon, das den zweiten Faktor erzeugt.
- Dasselbe für **GitHub** (dort liegt der Quelltext) und **Supabase** (dort
  liegen die Daten).

---

## Wenn die Konsole einmal nicht geht

Sie ist Bequemlichkeit, nicht die einzige Möglichkeit. Freischalten, sperren und
Anfragen ansehen geht genauso im SQL-Editor von Supabase — der Ablauf steht in
[freischalten.md](freischalten.md) unter „Der Weg von Hand". Solange Sie Ihr
Supabase-Konto haben, können Sie den Dienst betreiben, auch wenn Vercel gerade
streikt oder ein Deployment kaputt ist.

---

## Ein Satz, den man ungern schreibt

Sie sind derzeit der Einzige mit Zugang. Für Sie ist das übersichtlich; für die
Vereine, die dafür bezahlen, ist es ein Risiko. Wenn Ihnen etwas zustößt, kann
niemand einen Verein freischalten, eine Rechnung zuordnen oder auch nur eine
Auskunft geben.

Das lässt sich ohne großen Aufwand entschärfen: Wiederherstellungscodes und
Passwörter in einen versiegelten Umschlag bei jemandem, dem Sie vertrauen, oder
in ein Notfall-Fach Ihres Passwortmanagers mit hinterlegtem Notfallkontakt
(1Password und Bitwarden können das). Sie müssen niemandem heute Zugang geben —
nur dafür sorgen, dass es einen Weg gibt, falls es nötig wird.
