/* Spielergebnisse: Heim : Gast in der Anzeige, wir : Gegner im Speicher.
 *
 * Betreiberentscheidung vom 13.09.2026: Ueberall, wo ein Ergebnis oder ein
 * Tipp gezeigt oder eingegeben wird, steht es als Heim : Gast - so, wie es auf
 * jeder Anzeigetafel und in jedem Spielbericht steht.
 *
 * GESPEICHERT wird weiter wir : Gegner, und zwar unabhaengig vom Spielort:
 *   event_results.heim      = unsere Tore,  event_results.auswaerts = die des Gegners
 *   predictions.home_score  = unsere Tore,  predictions.away_score  = die des Gegners
 * In der App heisst diese Form wg = { home: unsere, away: Gegner } (siehe den
 * Lader in app/page.tsx). Die Spaltennamen fuehren in die Irre, die Bedeutung
 * aber haengt nicht am Spielort. Deshalb bleibt ein Ergebnis richtig, wenn
 * jemand nachtraeglich Heim und Auswaerts am Termin tauscht, und die Punkte
 * im Tippspiel vergleichen immer Gleiches mit Gleichem.
 *
 * Umgerechnet wird NUR hier. Und nur fuer die Anzeige: Jedes Eingabefeld
 * haengt ueber feldSchluessel(ort) direkt an seinem Speicherschluessel.
 * Entwuerfe und Schreibvorgaenge rechnen also nie um - die Gefahr, dass nur
 * eine Seite gedreht wird (ein Heim:Gast-Tipp gegen ein wir:Gegner-Ergebnis),
 * entsteht so gar nicht erst.
 *
 * Reines JavaScript ohne React und ohne Supabase, damit die Tests es direkt
 * mit "node --test" laden koennen (tests/ergebnis.test.mjs).
 */
import { memberTrainerTeams, memberCaptainTeams, memberManagedTeams } from "./mannschaften.mjs";
import { nachRangSortiert } from "./mannschaftsrang.mjs";

/* ------------------------------------------------------------------ */
/* Spielort                                                             */
/* ------------------------------------------------------------------ */
/* 'heim', 'auswaerts' oder null. Liest alle drei Formen, in denen der Ort
   in der App vorkommt: ort (Begegnungen aus tippBegegnungen), home (Termine
   aus dem Lader: true/false/undefined) und home_away (die Datenbankspalte).
   Bewusst KEIN Rueckfall auf "heim": Ein Termin ohne Ort ist kein Heimspiel,
   sonst stuende bei einem Auswaertsspiel ohne Angabe der Gegner als Gast da. */
export function spielOrt(x) {
  if (!x) return null;
  if (x.ort === "heim" || x.ort === "auswaerts") return x.ort;
  if (x.home === true) return "heim";
  if (x.home === false) return "auswaerts";
  if (x.home_away === "heim" || x.home_away === "auswaerts") return x.home_away;
  return null;
}

/* ------------------------------------------------------------------ */
/* Umrechnung                                                           */
/* ------------------------------------------------------------------ */
/* Die EINZIGE Umrechnung fuer die Anzeige. Auswaerts stehen die Gastgeber
   links, also der Gegner. Ohne bekannten Ort bleibt es bei wir : Gegner.
   Die Werte gehen unveraendert durch - "" bleibt "". */
export function zuHeimGast(wg, ort) {
  const w = wg || {};
  return ort === "auswaerts"
    ? { heim: w.away, gast: w.home }
    : { heim: w.home, gast: w.away };
}

/* Die Umkehrung. Nur fuer die Tests (Hin- und Rueckweg) - kein Schreibweg
   benutzt sie, siehe feldSchluessel. */
export function ausHeimGast(hg, ort) {
  const h = hg || {};
  return ort === "auswaerts"
    ? { home: h.gast, away: h.heim }
    : { home: h.heim, away: h.gast };
}

/* Welcher Speicherschluessel links und welcher rechts steht. Links ist
   immer Heim. Jedes Eingabefeld bindet ueber diese Zuordnung direkt an
   home/away im Entwurf - so wird beim Tippen nichts umgerechnet. */
export function feldSchluessel(ort) {
  return ort === "auswaerts"
    ? { links: "away", rechts: "home" }
    : { links: "home", rechts: "away" };
}

