# Club Member Organisation veröffentlichen

## 1. Projekt in GitHub Desktop aufnehmen

1. GitHub Desktop öffnen und mit dem GitHub-Konto anmelden.
2. **File → Add Local Repository** wählen.
3. Diesen Ordner auswählen:
   `/Users/marcoaleixo/Documents/Codex/2026-08-01/er/erg-iserlohn-app`
4. Oben auf **Publish repository** klicken.
5. Als Namen `club-member-organisation` eintragen.
6. **Keep this code private** aktiviert lassen, wenn der Quellcode nicht
   öffentlich sein soll.
7. **Publish Repository** bestätigen.

Danach werden spätere Änderungen in GitHub Desktop mit **Commit to main** und
anschließend **Push origin** zu GitHub übertragen.

## 2. Projekt bei Vercel importieren

1. Bei [Vercel](https://vercel.com/) anmelden.
2. **Add New → Project** öffnen.
3. Falls gefragt, das GitHub-Konto mit Vercel verbinden.
4. Das Repository `club-member-organisation` auswählen und auf **Import** klicken.
5. Diese Einstellungen prüfen:

   - Framework Preset: **Next.js**
   - Root Directory: leer lassen (`./`)
   - Build Command: `npm run build`
   - Install Command: `npm install`
   - Node.js Version: **22.x**

6. Vor dem ersten Deploy die Supabase-Werte wie im nächsten Abschnitt
   eintragen.

## 3. Supabase-Daten bei Vercel eintragen

Im Vercel-Projekt **Settings → Environment Variables** öffnen und folgende
Variablen anlegen:

| Name | Wert aus Supabase | Umgebungen |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Project URL | Production, Preview, Development |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Publishable Key, alternativ vorhandener anon Key | Production, Preview, Development |

Die Werte sind im Supabase-Projekt über **Connect** oder unter
**Settings → API Keys** zu finden.

Ein Supabase Secret Key oder alter `service_role`-Schlüssel darf niemals als
`NEXT_PUBLIC_...` gespeichert und niemals in GitHub eingetragen werden. Sollte
später eine geschützte Server-Funktion einen solchen Schlüssel benötigen, wird
er ausschließlich als `SUPABASE_SECRET_KEY` in Vercel hinterlegt.

## 4. Veröffentlichen

1. Im Vercel-Importfenster auf **Deploy** klicken.
2. Nach erfolgreichem Aufbau zeigt Vercel die öffentliche Adresse an.
3. Jeder spätere Push auf den Branch `main` veröffentlicht automatisch eine
   neue Produktionsversion. Andere Branches erzeugen Vorschau-Versionen.

## 5. Eigene Domain verbinden (optional)

Im Vercel-Projekt unter **Settings → Domains** die gewünschte Domain eintragen.
Vercel zeigt danach die DNS-Einträge an, die beim Domain-Anbieter übernommen
werden müssen.

## Sicherheitscheck vor jedem Push

- Keine `.env.local`-Datei in GitHub veröffentlichen.
- Keine Supabase Secret Keys oder `service_role`-Schlüssel committen.
- Nur `.env.example` bleibt als leere Vorlage im Repository.
- Das GitHub-Repository möglichst privat halten.

## Aktueller Datenstand

Die App ist jetzt technisch für GitHub und Vercel vorbereitet. Die sichtbaren
Mitglieder-, Beitrags- und Termindaten sind derzeit jedoch noch Demo-Daten in
der Oberfläche. Für echte Konten und dauerhafte, geräteübergreifende Speicherung
muss die App in einem weiteren Schritt mit den Supabase-Tabellen und Supabase
Auth verbunden werden.
