#!/usr/bin/env node
/* Erzeugt aus der Heft-Quelle die Fassung fuer die App.
 *
 * WOZU
 * Anleitung/quelle/inhalte.json ist die einzige Quelle der Handbuecher. Bisher
 * wurde daraus nur gedruckt. Seit dem 30.09.2026 zeigt die App dieselben
 * Texte auch selbst - gefiltert nach der Rolle, mit einem Knopf, der dorthin
 * springt, wo der Abschnitt hingehoert.
 *
 * WARUM NICHT DIE PDFs EINBINDEN
 * Die dreizehn Hefte sind zusammen 68 MB - fast ausschliesslich Screenshots.
 * Der Text dahinter ist 72 KB. Und Screenshots braucht die App gar nicht: Der
 * Nutzer IST ja schon drin. Papier muss ihm zeigen, wo der Knopf sitzt; die
 * App kann ihn hinbringen.
 *
 * WARUM EIN KAPITEL JE DATEI
 * Damit die App nur laedt, was die Rolle sehen darf. Ein Mitglied bekommt
 * fuenfzehn Abschnitte, nicht dreiundachtzig. Dasselbe Vorgehen wie bei den
 * Woerterbuechern seit dem 28.09.
 *
 * DIE SPRUNGZIELE entstehen aus dem Feld "wo" - "Untere Leiste > Support >
 * Helferdienste" wird zu { tab: "support" }. Gesucht wird das ZUERST genannte
 * Schlagwort, nicht das wichtigste: Steht in einem Abschnitt "Reiter Termine,
 * Reiter Redaktion, Reiter Verwaltung", ist der Termin-Reiter gemeint, und
 * die anderen beiden sind Nebensatz. Findet sich keines, gibt es keinen Knopf
 * - ein Sprung, der woanders landet, ist schlechter als keiner.
 *
 * AUFRUF: node scripts/handbuch-bauen.mjs
 * Danach liegen die Dateien in lib/handbuch/. Sie gehoeren in die
 * Versionsverwaltung, damit der Bau ohne diesen Schritt durchlaeuft.
 */
import { readFileSync, writeFileSync, mkdirSync, readdirSync, unlinkSync } from "node:fs";
import { join } from "node:path";

const QUELLE = "Anleitung/quelle/inhalte.json";
const ZIEL = "lib/handbuch";

/* Schlagwort -> Reiter der unteren Leiste. "Sponsoren" ist kein eigener
   Reiter: Fuer die Sponsorenbetreuung heisst der Verwaltungs-Reiter so
   (app/page.tsx, tabs). */
const REITER = [
  ["Verwaltung", "admin"],
  ["Sponsoren", "admin"],
  ["Redaktion", "redaktion"],
  ["Support", "support"],
  ["Teams", "teams"],
  ["Mannschaft", "teams"],
  ["Chat", "chat"],
  ["Termin", "events"],
  ["Profil", "profile"],
  ["Home", "home"],
  ["Startseite", "home"],
];

/* Wege, die nirgendwohin in der App fuehren. Die Betreiber-Konsole ist eine
   eigene Seite, und Saetze wie "Faellt auf, sobald man danach sucht"
   beschreiben keinen Ort. */
const KEIN_SPRUNG = [/betreiber/i, /Vereine/, /Werbeanzeigen/, /Faellt auf/i, /Fällt auf/,
                     /Ergibt sich/, /Dieselben Wege/];
/* "Dein Kind registriert sich selbst; danach Reiter Verwaltung" stand hier
   zunaechst auch auf der Ausschlussliste - zu Unrecht: Der Satz beschreibt
   sehr wohl ein Ziel, es steht nur hinten. Die Regel "das zuerst genannte
   Schlagwort gewinnt" findet es von allein. */

function sprungZiel(wo, kapitel) {
  if (kapitel === "betreiber") return null;
  const text = String(wo || "");
  if (!text || KEIN_SPRUNG.some((r) => r.test(text))) return null;
  /* Das zuerst genannte Schlagwort gewinnt - siehe Kopf. */
  let treffer = null;
  for (const [wort, tab] of REITER) {
    const pos = text.indexOf(wort);
    if (pos >= 0 && (treffer === null || pos < treffer.pos)) treffer = { pos, tab };
  }
  return treffer ? { tab: treffer.tab } : null;
}

const alle = JSON.parse(readFileSync(QUELLE, "utf8"));
mkdirSync(ZIEL, { recursive: true });

/* Alte Kapitel wegraeumen: Wird eines aus inhalte.json entfernt, bliebe es
   sonst als Karteileiche liegen und die App zeigte es weiter. */
for (const datei of readdirSync(ZIEL)) {
  if (datei.endsWith(".ts") && datei !== "index.ts") unlinkSync(join(ZIEL, datei));
}

const KOPF = (key) => `/* Handbuch-Kapitel "${key}" - ERZEUGT, nicht von Hand pflegen.
 *
 * Quelle ist Anleitung/quelle/inhalte.json, erzeugt von
 * scripts/handbuch-bauen.mjs. Wer hier etwas aendert, verliert es beim
 * naechsten Lauf. Die Texte gehoeren in die Quelle - dann aendern sich
 * Heft UND App zugleich.
 *
 * Nur auf Deutsch. Die App kann sieben Sprachen, die Hefte nicht; das
 * Uebersetzen der dreiundachtzig Abschnitte steht noch aus und ist bewusst
 * nicht nebenbei geschehen. */
`;

