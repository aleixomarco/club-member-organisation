import { NextResponse } from "next/server";
import {
  SITZUNGS_COOKIE, SITZUNGSDAUER_SEKUNDEN, cookieOptionen, konfigurationsFehler,
  passwortStimmt, sitzungErzeugen, versuchVermerken, zuVieleVersuche,
} from "@/lib/betreiber";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const fehlt = konfigurationsFehler();
  if (fehlt) {
    /* Ohne gesetztes Passwort gibt es keinen Zugang - und zwar keinen mit
       irgendeinem Passwort, nicht bloss keinen mit dem falschen.

       Der genaue Grund steht mit dabei. "Nicht eingerichtet" waere zwar
       wortkarger, aber wer die Variablen gerade gesetzt hat und trotzdem diese
       Meldung liest, sucht sonst an der falschen Stelle - naemlich beim Deploy,
       obwohl in Wahrheit das Passwort zwei Zeichen zu kurz ist. Verraten wird
       damit nichts, was hilft: Ohne das Passwort kommt hier ohnehin niemand
       hinein, und dass die Konsole existiert, sieht man an der Seite selbst. */
    return NextResponse.json({ error: `Der Betreiberzugang ist nicht eingerichtet. ${fehlt}` }, { status: 503 });
  }

  const kennung = request.headers.get("x-forwarded-for")?.split(",")[0].trim() || "unbekannt";
  if (zuVieleVersuche(kennung)) {
    return NextResponse.json({ error: "Zu viele Versuche. Bitte in einer Viertelstunde noch einmal." }, { status: 429 });
  }

  const daten = await request.json().catch(() => null);
  const stimmt = passwortStimmt((daten as { passwort?: unknown } | null)?.passwort);
  versuchVermerken(kennung, stimmt);

  if (!stimmt) {
    /* Eine kurze Bremse. Sie macht das Durchprobieren spuerbar langsamer, ohne
       jemanden zu stoeren, der sein Passwort kennt. */
    await new Promise((r) => setTimeout(r, 800));
    return NextResponse.json({ error: "Das Passwort stimmt nicht." }, { status: 401 });
  }

  const antwort = NextResponse.json({ ok: true });
  antwort.cookies.set(SITZUNGS_COOKIE, sitzungErzeugen(), cookieOptionen(SITZUNGSDAUER_SEKUNDEN));
  return antwort;
}
