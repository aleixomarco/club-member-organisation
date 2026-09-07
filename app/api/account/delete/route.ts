import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

/* Kontoloeschung in drei Schritten.
 *
 * WARUM DREI UND WARUM IN DIESER REIHENFOLGE
 * admin.auth.admin.deleteUser ist ein HTTP-Aufruf und kann NICHT in derselben
 * Transaktion liegen wie das SQL. Irgendwo dazwischen kann es also abbrechen -
 * die Frage ist nur, welcher halbe Zustand dabei entsteht.
 *
 *   Erst Verein loeschen, dann Konto: Scheitert der zweite Schritt - und er
 *   scheitert regelmaessig an Fremdschluesseln, siehe unten -, ist der Verein
 *   unwiederbringlich weg und das Konto lebt weiter. Der Nutzer bekommt die
 *   Aufforderung, sich beim Verein zu melden. Bei einem Verein, den es nicht
 *   mehr gibt.
 *
 *   Erst Konto, dann Verein: Bleibt schlimmstenfalls ein leerer Verein
 *   stehen. Die Vormerkung in konto_loeschungen ueberlebt den Abbruch, der
 *   naechste Versuch raeumt nach - konto_loeschung_abschliessen ist
 *   wiederholbar und meldet beim zweiten Mal 0.
 *
 * Deshalb: vormerken (1), Konto loeschen (2), Vormerkung ausfuehren (3).
 *
 * ENTSCHIEDEN WIRD IN DER DATENBANK, NICHT HIER
 * konto_loeschung_vormerken sperrt die betroffenen Vereine und prueft unter
 * dieser Sperre. Ohne sie saehen zwei gleichzeitig loeschende Admins jeweils
 * den anderen, beide Pruefungen sagten ja, und der Verein bliebe ohne Leitung
 * zurueck. Die Route entscheidet nichts selbst; sie reicht nur die Kennung
 * weiter und uebersetzt das Ergebnis in eine Antwort.
 *
 * Das Feld vereineBestaetigt aus dem Client ist eine EINWILLIGUNG, keine
 * Anweisung: WELCHE Vereine mitgehen, ermittelt ausschliesslich die Datenbank
 * im Moment der Loeschung neu.
 */
