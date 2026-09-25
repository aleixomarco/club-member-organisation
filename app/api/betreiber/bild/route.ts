import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { SITZUNGS_COOKIE, fremdeHerkunft, sitzungGueltig } from "@/lib/betreiber";
import { getSupabaseAdmin } from "@/lib/supabase-admin";
import { BETREIBER_BILD_ORDNER, BILD_EIMER, bildAdresse } from "@/lib/betreiber-bild";

export const dynamic = "force-dynamic";

/* Das Vorschaubild einer eigenen Werbeanzeige.
 *
 * Warum eine eigene Route: Die Konsole hat keinen Supabase-Client — sie spricht
 * nur mit diesem Server, der den Dienstschlüssel hält. Die Vereins-App lädt ihre
 * Sponsorenbilder dagegen direkt hoch, weil dort ein angemeldetes Mitglied am
 * Gerät sitzt, auf das die Speicherregeln passen.
 *
 * Wo die Bilder liegen und warum dort, steht in lib/betreiber-bild.ts. */

/* Derselbe Rahmen, den der Eimer selbst setzt (2 MB, drei Bildformate). Hier
   noch einmal, damit eine zu große Datei eine deutsche Meldung bekommt statt
   eines Fehlers aus dem Speicher. */
const ERLAUBTE_TYPEN = ["image/jpeg", "image/png", "image/webp"];
const GRENZE = 2 * 1024 * 1024;
const ENDUNGEN: Record<string, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };

export async function POST(request: Request) {
  const cookieSpeicher = await cookies();
  if (!sitzungGueltig(cookieSpeicher.get(SITZUNGS_COOKIE)?.value)) {
    return NextResponse.json({ error: "Nicht angemeldet." }, { status: 401 });
  }
  if (fremdeHerkunft(request)) {
    return NextResponse.json({ error: "Ungültige Herkunft." }, { status: 403 });
  }

  let formular: FormData;
  try {
    formular = await request.formData();
  } catch {
    return NextResponse.json({ error: "Unvollständige Anfrage." }, { status: 400 });
  }

  const datei = formular.get("bild");
  if (!(datei instanceof File) || datei.size === 0) {
    return NextResponse.json({ error: "Keine Datei gewählt." }, { status: 400 });
  }
  if (!ERLAUBTE_TYPEN.includes(datei.type)) {
    return NextResponse.json({ error: "Nur JPG, PNG oder WebP." }, { status: 400 });
  }
  if (datei.size > GRENZE) {
    return NextResponse.json({ error: "Das Bild ist größer als 2 MB." }, { status: 400 });
  }

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  /* Zufall im Namen, nicht nur die Uhrzeit: Zwei Bilder in derselben Sekunde
     würden sich sonst überschreiben, und upsert steht bewusst auf false. */
  const endung = ENDUNGEN[datei.type];
  const zufall = Math.random().toString(36).slice(2, 8);
  const pfad = `${BETREIBER_BILD_ORDNER}/anzeige-${Date.now()}-${zufall}.${endung}`;

  const { error } = await admin.storage.from(BILD_EIMER).upload(pfad, await datei.arrayBuffer(), {
    contentType: datei.type,
    upsert: false,
  });
  if (error) {
    console.error("Anzeigenbild konnte nicht hochgeladen werden", error);
    return NextResponse.json({ error: "Das Bild konnte nicht gespeichert werden." }, { status: 500 });
  }

  /* Das abgelöste Bild räumt NICHT diese Route weg, sondern erst
     /api/betreiber/aktion beim Speichern. Sonst wäre das alte Bild schon weg,
     wenn der Betreiber den Dialog danach abbricht - und die laufende Anzeige
     zeigte ins Leere. Bleibt ein Bild liegen, weil jemand hochlädt und dann
     abbricht, ist das der harmlosere der beiden Fehler. */

  return NextResponse.json({ ok: true, bild_pfad: pfad, bild_url: bildAdresse(pfad) });
}
