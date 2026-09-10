# Die Anleitungen neu bauen

Acht Dokumente aus einer Quelle: die Gesamtanleitung und je ein Handbuch pro
Rolle. Alle im Querformat, Screenshot links, Erklärung rechts.

## Wenn sich an der App etwas geändert hat

Die Screenshots kommen aus der laufenden Demo-App. **Den Demo-Server vorher neu
starten** — er lädt Änderungen im Entwicklungsbetrieb zwar nach, aber nach
einigen Stunden und vielen Eingriffen steht im Speicher teils noch der alte
Stand. Genau daran sind schon einmal veraltete Bilder entstanden.

```
rm -rf .next
scripts/dev-demo.sh          # oder über .claude/launch.json, Eintrag cmo-demo
```

Dann Chrome mit Fernsteuerung starten und die Bilder aufnehmen:

```
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --remote-debugging-port=9333 \
  --user-data-dir=/tmp/cmo-chrome --hide-scrollbars --no-first-run about:blank &

BILD_ORDNER=$PWD/bilder node alles-neu.mjs     # 26 Bildschirme aus der App
BILD_ORDNER=$PWD/bilder node betreiber.mjs     # 3 aus der Konsole
```

`alles-neu.mjs` meldet am Ende **„Alle Wege gefunden"**. Steht dort etwas
anderes, ist eine Aufnahme auf dem Bildschirm der vorigen gelandet — dann
stimmt das Bild nicht, auch wenn eine Datei entstanden ist.

## Texte ändern

`inhalte.json` trägt alle Abschnitte je Rolle: Titel, Weg, Punkte, Hinweis.
Reiner Text, keine Auszeichnung. Wer eine Funktion ergänzt, ergänzt hier.

## Bauen und drucken

```
python3 bauen.py                               # HTML je Ausgabe
node drucken.mjs                               # PDF je Ausgabe
```

`drucken.mjs` erwartet `ORDNER` und `AUSGABEN` als Umgebungsvariablen — die
Namen stehen in `bauen.py` unter `AUSGABEN`.

Gedruckt wird über das DevTools-Protokoll, nicht über `--print-to-pdf`: Nur so
lässt sich `generateDocumentOutline` setzen, das die Lesezeichen im PDF
erzeugt.

## Prüfen

```
node pruefen.mjs        # findet Seiten, deren Inhalt unten herausläuft
node vorschau.mjs       # einzelne Seiten als PNG ansehen (SEITEN=1,2,3)
```

## QR-Codes

`qr.py` erzeugt sie ohne Fremdpaket und ohne Fremddienst — Version 5,
Fehlerkorrektur M. Wer eine Adresse ändert, muss den Code **gegenlesen
lassen**; ein QR-Code, den niemand geprüft hat, gehört nicht in ein gedrucktes
Handbuch:

```
python3 qr.py "https://…" ziel.svg
python3 qr_png.py "https://…" ziel.png
swiftc -O QRLesen.swift -o qrlesen && ./qrlesen ziel.png
```

`qrlesen` benutzt den Barcode-Leser von macOS — also einen anderen als den, der
den Code erzeugt hat. Genau darum geht es beim Gegenlesen. Beim ersten Versuch
stand die Formatangabe spiegelverkehrt und kein Gerät konnte den Code lesen.

## Was hier NICHT liegt

Die fertigen PDFs und die Screenshots sind bewusst nicht in der
Versionsverwaltung (siehe `../.gitignore`). Sie liegen im Ordner `Anleitung/`
daneben und lassen sich mit den Schritten oben neu erzeugen.
