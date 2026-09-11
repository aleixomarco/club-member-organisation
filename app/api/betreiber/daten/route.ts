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

  const [vereine, anfragen, anzeigen, sponsoren, kennzahlen, kontenStand] = await Promise.all([
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
       zeigt die Vereinsansicht ohnehin schon.

       OHNE Einbetten des Vereinsnamens ueber clubs(name), obwohl das kuerzer
       waere. Genau das hat diese Route lahmgelegt: Die neue Tabelle
       anzeigen_statistik hat Fremdschluessel auf anzeigen UND clubs, PostgREST
       liest sie deshalb als Verbindungstabelle zwischen beiden, und das
       Einbetten wurde mehrdeutig - PGRST201, HTTP 500, keine Uebersicht mehr.
       Ein Verweis "clubs!anzeigen_club_id_fkey(name)" wuerde es heute
       aufloesen, aber die naechste Tabelle mit zwei Fremdschluesseln bricht
       die naechste Abfrage. Der Name steht ohnehin schon in vereine; ihn dort
       nachzuschlagen kann keine kuenftige Tabelle kaputtmachen. */
    admin.from("anzeigen").select("id,platz,titel,aktiv,laeuft_bis,impressionen,klicks,club_id")
      .not("club_id", "is", null).order("platz"),
    /* Die Zahlen ueber alle Vereine hinweg. Sie liessen sich auch aus der
       Vereinsliste rechnen - aber nur die, die schon geladen ist. Wer
       spaeter nach Vereinen sucht, wuerde eine gefilterte Gesamtsumme
       sehen, und das waere schlimmer als gar keine. */
    admin.rpc("betreiber_kennzahlen"),
    /* Konten auf der ganzen Plattform gegen die Obergrenze. Die Kachel
       "Konten" aus den Kennzahlen zaehlt Mitgliedschaften - die Sperre bei
       der Registrierung zaehlt jedes Konto. Ohne diese Zahl merkte der
       Betreiber die Sperre erst an Beschwerden. */
    admin.rpc("betreiber_konten_stand"),
  ]);

  /* Was die Uebersicht AUSMACHT, muss da sein: Vereine, Anfragen, die eigenen
     Anzeigen. Faellt eines davon aus, ist die Seite ohne Aussage und sagt das
     auch. */
  if (vereine.error || anfragen.error || anzeigen.error) {
    console.error("Betreiberübersicht konnte nicht geladen werden", vereine.error || anfragen.error || anzeigen.error);
    return NextResponse.json({ error: "Die Übersicht konnte nicht geladen werden." }, { status: 500 });
  }

  /* Kennzahlen und Sponsorenliste duerfen fehlen, ohne dass die Seite leer
     bleibt. Beide sind Beiwerk: die einen eine Zusammenfassung dessen, was
     daneben ohnehin steht, die andere eine Nachschlageliste fuer einen
     Unterreiter.
     Die Sponsorenliste stand bis eben in derselben Prüfung wie die
     Vereinsliste - eine neu hinzugefuegte Nebenabfrage konnte damit die ganze
     Konsole abschalten, und genau das ist passiert. Eine Ergaenzung darf nie
     mehr kosten als sich selbst. */
  if (kennzahlen.error) console.error("Kennzahlen konnten nicht geladen werden", kennzahlen.error);
  if (sponsoren.error) console.error("Sponsorenliste konnte nicht geladen werden", sponsoren.error);
  if (kontenStand.error) console.error("Kontenstand konnte nicht geladen werden", kontenStand.error);

  /* Der Vereinsname zu einer club_id - nachgeschlagen statt eingebettet.
     betreiber_uebersicht fuehrt jeden Verein, die Zuordnung ist also
     vollstaendig. */
  const vereinsName = new Map(
    (vereine.data || []).map((v: Record<string, unknown>) => [v.id as string, String(v.name ?? "")]),
  );

  return NextResponse.json({
    vereine: vereine.data || [],
    anfragen: anfragen.data || [],
    anzeigen: anzeigen.data || [],
    sponsoren: (sponsoren.data || []).map((a: Record<string, unknown>) => ({
      ...a,
      verein: vereinsName.get(a.club_id as string) || "—",
    })),
    kennzahlen: kennzahlen.error ? null : (kennzahlen.data?.[0] ?? null),
    kontenStand: kontenStand.error ? null : (kontenStand.data?.[0] ?? null),
  });
}
