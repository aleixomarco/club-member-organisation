# -*- coding: utf-8 -*-
"""Baut die Anleitungen als druckfertiges HTML im Querformat.

Eine Quelle, mehrere Ausgaben: die Gesamtanleitung und je ein Handbuch pro
Rolle. Jedes Handbuch ist in sich geschlossen - es beginnt mit den Grundlagen,
die fuer alle gelten, und traegt danach den eigenen Teil. Wer eine Rolle hat,
soll nicht zwei Dokumente nebeneinanderlegen muessen.

Navigation: Das Inhaltsverzeichnis ist verlinkt, jede Seite hat oben rechts
einen Knopf zurueck dorthin, und beim Drucken entsteht zusaetzlich ein echtes
Lesezeichen-Verzeichnis im PDF.
"""
import json, io, os, html, re

ORDNER = os.path.dirname(os.path.abspath(__file__))
ALLE = json.load(io.open(os.path.join(ORDNER, "inhalte.json"), encoding="utf-8"))
NACH_KEY = {r["key"]: r for r in ALLE}

FARBEN = {
 "mitglied": "#B3261E", "trainer": "#1E6B3A", "vereinsadmin": "#7A2E86",
 "organisator": "#8A5A00", "sponsoren": "#0F5F86", "redaktion": "#A03A6B",
 "eltern": "#2F5AA8", "betreiber": "#2A2028",
}

BILDER = {
 ("mitglied","Anmelden und Verein wählen"): "01-anmeldung",
 ("mitglied","Die Startseite"): "02-startseite",
 ("mitglied","Termine und Zusagen"): "03-termine",
 ("mitglied","Mitfahren und Fahrten anbieten"): "04-termin-detail",
 ("mitglied","Helferdienste übernehmen"): "20-helferplanung",
 ("mitglied","Aufgaben übernehmen"): "21-aufgaben",
 ("mitglied","Vereinsfahrzeug anfragen"): "22-fahrzeuge",
 ("mitglied","Im Chat schreiben"): "06-chat",
 ("mitglied","News und Umfragen"): "24-athlet",
 ("mitglied","Tippspiel und Athlet/in der Saison"): "23-tippspiel",
 ("mitglied","Mannschaften und Strafenkatalog"): "05-teams",
 ("mitglied","Profil, Punkte, Benachrichtigungen"): "07-profil",
 ("trainer","Dein Trainerbereich"): "11-trainerbereich",
 ("trainer","Training oder Spiel ansetzen"): "27-termin-anlegen",
 ("trainer","Absagen und löschen"): "04-termin-detail",
 ("trainer","Kader und Aufgaben"): "33-team-detail",
 ("trainer","Strafenkatalog führen"): "26-strafenkatalog",
 ("vereinsadmin","Dein Reiter Verwaltung"): "09-verwaltung",
 ("vereinsadmin","Mannschaften anlegen"): "33-team-detail",
 ("vereinsadmin","Mitglieder aufnehmen und verwalten"): "31-mitgliedsantraege",
 ("vereinsadmin","Rollen vergeben"): "28-rollen",
 ("vereinsadmin","Logo und Farben einstellen"): "30-vereinsprofil",
 ("vereinsadmin","Funktionen ein- und ausschalten"): "29-funktionen",
 ("organisator","Termine anlegen"): "27-termin-anlegen",
 ("organisator","Termine absagen und löschen"): "04-termin-detail",
 ("organisator","Sätze und Stationen anlegen"): "32-helferplanung-verwaltung",
 ("organisator","Helfer einteilen"): "20-helferplanung",
 ("organisator","Aufgaben und Fahrzeuge"): "22-fahrzeuge",
 ("sponsoren","Dein Bereich in der App"): "12-sponsoren",
 ("sponsoren","Die vier Werbeplätze"): "12-sponsoren",
 ("redaktion","Dein Reiter Redaktion"): "10-redaktion",
 ("redaktion","News ändern und löschen"): "35-redaktion-news",
 ("redaktion","Wo deine News ankommen"): "02-startseite",
 ("redaktion","Der Kanal Vereins-News"): "06-chat",
 ("eltern","Familie im Profil öffnen"): "25-persoenliche-daten",
 ("eltern","Vorhandenes Profil verknüpfen"): "25-persoenliche-daten",
 ("eltern","Betreutes Profil zusammenführen"): "28-rollen",
 ("betreiber","Anmelden und Überblick"): "13-betreiber-vereine",
 ("betreiber","Die Vereinsliste"): "13-betreiber-vereine",
 ("betreiber","Werbeanzeigen und Kennzahlen"): "15-betreiber-kpi",
}
QUER = {"13-betreiber-vereine", "14-betreiber-anzeigen", "15-betreiber-kpi"}

