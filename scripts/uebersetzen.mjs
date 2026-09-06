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
  "Nächstes Spiel": "home.naechstesSpiel",
  "Nächstes Training": "home.naechstesTraining",
  "Angemeldet bleiben": "login.bleiben",
  "Passwort vergessen?": "login.vergessen",
  "Zum Login": "reg.jetztAnmelden",
  "Konto erstellen": "reg.titel",
  "Fast geschafft": "reg.fastGeschafft",
  "Ich registriere mich als": "reg.alsWas",
  "Ich akzeptiere die": "reg.akzeptiere",
  "Datenschutzerklärung": "recht.datenschutzerklaerung",
  "Alle Mitglieder": "mit.alle",
  "Tippe, um abzustimmen": "umf.tippen",
  "Jetzt eintragen": "allg.jetztEintragen",
  "Alle ansehen": "allg.alleAnsehen",
  "Noch keine News.": "news.keine",
  "Liste wird geladen …": "allg.listeLaedt",
  "Noch niemand eingetragen": "helf.niemand",
  "Jemanden eintragen": "helf.jemanden",
  "Mitfahren": "fahr.mitfahren",
  "Fahrgemeinschaft löschen": "fahr.loeschen",
  "Platz anbieten": "fahr.anbieten",
  "Helfer:innen gesucht": "helf.gesucht",
  "Termin eintragen": "ev.eintragen",
  "Training": "ev.training",
  "Spiel": "ev.spiel",
  "Vereins-Event": "ev.vereinsevent",
  "Heimspiel": "ev.heimspiel",
  "Wiederholend": "ev.wiederholend",
  "Alle Mannschaften": "ev.alleTeams",
  "Nur diesen Termin": "ev.nurDiesen",
  "Ganze Reihe löschen": "ev.ganzeReihe",
  "Diesen Termin wirklich löschen?": "ev.wirklichLoeschen",
  "Beitragsart": "bei.art",
  "Mitgliedsbeitrag": "bei.mitglied",
  "Familienbeitrag": "bei.familie",
  "Weitere Vereinsmitglieder": "mit.weitere",
  "Melden": "chat.melden",
  "Blockieren": "chat.blockieren",
  "Noch kein Chat für dich": "chat.keiner",
  "Für dich ausgeblendet": "chat.ausgeblendet",
  "Noch keine News veröffentlicht.": "news.keineVeroeffentlicht",
  "Bezahlt": "bei.bezahlt",
  "Noch nicht bezahlt": "bei.offen",
  "Noch keine Beitragsdatensätze vorhanden.": "bei.keineDaten",
  "Anzahl der Personen insgesamt": "bei.anzahlPersonen",
  "Weitere Namen ohne Benutzerkonto": "bei.weitereNamen",
  "Mehrere Namen bitte durch Komma trennen.": "bei.kommaHinweis",
  "Familienverknüpfung": "fam.verknuepfung",
  "Rolle in der Verknüpfung": "fam.rolle",
  "Verbinden": "fam.verbinden",
  "Kein passendes Profil gefunden.": "fam.keinProfil",
  "Kind ohne Account vorläufig anlegen": "fam.kindAnlegen",
  "Kapitänsrolle zuweisen": "tm.kapitaenZuweisen",
  "Athlet/in auswählen …": "tm.athletWaehlen",
  "Du bist aktuell keiner Mannschaft zugeordnet.": "tm.keineZuordnung",
  "Neue Mannschaft anlegen": "tm.neuAnlegen",
  "Erwachsenenmannschaft?": "tm.erwachsene",
  "Noch keiner Mannschaft zugeordnet.": "tm.keineZuordnungKurz",
  "Für diese Mannschaft ist derzeit kein Spiel geplant.": "home.keinSpiel",
  "Für diesen Termin ist niemand eingeteilt.": "helf.niemandEingeteilt",
  "Noch keine Fahrgemeinschaft für diesen Termin.": "fahr.keine",
  "Nur diesen Termin oder die ganze Reihe?": "ev.reiheFrage",
  "Heute Geburtstag:": "home.geburtstag",
  "Willkommen zurück,": "home.willkommenKomma",
  "Demo-Zugänge zum Ausprobieren": "login.demo",
  "Vorschlag · Name stimmt überein": "sys.vorschlag",
  "Strafenverwaltung": "straf.verwaltung",
  "Bisherige Strafen": "straf.bisherige",
  "Alle Strafen": "straf.alle",
  "Historie wird geladen …": "straf.historieLaedt",
  "Athlet/in wählen …": "tm.athletWaehlen2",
  "Ändern": "allg.aendern",
  "Datum": "ev.datum",
  "Personen": "feld.personen",
  "Ganzer Verein": "auf.ganzerVerein",
  "Verantwortlich (mehrere möglich)": "auf.verantwortlich",
  "Aufgaben werden geladen …": "auf.laden",
  "Aktuell keine offenen Vereinsaufgaben.": "auf.keine",
  "Ich übernehme das": "auf.uebernehmeIch",
  "Zurückziehen": "auf.zurueckziehen",
  "Noch keine Fahrzeuge hinterlegt.": "fz.keine",
  "Kalender wird geladen …": "fz.kalenderLaedt",
  "Keine Buchungen in diesem Monat.": "fz.keineBuchungen",
  "Private Buchung (keine Mannschaft)": "fz.privat",
  "Mannschaft wählen …": "tm.mannschaftWaehlen",
  "Telefonnummer wird geladen …": "tel.laedt",
  "Keine Telefonnummer hinterlegt.": "tel.keine",
  "Satz vorladen …": "helf.satzVorladen",
  "Stationen an diesem Termin": "helf.stationen",
  "Alle entfernen": "helf.alleEntfernen",
  "Noch keine Sätze angelegt.": "helf.keineSaetze",
  "Satz löschen": "helf.satzLoeschen",
  "Anfrage zurückziehen": "zug.zurueckziehen",
  "Eigene Sponsoren zeigen": "sp.eigene",
  "Vollzugang anfragen": "zug.vollzugang",
  "Kein eigenes Abo nötig": "zug.keinAbo",
  "Keine Mitglieder gefunden.": "mit.keine",
  "Für deine aktuellen Rollen gibt es noch keine Videos.": "vid.keine",
  "Tippe einen Namen an, um die Person wieder anzuzeigen.": "chat.wiederAnzeigen",
  "Anschließend kannst du dich anmelden.": "reg.danach",
  "Ich akzeptiere die": "reg.akzeptiere",
  "Strafen": "straf.titel",
  "Keine aktiven Strafen.": "straf.keineAktiven",
  "Strafen-Historie": "straf.historie",
  "Aufgaben": "auf.titel",
  "Für keine Aufgabe eingetragen.": "auf.keineEingetragen",
  "Fahrgemeinschaften": "fahr.titel",
  "Keine Fahrgemeinschaften.": "fahr.keineKurz",
  "Aktuell keine offenen Beitrittsanfragen.": "mit.keineAnfragen",
  "Vereinsprofil bearbeiten": "verein.profilBearbeiten",
  "Aktiv": "status.aktiv",
  "Ausstehend": "status.ausstehend",
  "Inaktiv": "status.inaktiv",
  "Gesperrt": "status.gesperrt",
  "Athleten-Mannschaften": "tm.athletenTeams",
  "Telefonnummern": "feld.telefonnummern",
  "Geburtstag im Verein anzeigen": "feld.geburtstagZeigen",
  "Weiblich": "gesch.w",
  "Männlich": "gesch.m",
  "Divers": "gesch.d",
  "Keine Angabe": "gesch.k",
  "Push-Benachrichtigungen auf diesem Gerät": "push.aufGeraet",
  "Automatischer Logout": "sich.autoLogout",
  "Nach 30 Tagen": "sich.tage30",
  "Nach 60 Tagen": "sich.tage60",
  "Nach 90 Tagen": "sich.tage90",
  "Vereine werben Vereine": "zug.werben",
  "Code kopieren": "zug.codeKopieren",
  "Termine abonnieren": "kal.abonnieren",
  "Aktualisierung": "kal.aktualisierung",
  "Nie automatisch": "kal.nie",
  "Täglich": "kal.taeglich",
  "Auswahl aufheben — meine Mannschaften verwenden": "kal.auswahlAufheben",
  "Zur Aktion": "sp.zurAktion",
  "Website ansehen": "sp.website",
  "Konto löschen": "pf.kontoLoeschen",
  "Verein anlegen": "verein.anlegen",
  "Wöchentlich · Sonntagabend": "kal.woechentlich",
  "Monatlich": "kal.monatlich",
  "Mit Gerätekalender verbinden": "kal.verbinden",
  "Bedingungen": "recht.bedingungen",
  "Konto und persönliche Daten löschen": "konto.loeschenLang",
  "Abstimmung beendet — Ergebnis final": "sais.beendet",
  "Athlet/in der Saison — Ehrung beim Sommerfest": "sais.ehrung",
  "Tippspiel je Mannschaft": "tipp.jeTeam",
  "Noch niemand in dieser Runde.": "tipp.niemand",
  "Wartet auf Ergebnis": "tipp.wartet",
  "Ergebnisse & Punkte": "tipp.ergebnisse",
  "Keine offenen Aufgaben — sehr gut! 🎉": "prot.keineAufgaben",
  "Neues Protokoll erfassen": "prot.neu",
  "Teilnehmer:innen": "prot.teilnehmer",
  "Protokoll & Aufgaben speichern": "prot.speichern",
  "Bitte Titel und Protokolltext ausfüllen.": "prot.pflicht",
  "Vergangene Protokolle": "prot.vergangene",
  "Automatische Zahlungserinnerungen": "bei.erinnerungen",
  "Aktuell keine offenen Beiträge. 🎉": "bei.keineOffenen",
  "Eigene Sponsoren sind noch nicht freigeschaltet": "sp.nichtFrei",
  "Zu sehen:": "sp.zuSehen",
  "Der Sponsor": "sp.derSponsor",
  "Die Aktion (optional)": "sp.dieAktion",
  "Der Sponsor steht auf dem Platz": "sp.stehtAufPlatz",
  "Sponsor von diesem Platz entfernen": "sp.entfernen",
  "Neue Mitmach-Umfrage": "umf.neu",
  "Mindestens zwei Antwortmöglichkeiten eintragen.": "umf.mindestens",
  "Veröffentlichen": "allg.veroeffentlichen",
  "Mannschaft auswählen …": "tm.mannschaftWaehlen2",
  "Chat-Kanäle": "chat.kanaele",
  "Konten-Übersicht": "sys.konten",
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
  /* EINZEILIGE KOMPONENTEN. Manche stehen komplett in einer Zeile:
     function X({...}) { const [a,b]=useState(); ... }
     Eine Zeile DANACH einzufuegen landet ausserhalb der Funktion - der Haken
     stuende dann auf oberster Ebene, was React verbietet. Genau das ist bei
     SecuritySettings und ReferralSettings passiert; der Linter hat es
     gemeldet ("React Hook cannot be called at the top level").
     Bei einer Zeile, die nach "{" noch Code enthaelt, wird deshalb DIREKT
     hinter der Klammer eingesetzt statt in einer neuen Zeile. */
  const nachKlammer = neuZeilen[ende].slice(neuZeilen[ende].indexOf(") {") + 3).trim();
  if (nachKlammer.length > 0) {
    neuZeilen[ende] = neuZeilen[ende].replace(") {", ") { const t = useT();");
  } else {
    neuZeilen.splice(ende + 1, 0, "  const t = useT();");
  }
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