export async function DELETE(request: Request) {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!token || !url || !key) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const authClient = createClient(url, key, { auth: { persistSession: false } });
  const { data: { user }, error } = await authClient.auth.getUser(token);
  if (error || !user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  /* Die Einwilligung kommt als Feld im Rumpf. Ein fehlender oder kaputter
     Rumpf ist kein Fehler - dann gilt sie eben als nicht erteilt. */
  let vereineBestaetigt = false;
  try {
    const rumpf = await request.json();
    vereineBestaetigt = rumpf?.vereineBestaetigt === true;
  } catch {
    vereineBestaetigt = false;
  }

  /* Wer spaeter zu benachrichtigen ist, muss JETZT ermittelt werden: Nach der
     Loeschung sind die eigenen Mitgliedschaften ueber die Kaskade weg, und
     damit auch die Spur, zu welchen Vereinen dieses Konto gehoerte. */
  const { data: eigeneMitgliedschaften } = await admin.from("club_memberships")
    .select("club_id,display_name,status").eq("profile_id", user.id);
  const eigeneVereine = (eigeneMitgliedschaften || [])
    .filter((m) => m.status === "active").map((m) => m.club_id);
  const eigenerName = (eigeneMitgliedschaften || [])[0]?.display_name || null;

  // ---------------------------------------------------------- 1. Vormerken
  const { data: lage, error: pruefFehler } = await admin.rpc("konto_loeschung_vormerken", {
    p_profile: user.id,
    p_vereine_bestaetigt: vereineBestaetigt,
  });
  if (pruefFehler) {
    console.error(`Kontoloeschung: Pruefung fehlgeschlagen fuer ${user.id}:`, pruefFehler.message);
    return NextResponse.json({ error: "Deletion check failed" }, { status: 500 });
  }

  if (!lage?.erlaubt) {
    /* 409, nicht 403: Es ist kein Rechteproblem, sondern ein Zustand, den der
       Nutzer selbst aufloesen kann - indem er einen Nachfolger bestimmt oder
       die Rueckfrage beantwortet. Der Code steht im Rumpf, damit die App ihn
       in ihren sieben Sprachen selbst formulieren kann, statt einen fertigen
       deutschen Satz vom Server anzuzeigen. */
    return NextResponse.json({
      code: lage?.grund ?? "unbekannt",
      blockiert: lage?.blockiert ?? [],
      vereine: lage?.vereine ?? [],
    }, { status: 409 });
  }

  // ------------------------------------------------------ 2. Konto loeschen
  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id);
  if (deletionError) {
    /* Ein Fremdschluessel kann die Loeschung blockieren. Bekannter Fall:
       news_posts.author_id verwies mit "on delete restrict" auf profiles - wer je
       eine Neuigkeit verfasst hatte, kam nicht mehr aus dem Verein heraus. Die
       Migration 20260829120000_news_author_loeschbar.sql stellt das auf
       "set null" um.
       Solange sie nicht eingespielt ist, soll wenigstens im Log stehen, WARUM es
       scheitert - "Deletion failed" allein hat niemandem geholfen und sah nach
       einem Serverfehler aus, obwohl es einer an einer bestimmten Stelle ist.

       Die Vormerkung bleibt dabei stehen und wird NICHT ausgefuehrt: Der
       Verein gehoert dem Konto, das es noch gibt. */
    const blockiert = /foreign key|violates|constraint/i.test(deletionError.message || "");
    console.error(`Kontoloeschung fehlgeschlagen fuer ${user.id}${blockiert ? " - ein Fremdschluessel blockiert sie" : ""}:`, deletionError.message);
    return NextResponse.json({
      code: blockiert ? "fremdschluessel" : "fehlgeschlagen",
      error: blockiert
        ? "Dein Konto konnte nicht gelöscht werden, weil noch Beiträge daran hängen. Wir haben den Fall protokolliert — melde dich bitte kurz beim Verein, dann erledigen wir es von Hand."
        : "Deletion failed",
    }, { status: 500 });
  }

  // ------------------------------------------- 3. Vorgemerkte Vereine loeschen
  try {
    await admin.rpc("konto_loeschung_abschliessen", { p_profile: user.id });
  } catch (fehler) {
    /* Das Konto ist weg, der Verein noch da. Kein Grund, dem Nutzer einen
       Fehler zu zeigen - fuer ihn ist die Loeschung vollzogen. Die Vormerkung
       bleibt offen, damit sich das nachholen laesst. */
    console.error(`Kontoloeschung: vorgemerkte Vereine blieben stehen fuer ${user.id}:`, fehler);
  }

  /* Vereinsverantwortliche informieren - ZULETZT, nicht zuerst.
   *
   * Vorher stand das ganz oben. Mit der neuen Pruefung waere der Abbruch nach
   * der Benachrichtigung zum Regelfall geworden: Jeder blockierte Versuch
   * haette der Vereinsleitung "X hat das eigene Konto dauerhaft geloescht"
   * auf den Sperrbildschirm geschickt, obwohl X noch da ist. Zuruecknehmen
   * laesst sich das nicht.
   *
   * Die Mitgliedschaften des Geloeschten sind an dieser Stelle ueber die
   * Kaskade schon weg - deshalb steht der Name aus der Vormerkung bzw. dem
   * Protokoll, nicht mehr aus club_memberships. Bleibt best effort. */
  try {
    /* Nur die Vereine, die den Nutzer verloren haben und es noch GIBT. In den
       mitgeloeschten ist niemand mehr, den man benachrichtigen koennte. */
    const mitgegangen = new Set(((lage?.vereine as { id: string }[]) || []).map((v) => v.id));
    const ziele = eigeneVereine.filter((id) => !mitgegangen.has(id));
    if (ziele.length) {
      const { data: leitung } = await admin.from("club_memberships")
        .select("id,membership_roles(role)").in("club_id", ziele).eq("status", "active");
      const empfaenger = (leitung || [])
        .filter((m) => (m.membership_roles || []).some((r: { role: string }) => ["vereinsadmin", "sysadmin"].includes(r.role)))
        .map((m) => m.id);
      if (empfaenger.length) {
        await admin.rpc("notify_many", {
          target_memberships: empfaenger, p_notif_type: "membership",
          p_title: "Konto gelöscht",
          p_body: `${eigenerName || "Ein Mitglied"} hat das eigene Konto dauerhaft gelöscht.`,
        });
      }
    }
  } catch {
    // Benachrichtigung ist nicht kritisch für die Löschung selbst.
  }

  return NextResponse.json({ deleted: true, vereine: lage?.vereine ?? [] });
}