# Die Ausgaben. Der erste Eintrag ist die Gesamtanleitung, danach je ein
# Handbuch. "Vereinsleitung" fasst Vereinsadministration und Organisation
# zusammen: Beide arbeiten im selben Reiter, und wer das eine tut, tut in
# aller Regel auch das andere.
AUSGABEN = [
 {"datei": "CMO-Anleitung", "rollen": ["mitglied","trainer","vereinsadmin","organisator","sponsoren","redaktion","eltern"],
  "titel": "Die Vereins-App<br><span>von A bis Z</span>",
  "unter": "Einführung und Anleitung für alle Rollen —<br>vom Mitglied bis zur Vereinsleitung.",
  "kopf": "Anleitung"},
 {"datei": "CMO-Handbuch-Mitglieder", "rollen": ["mitglied"],
  "titel": "Handbuch<br><span>für Mitglieder</span>",
  "unter": "Alles, was du als Mitglied oder Athlet/in<br>in der App tun kannst.",
  "kopf": "Handbuch Mitglieder"},
 {"datei": "CMO-Handbuch-Trainer", "rollen": ["mitglied","trainer"],
  "titel": "Handbuch<br><span>für Trainer/innen</span>",
  "unter": "Die Grundlagen für alle — und dazu alles,<br>was deine Mannschaft betrifft.",
  "kopf": "Handbuch Trainer/innen"},
 {"datei": "CMO-Handbuch-Vereinsleitung", "rollen": ["mitglied","vereinsadmin","organisator"],
  "titel": "Handbuch<br><span>für die Vereinsleitung</span>",
  "unter": "Vereinsadministration und Organisation —<br>alles, was den Verein am Laufen hält.",
  "kopf": "Handbuch Vereinsleitung"},
 {"datei": "CMO-Handbuch-Sponsoren", "rollen": ["mitglied","sponsoren"],
  "titel": "Handbuch<br><span>für die Sponsorenbetreuung</span>",
  "unter": "Werbeplätze, Sponsoren und die Zahlen,<br>die du deinem Sponsor gibst.",
  "kopf": "Handbuch Sponsorenbetreuung"},
 {"datei": "CMO-Handbuch-Redaktion", "rollen": ["mitglied","redaktion"],
  "titel": "Handbuch<br><span>für die Redaktion</span>",
  "unter": "News, Kanäle und Abstimmungen —<br>alles, was der Verein zu sagen hat.",
  "kopf": "Handbuch Redaktion"},
 {"datei": "CMO-Handbuch-Eltern", "rollen": ["mitglied","eltern"],
  "titel": "Handbuch<br><span>für Eltern</span>",
  "unter": "Die App für dich — und für das Konto<br>deines Kindes.",
  "kopf": "Handbuch Eltern"},
 {"datei": "CMO-Handbuch-Betreiber", "rollen": ["betreiber"],
  "titel": "Handbuch<br><span>Vereinsverwaltung</span>",
  "unter": "Die Konsole des Betreibers.<br>Nicht für Vereine bestimmt.",
  "kopf": "Handbuch Vereinsverwaltung", "intern": True},
]

WEB_ADRESSE = "https://club-member-organisation.vercel.app"
APPLE_ADRESSE = "https://apps.apple.com/de/app/club-member-organisation/id6801881765"
KONSOLE_ADRESSE = "https://club-member-organisation.vercel.app/betreiber"

def qr(datei):
    """Der QR-Code liegt als SVG daneben und wird eingebettet - kein Bild, das
       beim Drucken nachgeladen werden muss, und kein Fremddienst. Erzeugt hat
       ihn qr.py; gegengelesen hat ihn der Barcode-Leser von macOS."""
    return io.open(os.path.join(ORDNER, datei), encoding="utf-8").read()

def e(t):
    """Deutsche Anführungszeichen statt gerader Zoll-Zeichen."""
    text = re.sub(r'"([^"]*)"', lambda m: "„" + m.group(1) + "“", str(t or ""))
    return html.escape(text)

