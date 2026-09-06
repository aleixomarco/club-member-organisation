#!/usr/bin/env node
/* Werkzeug zum Uebersetzen von app/page.tsx.
 *
 * WARUM EIN WERKZEUG
 * Die Datei hat rund 11.700 Zeilen und ueber hundert Komponenten. Jede
 * Textstelle von Hand zu ersetzen heisst: Stelle finden, pruefen ob die
 * umgebende Komponente die Uebersetzungsfunktion ueberhaupt kennt, notfalls
 * eine Zeile ergaenzen, dann ersetzen. Bei 369 Texten sind das rund 1.500
 * Handgriffe - und beim fuenfzigsten vergisst man den zweiten Schritt.
 *
 * Genau dieser zweite Schritt ist der gefaehrliche: Fehlt "const t = useT()",
 * ist t undefined, und die Ansicht stuerzt beim Oeffnen ab. Der Build meldet
 * das NICHT - es ist ein Laufzeitfehler.
 *
 * Das Werkzeug macht beides zusammen und meldet, was es nicht sicher
 * zuordnen kann, statt zu raten.
 *
 * AUFRUF
 *   node scripts/uebersetzen.mjs pruefen      zeigt, was zu tun waere
 *   node scripts/uebersetzen.mjs anwenden     schreibt die Aenderungen
 */

import { readFileSync, writeFileSync } from "node:fs";

const DATEI = "app/page.tsx";
const modus = process.argv[2] || "pruefen";

/* Was ersetzt werden soll: deutscher Text -> Schluessel.
   Nur Texte, die in JEDEM Zusammenhang dasselbe bedeuten. Ein Wort wie
   "Termin" kann Ueberschrift oder Knopf sein - solche kommen hier NICHT
   hinein, sondern werden einzeln behandelt. */
const ERSETZUNGEN = {
  "Abbrechen": "allg.abbrechen",
  "Speichern": "allg.speichern",
  "Löschen": "allg.loeschen",
  "Bearbeiten": "allg.bearbeiten",
  "Zurück": "allg.zurueck",
  "Entfernen": "allg.entfernen",
  "Anlegen": "allg.anlegen",
  "Hinzufügen": "allg.hinzufuegen",
  "Schließen": "allg.schliessen",
  "Abmelden": "allg.abmelden",
  "Wird geladen …": "allg.laedt",
  "Niemand gefunden.": "allg.niemandGefunden",
  "Ablehnen": "allg.ablehnen",
  "Annehmen": "allg.annehmen",
  "Austragen": "allg.austragen",
  "Übernehmen": "allg.uebernehmen",
  "Eintragen": "allg.eintragenKnopf",
  "Vor- und Nachname": "feld.vollerName",
  "E-Mail-Adresse": "login.email",
  "Passwort": "login.passwort",
  "Rückennummer": "feld.rueckennummer",
  "Mannschaft": "tm.mannschaft",
  "Mannschaften": "tm.mannschaften",
  "Stadt": "feld.stadt",
  "Gegner": "feld.gegner",
  "Impressum": "recht.impressum",
  "Datenschutz": "recht.datenschutz",
  "Nutzungsbedingungen": "recht.nutzung",
  "Verein wechseln": "verein.wechseln",
  "Deine Vereine": "verein.deine",
  "Beitritt anfragen": "verein.beitrittAnfragen",
  "Ich trete bei als": "verein.beitrittAls",
  "Verein finden": "verein.finden",
  "Suche den Verein, dem du beitreten möchtest.": "verein.findenHinweis",
  "Vereine werden geladen …": "verein.laden",
  "Die Vereinsliste konnte nicht geladen werden.": "verein.ladenFehler",
  "Erneut versuchen": "allg.erneut",
  "Neuen Verein registrieren": "verein.neuAnlegen",
  "Verein anlegen": "verein.anlegen",
  "Zurück zur Vereinsauswahl": "verein.zurueckAuswahl",
  "Eigene Farben": "verein.eigeneFarben",
  "Mannschaften werden geladen …": "tm.laden",
  "Noch keine Mannschaften angelegt.": "tm.keine",
  "Strafe wählen …": "straf.waehlen",
  "Noch keine Strafen vergeben.": "straf.keine",
  "Entsperren": "allg.entsperren",
  "Vorname": "reg.vorname",
  "Nachname": "reg.nachname",
  "Beschreibung (optional)": "feld.beschreibung",
  "Nutzer suchen": "feld.nutzerSuchen",
  "Mannschaft filtern": "feld.mannschaftFiltern",
  "Vorheriger Monat": "kal.vorher",
  "Nächster Monat": "kal.naechster",
  "Diesen Bereich schaltet der Verein frei.": "allg.gesperrt",
  "Mehr erfahren": "allg.mehr",
  "Zur Aktion": "sp.zurAktion",
  "Website ansehen": "sp.website",
  "Konto endgültig löschen?": "konto.loeschenFrage",
  "Jetzt registrieren": "login.registrieren",
};

