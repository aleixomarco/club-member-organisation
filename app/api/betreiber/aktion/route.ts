import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { SITZUNGS_COOKIE, fremdeHerkunft, sitzungGueltig } from "@/lib/betreiber";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

const TARIFE = ["basic", "plus", "pro"];
const LAUFZEITEN: Record<string, string> = {
  monat: "1 month",
  quartal: "3 months",
  halbjahr: "6 months",
  jahr: "1 year",
  zwei_jahre: "2 years",
};

function istUuid(wert: unknown): wert is string {
  return typeof wert === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(wert);
}

/* Was der Betreiber tun kann.
 *
 * Alle vier Vorgänge laufen über den Dienstschlüssel — verein_freischalten()
 * und verein_sperren() sind für authenticated und anon ausdrücklich gesperrt,
 * damit sich kein Vereinsadmin selbst freischaltet. Genau deshalb gibt es diese
 * Route: Sie ist der einzige Weg dorthin, und sie führt nur über das
 * Betreiber-Passwort. */
export async function POST(request: Request) {
  const cookieSpeicher = await cookies();
  if (!sitzungGueltig(cookieSpeicher.get(SITZUNGS_COOKIE)?.value)) {
    return NextResponse.json({ error: "Nicht angemeldet." }, { status: 401 });
  }
  /* Zweiter Boden neben sameSite=lax. Die Konsole liegt auf derselben Herkunft
     wie die Vereins-App; was von dort oder von irgendwo sonst kommt, hat hier
     nichts verloren. */
  if (fremdeHerkunft(request)) {
    return NextResponse.json({ error: "Ungültige Herkunft." }, { status: 403 });
  }

  const daten = (await request.json().catch(() => null)) as Record<string, unknown> | null;
  if (!daten || typeof daten.art !== "string") {
    return NextResponse.json({ error: "Unvollständige Anfrage." }, { status: 400 });
  }

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  /* Was hier passiert, wird festgehalten.
     Das Freischalten hinterlaesst immerhin mittelbar eine Spur in
     club_subscriptions; das Sperren und das Abhaken von Anfragen praktisch
     keine. Wenn ein Verein anruft, weil er ploetzlich auf drei Zugaenge
     zurueckgefallen ist, soll es etwas nachzusehen geben. */
  const protokollieren = async (aktionsName: string, clubId: string | null, einzelheiten: Record<string, unknown>) => {
    try {
      const { data: verein } = clubId
        ? await admin.from("clubs").select("name").eq("id", clubId).maybeSingle()
        : { data: null };
      await admin.from("betreiber_protokoll").insert({
        aktion: aktionsName,
        club_id: clubId,
        club_name: verein?.name || null,
        einzelheiten,
        herkunft: request.headers.get("x-forwarded-for")?.split(",")[0].trim() || null,
      });
    } catch (fehler) {
      /* Ein misslungener Protokolleintrag darf die Aktion nicht verhindern -
         sonst waere die Buchfuehrung wichtiger als das Geschaeft. Er faellt
         aber ins Serverprotokoll, damit es auffaellt. */
      console.error("Betreiber-Protokoll konnte nicht geschrieben werden", fehler);
    }
  };

  if (daten.art === "freischalten") {
    if (!istUuid(daten.verein)) return NextResponse.json({ error: "Kein Verein gewählt." }, { status: 400 });
    const stufe = typeof daten.stufe === "string" && TARIFE.includes(daten.stufe) ? daten.stufe : "basic";
    const laufzeit = LAUFZEITEN[String(daten.laufzeit)] || "1 year";

    /* null heisst "unveraendert lassen", 0 heisst "auf die Zahl des Tarifs
       zuruecksetzen". Ein leeres Feld in der Oberflaeche darf deshalb nicht als
       0 ankommen - sonst verlaengert der Betreiber einen Verein mit 2.000
       vereinbarten Zugaengen und setzt ihn dabei stillschweigend auf 1.000. */
    const rohZugaenge = daten.zugaenge;
    const zugaenge = rohZugaenge === "" || rohZugaenge === null || rohZugaenge === undefined
      ? null
      : Math.max(0, Math.min(Math.trunc(Number(rohZugaenge)), 1000000));
    if (zugaenge !== null && !Number.isFinite(zugaenge)) {
      return NextResponse.json({ error: "Die Zahl der Zugänge ist ungültig." }, { status: 400 });
    }

    const { data, error } = await admin.rpc("verein_freischalten", {
      target_club: daten.verein,
      stufe,
      zugaenge,
      laufzeit,
      belegnummer: typeof daten.belegnummer === "string" && daten.belegnummer.trim() ? daten.belegnummer.trim().slice(0, 120) : null,
      sponsoring: typeof daten.sponsoring === "boolean" ? daten.sponsoring : null,
    });
    if (error) {
      console.error("Freischaltung fehlgeschlagen", error);
      return NextResponse.json({ error: error.message || "Die Freischaltung ist fehlgeschlagen." }, { status: 500 });
    }
    await protokollieren("freischalten", daten.verein, {
      stufe, laufzeit, zugaenge, sponsoring: daten.sponsoring ?? null,
      belegnummer: typeof daten.belegnummer === "string" ? daten.belegnummer : null,
      ergebnis: data?.[0] || null,
    });
    return NextResponse.json({ ok: true, ergebnis: data?.[0] || null });
  }

  if (daten.art === "sperren") {
    if (!istUuid(daten.verein)) return NextResponse.json({ error: "Kein Verein gewählt." }, { status: 400 });
    const { data, error } = await admin.rpc("verein_sperren", { target_club: daten.verein });
    if (error) {
      console.error("Sperren fehlgeschlagen", error);
      return NextResponse.json({ error: "Der Verein konnte nicht gesperrt werden." }, { status: 500 });
    }
    await protokollieren("sperren", daten.verein, { ergebnis: data?.[0] || null });
    return NextResponse.json({ ok: true, ergebnis: data?.[0] || null });
  }

  if (daten.art === "anfrage") {
    if (!istUuid(daten.anfrage)) return NextResponse.json({ error: "Keine Anfrage gewählt." }, { status: 400 });
    const status = daten.status === "berechnet" || daten.status === "abgelehnt" ? daten.status : null;
    if (!status) return NextResponse.json({ error: "Unbekannter Status." }, { status: 400 });
    const { error } = await admin.from("club_access_requests")
      .update({
        status,
        handled_at: new Date().toISOString(),
        handled_note: typeof daten.notiz === "string" ? daten.notiz.trim().slice(0, 500) || null : null,
      })
      .eq("id", daten.anfrage);
    if (error) {
      console.error("Anfrage konnte nicht geändert werden", error);
      return NextResponse.json({ error: "Die Anfrage konnte nicht geändert werden." }, { status: 500 });
    }
    await protokollieren(`anfrage:${status}`, null, { anfrage: daten.anfrage });
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ error: "Unbekannte Aktion." }, { status: 400 });
}