/* Beide Seiten einer Begegnung, fertig zum Beschriften.
   rolle ist 'heim'/'gast' - oder 'wir'/'gegner', wenn am Termin kein Ort
   steht; dann waere "Heim" geraten. */
export function seitenFuer(ort, { wir = "", gegner = "" } = {}) {
  const schluessel = feldSchluessel(ort);
  const ortBekannt = ort === "heim" || ort === "auswaerts";
  const name = (key) => (key === "home" ? wir : gegner);
  return {
    links: { schluessel: schluessel.links, name: name(schluessel.links), rolle: ortBekannt ? "heim" : "wir" },
    rechts: { schluessel: schluessel.rechts, name: name(schluessel.rechts), rolle: ortBekannt ? "gast" : "gegner" },
    ortBekannt,
  };
}

const leer = (v) => v === "" || v === null || v === undefined;

/* "H:G" zum Anzeigen, oder "" solange eine Seite fehlt. */
export function stand(wg, ort) {
  if (!wg || leer(wg.home) || leer(wg.away)) return "";
  const { heim, gast } = zuHeimGast(wg, ort);
  return `${heim}:${gast}`;
}

/* Sieg, Remis oder Niederlage aus UNSERER Sicht. Vergleicht unsere Tore mit
   denen des Gegners - der Spielort spielt dafuer keine Rolle. */
export function ausgang(wg) {
  if (!wg || leer(wg.home) || leer(wg.away)) return null;
  const wir = Number(wg.home);
  const gegner = Number(wg.away);
  if (!Number.isFinite(wir) || !Number.isFinite(gegner)) return null;
  return wir > gegner ? "sieg" : wir === gegner ? "remis" : "niederlage";
}

/* ------------------------------------------------------------------ */
/* Tippspiel-Punkte                                                     */
/* ------------------------------------------------------------------ */
/* Unveraendert aus predictionPoints in app/page.tsx. Tipp und Ergebnis
   kommen BEIDE in der gespeicherten Form wir : Gegner - nie umgerechnet.
   Exakt 3 Punkte, richtige Tendenz 1 Punkt. */
export function tippPunkte(prediction, result) {
  if (!prediction || !result || prediction.home === "" || prediction.away === "") return 0;
  const predictedHome = Number(prediction.home);
  const predictedAway = Number(prediction.away);
  const actualHome = Number(result.home);
  const actualAway = Number(result.away);
  if (predictedHome === actualHome && predictedAway === actualAway) return 3;
  const tendency = (home, away) => home === away ? 0 : home > away ? 1 : -1;
  return tendency(predictedHome, predictedAway) === tendency(actualHome, actualAway) ? 1 : 0;
}

/* ------------------------------------------------------------------ */
/* Pruefung                                                             */
/* ------------------------------------------------------------------ */
/* Stand: ganze Zahl von 0 bis 999, als Zahl oder als Text aus dem Feld.
   Drei Stellen, weil Punktsportarten (Basketball) ueber 99 kommen (U7).
   Dieselbe Grenze wie ergebnis_pruefgrund und die CHECKs in der Datenbank
   (20260914100000, 20260914110600). */
export function toreGueltig(v) {
  if (typeof v === "number") return Number.isInteger(v) && v >= 0 && v <= 999;
  if (typeof v === "string") return /^\d{1,3}$/.test(v.trim());
  return false;
}
export function ergebnisGueltig(wg) {
  return !!wg && toreGueltig(wg.home) && toreGueltig(wg.away);
}

/* ------------------------------------------------------------------ */
/* Recht zum Eintragen                                                  */
/* ------------------------------------------------------------------ */
/* Betreiberentscheidung vom 13.09.2026, Punkt 3. Spiegelt
   darf_ergebnis_eintragen_fuer und ergebnis_pruefgrund aus der Migration
   20260914100000 - die Datenbank entscheidet, das hier blendet nur die
   Knoepfe aus, die dort ohnehin abgelehnt wuerden.
     - Nur Spiele, nicht abgesagt, mit Ort, ab Anpfiff.
     - Vereinsadmin, Sysadmin und Organisation: jedes Spiel.
     - Trainer, Kapitaen, Teammanager: nur Spiele ihrer Mannschaft. Es zaehlen
       die Listen aus team_members (trainerTeams, captainTeams, managedTeams),
       wie in der Datenbank - die Vereinsrolle "trainer" allein reicht nicht.
   streng = false nur im Demo-Betrieb ohne Datenbank: Dort stehen die Rollen
   oft nur global am Mitglied, deshalb gelten die Rueckfaelle aus
   mannschaften.mjs. */
