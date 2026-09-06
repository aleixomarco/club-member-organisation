import { NextResponse } from "next/server";

/* Welche Version steht gerade im App Store?
 *
 * WARUM ÜBER DEN EIGENEN SERVER
 * Apple beantwortet diese Frage unter itunes.apple.com/lookup. Direkt aus der
 * App heraus geht das nicht zuverlässig: Die Antwort trägt keine
 * CORS-Freigabe, und in der WKWebView scheitert der Aufruf dann still. Der
 * Umweg über die eigene Route löst das und hat zwei weitere Vorteile — die
 * Antwort lässt sich zwischenspeichern, und wenn Apple einmal nicht antwortet,
 * entscheidet unser Code, was passiert, statt dass die App rät.
 *
 * FEHLER HEISST HIER: NICHTS TUN
 * Diese Auskunft steuert eine Sperre, die den ganzen Bildschirm einnimmt.
 * Wäre sie bei einer Störung "unbekannt = veraltet", würde ein Ausfall bei
 * Apple sämtliche Nutzer aussperren — für ein Problem, das nichts mit ihnen
 * zu tun hat. Deshalb liefert die Route im Zweifel version: null, und die App
 * sperrt dann nicht.
 */

export const dynamic = "force-dynamic";
export const revalidate = 0;

const BUNDLE_ID = "de.idbranding.clubmemberorganisation";

/* Zwischenspeicher im Arbeitsspeicher. Eine neue Version erscheint höchstens
   ein paar Mal im Monat; sie alle fünf Minuten zu erfragen reicht vollkommen
   und hält uns von Apples Ratenbegrenzung fern. */
let zwischenspeicher: { version: string | null; storeUrl: string | null; bis: number } | null = null;
const HALTBARKEIT = 5 * 60 * 1000;

export async function GET() {
  if (zwischenspeicher && Date.now() < zwischenspeicher.bis) {
    return NextResponse.json({ version: zwischenspeicher.version, storeUrl: zwischenspeicher.storeUrl });
  }

  try {
    const antwort = await fetch(
      `https://itunes.apple.com/lookup?bundleId=${BUNDLE_ID}&country=de&t=${Date.now()}`,
      { cache: "no-store", signal: AbortSignal.timeout(5000) },
    );
    if (!antwort.ok) throw new Error(`Apple antwortete mit ${antwort.status}`);

    const inhalt = await antwort.json();
    const eintrag = inhalt?.results?.[0];
    const version = typeof eintrag?.version === "string" ? eintrag.version : null;
    const storeUrl = typeof eintrag?.trackViewUrl === "string" ? eintrag.trackViewUrl : null;

    zwischenspeicher = { version, storeUrl, bis: Date.now() + HALTBARKEIT };
    return NextResponse.json({ version, storeUrl });
  } catch (fehler) {
    console.error("App-Store-Version konnte nicht abgefragt werden", fehler);
    /* Kein Fehlercode: Die App soll das als "weiss ich nicht" lesen und
       weiterlaufen, nicht als Grund, den Bildschirm zu sperren. */
    return NextResponse.json({ version: null, storeUrl: null });
  }
}
