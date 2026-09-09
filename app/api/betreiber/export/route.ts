import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { SITZUNGS_COOKIE, sitzungGueltig } from "@/lib/betreiber";
import { getSupabaseAdmin } from "@/lib/supabase-admin";
import { mappeBauen, dateiname, type Blatt } from "@/lib/betreiber-export";

export const dynamic = "force-dynamic";
/* Die Mappe wird im Speicher gebaut; bei vielen Vereinen dauert das laenger
   als die Vorgabe von zehn Sekunden. */
export const maxDuration = 60;

/* Beschriftungen fuer die beiden Anzeigen-Blaetter. Sie stehen auch in der
   Konsole - dort fuer den Bildschirm, hier fuer die Mappe. Doppelt, weil das
   eine ein Client-Bauteil ist und das andere auf dem Server laeuft; ein
   gemeinsames Modul dafuer waere mehr Verdrahtung als Ersparnis. */
const PLATZ_NAMEN: Record<string, string> = {
  dashboard_top: "Start – oben", dashboard_bottom: "Start – unter den News",
  events_header: "Termine – Kopfbereich", profile_bottom: "Profil – unten",
};
const ELEMENT_NAMEN: Record<string, string> = {
  anzeige: "Anzeige geöffnet", website: "Website", telefon: "Angerufen",
  email: "E-Mail", aktion: "Zur Aktion",
};

/* Alle Vereinsdaten als Excel-Mappe.
 *
 * WOZU
 * Die Konsole zeigt, was man am Bildschirm braucht. Alles andere - Auswertung,
 * Rechnungsstellung, Jahresvergleich, eine Liste fuer den Steuerberater -
 * passiert in einer Tabelle. Bisher hiess das: von Hand abschreiben oder im
 * SQL-Editor abfragen.
 *
 * WARUM AUF DEM SERVER
 * Der Dienstschluessel umgeht die Zeilenregeln - nur so kommt man ueber alle
 * Vereine hinweg an die Daten. Er darf den Browser deshalb nie erreichen. Die
 * Route laeuft mit derselben Absicherung wie die uebrige Konsole: ohne
 * gueltige Betreibersitzung gibt es nichts.
 *
 * PERSONENBEZOGENE DATEN
 * Das Blatt "Mitglieder" enthaelt Namen, E-Mail-Adressen und Geburtsdaten
 * echter Menschen. Die Mappe gehoert damit behandelt wie eine Mitgliederliste
 * auf Papier: nicht weitergeben, nicht in einer Cloud ablegen, die nicht
 * dafuer vorgesehen ist, und loeschen, wenn der Zweck erledigt ist. Deshalb
 * steht der Hinweis auch im Blatt "Uebersicht" - wer die Datei in einem Jahr
 * wiederfindet, soll ihn dort lesen.
 */

type Zeile = Record<string, unknown>;