def pfad(text):
    teile = [t.strip() for t in str(text or "").replace("&gt;", ">").split(">") if t.strip()]
    return '<span class="pfeil">›</span>'.join(f'<span class="stufe">{e(t)}</span>' for t in teile)

def zurueck():
    """Der Weg zurück zur Übersicht. Auf jeder Seite an derselben Stelle -
       eine Navigation, die wandert, benutzt niemand."""
    return '<a class="zum-inhalt" href="#inhalt">↑ Inhalt</a>'

def fuss(rolle, farbe, anker):
    return (f'<div class="fuss"><a class="fuss-links" href="#{anker}">{e(rolle)}</a>'
            f'<a class="fuss-rechts" href="#inhalt" style="color:{farbe}">@@SEITE@@</a></div>')


def bauen(ausgabe):
    rollen = [NACH_KEY[k] for k in ausgabe["rollen"] if k in NACH_KEY]
    nummer = {r["key"]: str(i) for i, r in enumerate(rollen, start=1)}
    rollen_gesamt = len(rollen)
    themen_gesamt = sum(len(r["abschnitte"]) for r in rollen)
    seiten = []

    # ---------- Titel ----------
    seiten.append(f"""
<section class="seite titel" id="start">
  <div class="titel-links">
    <div class="marke">
      <svg viewBox="0 0 100 100" class="logo"><path d="M78 26a34 34 0 1 0 0 48" fill="none" stroke="#B3261E" stroke-width="15" stroke-linecap="round"/><circle cx="70" cy="50" r="8" fill="#14151A"/></svg>
      <div><div class="marke-name">CLUB MEMBER</div><div class="marke-sub">ORGANISATION</div></div>
    </div>
    <h1>{ausgabe["titel"]}</h1>
    <p class="unter">{ausgabe["unter"]}</p>
    <div class="titel-fuss">
      <div><b>{rollen_gesamt} {"Rolle" if rollen_gesamt == 1 else "Rollen"}</b><span>alles, was du darfst</span></div>
      <div><b>{themen_gesamt} Themen</b><span>je eines pro Seite</span></div>
      <div><b>Verlinkt</b><span>Inhalt anklicken, überall zurück</span></div>
    </div>
    {'<div class="intern-marke">Nur für den Betreiber — nicht an Vereine geben</div>' if ausgabe.get("intern") else ''}
  </div>
  <div class="titel-rechts">
    <img src="bilder/{"13-betreiber-vereine" if ausgabe.get("intern") else "02-startseite"}.png"
         class="{"quer gross" if ausgabe.get("intern") else "phone gross"}">
  </div>
</section>
""")

    # ---------- So kommst du hinein ----------
    if ausgabe.get("intern"):
        seiten.append(f"""
<section class="seite einstieg">
  {zurueck()}
  <div class="eyebrow">Zuerst</div>
  <h2>So kommst du in die Verwaltung</h2>
  <p class="einstieg-vor">Die Vereinsverwaltung ist eine eigene Seite im Browser — kein Teil der App und ohne Vereinskonto erreichbar.</p>
  <div class="einstieg-raster einzeln">
    <div class="weg">
      <div class="weg-kopf"><span class="weg-nr">→</span><h3>Im Browser öffnen</h3></div>
      <div class="qr">{qr("qr-konsole.svg")}</div>
      <a class="adresse" href="{KONSOLE_ADRESSE}">{KONSOLE_ADRESSE}</a>
      <ul>
        <li>Adresse eingeben oder den Code mit der Kamera scannen.</li>
        <li>Mit dem Betreiberpasswort anmelden — es ist nicht dasselbe wie ein Vereinskonto.</li>
        <li>Funktioniert an jedem Rechner; ein breiter Bildschirm ist hier von Vorteil.</li>
      </ul>
    </div>
  </div>
  <div class="einstieg-fuss">Diese Seite gehört nicht in die Hand eines Vereins.</div>
  {fuss(ausgabe["kopf"], "#2A2028", "start")}
</section>
""")
    else:
        seiten.append(f"""
<section class="seite einstieg">
  {zurueck()}
  <div class="eyebrow">Zuerst</div>
  <h2>So kommst du hinein</h2>
  <p class="einstieg-vor">Zwei Wege, dieselbe App. Auf dem iPhone lohnt sich die Installation — nur so kommen Benachrichtigungen an. Sonst reicht der Browser.</p>
  <div class="einstieg-raster">
    <div class="weg">
      <div class="weg-kopf"><span class="weg-nr">1</span><h3>Auf iPhone und iPad</h3></div>
      <div class="qr">{qr("qr-apple.svg")}</div>
      <a class="adresse" href="{APPLE_ADRESSE}">Im App&nbsp;Store: Club Member Organisation</a>
      <ul>
        <li>Code mit der Kamera scannen — der App&nbsp;Store öffnet sich von selbst.</li>
        <li>Laden, öffnen, anmelden. Ab iOS&nbsp;15.</li>
        <li>Benachrichtigungen erlauben, sonst bekommst du keine Absagen mit.</li>
      </ul>
    </div>
    <div class="weg">
      <div class="weg-kopf"><span class="weg-nr">2</span><h3>Im Browser, ohne Installation</h3></div>
      <div class="qr">{qr("qr-web.svg")}</div>
      <a class="adresse" href="{WEB_ADRESSE}">{WEB_ADRESSE.replace("https://", "")}</a>
      <ul>
        <li>Adresse eingeben oder scannen — fertig, nichts zu installieren.</li>
        <li>Funktioniert auf Android, am Rechner und auf dem Tablet.</li>
        <li>Alles ist gleich; nur Benachrichtigungen aufs Telefon gibt es hier nicht.</li>
      </ul>
    </div>
  </div>
  <div class="einstieg-fuss">Bei Google&nbsp;Play liegt die App noch nicht — auf Android nimmst du den Browser. Anmelden kannst du dich in beiden Wegen mit demselben Konto.</div>
  {fuss(ausgabe["kopf"], "#B3261E", "start")}
</section>
""")

    # ---------- Lesehilfe ----------
    seiten.append(f"""
<section class="seite lesehilfe">
  {zurueck()}
  <div class="lese-kopf"><div class="eyebrow">Zum Anfang</div><h2>So liest du dieses Dokument</h2></div>
  <div class="lese-raster">
    <div class="lese-karte"><div class="ziffer">1</div><h3>Links das Bild</h3><p>Jede Seite zeigt genau den Bildschirm, um den es geht. So erkennst du ihn in der App sofort wieder.</p></div>
    <div class="lese-karte"><div class="ziffer">2</div><h3>Rechts der Weg</h3><p>Die graue Kette oben nennt den Weg dorthin — Reiter für Reiter, Knopf für Knopf.</p></div>
    <div class="lese-karte"><div class="ziffer">3</div><h3>Dann die Punkte</h3><p>Ein Satz je Handgriff. Kein Fachwort, keine Umschweife.</p></div>
    <div class="lese-karte"><div class="ziffer">4</div><h3>Zuletzt der Hinweis</h3><p>Der farbige Kasten nennt Voraussetzungen: eine Freischaltung, eine Rolle, eine Altersgrenze.</p></div>
  </div>
  <div class="lese-hinweis">
    <b>Am Bildschirm ist alles verlinkt.</b> Im Inhalt springst du mit einem Klick auf jedes Kapitel,
    und oben rechts kommst du von jeder Seite zurück zur Übersicht. Dein PDF-Programm zeigt zusätzlich
    ein Lesezeichen-Verzeichnis in der Seitenleiste.
  </div>
</section>
""")

    # ---------- Inhalt ----------
    zeilen = []
    for r in rollen:
        k = r["key"]
        zeilen.append(f'<a class="inh-rolle" href="#teil-{k}" style="--f:{FARBEN[k]}">'
                      f'<span class="inh-nr">{nummer[k]}</span>'
                      f'<span class="inh-titel">{e(r["rolle"])}</span>'
                      f'<span class="inh-anzahl">{len(r["abschnitte"])} Themen</span></a>')
        for i, a in enumerate(r["abschnitte"], start=1):
            zeilen.append(f'<a class="inh-zeile" href="#t-{k}-{i}"><span>{e(a["titel"])}</span></a>')
    seiten.append(f"""
<section class="seite inhalt" id="inhalt">
  <div class="eyebrow">Übersicht</div>
  <h2 class="inh-h2">Inhalt</h2>
  <p class="inh-hilfe">Jede Zeile ist ein Sprung. Zurück kommst du oben rechts auf jeder Seite.</p>
  <div class="inh-spalten{" zwei" if themen_gesamt + rollen_gesamt <= 26 else ""}">{''.join(zeilen)}</div>
</section>
""")

    # ---------- Rollen ----------
    for r in rollen:
        k = r["key"]; farbe = FARBEN[k]
        seiten.append(f"""
<section class="seite trenner" id="teil-{k}" style="--f:{farbe}">
  {zurueck()}
  <div class="tr-nr">{nummer[k]}</div>
  <div class="tr-text">
    <div class="eyebrow" style="color:{farbe}">Teil {nummer[k]} von {rollen_gesamt}</div>
    <h2>{e(r["rolle"])}</h2>
    <p>{e(r["einleitung"])}</p>
    <div class="tr-liste">{''.join(f'<a href="#t-{k}-{i}">{e(a["titel"])}</a>' for i, a in enumerate(r["abschnitte"], start=1))}</div>
  </div>
  {fuss(r["rolle"], farbe, f"teil-{k}")}
</section>
""")
        for i, a in enumerate(r["abschnitte"], start=1):
            bild = BILDER.get((k, a["titel"]))
            menge = sum(len(x) for x in a.get("punkte", [])) + len(a.get("hinweis") or "")
            dichte = "kurz" if menge < 520 else ("sehr-eng" if menge > 1080 else ("eng" if menge > 800 else ""))
            punkte = "".join(f"<li>{e(p)}</li>" for p in a.get("punkte", []))
            hinweis = (a.get("hinweis") or "").strip()
            hin = f'<div class="hinweis"><b>Gut zu wissen</b>{e(hinweis)}</div>' if hinweis else ""
            kopf = (f'<div class="eyebrow" style="color:{farbe}">{e(r["rolle"])}</div>'
                    f'<h2>{e(a["titel"])}</h2>'
                    f'<div class="pfad">{pfad(a.get("wo"))}</div>')
            if bild:
                spalte = (f'<div class="bildspalte {"breit" if bild in QUER else ""}">'
                          f'<img src="bilder/{bild}.png" class="{"quer" if bild in QUER else "phone"}"></div>')
                seiten.append(f"""
<section class="seite thema {dichte} {"mitquer" if bild in QUER else ""}" id="t-{k}-{i}" style="--f:{farbe}">
  {zurueck()}{spalte}
  <div class="textspalte">{kopf}<ul>{punkte}</ul>{hin}</div>
  {fuss(r["rolle"], farbe, f"teil-{k}")}
</section>
""")
            else:
                seiten.append(f"""
<section class="seite thema ohnebild {dichte}" id="t-{k}-{i}" style="--f:{farbe}">
  {zurueck()}
  <div class="textspalte weit">{kopf}<ul class="zweispaltig">{punkte}</ul>{hin}</div>
  {fuss(r["rolle"], farbe, f"teil-{k}")}
</section>
""")

    # ---------- Schluss ----------
    seiten.append(f"""
<section class="seite schluss">
  {zurueck()}
  <h2>Noch Fragen?</h2>
  <p>Dieses Dokument beschreibt den Stand der App zum Zeitpunkt der Erstellung. Kommt eine Funktion dazu, wächst es mit.</p>
  <div class="schluss-karten">
    <div><b>Etwas fehlt dir?</b><span>Wende dich an die Vereinsleitung — viele Funktionen sind absichtlich abschaltbar.</span></div>
    <div><b>Etwas geht nicht?</b><span>Im Profil unten findest du „Fehler melden“. Das landet direkt beim Betreiber.</span></div>
    <div><b>Neu im Verein?</b><span>Lies Teil 1. Alles Weitere kommt mit deinen Rollen von selbst dazu.</span></div>
  </div>
  <div class="schluss-fuss">Club Member Organisation · Die Screenshots stammen aus einem Demo-Verein; Namen und Zahlen darin sind erfunden.</div>
</section>
""")

    seiten = [s.replace("@@SEITE@@", str(i)) for i, s in enumerate(seiten, start=1)]
    doc = (f'<!doctype html><html lang="de"><head><meta charset="utf-8">'
           f'<title>Club Member Organisation — {html.escape(ausgabe["kopf"])}</title>'
           f'<style>{CSS}</style></head><body>{"".join(seiten)}</body></html>')
    io.open(os.path.join(ORDNER, ausgabe["datei"] + ".html"), "w", encoding="utf-8").write(doc)
    return len(seiten)


