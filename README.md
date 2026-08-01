# Club Member Organisation

Die Vereins-App ist als Next.js-Projekt für GitHub und Vercel vorbereitet.

## Lokal starten

Voraussetzung: Node.js ab Version 22.13.

```bash
npm install
npm run dev
```

Die lokale App ist anschließend unter `http://localhost:3000` erreichbar. Mit
`npm run build` kann vor einer Veröffentlichung geprüft werden, ob das Projekt
vollständig gebaut werden kann.

## Veröffentlichen

Die vollständige, nicht-technische Schritt-für-Schritt-Anleitung befindet sich
in [VEROEFFENTLICHUNG.md](./VEROEFFENTLICHUNG.md).

## Supabase

Die benötigten Feldnamen stehen in `.env.example`. Echte Schlüssel gehören nur
in `.env.local` auf dem eigenen Rechner und in die Environment Variables bei
Vercel. Sie dürfen nie in GitHub eingecheckt werden.

Wichtig: Die aktuelle App-Oberfläche arbeitet noch mit Demo-Daten im Browser.
Die Variablen sind für die geplante Supabase-Anbindung vorbereitet; eine
dauerhafte Speicherung in Supabase ist damit noch nicht automatisch umgesetzt.
