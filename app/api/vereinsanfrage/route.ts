import { timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

/* Nimmt Anfragen vom Formular auf der Website entgegen und legt sie in
   derselben Tabelle ab wie die Anfragen aus der App. Der Betreiber schaut damit
   an einer Stelle nach statt in zwei Postfächern.

   Abgesichert über einen gemeinsamen Schlüssel im Kopf der Anfrage. Ohne ihn
   wäre der Endpunkt eine offene Tür für Werbemüll: Er schreibt in die
   Datenbank, und niemand müsste sich dafür anmelden. */

const MAX = { name: 200, email: 320, telefon: 60, notiz: 2000 };

function schluesselStimmt(gesendet: string, erwartet: string) {
  const a = Buffer.from(gesendet);
  const b = Buffer.from(erwartet);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

/* Bewusst großzügig: Die Prüfung soll offensichtlichen Unsinn abfangen, nicht
   Adressen aussortieren, die ungewöhnlich aussehen, aber gültig sind. Ob
   jemand tatsächlich erreichbar ist, zeigt sich beim Antworten. */
const SIEHT_WIE_EMAIL_AUS = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function text(wert: unknown, grenze: number): string | null {
  if (typeof wert !== "string") return null;
  const sauber = wert.trim();
  if (!sauber) return null;
  return sauber.slice(0, grenze);
}

export async function POST(request: Request) {
  const secret = process.env.WEBSITE_ANFRAGE_SECRET;
  if (!secret) return NextResponse.json({ error: "Server configuration error" }, { status: 500 });

  /* Der Schlüssel darf im Authorization-Kopf oder in X-Anfrage-Schluessel
     stehen - manche Baukästen lassen nur eigene Kopfzeilen zu, andere nur
     Authorization. */
  const kopf = request.headers.get("authorization") || request.headers.get("x-anfrage-schluessel") || "";
  const wert = kopf.replace(/^Bearer\s+/i, "");
  if (!schluesselStimmt(wert, secret)) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const daten = await request.json().catch(() => null);
  if (!daten || typeof daten !== "object") return NextResponse.json({ error: "Invalid payload" }, { status: 400 });

  /* Honigtopf: ein im Formular unsichtbares Feld, das nur ein Automat ausfüllt.
     Ist es belegt, wird still bestätigt statt abgewiesen - wer Müll schickt,
     soll nicht erfahren, dass er erkannt wurde. */
  if (text((daten as Record<string, unknown>).website, 100)) {
    return NextResponse.json({ ok: true });
  }

  const d = daten as Record<string, unknown>;
  const vereinsname = text(d.club_name ?? d.verein, MAX.name);
  const ansprechpartner = text(d.contact_name ?? d.name, MAX.name);
  const email = text(d.contact_email ?? d.email, MAX.email);
  const telefon = text(d.contact_phone ?? d.telefon, MAX.telefon);
  const notiz = text(d.note ?? d.nachricht, MAX.notiz);

  const roh = d.expected_accounts ?? d.zugaenge;
  const zugaenge = Number.isFinite(Number(roh)) && Number(roh) > 0 ? Math.min(Math.trunc(Number(roh)), 100000) : null;

  if (!vereinsname || !ansprechpartner || !email) {
    return NextResponse.json({ error: "Vereinsname, Ansprechpartner und E-Mail werden gebraucht." }, { status: 422 });
  }
  if (!SIEHT_WIE_EMAIL_AUS.test(email)) {
    return NextResponse.json({ error: "Die E-Mail-Adresse sieht nicht gültig aus." }, { status: 422 });
  }

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  /* Gibt es den Verein schon, wird die Anfrage ihm zugeordnet - dann sieht der
     Betreiber sofort, wie groß er inzwischen ist. Die Zuordnung ist bewusst
     streng (exakter Name, ohne Rücksicht auf Groß- und Kleinschreibung): Lieber
     eine Anfrage ohne Verein als eine, die beim falschen landet. */
  const { data: treffer } = await admin
    .from("clubs")
    .select("id")
    .ilike("name", vereinsname)
    .limit(2);
  const clubId = treffer?.length === 1 ? treffer[0].id : null;

  const { error } = await admin.from("club_access_requests").insert({
    club_id: clubId,
    club_name: vereinsname,
    quelle: "website",
    contact_name: ansprechpartner,
    contact_email: email,
    contact_phone: telefon,
    expected_accounts: zugaenge,
    note: notiz,
  });

  if (error) {
    /* Liegt für diesen Verein schon eine offene Anfrage vor, greift der
       eindeutige Index. Für die Website ist das kein Fehler: Wer zweimal
       schreibt, hat es eilig - er bekommt dieselbe freundliche Bestätigung. */
    if (/duplicate|unique/i.test(error.message || "")) return NextResponse.json({ ok: true, hinweis: "bereits erfasst" });
    console.error("Vereinsanfrage konnte nicht gespeichert werden", error);
    return NextResponse.json({ error: "Could not store request" }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