let quelle = readFileSync(DATEI, "utf8");
const zeilen = quelle.split("\n");

/* In welcher Funktion liegt eine Zeile? Ermittelt ueber die letzte
   Funktionsdeklaration am Zeilenanfang davor - in dieser Datei stehen alle
   Komponenten auf der obersten Ebene, deshalb reicht das. */
function funktionVon(zeilennummer) {
  for (let i = zeilennummer; i >= 0; i--) {
    const treffer = zeilen[i].match(/^function ([A-Z][A-Za-z0-9_]*)\s*\(/);
    if (treffer) return { name: treffer[1], zeile: i };
  }
  return null;
}

const zuErgaenzen = new Set();
const berichte = [];
let ersetzungen = 0;

for (const [deutsch, schluessel] of Object.entries(ERSETZUNGEN)) {
  const escaped = deutsch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  /* Drei Formen, in denen ein Text vorkommt. Attribute brauchen geschweifte
     Klammern, Textknoten nicht - deshalb getrennt. */
  const formen = [
    { muster: new RegExp(`>${escaped}<`, "g"), ersatz: `>{t("${schluessel}")}<` },
    { muster: new RegExp(`placeholder="${escaped}"`, "g"), ersatz: `placeholder={t("${schluessel}")}` },
    { muster: new RegExp(`aria-label="${escaped}"`, "g"), ersatz: `aria-label={t("${schluessel}")}` },
  ];
  for (const { muster, ersatz } of formen) {
    let treffer;
    const kopie = new RegExp(muster.source, "g");
    while ((treffer = kopie.exec(quelle)) !== null) {
      const zeilennummer = quelle.slice(0, treffer.index).split("\n").length - 1;
      const funktion = funktionVon(zeilennummer);
      if (!funktion) { berichte.push(`  ? Zeile ${zeilennummer + 1}: keine Funktion gefunden fuer "${deutsch}"`); continue; }
      zuErgaenzen.add(funktion.name);
      ersetzungen++;
    }
    quelle = quelle.replace(muster, ersatz);
  }
}

/* useT() dort ergaenzen, wo es fehlt. */
const neuZeilen = quelle.split("\n");
let ergaenzt = 0;
for (const name of zuErgaenzen) {
  const start = neuZeilen.findIndex((z) => new RegExp(`^function ${name}\\s*\\(`).test(z));
  if (start < 0) continue;
  /* Schon vorhanden? Innerhalb der naechsten 12 Zeilen nachsehen. */
  const kopf = neuZeilen.slice(start, start + 12).join("\n");
  if (kopf.includes("const t = useT()")) continue;
  /* Nach der oeffnenden Klammer der Funktion einfuegen - die kann ueber
     mehrere Zeilen gehen (lange Parameterlisten). */
  let ende = start;
  while (ende < neuZeilen.length && !neuZeilen[ende].includes(") {")) ende++;
  if (ende >= neuZeilen.length) { berichte.push(`  ? ${name}: Funktionskopf nicht gefunden`); continue; }
  neuZeilen.splice(ende + 1, 0, "  const t = useT();");
  ergaenzt++;
}

console.log(`  ${ersetzungen} Textstellen, ${zuErgaenzen.size} Komponenten betroffen, ${ergaenzt} mal useT ergaenzt`);
berichte.forEach((z) => console.log(z));

if (modus === "anwenden") {
  writeFileSync(DATEI, neuZeilen.join("\n"), "utf8");
  console.log("  geschrieben");
} else {
  console.log("  (nur Probelauf - mit 'anwenden' schreiben)");
}
