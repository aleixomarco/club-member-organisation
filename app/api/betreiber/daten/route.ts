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

  const [vereine, anfragen, anzeigen, sponsoren, kennzahlen] = await Promise.all([
    admin.from("betreiber_uebersicht").select("*").order("name"),
    admin.from("offene_freischaltungen").select("*"),
    /* Die eigenen Werbeplaetze: club_id null heisst "gilt in jedem Verein".
       Sie liessen sich bisher nur von Hand im SQL-Editor anlegen. */
    admin.from("anzeigen").select("id,platz,titel,text,ziel_url,telefon,email,aktion_titel,aktion_bis,laeuft_bis,aktiv,impressionen,klicks")
      .is("club_id", null).order("platz"),
    /* Die Sponsoren der Vereine - nur so viel, wie die Auswahlliste im
       Reiter "Werbeanzeigen" braucht. Sie stehen dort neben der eigenen
       Werbung, weil der Betreiber beim Verkauf eines Platzes wissen muss,
       was auf den anderen Plaetzen schon laeuft. Die Einzelheiten dazu
       zeigt die Vereinsansicht ohnehin schon. */
    admin.from("anzeigen").select("id,platz,titel,aktiv,laeuft_bis,impressionen,klicks,club_id,clubs(name)")
      .not("club_id", "is", null).order("platz"),
    /* Die Zahlen ueber alle Vereine hinweg. Sie liessen sich auch aus der
       Vereinsliste rechnen - aber nur die, die schon geladen ist. Wer
       spaeter nach Vereinen sucht, wuerde eine gefilterte Gesamtsumme
       sehen, und das waere schlimmer als gar keine. */
    admin.rpc("betreiber_kennzahlen"),
  ]);

  if (vereine.error || anfragen.error || anzeigen.error || sponsoren.error) {
    console.error("Betreiberübersicht konnte nicht geladen werden", vereine.error || anfragen.error || anzeigen.error || sponsoren.error);
    return NextResponse.json({ error: "Die Übersicht konnte nicht geladen werden." }, { status: 500 });
  }

  /* Die Kennzahlen duerfen fehlen, ohne dass die Seite leer bleibt: Sie sind
     eine Zusammenfassung dessen, was daneben ohnehin steht. Ein Fehler dort
     kostet die Kopfzeile, nicht die Uebersicht. */
  if (kennzahlen.error) console.error("Kennzahlen konnten nicht geladen werden", kennzahlen.error);

  return NextResponse.json({
    vereine: vereine.data || [],
    anfragen: anfragen.data || [],
    anzeigen: anzeigen.data || [],
    sponsoren: (sponsoren.data || []).map((a: Record<string, unknown>) => ({
      ...a,
      /* Supabase liefert die verbundene Zeile je nach Beziehung als Objekt
         oder als einelementige Liste. Beides hier auf einen Namen bringen,
         damit die Oberflaeche nicht raten muss. */
      verein: (Array.isArray(a.clubs) ? (a.clubs[0] as { name?: string })?.name : (a.clubs as { name?: string })?.name) || "—",
      clubs: undefined,
    })),
    kennzahlen: kennzahlen.error ? null : (kennzahlen.data?.[0] ?? null),
  });
}
