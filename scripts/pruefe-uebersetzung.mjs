#!/usr/bin/env node
/* Findet deutschen Text, der noch nicht uebersetzt ist.
 *
 * WARUM ES DIESES WERKZEUG GIBT
 * Zweimal hintereinander habe ich "die Uebersetzung ist fertig" gesagt und
 * mich geirrt. Beide Male lag es an der Suche, nicht an der Arbeit:
 *
 * Der erste Durchlauf suchte nur nach JSX-Text (>Hallo<) und Attributen
 * (placeholder="…"). Der groessere Teil der App steht aber als Zeichenkette
 * im Code - setFehler("…"), {offen ? "Ja" : "Nein"}. 337 Saetze fehlten.
 *
 * Der zweite Durchlauf suchte diese Zeichenketten, verlangte aber einen
 * Umlaut oder ein deutsches Fuellwort ("der", "nicht", "kein"), um Deutsch
 * von Englisch zu unterscheiden. "Anmelden" hat weder das eine noch das
 * andere. 155 Beschriftungen fehlten - darunter der Knopf, mit dem man sich
 * anmeldet.
 *
 * WIE ES JETZT SUCHT
 * Umgekehrt: Alles, was mit einem Grossbuchstaben anfaengt und in einer
 * Komponente steht, gilt als verdaechtig. Was KEIN Text fuer Menschen ist,
 * steht unten namentlich in AUSNAHMEN. Diese Liste ist kurz und muss es
 * bleiben - jeder Eintrag ist eine Behauptung, die jemand geprueft hat.
 *
 * Lieber zehn falsche Treffer als ein uebersehener Knopf.
 *
 * AUFRUF
 *   node scripts/pruefe-uebersetzung.mjs          Zusammenfassung
 *   node scripts/pruefe-uebersetzung.mjs liste    mit allen Fundstellen
 */

import { readFileSync } from "node:fs";

const DATEI = "app/page.tsx";
const zeigeListe = process.argv[2] === "liste";

/* Kein Text fuer Menschen - und warum nicht.
   Wer hier etwas ergaenzt, sollte den Grund dazuschreiben. */
const AUSNAHMEN = new Map([
  ["Inter", "Schriftart"],
  ["Oswald", "Schriftart"],
  ["JetBrains Mono", "Schriftart"],
  ["EUR", "Waehrungscode nach ISO 4217"],
  ["Content-Type", "HTTP-Kopfzeile, kein Anzeigetext"],
  ["DELETE", "SQL"],
  ["INSERT", "SQL"],
  ["Invalid Date", "Meldung der JavaScript-Laufzeitumgebung"],
  ["Deutsch", "Sprachname - Sprachnamen stehen in ihrer eigenen Sprache"],
  ["VEREINS-APP", "Wortmarke unter dem Logo"],
  ["Vereins-App", "Wortmarke"],
  ["Club Member Organisation", "Produktname"],
  ["Club Member", "Produktname, zweizeilig gesetzt"],
  ["Organisation", "Produktname, zweizeilig gesetzt"],
  ["Android", "Betriebssystem"],
  ["Mitgliedsbeitrag", "Wert in der Spalte fee_kind, kein Text zum Anzeigen"],
  ["Familienbeitrag", "Wert in der Spalte fee_kind, wird verglichen"],
  ["Tippspiel-Ergebnis eingetragen", "Titel einer Push-Meldung an ANDERE - die Sprache des Absenders darf nicht entscheiden, was alle lesen"],
  ["Heimspiel vs. Herringen", "erfundener Termin in den Demodaten"],
  ["Fan", "Rollenname, in allen Zielsprachen gleich"],
  ["Chat", "in allen Zielsprachen gleich"],
  ["Sponsor", "in allen Zielsprachen gleich"],
  ["Sponsoring", "in allen Zielsprachen gleich"],
  ["Browser", "in allen Zielsprachen gleich"],
  ["Diese Funktion", "Vorgabewert im Funktionskopf von LockedFeature - dort steht t noch nicht zur Verfuegung, ein t() an dieser Stelle wuerde beim Laden abstuerzen"],
]);

const quelle = readFileSync(DATEI, "utf8");
const zeilen = quelle.split("\n");

