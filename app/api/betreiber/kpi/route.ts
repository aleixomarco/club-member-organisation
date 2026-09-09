import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { SITZUNGS_COOKIE, sitzungGueltig } from "@/lib/betreiber";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

/* Die Kennzahlen einer Anzeige, für die Betreiberkonsole.
 *
 * Eigene Route und nicht Teil von /daten: Die Übersicht wird bei jedem
 * Seitenaufruf geladen, die Kennzahlen nur, wenn jemand eine Anzeige auswählt.
 * Zusammengelegt würde jeder Aufruf der Konsole eine Auswertung über die
 * gesamte Statistik anstoßen, die in neunundneunzig von hundert Fällen niemand
 * ansieht.
 *
 * Gerechnet wird in der Datenbank (anzeigen_kennzahlen). Dieselbe Funktion
 * beantwortet auch die Sponsorenansicht in der App - damit dort und hier
 * dieselbe Zahl steht. Zwei Auswertungen mit derselben Überschrift, die
 * verschieden rechnen, sind schlimmer als gar keine. */
export async function GET(request: Request) {
  const cookieSpeicher = await cookies();
  if (!sitzungGueltig(cookieSpeicher.get(SITZUNGS_COOKIE)?.value)) {
    return NextResponse.json({ error: "Nicht angemeldet." }, { status: 401 });
  }

  const adresse = new URL(request.url);
  const anzeige = adresse.searchParams.get("anzeige") || "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(anzeige)) {
    return NextResponse.json({ error: "Keine Anzeige gewählt." }, { status: 400 });
  }
  /* Ein unsinniger Zeitraum wird auf 30 Tage zurückgesetzt statt abgelehnt:
     Der Wert kommt aus einer Auswahlliste, und eine Fehlermeldung dafür wäre
     eine Sackgasse ohne Gewinn. Die Datenbank begrenzt zusätzlich. */
  const roh = Number(adresse.searchParams.get("tage"));
  const tage = Number.isFinite(roh) && roh >= 1 && roh <= 730 ? Math.round(roh) : 30;

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  const { data, error } = await admin.rpc("anzeigen_kennzahlen", { ziel: anzeige, tage });
  if (error) {
    console.error("Kennzahlen einer Anzeige konnten nicht geladen werden", error);
    return NextResponse.json({ error: "Die Kennzahlen konnten nicht geladen werden." }, { status: 500 });
  }

  return NextResponse.json({ kennzahlen: data ?? null });
}
