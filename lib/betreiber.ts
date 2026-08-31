import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";

/* Zugang zur Betreiber-Oberfläche.
 *
 * Bewusst getrennt vom Vereins-Login. Ein Konto in der App gehört immer zu
 * einem Verein — der Betreiber gehört zu keinem. Bände man seine Rechte an eine
 * Vereinsrolle, bekäme sie jeder Vereinsgründer: `sysadmin` wird beim Anlegen
 * eines Vereins automatisch vergeben und ist deshalb keine Betreiberrolle,
 * sondern die höchste Rolle INNERHALB eines Vereins.
 *
 * Deshalb ein eigener Weg mit einem eigenen Passwort, und die ganze Arbeit
 * passiert auf dem Server: Die Oberfläche im Browser bekommt nie einen
 * Datenbankschlüssel zu sehen, sie fragt nur diesen Server. Der wiederum
 * arbeitet mit dem Dienstschlüssel — genau der Schlüssel, für den
 * verein_freischalten() und verein_sperren() vorgesehen sind.
 *
 * Ohne gesetztes Passwort ist die Oberfläche tot. Das ist Absicht: Eine
 * Betreiberkonsole, die versehentlich ohne Zugangsschutz online geht, wäre
 * schlimmer als gar keine.
 */

const SITZUNGSDAUER_MS = 8 * 60 * 60 * 1000; // acht Stunden
const MINDESTLAENGE = 16;

export function betreiberKonfiguriert(): boolean {
  const passwort = process.env.BETREIBER_PASSWORT;
  const geheimnis = process.env.BETREIBER_SESSION_SECRET;
  return !!passwort && passwort.length >= MINDESTLAENGE && !!geheimnis && geheimnis.length >= 32;
}

/* Warum eine Mindestlänge erzwungen wird: Dieses Passwort schützt jeden Verein
 * in der Datenbank, es wird selten getippt und nie geteilt. Ein kurzes wäre
 * hier kein Kompromiss zwischen Sicherheit und Bequemlichkeit, sondern nur
 * unsicher. */
export function konfigurationsFehler(): string | null {
  const passwort = process.env.BETREIBER_PASSWORT;
  const geheimnis = process.env.BETREIBER_SESSION_SECRET;
  if (!passwort) return "BETREIBER_PASSWORT ist nicht gesetzt.";
  if (passwort.length < MINDESTLAENGE) return `BETREIBER_PASSWORT muss mindestens ${MINDESTLAENGE} Zeichen haben.`;
  if (!geheimnis) return "BETREIBER_SESSION_SECRET ist nicht gesetzt.";
  if (geheimnis.length < 32) return "BETREIBER_SESSION_SECRET muss mindestens 32 Zeichen haben.";
  return null;
}

function gleich(a: string, b: string): boolean {
  /* Zeichenweise vergleichen wäre messbar: Wer die Antwortzeit misst, kann ein
     Passwort Zeichen für Zeichen erraten. Über den Umweg HMAC haben beide
     Seiten immer dieselbe Länge, sonst würde timingSafeEqual selbst schon an
     der Länge scheitern und sie damit verraten. */
  const schluessel = process.env.BETREIBER_SESSION_SECRET || "";
  const ha = createHmac("sha256", schluessel).update(a).digest();
  const hb = createHmac("sha256", schluessel).update(b).digest();
  return timingSafeEqual(ha, hb);
}

export function passwortStimmt(eingabe: unknown): boolean {
  if (typeof eingabe !== "string" || !betreiberKonfiguriert()) return false;
  return gleich(eingabe, process.env.BETREIBER_PASSWORT as string);
}