/* Welche Zeilen stehen in einer Komponente? Nur dort gibt es t(). */
const bereiche = [];
{
  let tiefe = 0, offen = null;
  for (let i = 0; i < zeilen.length; i++) {
    const treffer = zeilen[i].match(/^(?:export default )?function ([A-Za-z0-9_]+)\s*\(/);
    if (treffer && offen === null) { offen = { name: treffer[1], von: i }; tiefe = 0; }
    if (offen === null) continue;
    for (const z of zeilen[i]) { if (z === "{") tiefe++; else if (z === "}") tiefe--; }
    if (tiefe === 0 && i > offen.von) { bereiche.push({ ...offen, bis: i }); offen = null; }
  }
}
const inKomponente = (i) => bereiche.some((b) => i >= b.von && i <= b.bis);

const funde = new Map();
const merken = (text, zeile, art) => {
  const sauber = text.trim();
  if (!sauber || AUSNAHMEN.has(sauber)) return;
  if (!/^[A-ZÄÖÜ]/.test(sauber)) return;         // Beschriftungen fangen gross an
  if (/^[A-Z0-9_]+$/.test(sauber)) return;       // Konstanten wie ISO, PNG
  if (!/[a-zäöüß]/.test(sauber)) return;         // reine Abkuerzungen
  if (/^https?:|^\/|^#|^data:/.test(sauber)) return;
  if (!funde.has(sauber)) funde.set(sauber, { zeilen: [], art });
  funde.get(sauber).zeilen.push(zeile + 1);
};

/* Kommentare ueberspringen - und zwar richtig.
 *
 * "Zeile faengt mit * an" reicht in dieser Datei nicht: Die Erklaerbloecke
 * sind so gesetzt, dass die Folgezeilen eingerueckter Fliesstext sind, ohne
 * Sternchen. Der Pruefer hat deshalb Saetze aus Kommentaren als fehlende
 * Uebersetzung gemeldet - "Rendered more hooks than during the previous
 * render" zum Beispiel, was ausgerechnet eine englische Fehlermeldung von
 * React ist, die jemand aufgeschrieben hat. Also wird der Zustand
 * mitgefuehrt: Ab /* bis zum passenden Ende ist alles Kommentar. */
let imBlock = false;
for (let i = 0; i < zeilen.length; i++) {
  const roh = zeilen[i], s = roh.trim();
  const beginnt = roh.lastIndexOf("/" + "*");
  const endet = roh.lastIndexOf("*" + "/");
  const warImBlock = imBlock;
  if (!imBlock && beginnt >= 0 && endet < beginnt) imBlock = true;
  else if (imBlock && endet >= 0) imBlock = false;
  if (warImBlock || imBlock) continue;
  if (s.startsWith("//") || s.startsWith("*") || s.startsWith("/" + "*")) continue;

  /* JSX-Text und Attribute - gelten ueberall, auch ausserhalb von Komponenten
     kann so etwas nicht stehen, also ist die Einschraenkung hier unnoetig. */
  for (const [, text] of roh.matchAll(/>([A-ZÄÖÜ][^<>{}\n]{2,80})</g)) merken(text, i, "JSX");
  for (const [, text] of roh.matchAll(/placeholder="([^"]{3,80})"/g)) merken(text, i, "Platzhalter");
  for (const [, text] of roh.matchAll(/aria-label="([^"]{3,80})"/g)) merken(text, i, "Vorlesehilfe");

  /* Zeichenketten im Code. Nur in Komponenten - ausserhalb gibt es kein t().
     Und nicht dort, wo die Zeichenkette ein Datenwert ist. */
  if (!inKomponente(i)) continue;
  if (/\.(insert|update|upsert|eq|match|is|neq)\s*\(/.test(roh)) continue;
  for (const treffer of roh.matchAll(/(.{0,6})"([A-ZÄÖÜ][^"\\\n]{2,80})"/g)) {
    const davor = treffer[1];
    if (/[=!]==?\s*$/.test(davor)) continue;   // ein Vergleich
    if (/case\s+$/.test(davor)) continue;      // switch
    if (/=$/.test(davor)) continue;            // JSX-Attribut
    if (/[A-Za-z0-9_$]$/.test(davor)) continue;
    merken(treffer[2], i, "Zeichenkette");
  }
}

/* Zweite Frage, und die wichtigere:
 * Gibt es zu JEDEM benutzten Schluessel auch in JEDER Sprache einen Eintrag?
 *
 * Der Teil oben findet nur deutschen Text, der noch fest im Code steht. Er
 * sagt nichts darueber, ob t("tm.keineAthleten") auf Tuerkisch etwas
 * zurueckgibt. Faellt ein Schluessel durch, liefert uebersetze() das
 * deutsche Wort - unauffaellig, aber falsch. */
const woerterbuch = readFileSync("lib/sprachen.ts", "utf8");
const SPRACHCODES = ["de", "en", "es", "pt", "it", "tr", "fr"];
const lies = (code) => {
  const block = woerterbuch.match(new RegExp(`const ${code}: Woerterbuch = \\{([\\s\\S]*?)\\n\\};`));
  const eintraege = new Map();
  if (!block) return eintraege;
  for (const [, k, v] of block[1].matchAll(/^\s*"([a-zA-Z0-9._]+)":\s*("(?:[^"\\]|\\.)*")/gm)) {
    eintraege.set(k, JSON.parse(v));
  }
  return eintraege;
};
const buecher = Object.fromEntries(SPRACHCODES.map((c) => [c, lies(c)]));
const benutzteSchluessel = new Set([...quelle.matchAll(/\bt\("([a-zA-Z0-9._]+)"\)/g)].map((m) => m[1]));
const luecken = [];
for (const code of SPRACHCODES) {
  for (const schluessel of benutzteSchluessel) {
    if (!buecher[code].has(schluessel)) luecken.push(`${code}: ${schluessel}`);
  }
}
console.log(`  ${benutzteSchluessel.size} Schluessel in Gebrauch, ${buecher.de.size} im Woerterbuch`);
console.log(`  ${luecken.length} Luecken in den sieben Sprachen`);
if (luecken.length) luecken.slice(0, 20).forEach((l) => console.log(`  ! ${l}`));

/* Und: Steht in einer Fremdsprache einfach der deutsche Satz?
   Einzelne Woerter duerfen gleich sein - "Chat" heisst ueberall Chat.
   Ein Satz mit Umlaut ist dagegen sicher nicht uebersetzt worden. */
const undurchgereicht = [];
for (const code of SPRACHCODES.slice(1)) {
  for (const [schluessel, deutsch] of buecher.de) {
    if (buecher[code].get(schluessel) === deutsch && /[äöüßÄÖÜ]/.test(deutsch)) {
      undurchgereicht.push(`${code}: ${schluessel} = "${deutsch}"`);
    }
  }
}
console.log(`  ${undurchgereicht.length} Eintraege stehen unveraendert auf Deutsch`);
undurchgereicht.slice(0, 20).forEach((l) => console.log(`  ! ${l}`));

/* Dritte Frage: Steht ein t()-Aufruf an einer Stelle, an der es t noch gar
 * nicht gibt?
 *
 * Vorgabewerte von Parametern werden ausgewertet, BEVOR der Funktionsrumpf
 * laeuft. Steht dort t("..."), wirft der Aufruf sofort - und zwar nur zur
 * Laufzeit, nur beim Rendern, und nur wenn der Aufrufer den Parameter
 * weglaesst. Der Build sagt nichts, ESLint sagt nichts.
 *
 * Das ist heute zweimal passiert. Beim zweiten Mal traf es ProfileUnderlay:
 *   function ProfileUnderlay({ title, eyebrow = t("pf.einstellungen2"), ... }) {
 *     const t = useT();
 * Profil > Benachrichtigungen ist die einzige Ansicht, die ProfileUnderlay
 * ohne eigenes eyebrow benutzt - sie stuerzte beim Oeffnen ab, alle anderen
 * Unterseiten liefen. So etwas findet man nicht durch Nachdenken. */
const zuFrueh = [];
for (let i = 0; i < zeilen.length; i++) {
  const s = zeilen[i];
  if (!/^\s*(export default )?(function|const)\s/.test(s)) continue;
  if (!/=\s*t\("/.test(s)) continue;
  zuFrueh.push(`Zeile ${i + 1}: ${s.trim().slice(0, 120)}`);
}
console.log(`  ${zuFrueh.length} t()-Aufrufe im Funktionskopf (dort gibt es t noch nicht)`);
zuFrueh.forEach((l) => console.log(`  ! ${l}`));

const uebersetzt = (quelle.match(/\bt\("[a-z]+\.[A-Za-z0-9_.]+"\)/g) || []).length;
console.log(`  ${uebersetzt} uebersetzte Aufrufe`);
console.log(`  ${funde.size} verdaechtige Texte (${AUSNAHMEN.size} bekannte Ausnahmen ausgenommen)`);

if (funde.size > 0 && zeigeListe) {
  for (const [text, info] of [...funde].sort()) {
    console.log(`  ${info.art.padEnd(13)} Zeile ${info.zeilen.join(", ")}: ${text}`);
  }
} else if (funde.size > 0) {
  console.log("  (mit 'liste' als Argument einzeln anzeigen)");
}

process.exit(funde.size === 0 && luecken.length === 0 && undurchgereicht.length === 0 && zuFrueh.length === 0 ? 0 : 1);