const VEREINSWEIT = ["vereinsadmin", "sysadmin", "organisator"];

export function darfErgebnisEintragen(user, ev, { jetzt = new Date(), streng = true } = {}) {
  if (!user || !ev) return false;
  if (ev.type !== "spiel") return false;
  if (ev.cancelled === true || ev.status === "cancelled") return false;
  if (spielOrt(ev) === null) return false;
  const anpfiff = new Date(ev.date);
  if (!ev.date || Number.isNaN(anpfiff.getTime()) || anpfiff > jetzt) return false;
  if ((user.roles || []).some((r) => VEREINSWEIT.includes(r))) return true;
  if (!ev.team) return false;
  const teams = streng
    ? [...(user.trainerTeams || []), ...(user.captainTeams || []), ...(user.managedTeams || [])]
    : [...memberTrainerTeams(user), ...memberCaptainTeams(user), ...memberManagedTeams(user)];
  return teams.includes(ev.team);
}

/* Fehler beim Schreiben -> Textschluessel. Die Datenbank schickt den Grund
   als HINT (ergebnis_pruefgrund), der schon ein App-Schluessel ist.
   42501 = Regel hat abgelehnt, 23514 = CHECK auf den Toren.
   ersatz fuer alles andere - beim Entfernen ein anderer Text als beim
   Speichern. */
export function ergebnisFehlerSchluessel(err, ersatz = "tipp.ergebnisFehler") {
  const hint = typeof err?.hint === "string" ? err.hint : "";
  if (hint.startsWith("erg.fehler.")) return hint;
  if (err?.code === "42501") return "erg.fehler.keinRecht";
  if (err?.code === "23514") return "erg.fehler.bereich";
  return ersatz;
}

/* ------------------------------------------------------------------ */
/* Ergebnisliste                                                        */
/* ------------------------------------------------------------------ */
/* Die Spiele fuer die Ergebnisansicht, nach Mannschaft gegliedert.
     - Nur Spiele, die begonnen haben. Abgesagte fallen weg - auch mit
       Ergebnis (am abgesagten Spiel haengt auf PROD ein verwaistes).
     - Innerhalb der Mannschaft das neueste Spiel zuerst.
     - Mannschaften nach Rang, die Lieblingsmannschaft vorn. Spiele ohne
       Mannschaft kommen in eine vereinsweite Gruppe (team: null) ans Ende.
     - wartet: begonnen, aber noch kein Ergebnis ("Wartet auf Ergebnis").
   Gefiltert wird nicht nach der Person - Fans sehen alle Mannschaften. */
export function ergebnisseJeMannschaft(events, results, { jetzt = new Date(), favorit = "" } = {}) {
  const ergebnisse = results || {};
  const gruppen = new Map();
  for (const ev of events || []) {
    if (ev?.type !== "spiel" || ev.cancelled === true || ev.status === "cancelled") continue;
    const anpfiff = new Date(ev.date);
    if (!ev.date || Number.isNaN(anpfiff.getTime()) || anpfiff > jetzt) continue;
    const ergebnis = ergebnisse[ev.id] || null;
    const team = ev.team || null;
    if (!gruppen.has(team)) gruppen.set(team, []);
    gruppen.get(team).push({ ev, ergebnis, wartet: !ergebnis });
  }
  for (const spiele of gruppen.values()) {
    spiele.sort((a, b) => new Date(b.ev.date) - new Date(a.ev.date));
  }
  const namen = nachRangSortiert([...gruppen.keys()].filter(Boolean));
  const reihenfolge = favorit && namen.includes(favorit)
    ? [favorit, ...namen.filter((n) => n !== favorit)]
    : namen;
  if (gruppen.has(null)) reihenfolge.push(null);
  return reihenfolge.map((team) => ({ team, spiele: gruppen.get(team) }));
}