/* Der Schlüssel, mit dem Sitzungen unterschrieben werden.
 *
 * Er wird aus BEIDEN Angaben abgeleitet, aus dem Sitzungsgeheimnis und aus dem
 * Passwort. Das hat einen konkreten Grund: Bei einem unterschriebenen Cookie
 * ist der Unterschriftsschlüssel selbst ein Zugang — wer ihn hat, kann sich ein
 * gültiges Cookie ausstellen, ohne das Passwort je zu kennen. Solange der
 * Schlüssel ausschließlich auf dem Server liegt, ist das kein Problem. Sobald
 * er einmal woanders auftaucht — in einer Notiz, einem Chatverlauf, einem
 * geteilten Bildschirm —, wäre er es sehr wohl.
 *
 * Aus beidem abgeleitet ist das Geheimnis allein wertlos. Ein Nebeneffekt, den
 * man ohnehin will: Ein geändertes Passwort beendet alle offenen Sitzungen. */
function signierSchluessel(): Buffer {
  return createHmac("sha256", process.env.BETREIBER_SESSION_SECRET as string)
    .update(`sitzung|${process.env.BETREIBER_PASSWORT}`)
    .digest();
}

/* Der Sitzungswert: Ablaufzeitpunkt und Zufall, dazu eine Signatur.
 *
 * Der Zufall sorgt dafür, dass zwei Anmeldungen in derselben Millisekunde nicht
 * denselben Wert bekommen; die Signatur dafür, dass sich der Ablauf nicht von
 * Hand verlängern lässt. Etwas anderes steht nicht darin — es gibt nichts
 * anderes zu wissen, als dass diese Sitzung gültig ist. */
export function sitzungErzeugen(): string {
  const ablauf = Date.now() + SITZUNGSDAUER_MS;
  const zufall = randomBytes(12).toString("hex");
  const nutzlast = `${ablauf}.${zufall}`;
  const signatur = createHmac("sha256", signierSchluessel()).update(nutzlast).digest("hex");
  return `${nutzlast}.${signatur}`;
}

export function sitzungGueltig(wert: unknown): boolean {
  if (typeof wert !== "string" || !betreiberKonfiguriert()) return false;
  const teile = wert.split(".");
  if (teile.length !== 3) return false;
  const [ablauf, zufall, signatur] = teile;
  const erwartet = createHmac("sha256", signierSchluessel())
    .update(`${ablauf}.${zufall}`).digest("hex");
  if (signatur.length !== erwartet.length) return false;
  if (!timingSafeEqual(Buffer.from(signatur), Buffer.from(erwartet))) return false;
  const zeit = Number(ablauf);
  return Number.isFinite(zeit) && zeit > Date.now();
}

export const SITZUNGS_COOKIE = "cmo_betreiber";

export function cookieOptionen(dauerSekunden: number) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/",
    maxAge: dauerSekunden,
  };
}

export const SITZUNGSDAUER_SEKUNDEN = SITZUNGSDAUER_MS / 1000;

/* Ein einfacher Riegel gegen das Durchprobieren.
 *
 * Er liegt im Arbeitsspeicher und gilt deshalb nur je Serverinstanz — auf einer
 * Plattform, die Instanzen nach Bedarf startet, ist das kein vollständiger
 * Schutz. Zusammen mit der Mindestlänge des Passworts reicht es: Sechzehn
 * zufällige Zeichen lassen sich auch ohne Bremse nicht durchprobieren, und die
 * Bremse fängt den lauten, dummen Fall ab. */
const versuche = new Map<string, { anzahl: number; bis: number }>();
const MAX_VERSUCHE = 5;
const SPERRE_MS = 15 * 60 * 1000;

export function zuVieleVersuche(kennung: string): boolean {
  const eintrag = versuche.get(kennung);
  if (!eintrag) return false;
  if (Date.now() > eintrag.bis) { versuche.delete(kennung); return false; }
  return eintrag.anzahl >= MAX_VERSUCHE;
}

export function versuchVermerken(kennung: string, erfolgreich: boolean): void {
  if (erfolgreich) { versuche.delete(kennung); return; }
  const eintrag = versuche.get(kennung);
  if (!eintrag || Date.now() > eintrag.bis) {
    versuche.set(kennung, { anzahl: 1, bis: Date.now() + SPERRE_MS });
    return;
  }
  eintrag.anzahl += 1;
}
