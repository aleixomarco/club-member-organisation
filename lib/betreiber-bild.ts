/* Wo die Vorschaubilder der eigenen Werbeanzeigen liegen.
 *
 * Eigene Datei, weil zwei Routen dasselbe wissen müssen: /api/betreiber/bild
 * legt die Bilder ab, /api/betreiber/aktion räumt sie wieder weg, wenn eine
 * Anzeige ein neues Bild bekommt oder ganz verschwindet.
 *
 * DERSELBE EIMER wie bei den Sponsoren der Vereine: Die App baut die
 * Bildadresse fest aus "sponsor-bilder" zusammen (ladeWerbeplaetze in
 * app/page.tsx), und beide Arten von Werbung liegen ohnehin in derselben
 * Tabelle public.anzeigen.
 *
 * DER ORDNER IST EINE UUID AUS NULLEN. Die Schreibregeln auf storage.objects
 * lesen den ersten Ordner als Verein ( ((storage.foldername(name))[1])::uuid ).
 * Stünde dort "betreiber", bräche diese Umwandlung mit einem Fehler ab, sobald
 * die Regel auf so eine Zeile trifft — für jeden, der in diesem Eimer etwas
 * ändern will. Eine Nullen-UUID lässt sich umwandeln, gehört zu keinem Verein,
 * und has_club_role() sagt dazu nein. Schreiben kann hier also nur, wer den
 * Dienstschlüssel hat: der Server. */
export const BILD_EIMER = "sponsor-bilder";
export const BETREIBER_BILD_ORDNER = "00000000-0000-0000-0000-000000000000";

/* Gehört dieses Bild zu einer Betreiberanzeige? Alles andere gehört einem
   Verein und wird von den Betreiber-Routen nie angefasst. */
export function istBetreiberBild(pfad: unknown): pfad is string {
  return typeof pfad === "string" && pfad.startsWith(`${BETREIBER_BILD_ORDNER}/`);
}

/* Aus dem gespeicherten Pfad die abrufbare Adresse. Der Eimer ist öffentlich
   lesbar; dieselbe Zusammensetzung benutzt die Route für die Sponsorenbilder. */
export function bildAdresse(pfad: unknown): string | null {
  if (typeof pfad !== "string" || !pfad) return null;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || "";
  return `${url}/storage/v1/object/public/${BILD_EIMER}/${pfad}`;
}
