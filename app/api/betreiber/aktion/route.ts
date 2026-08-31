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

  /* Eigene Werbung des Betreibers. club_id bleibt null - solche Anzeigen
     gelten in jedem Verein und treten zurueck, sobald ein Verein einen eigenen
     Sponsor auf denselben Platz setzt. */
  if (daten.art === "anzeige") {
    const PLAETZE = ["dashboard_top", "dashboard_bottom", "events_header", "profile_bottom"];
    if (daten.entfernen) {
      if (!istUuid(daten.anzeige)) return NextResponse.json({ error: "Keine Anzeige gewählt." }, { status: 400 });
      const { error } = await admin.from("anzeigen").delete().eq("id", daten.anzeige).is("club_id", null);
      if (error) return NextResponse.json({ error: "Die Anzeige konnte nicht entfernt werden." }, { status: 500 });
      await protokollieren("anzeige:entfernt", null, { anzeige: daten.anzeige });
      return NextResponse.json({ ok: true });
    }

    const platz = typeof daten.platz === "string" && PLAETZE.includes(daten.platz) ? daten.platz : null;
    const titel = typeof daten.titel === "string" ? daten.titel.trim().slice(0, 120) : "";
    if (!platz) return NextResponse.json({ error: "Unbekannter Werbeplatz." }, { status: 400 });
    if (!titel) return NextResponse.json({ error: "Ohne Titel geht es nicht." }, { status: 400 });

    const text = (w: unknown, max: number) => (typeof w === "string" && w.trim() ? w.trim().slice(0, max) : null);
    const satz = {
      club_id: null,
      platz,
      titel,
      text: text(daten.text, 400),
      ziel_url: text(daten.ziel_url, 500),
      aktiv: daten.aktiv !== false,
      laeuft_bis: text(daten.laeuft_bis, 40) ? new Date(`${daten.laeuft_bis}T23:59:59`).toISOString() : null,
    };
    const { error } = istUuid(daten.anzeige)
      ? await admin.from("anzeigen").update(satz).eq("id", daten.anzeige).is("club_id", null)
      : await admin.from("anzeigen").insert(satz);
    if (error) {
      console.error("Anzeige konnte nicht gespeichert werden", error);
      return NextResponse.json({ error: error.message || "Die Anzeige konnte nicht gespeichert werden." }, { status: 500 });
    }
    await protokollieren("anzeige", null, satz);
    return NextResponse.json({ ok: true });
  }

  if (daten.art === "guthaben") {
    if (!istUuid(daten.verein)) return NextResponse.json({ error: "Kein Verein gewählt." }, { status: 400 });
    const { data, error } = await admin.rpc("guthaben_einloesen", {
      target_club: daten.verein,
      monate: typeof daten.monate === "number" && daten.monate > 0 ? Math.trunc(daten.monate) : null,
    });
    if (error) {
      console.error("Guthaben konnte nicht eingeloest werden", error);
      return NextResponse.json({ error: "Das Guthaben konnte nicht eingelöst werden." }, { status: 500 });
    }
    await protokollieren("guthaben", daten.verein, { ergebnis: data?.[0] || null });
    return NextResponse.json({ ok: true, ergebnis: data?.[0] || null });
  }

  /* Ein Schritt im Rechnungsablauf.
     Welcher Schritt von wo aus moeglich ist, entscheidet die Datenbank
     (anfrage_weiter) - nicht diese Route und schon gar nicht der Browser. */
  const SCHRITTE = ["offen", "rechnung_erstellt", "rechnung_versendet", "rechnung_bezahlt", "abgelehnt"];
  if (daten.art === "anfrage") {
    if (!istUuid(daten.anfrage)) return NextResponse.json({ error: "Keine Anfrage gewählt." }, { status: 400 });
    const status = typeof daten.status === "string" && SCHRITTE.includes(daten.status) ? daten.status : null;
    if (!status) return NextResponse.json({ error: "Unbekannter Schritt." }, { status: 400 });

    const summe = daten.betrag === "" || daten.betrag === null || daten.betrag === undefined
      ? null : Number(daten.betrag);
    if (summe !== null && (!Number.isFinite(summe) || summe < 0)) {
      return NextResponse.json({ error: "Der Betrag ist ungültig." }, { status: 400 });
    }

    const { data, error } = await admin.rpc("anfrage_weiter", {
      ziel_anfrage: daten.anfrage,
      neuer_status: status,
      nummer: typeof daten.rechnungsnummer === "string" ? daten.rechnungsnummer.trim().slice(0, 120) || null : null,
      summe,
      art: daten.zahlweise === "monatlich" || daten.zahlweise === "jaehrlich" ? daten.zahlweise : null,
      grund: typeof daten.grund === "string" ? daten.grund.trim().slice(0, 500) || null : null,
    });
    if (error) {
      console.error("Schritt nicht möglich", error);
      return NextResponse.json({ error: error.message || "Der Schritt war nicht möglich." }, { status: 400 });
    }
    await protokollieren(`anfrage:${status}`, istUuid(daten.verein) ? daten.verein : null,
      { anfrage: daten.anfrage, rechnungsnummer: daten.rechnungsnummer ?? null, betrag: summe });
    return NextResponse.json({ ok: true, ergebnis: data?.[0] || null });
  }

  /* Die Bestaetigungsmail ist raus. Eigener Schritt, weil sie nach dem
     Freischalten kommt und von einem Menschen geschrieben wird. */
  if (daten.art === "bestaetigung") {
    if (!istUuid(daten.anfrage)) return NextResponse.json({ error: "Keine Anfrage gewählt." }, { status: 400 });
    const { data, error } = await admin.rpc("bestaetigung_vermerken", { ziel_anfrage: daten.anfrage });
    if (error) return NextResponse.json({ error: "Konnte nicht vermerkt werden." }, { status: 500 });
    if (!data) return NextResponse.json({ error: "Das geht erst, wenn der Verein freigeschaltet ist." }, { status: 400 });
    await protokollieren("anfrage:bestaetigung", null, { anfrage: daten.anfrage });
    return NextResponse.json({ ok: true });
  }

  /* Alles ueber einen Verein: Mitglieder, Zielgruppe, Sponsoren. */
  if (daten.art === "verein") {
    if (!istUuid(daten.verein)) return NextResponse.json({ error: "Kein Verein gewählt." }, { status: 400 });
    const [mitglieder, zielgruppe, sponsoren] = await Promise.all([
      admin.rpc("mitglieder_eines_vereins", { target_club: daten.verein }),
      admin.rpc("zielgruppe_eines_vereins", { target_club: daten.verein }),
      admin.rpc("sponsoren_eines_vereins", { target_club: daten.verein }),
    ]);
    if (mitglieder.error || zielgruppe.error || sponsoren.error) {
      console.error("Vereinsansicht", mitglieder.error || zielgruppe.error || sponsoren.error);
      return NextResponse.json({ error: "Die Vereinsansicht konnte nicht geladen werden." }, { status: 500 });
    }
    /* Bilder liegen im Speicher unter einem Pfad; die Konsole braucht eine
       abrufbare Adresse. Der Eimer ist oeffentlich lesbar. */
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL || "";
    const sponsorenMitBild = (sponsoren.data || []).map((a: Record<string, unknown>) => ({
      ...a,
      bild_url: a.bild_pfad ? `${url}/storage/v1/object/public/sponsor-bilder/${a.bild_pfad}` : null,
    }));
    return NextResponse.json({
      mitglieder: mitglieder.data || [],
      zielgruppe: zielgruppe.data?.[0] || null,
      sponsoren: sponsorenMitBild,
    });
  }

  return NextResponse.json({ error: "Unbekannte Aktion." }, { status: 400 });
}