let abschnitteGesamt = 0;
let mitSprung = 0;
const inhalt = [];

for (const kapitel of alle) {
  const abschnitte = kapitel.abschnitte.map((a) => {
    const sprung = sprungZiel(a.wo, kapitel.key);
    if (sprung) mitSprung += 1;
    abschnitteGesamt += 1;
    return {
      titel: a.titel,
      wo: a.wo,
      punkte: a.punkte || [],
      hinweis: a.hinweis || "",
      ...(sprung ? { sprung } : {}),
    };
  });

  writeFileSync(join(ZIEL, `${kapitel.key}.ts`),
    KOPF(kapitel.key) +
    `const abschnitte = ${JSON.stringify(abschnitte, null, 1)} as const;\n\nexport default abschnitte;\n`);

  inhalt.push({ key: kapitel.key, rolle: kapitel.rolle, einleitung: kapitel.einleitung, anzahl: abschnitte.length });
  console.log(`  ${kapitel.key.padEnd(14)} ${String(abschnitte.length).padStart(2)} Abschnitte`);
}

writeFileSync(join(ZIEL, "index.ts"),
`/* Verzeichnis der Handbuch-Kapitel - ERZEUGT von scripts/handbuch-bauen.mjs.
 *
 * Hier stehen nur Titel, Einleitung und Umfang. WER welches Kapitel sehen
 * darf, entscheidet die App (HANDBUCH_KAPITEL in app/page.tsx) - das haengt
 * an den Rollen des angemeldeten Nutzers und hat in einer erzeugten Datei
 * nichts zu suchen. */
export type HandbuchAbschnitt = {
  titel: string; wo: string; punkte: readonly string[]; hinweis: string;
  sprung?: { tab: string };
};

export const KAPITEL = ${JSON.stringify(inhalt, null, 1)} as const;

const LADER: Record<string, () => Promise<{ default: readonly HandbuchAbschnitt[] }>> = {
${inhalt.map((k) => `  ${k.key}: () => import("./${k.key}"),`).join("\n")}
};

const GELADEN: Record<string, readonly HandbuchAbschnitt[]> = {};

/* Laedt ein Kapitel nach. Gibt null zurueck, wenn es das Kapitel nicht gibt
   oder das Laden scheitert - dann zeigt die App den Abschnitt eben nicht,
   statt abzustuerzen. */
export async function kapitelLaden(key: string): Promise<readonly HandbuchAbschnitt[] | null> {
  if (GELADEN[key]) return GELADEN[key];
  const lader = LADER[key];
  if (!lader) return null;
  try {
    GELADEN[key] = (await lader()).default as readonly HandbuchAbschnitt[];
    return GELADEN[key];
  } catch {
    return null;
  }
}
`);

console.log(`\n${alle.length} Kapitel, ${abschnitteGesamt} Abschnitte, davon ${mitSprung} mit Sprungziel.`);

/* Warnung vor dem stillen Ausfall.
 *
 * Welches Kapitel WER sieht, steht in HANDBUCH_RECHTE in app/page.tsx - und
 * muss dort stehen, denn es haengt an Rollen und Rechtepruefungen, die eine
 * erzeugte Datei nicht kennt. Der Preis dafuer: Wer ein Kapitel in
 * inhalte.json ergaenzt und die Regel vergisst, bekommt keine Fehlermeldung.
 * Die Datei entsteht, der Bau laeuft durch, das Kapitel erscheint nur nie -
 * und niemand sucht danach, weil nichts kaputt aussieht.
 *
 * "betreiber" ist die eine gewollte Ausnahme: Das ist die Konsole unter
 * /betreiber, eine andere Anwendung. */
const OHNE_REGEL_GEWOLLT = ["betreiber"];
try {
  const seite = readFileSync("app/page.tsx", "utf8");
  const block = seite.split("const HANDBUCH_RECHTE = {")[1]?.split("};")[0] || "";
  const regeln = [...block.matchAll(/^\s*([a-z]+)\s*:/gm)].map((m) => m[1]);
  const fehlend = inhalt.map((k) => k.key)
    .filter((k) => !regeln.includes(k) && !OHNE_REGEL_GEWOLLT.includes(k));
  const tot = regeln.filter((r) => !inhalt.some((k) => k.key === r));
  if (fehlend.length) console.log(`\n  ACHTUNG: ohne Regel in HANDBUCH_RECHTE, erscheint niemandem: ${fehlend.join(", ")}`);
  if (tot.length) console.log(`\n  ACHTUNG: Regel ohne Kapitel, wirkungslos: ${tot.join(", ")}`);
  if (!fehlend.length && !tot.length) console.log("  Jedes Kapitel hat seine Regel in app/page.tsx.");
} catch {
  console.log("  (app/page.tsx nicht lesbar - Abgleich der Rechte uebersprungen)");
}
