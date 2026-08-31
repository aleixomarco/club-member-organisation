import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { SITZUNGS_COOKIE, sitzungGueltig } from "@/lib/betreiber";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

/* Alles, was die Betreiber-Oberfläche anzeigt — in einer Antwort.
 *
 * Die Abfrage läuft hier auf dem Server mit dem Dienstschlüssel. Der Browser
 * bekommt nur das fertige Ergebnis; einen Datenbankschlüssel sieht er nie. Das
 * ist der ganze Grund, warum diese Oberfläche über eigene Routen läuft und
 * nicht direkt mit Supabase spricht wie die App. */
export async function GET() {
  const cookieSpeicher = await cookies();
  if (!sitzungGueltig(cookieSpeicher.get(SITZUNGS_COOKIE)?.value)) {
    return NextResponse.json({ error: "Nicht angemeldet." }, { status: 401 });
  }

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  const [vereine, anfragen, anzeigen] = await Promise.all([
    admin.from("betreiber_uebersicht").select("*").order("name"),
    admin.from("offene_freischaltungen").select("*"),
    /* Die eigenen Werbeplaetze: club_id null heisst "gilt in jedem Verein".
       Sie liessen sich bisher nur von Hand im SQL-Editor anlegen. */
    admin.from("anzeigen").select("id,platz,titel,text,ziel_url,aktion_titel,aktion_bis,laeuft_bis,aktiv,impressionen,klicks")
      .is("club_id", null).order("platz"),
  ]);

  if (vereine.error || anfragen.error || anzeigen.error) {
    console.error("Betreiberübersicht konnte nicht geladen werden", vereine.error || anfragen.error || anzeigen.error);
    return NextResponse.json({ error: "Die Übersicht konnte nicht geladen werden." }, { status: 500 });
  }

  return NextResponse.json({
    vereine: vereine.data || [],
    anfragen: anfragen.data || [],
    anzeigen: anzeigen.data || [],
  });
}
