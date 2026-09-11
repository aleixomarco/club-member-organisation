import { createClient } from "@supabase/supabase-js";

/* Ein Abruf, der einen kurzen Zeitversatz übersteht.
 *
 * SUPABASE_SECRET_KEY ist ein Schlüssel des neuen Formats; die kurzlebigen
 * Token dafür stellt Supabase selbst aus. Liegt die Uhr der ausstellenden
 * Stelle ein paar hundert Millisekunden vor der von PostgREST, lehnt PostgREST
 * das Token ab: "JWT issued at future", Fehlercode PGRST303. Der Aufruf
 * scheitert, der nächste geht wieder durch.
 *
 * Das ist im Kalender-Abo aufgefallen: Ein Telefon holt den Feed automatisch
 * alle paar Minuten, und ein einzelner Fehlschlag sah für den Nutzer aus wie
 * ein kaputter Kalender.
 *
 * Ein Versuch mehr genügt. Mehr wäre falsch: Hält der Versatz an, ist das
 * nichts, was sich wegwiederholen lässt - dann soll der Aufrufer eine ehrliche
 * "gerade nicht verfügbar"-Antwort geben können.
 *
 * Gewartet wird 1,5 Sekunden. Mit 400 ms scheiterte am 11./12.09. auch der
 * zweite Versuch mehrfach - der Versatz hielt länger an.
 */
export async function mitZweitemVersuch<T extends { error: { code?: string | null } | null }>(
  abfrage: () => PromiseLike<T>,
): Promise<T> {
  const erst = await abfrage();
  if (erst.error?.code !== "PGRST303") return erst;
  await new Promise((weiter) => setTimeout(weiter, 1500));
  return abfrage();
}

export function getSupabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!url || !secret) throw new Error("Supabase server configuration is missing");
  return createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
}

