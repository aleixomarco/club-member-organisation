import { NextResponse } from "next/server";

/* Welche Fassung der Weboberflaeche ist gerade veroeffentlicht?
 *
 * Die App vergleicht diese Kennung mit der, die beim Bauen in ihr Buendel
 * geschrieben wurde (NEXT_PUBLIC_BUILD_ID, siehe next.config.ts). Weichen
 * sie ab, laeuft sie auf altem Code.
 *
 * WARUM DAS UEBERHAUPT NOETIG IST
 * Die App laedt ihren Code beim Start und behaelt ihn. Auf dem Telefon lebt
 * eine App tagelang im Hintergrund, ohne je neu zu laden - und wer in dieser
 * Zeit eine Veroeffentlichung verpasst, merkt nichts davon. Er sieht keine
 * Fehlermeldung, ihm fehlen nur die neuen Sachen. Ein Mitglied hat auf diese
 * Weise eine Abstimmung als blossen Text gesehen: Sein Buendel kannte
 * Abstimmungen noch nicht und zeigte den Fragetext, den die Nachricht
 * zusaetzlich mitfuehrt.
 *
 * BEIDE SEITEN LESEN DIESELBE VARIABLE
 * Hier zur Laufzeit, in next.config.ts beim Bauen. Nur so vergleicht die App
 * Gleiches mit Gleichem. Fehlt sie auf einer der beiden Seiten - beim
 * Entwickeln, oder wenn Vercel die Systemvariablen nicht freigibt -, bleibt
 * der Wert leer und die App schweigt. Ein falscher Hinweis ("neue Version!",
 * obwohl es keine gibt) waere schlimmer als gar keiner: Beim ersten Mal laedt
 * man neu, beim zweiten Mal glaubt man ihm nicht mehr.
 */

export const dynamic = "force-dynamic";
export const revalidate = 0;

export async function GET() {
  const build = process.env.VERCEL_GIT_COMMIT_SHA || "";
  /* Ausdruecklich nicht zwischenspeichern - weder hier noch unterwegs. Eine
     zwischengespeicherte Antwort waere die alte Kennung, und die Pruefung
     wuerde genau dann schweigen, wenn sie etwas zu sagen haette. */
  return NextResponse.json({ build }, {
    headers: { "Cache-Control": "no-store, max-age=0" },
  });
}
