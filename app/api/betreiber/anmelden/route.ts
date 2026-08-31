import { NextResponse } from "next/server";
import {
  SITZUNGS_COOKIE, SITZUNGSDAUER_SEKUNDEN, betreiberKonfiguriert, cookieOptionen,
  passwortStimmt, sitzungErzeugen, versuchVermerken, zuVieleVersuche,
} from "@/lib/betreiber";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  if (!betreiberKonfiguriert()) {
    /* Ohne gesetztes Passwort gibt es keinen Zugang - und zwar keinen mit
       irgendeinem Passwort, nicht bloss keinen mit dem falschen. */
    return NextResponse.json({ error: "Der Betreiberzugang ist nicht eingerichtet." }, { status: 503 });
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