const zahl = (w: unknown) => (typeof w === "number" ? w : Number(w ?? 0));

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

  const erzeugtAm = new Date();

  try {
    const [vereine, teams, termine, abos, plaene, anfragen, anzeigen, statistik, kennzahlen] = await Promise.all([
      admin.from("betreiber_uebersicht").select("*").order("name"),
      admin.from("teams").select("id,club_id,name,category,active,is_adult,zusagen_aktiv,zusagen_spiele_aktiv,strafen_aktiv,created_at"),
      admin.from("events").select("id,club_id,team_id,type,status,title,starts_at,ends_at,location,home_away,opponent,home_score,away_score,series_id,created_at"),
      admin.from("club_subscriptions").select("club_id,plan_id,provider,status,current_period_start,current_period_end,cancel_at_period_end,last_payment_at"),
      admin.from("subscription_plans").select("id,code,name,interval,price_cents,currency"),
      admin.from("club_access_requests").select("club_name,contact_name,contact_email,contact_phone,expected_accounts,status,quelle,rechnungsnummer,betrag,zahlweise,created_at,freigeschaltet_am,ablehnungsgrund"),
      admin.from("anzeigen").select("id,club_id,platz,titel,text,ziel_url,telefon,email,laeuft_von,laeuft_bis,aktiv,impressionen,klicks").order("platz"),
      /* Die Tageszahlen. Ein Jahr zurueck und gedeckelt: Wer eine Anzeige
         gegenueber einem Unternehmen abrechnet, braucht den Zeitraum, nicht
         die Vorgeschichte - und eine Mappe mit hunderttausend Zeilen oeffnet
         niemand mehr. */
      admin.from("anzeigen_statistik")
        .select("anzeige_id,club_id,tag,element,impressionen,klicks")
        .gte("tag", new Date(Date.now() - 365 * 86400000).toISOString().slice(0, 10))
        .order("tag", { ascending: false })
        .limit(20000),
      admin.rpc("betreiber_kennzahlen"),
    ]);

    const ersterFehler = [vereine, teams, termine, abos, plaene, anfragen, anzeigen, statistik]
      .find((a) => a.error);
    if (ersterFehler?.error) {
      console.error("Export konnte nicht geladen werden", ersterFehler.error);
      return NextResponse.json({ error: "Die Daten konnten nicht geladen werden." }, { status: 500 });
    }

    const vereinsZeilen = (vereine.data || []) as Zeile[];
    const vereinsName = new Map(vereinsZeilen.map((v) => [v.id as string, String(v.name ?? "")]));
    const teamName = new Map(((teams.data || []) as Zeile[]).map((t) => [t.id as string, String(t.name ?? "")]));
    /* Die Tageszahlen tragen nur Kennungen. Ohne diese beiden Zuordnungen
       staende im Blatt eine Spalte voller UUIDs - ein Datenbankauszug, keine
       Auswertung. */
    const anzeigenName = new Map(((anzeigen.data || []) as Zeile[]).map((a) => [a.id as string, String(a.titel ?? "")]));
    const anzeigenPlatz = new Map(((anzeigen.data || []) as Zeile[]).map((a) => [a.id as string, String(a.platz ?? "")]));
    const planName = new Map(((plaene.data || []) as Zeile[]).map((p) => [p.id as string, p]));

    /* Die Mitglieder je Verein ueber die vorhandene Funktion - sie liefert
       bereits Rollen, Mannschaften, Alter und Geraetezahl aufbereitet. Ein
       eigener Join haette dieselbe Logik ein zweites Mal beschrieben, und die
       beiden waeren mit der Zeit auseinandergelaufen. */
    const mitglieder: Zeile[] = [];
    for (const verein of vereinsZeilen) {
      const { data, error } = await admin.rpc("mitglieder_eines_vereins", { target_club: verein.id });
      if (error) {
        console.error("Mitglieder eines Vereins fehlten im Export", verein.name, error);
        continue;
      }
      for (const m of (data || []) as Zeile[]) mitglieder.push({ ...m, verein: verein.name });
    }

    const k = (kennzahlen.error ? null : kennzahlen.data?.[0]) as Zeile | null;

    const blaetter: Blatt[] = [
      {
        name: "Übersicht",
        hinweis: "Diese Mappe enthält personenbezogene Daten echter Vereinsmitglieder — bitte entsprechend behandeln und nach Gebrauch löschen.",
        spalten: [
          { titel: "Kennzahl", feld: "kennzahl", breite: 34 },
          { titel: "Wert", feld: "wert", art: "zahl", breite: 14 },
        ],
        zeilen: [
          { kennzahl: "Erzeugt am", wert: null },
          { kennzahl: "Vereine gesamt", wert: zahl(k?.vereine ?? vereinsZeilen.length) },
          { kennzahl: "davon freigeschaltet", wert: zahl(k?.freigeschaltet) },
          { kennzahl: "Mitglieder gesamt", wert: mitglieder.length },
          { kennzahl: "Mannschaften gesamt", wert: (teams.data || []).length },
          { kennzahl: "Termine gesamt", wert: (termine.data || []).length },
          { kennzahl: "Offene Zugangsanfragen", wert: ((anfragen.data || []) as Zeile[]).filter((a) => a.status === "offen").length },
        ],
      },
      {
        name: "Vereine",
        spalten: [
          { titel: "Verein", feld: "name", breite: 26 },
          { titel: "Kürzel", feld: "short_name", breite: 10 },
          { titel: "Stadt", feld: "city" },
          { titel: "Sportart", feld: "sport" },
          { titel: "Angelegt am", feld: "created_at", art: "datum" },
          { titel: "Tarif", feld: "tarif" },
          { titel: "Läuft bis", feld: "laeuft_bis", art: "datum" },
          { titel: "Vereinbarte Zugänge", feld: "vereinbarte_zugaenge", art: "zahl" },
          { titel: "Grenze", feld: "grenze", art: "zahl" },
          { titel: "Belegte Konten", feld: "konten", art: "zahl" },
          { titel: "Mitglieder", feld: "mitglieder", art: "zahl" },
          { titel: "Offene Aufnahmen", feld: "offene_aufnahmen", art: "zahl" },
          { titel: "Eigene Sponsoren", feld: "eigene_sponsoren", art: "zahl" },
          { titel: "Sponsoring frei", feld: "sponsoring_freigeschaltet", art: "ja_nein" },
          { titel: "Guthaben (Monate)", feld: "referral_credit_months", art: "zahl" },
          { titel: "Belegnummer", feld: "beleg" },
          { titel: "Ansprechpartner", feld: "ansprechpartner", breite: 26 },
          { titel: "Ausgeblendet", feld: "hidden", art: "ja_nein" },
          { titel: "Letzte Aktivität", feld: "letzte_aktivitaet", art: "zeitpunkt" },
          { titel: "Aktive (30 Tage)", feld: "aktive_30", art: "zahl" },
          { titel: "Termine (30 Tage)", feld: "termine_30", art: "zahl" },
          { titel: "Nachrichten (30 Tage)", feld: "nachrichten_30", art: "zahl" },
        ],
        zeilen: vereinsZeilen,
      },
      {
        name: "Mitglieder",
        spalten: [
          { titel: "Verein", feld: "verein", breite: 24 },
          { titel: "Name", feld: "name", breite: 26 },
          { titel: "E-Mail", feld: "email", breite: 30 },
          { titel: "Status", feld: "status" },
          { titel: "Mitglied seit", feld: "mitglied_seit", art: "zahl" },
          { titel: "Mitgliedsnummer", feld: "mitgliedsnummer" },
          { titel: "Geburtsdatum", feld: "geburtsdatum", art: "datum" },
          { titel: "Alter", feld: "alter_jahre", art: "zahl" },
          { titel: "Geschlecht", feld: "geschlecht" },
          { titel: "Ort", feld: "ort" },
          { titel: "Rollen", feld: "rollen", art: "liste", breite: 34 },
          { titel: "Mannschaften", feld: "mannschaften", art: "liste", breite: 28 },
          { titel: "Geräte", feld: "geraete", art: "zahl" },
          { titel: "Punkte", feld: "punkte", art: "zahl" },
          { titel: "Letzte Änderung", feld: "letzte_aenderung", art: "zeitpunkt" },
        ],
        zeilen: mitglieder,
      },
      {
        name: "Mannschaften",
        spalten: [
          { titel: "Verein", feld: "verein", breite: 24 },
          { titel: "Mannschaft", feld: "name", breite: 22 },
          { titel: "Kategorie", feld: "category" },
          { titel: "Erwachsene", feld: "is_adult", art: "ja_nein" },
          { titel: "Aktiv", feld: "active", art: "ja_nein" },
          { titel: "Mitglieder", feld: "mitglieder", art: "zahl" },
          { titel: "Termine", feld: "termine", art: "zahl" },
          { titel: "Zusagen Trainings", feld: "zusagen_aktiv", art: "ja_nein" },
          { titel: "Zusagen Spiele", feld: "zusagen_spiele_aktiv", art: "ja_nein" },
          { titel: "Strafenkatalog", feld: "strafen_aktiv", art: "ja_nein" },
          { titel: "Angelegt am", feld: "created_at", art: "datum" },
        ],
        /* Der Rueckgabetyp muss ausdruecklich Zeile sein: Ohne ihn engt
           TypeScript das Ergebnis auf die drei hier ergaenzten Felder ein,
           und der Vergleich unten liest name auf einem Typ, der es nicht
           mehr kennt. Zur Laufzeit war es immer da - der Spread traegt es. */
        zeilen: ((teams.data || []) as Zeile[]).map((t): Zeile => ({
          ...t,
          verein: vereinsName.get(t.club_id as string) ?? "",
          mitglieder: mitglieder.filter((m) =>
            Array.isArray(m.mannschaften) && (m.mannschaften as string[]).includes(String(t.name))
            && m.verein === vereinsName.get(t.club_id as string)).length,
          termine: ((termine.data || []) as Zeile[]).filter((e) => e.team_id === t.id).length,
        })).sort((a, b) => String(a.verein).localeCompare(String(b.verein), "de")
          || String(a.name).localeCompare(String(b.name), "de")),
      },
      {
        name: "Termine",
        spalten: [
          { titel: "Verein", feld: "verein", breite: 24 },
          { titel: "Mannschaft", feld: "mannschaft", breite: 18 },
          { titel: "Art", feld: "type" },
          { titel: "Titel", feld: "title", breite: 30 },
          { titel: "Beginn", feld: "starts_at", art: "zeitpunkt" },
          { titel: "Ende", feld: "ends_at", art: "zeitpunkt" },
          { titel: "Ort", feld: "location", breite: 26 },
          { titel: "Status", feld: "status" },
          { titel: "Heim/Auswärts", feld: "home_away" },
          { titel: "Gegner", feld: "opponent" },
          { titel: "Tore Heim", feld: "home_score", art: "zahl" },
          { titel: "Tore Auswärts", feld: "away_score", art: "zahl" },
          { titel: "Teil einer Reihe", feld: "reihe", art: "ja_nein" },
        ],
        zeilen: ((termine.data || []) as Zeile[]).map((e): Zeile => ({
          ...e,
          verein: vereinsName.get(e.club_id as string) ?? "",
          mannschaft: e.team_id ? (teamName.get(e.team_id as string) ?? "") : "",
          reihe: !!e.series_id,
        })).sort((a, b) => String(b.starts_at ?? "").localeCompare(String(a.starts_at ?? ""))),
      },
      {
        name: "Abos",
        spalten: [
          { titel: "Verein", feld: "verein", breite: 26 },
          { titel: "Tarif", feld: "tarif" },
          { titel: "Abrechnung", feld: "interval" },
          { titel: "Preis", feld: "preis", art: "geld" },
          { titel: "Zahlweg", feld: "provider" },
          { titel: "Status", feld: "status" },
          { titel: "Zeitraum von", feld: "current_period_start", art: "datum" },
          { titel: "Zeitraum bis", feld: "current_period_end", art: "datum" },
          { titel: "Kündigt zum Ende", feld: "cancel_at_period_end", art: "ja_nein" },
          { titel: "Letzte Zahlung", feld: "last_payment_at", art: "zeitpunkt" },
        ],
        zeilen: ((abos.data || []) as Zeile[]).map((a) => {
          const plan = planName.get(a.plan_id as string) as Zeile | undefined;
          return {
            ...a,
            verein: vereinsName.get(a.club_id as string) ?? "",
            tarif: plan?.name ?? plan?.code ?? "",
            interval: plan?.interval ?? "",
            preis: plan?.price_cents != null ? zahl(plan.price_cents) / 100 : null,
          };
        }).sort((a, b) => String(a.verein).localeCompare(String(b.verein), "de")),
      },
      {
        name: "Zugangsanfragen",
        spalten: [
          { titel: "Verein", feld: "club_name", breite: 26 },
          { titel: "Ansprechpartner", feld: "contact_name", breite: 24 },
          { titel: "E-Mail", feld: "contact_email", breite: 30 },
          { titel: "Telefon", feld: "contact_phone" },
          { titel: "Erwartete Zugänge", feld: "expected_accounts", art: "zahl" },
          { titel: "Status", feld: "status" },
          { titel: "Quelle", feld: "quelle" },
          { titel: "Rechnungsnummer", feld: "rechnungsnummer" },
          { titel: "Betrag", feld: "betrag", art: "geld" },
          { titel: "Zahlweise", feld: "zahlweise" },
          { titel: "Eingegangen am", feld: "created_at", art: "zeitpunkt" },
          { titel: "Freigeschaltet am", feld: "freigeschaltet_am", art: "zeitpunkt" },
          { titel: "Ablehnungsgrund", feld: "ablehnungsgrund", breite: 30 },
        ],
        zeilen: ((anfragen.data || []) as Zeile[])
          .sort((a, b) => String(b.created_at ?? "").localeCompare(String(a.created_at ?? ""))),
      },
      {
        name: "Anzeigen",
        spalten: [
          { titel: "Herkunft", feld: "herkunft" },
          { titel: "Verein", feld: "verein", breite: 24 },
          { titel: "Platz", feld: "platz" },
          { titel: "Titel", feld: "titel", breite: 28 },
          { titel: "Text", feld: "text", breite: 40 },
          { titel: "Ziel", feld: "ziel_url", breite: 34 },
          { titel: "Telefon", feld: "telefon" },
          { titel: "E-Mail", feld: "email", breite: 26 },
          { titel: "Läuft von", feld: "laeuft_von", art: "datum" },
          { titel: "Läuft bis", feld: "laeuft_bis", art: "datum" },
          { titel: "Aktiv", feld: "aktiv", art: "ja_nein" },
          { titel: "Einblendungen", feld: "impressionen", art: "zahl" },
          { titel: "Klicks", feld: "klicks", art: "zahl" },
          { titel: "Klickrate", feld: "klickrate", art: "prozent" },
        ],
        zeilen: ((anzeigen.data || []) as Zeile[]).map((a): Zeile => ({
          ...a,
          herkunft: a.club_id ? "Sponsor des Vereins" : "Werbung des Betreibers",
          verein: a.club_id ? (vereinsName.get(a.club_id as string) ?? "") : "— gilt überall —",
          /* Die Klickrate steht nur da, wo sie etwas bedeutet. Bei zwölf
             Einblendungen ist "25 %" kein Wert, sondern ein Zufall - und in
             einer Mappe, die an ein Unternehmen geht, eine Behauptung, die
             beim naechsten Mal zusammenbricht. */
          klickrate: Number(a.impressionen) >= 20
            ? Math.round((Number(a.klicks) / Number(a.impressionen)) * 1000) / 10
            : null,
        })),
      },
      {
        /* Die Tageszahlen. Das ist das Blatt, das man einem Unternehmen in die
           Hand gibt: Es beantwortet "wann" und "was wurde angetippt", und beides
           ohne Bezug zu einzelnen Mitgliedern - gezaehlt wird als Tagessumme. */
        name: "Anzeigen je Tag",
        hinweis: "Tagessummen der letzten zwölf Monate, je Anzeige, Verein und Element. Keine Angaben zu einzelnen Mitgliedern.",
        spalten: [
          { titel: "Tag", feld: "tag", art: "datum" },
          { titel: "Anzeige", feld: "anzeige", breite: 28 },
          { titel: "Platz", feld: "platz" },
          { titel: "Verein", feld: "verein", breite: 24 },
          { titel: "Element", feld: "element_name" },
          { titel: "Einblendungen", feld: "impressionen", art: "zahl" },
          { titel: "Klicks", feld: "klicks", art: "zahl" },
        ],
        zeilen: ((statistik.data || []) as Zeile[]).map((z): Zeile => ({
          ...z,
          anzeige: anzeigenName.get(z.anzeige_id as string) ?? "",
          platz: PLATZ_NAMEN[anzeigenPlatz.get(z.anzeige_id as string) ?? ""] ?? "",
          verein: vereinsName.get(z.club_id as string) ?? "",
          element_name: ELEMENT_NAMEN[z.element as string] ?? z.element,
        })),
      },
    ];

    const mappe = mappeBauen(blaetter, erzeugtAm);
    /* Der Zeitpunkt als echtes Datum in der Uebersicht - er wird oben mit
       null angelegt, weil die Spalte sonst als Zahl formatiert wuerde. */
    const uebersicht = mappe.getWorksheet("Übersicht");
    if (uebersicht) {
      const zelle = uebersicht.getCell("B3");
      zelle.value = erzeugtAm;
      zelle.numFmt = "DD.MM.YYYY HH:mm";
    }

    const puffer = await mappe.xlsx.writeBuffer();
    return new NextResponse(puffer as ArrayBuffer, {
      headers: {
        "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "Content-Disposition": `attachment; filename="${dateiname(erzeugtAm)}"`,
        "Cache-Control": "no-store",
      },
    });
  } catch (fehler) {
    console.error("Export fehlgeschlagen", fehler);
    return NextResponse.json({ error: "Der Export konnte nicht erstellt werden." }, { status: 500 });
  }
}