CSS = """
@import url('https://fonts.googleapis.com/css2?family=Oswald:wght@500;600;700&family=Inter:wght@400;500;600;700&display=swap');
@page { size: A4 landscape; margin: 0; }
* { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
html, body { margin: 0; padding: 0; background: #fff; }
body { font-family: Inter, system-ui, sans-serif; color: #2A2028; }
a { text-decoration: none; color: inherit; }
.seite { width: 297mm; height: 210mm; page-break-after: always; position: relative; overflow: hidden;
         background: #FDFCFD; padding: 16mm 18mm; display: flex; }
.seite:last-child { page-break-after: auto; }
.eyebrow { font-size: 8.5pt; letter-spacing: .18em; text-transform: uppercase; font-weight: 700; color: #B3261E; margin-bottom: 3mm; }
h1 { font-family: Oswald; font-weight: 700; font-size: 38pt; line-height: 1.03; margin: 0 0 6mm; color: #14151A; letter-spacing: -.01em; }
h1 span { color: #B3261E; }
h2 { font-family: Oswald; font-weight: 600; font-size: 25pt; line-height: 1.08; margin: 0 0 5mm; color: #14151A; }
h3 { font-family: Oswald; font-weight: 600; font-size: 13pt; margin: 0 0 2mm; color: #14151A; }
p { font-size: 10.5pt; line-height: 1.55; color: #4A424A; margin: 0; }

/* Zurueck zur Uebersicht - auf jeder Seite an derselben Stelle. */
.zum-inhalt { position: absolute; top: 9mm; right: 18mm; z-index: 5;
              font-size: 8pt; font-weight: 700; letter-spacing: .1em; text-transform: uppercase;
              color: #8A7F85; background: #F2EDF0; border: 1px solid #E9E4E7;
              border-radius: 99px; padding: 1.8mm 4.5mm; }

/* Titelseite */
.titel { padding: 0; align-items: stretch; }
.titel-links { width: 58%; padding: 20mm 12mm 16mm 20mm; display: flex; flex-direction: column; justify-content: center; }
.titel-rechts { width: 42%; background: linear-gradient(150deg, #FCEFF0 0%, #F3E9EE 55%, #EFE6EB 100%);
                display: flex; align-items: center; justify-content: center; padding: 10mm; }
.marke { display: flex; align-items: center; gap: 4mm; margin-bottom: 13mm; }
.logo { width: 13mm; height: 13mm; }
.marke-name { font-family: Oswald; font-weight: 700; font-size: 12pt; letter-spacing: .1em; color: #14151A; line-height: 1.1; }
.marke-sub { font-family: Oswald; font-weight: 500; font-size: 8.5pt; letter-spacing: .3em; color: #8A7F85; }
.unter { font-size: 13pt; line-height: 1.5; color: #6B6570; }
.titel-fuss { display: flex; gap: 10mm; margin-top: 16mm; padding-top: 7mm; border-top: 1px solid #E9E4E7; }
.titel-fuss div { display: flex; flex-direction: column; }
.titel-fuss b { font-family: Oswald; font-size: 15pt; color: #B3261E; font-weight: 600; }
.titel-fuss span { font-size: 8.5pt; color: #8A7F85; margin-top: 1mm; }
.intern-marke { margin-top: 8mm; align-self: flex-start; font-size: 8.5pt; font-weight: 700; letter-spacing: .1em;
                text-transform: uppercase; color: #B3261E; background: #FCF1F1; border: 1px solid #F0D9D9;
                border-radius: 99px; padding: 2mm 5mm; }
.phone.gross { width: 66mm; border-radius: 7mm; box-shadow: 0 14mm 26mm rgba(60,30,45,.22); }
.quer.gross { width: 100%; border-radius: 3mm; box-shadow: 0 10mm 22mm rgba(60,30,45,.2); }

/* So kommst du hinein */
.einstieg { flex-direction: column; }
.einstieg-vor { font-size: 11.5pt; max-width: 210mm; margin-bottom: 7mm; }
.einstieg-raster { display: grid; grid-template-columns: 1fr 1fr; gap: 9mm; flex: 1; }
.einstieg-raster.einzeln { grid-template-columns: 1fr 1fr; }
.einstieg-raster.einzeln .weg:only-child { max-width: 130mm; }
.weg { background: #fff; border: 1px solid #EDE7EA; border-radius: 5mm; padding: 7mm 8mm;
       display: flex; flex-direction: column; }
.weg-kopf { display: flex; align-items: center; gap: 3mm; margin-bottom: 4mm; }
.weg-nr { width: 8mm; height: 8mm; border-radius: 99px; background: #B3261E; color: #fff;
          font-family: Oswald; font-weight: 700; font-size: 12pt; display: flex;
          align-items: center; justify-content: center; flex-shrink: 0; }
.weg h3 { margin: 0; font-size: 14pt; }
.qr { align-self: flex-start; margin-bottom: 4mm; line-height: 0; }
.qr svg { width: 26mm; height: 26mm; display: block; }
.adresse { display: inline-block; align-self: flex-start; font-size: 9.5pt; font-weight: 700;
           color: #B3261E; background: #FCF1F1; border-radius: 99px; padding: 1.8mm 4.5mm; margin-bottom: 4mm; }
.weg ul { list-style: none; margin: 0; padding: 0; }
.weg li { font-size: 10pt; line-height: 1.5; color: #3A333A; padding-left: 5.5mm;
          margin-bottom: 2.4mm; position: relative; }
.weg li::before { content: ""; position: absolute; left: 0; top: 1.9mm; width: 2.2mm; height: 2.2mm;
                  border-radius: 99px; background: #B3261E; }
.einstieg-fuss { margin-top: 6mm; font-size: 9.5pt; line-height: 1.5; color: #6B6570;
                 background: #F7F3F5; border-radius: 3mm; padding: 5mm 6mm; }

/* Lesehilfe */
.lesehilfe { flex-direction: column; }
.lese-raster { display: grid; grid-template-columns: 1fr 1fr; gap: 7mm; margin-top: 6mm; }
.lese-karte { background: #fff; border: 1px solid #EDE7EA; border-radius: 5mm; padding: 7mm 8mm; }
.ziffer { font-family: Oswald; font-weight: 700; font-size: 17pt; color: #B3261E; margin-bottom: 2mm; }
.lese-karte p { font-size: 10pt; }
.lese-hinweis { margin-top: auto; background: #FCF1F1; border-left: 3px solid #B3261E; border-radius: 0 3mm 3mm 0;
                padding: 6mm 8mm; font-size: 10pt; line-height: 1.55; color: #4A424A; }
.lese-hinweis b { color: #14151A; }

/* Inhalt */
.inhalt { flex-direction: column; }
.inh-h2 { margin-bottom: 2mm; }
.inh-hilfe { font-size: 9pt; color: #8A7F85; margin-bottom: 6mm; }
.inh-spalten { column-count: 3; column-gap: 10mm; font-size: 9pt; }
/* Wenige Eintraege in drei Spalten lassen die halbe Seite leer. */
.inh-spalten.zwei { column-count: 2; column-gap: 14mm; font-size: 9.5pt; }
.inh-spalten.zwei .inh-zeile { padding-top: 1.2mm; padding-bottom: 1.2mm; }
.inh-rolle { break-inside: avoid; display: flex; align-items: baseline; gap: 2.5mm; margin: 5mm 0 2mm;
             border-bottom: 1.5px solid var(--f); padding-bottom: 1.2mm; }
.inh-rolle:first-child { margin-top: 0; }
.inh-nr { font-family: Oswald; font-weight: 700; font-size: 11pt; color: var(--f); }
.inh-titel { font-family: Oswald; font-weight: 600; font-size: 11pt; color: #14151A; flex: 1; }
.inh-anzahl { font-size: 7.5pt; color: #A79DA3; }
.inh-zeile { break-inside: avoid; display: block; padding: .9mm 0 .9mm 5mm; color: #6B6570; border-bottom: 1px dotted #EDE7EA; }

/* Rollen-Trenner */
.trenner { align-items: center; gap: 14mm; }
.tr-nr { font-family: Oswald; font-weight: 700; font-size: 130pt; line-height: .8; color: var(--f); opacity: .13; }
.tr-text { flex: 1; }
.tr-text h2 { font-size: 32pt; }
.tr-text p { font-size: 12.5pt; max-width: 155mm; }
.tr-liste { display: flex; flex-wrap: wrap; gap: 2mm; margin-top: 8mm; max-width: 165mm; }
.tr-liste a { font-size: 8.5pt; background: #fff; border: 1px solid #EDE7EA; border-radius: 99px; padding: 1.6mm 4mm; color: #4A424A; }

/* Themenseite */
.thema { gap: 12mm; align-items: stretch; }
.bildspalte { width: 33%; display: flex; align-items: center; justify-content: center;
              background: linear-gradient(155deg, #FBF6F8, #F4EDF1); border-radius: 6mm; padding: 8mm; }
.bildspalte.breit { width: 52%; padding: 5mm; }
.phone { max-height: 152mm; width: auto; border-radius: 5mm; box-shadow: 0 6mm 14mm rgba(60,30,45,.16); }
.quer { width: 100%; border-radius: 3mm; box-shadow: 0 6mm 14mm rgba(60,30,45,.16); }
.textspalte { flex: 1; display: flex; flex-direction: column; padding-top: 4mm; padding-bottom: 12mm; overflow: hidden; }
.pfad { display: flex; flex-wrap: wrap; align-items: center; gap: 1.5mm; margin-bottom: 6mm; }
.stufe { font-size: 8.5pt; font-weight: 600; background: #F2EDF0; color: #4A424A; border-radius: 99px; padding: 1.4mm 3.5mm; }
.pfeil { color: #B9AFB6; font-size: 9pt; }
.thema ul { list-style: none; margin: 0 0 6mm; padding: 0; }
.thema li { font-size: 11pt; line-height: 1.5; color: #3A333A; padding-left: 7mm; margin-bottom: 3.6mm; position: relative; }
.thema li::before { content: ""; position: absolute; left: 0; top: 2.1mm; width: 2.6mm; height: 2.6mm;
                    border-radius: 99px; background: var(--f); }
.zweispaltig { column-count: 2; column-gap: 12mm; }
.zweispaltig li { break-inside: avoid; }
/* Der Kasten nimmt die Farbe seines Teils auf. Vorher war er ueberall
   rosa - auf einer gruenen Trainerseite sah das aus wie ein Fremdkoerper. */
.hinweis { background: color-mix(in srgb, var(--f) 7%, #FFFFFF); border-left: 3px solid var(--f); border-radius: 0 3mm 3mm 0;
           padding: 5mm 7mm; font-size: 9.5pt; line-height: 1.5; color: #4A424A; margin-top: 4mm; }
.hinweis b { display: block; font-size: 8pt; letter-spacing: .12em; text-transform: uppercase; color: var(--f); margin-bottom: 1.5mm; }
.thema.kurz .hinweis { margin-top: auto; }
.thema.eng li { font-size: 10pt; line-height: 1.45; margin-bottom: 2.8mm; }
.thema.eng h2 { font-size: 22pt; margin-bottom: 4mm; }
.thema.eng .hinweis { font-size: 9pt; padding: 4mm 6mm; }
.thema.sehr-eng li { font-size: 9.2pt; line-height: 1.42; margin-bottom: 2.2mm; }
.thema.sehr-eng li::before { top: 1.6mm; width: 2.2mm; height: 2.2mm; }
.thema.sehr-eng h2 { font-size: 20pt; margin-bottom: 3.5mm; }
.thema.sehr-eng .pfad { margin-bottom: 4mm; }
.thema.sehr-eng .hinweis { font-size: 8.6pt; padding: 3.5mm 5.5mm; line-height: 1.45; }
.thema.sehr-eng ul { margin-bottom: 3mm; }

.fuss { position: absolute; left: 18mm; right: 18mm; bottom: 8mm; display: flex; justify-content: space-between;
        align-items: baseline; font-size: 8pt; color: #B9AFB6; letter-spacing: .06em; text-transform: uppercase; }
.fuss-rechts { font-family: Oswald; font-weight: 600; font-size: 11pt; letter-spacing: 0; text-transform: none; }

/* Schluss */
.schluss { flex-direction: column; justify-content: center; align-items: flex-start; }
.schluss h2 { font-size: 34pt; }
.schluss > p { font-size: 12.5pt; max-width: 170mm; }
.schluss-karten { display: flex; gap: 7mm; margin-top: 12mm; }
.schluss-karten div { flex: 1; background: #fff; border: 1px solid #EDE7EA; border-radius: 5mm; padding: 7mm; display: flex; flex-direction: column; gap: 2mm; }
.schluss-karten b { font-family: Oswald; font-size: 12pt; color: #B3261E; font-weight: 600; }
.schluss-karten span { font-size: 10pt; line-height: 1.5; color: #4A424A; }
.schluss-fuss { margin-top: 14mm; font-size: 8.5pt; color: #A79DA3; }
"""

if __name__ == "__main__":
    for a in AUSGABEN:
        n = bauen(a)
        print(f"  {a['datei']:34} {n:3} Seiten  ({len(a['rollen'])} Teil(e))")
