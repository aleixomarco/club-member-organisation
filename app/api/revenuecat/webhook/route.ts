import { timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

// RevenueCat-Events, die den Abo-Status ändern.
// Referenz: https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
const STATUS_BY_EVENT: Record<string, string> = {
  INITIAL_PURCHASE: "active",
  RENEWAL: "active",
  UNCANCELLATION: "active",
  PRODUCT_CHANGE: "active",
  CANCELLATION: "cancelled",
  EXPIRATION: "expired",
  BILLING_ISSUE: "past_due",
};

const PROVIDER_BY_STORE: Record<string, string> = {
  APP_STORE: "apple",
  MAC_APP_STORE: "apple",
  PLAY_STORE: "google_play",
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/* Zeitkonstanter Vergleich: Ein einfaches === verrät über die Antwortzeit,
   wie viele Zeichen des Secrets stimmen. */
function secretMatches(provided: string, expected: string) {
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

export async function POST(request: Request) {
  const secret = process.env.REVENUECAT_WEBHOOK_SECRET;
  if (!secret) return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  const authHeader = request.headers.get("authorization") || "";
  if (!secretMatches(authHeader, secret)) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const body = await request.json().catch(() => null);
  const event = body?.event;
  if (!event) return NextResponse.json({ error: "Invalid payload" }, { status: 400 });

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  // app_user_id wird clientseitig gesetzt — beim Vereinsabo die Vereins-ID, beim
  // persönlichen Basis-Abo die Profil-ID (siehe lib/revenuecat.ts). Welche der beiden
  // gemeint ist, verrät die Produkt-ID: sie entspricht dem Plancode, und member_*
  // gehört zum Mitglied, club_* zum Verein.
  const ownerId: string | undefined = event.app_user_id;
  const productId: string | undefined = event.product_id;
  const status = STATUS_BY_EVENT[event.type];
  const provider = PROVIDER_BY_STORE[event.store] || "apple";

  // Jedes Event festhalten, auch die nicht verarbeiteten — sonst fehlt bei einer
  // Reklamation der Nachweis, was der Store wann gemeldet hat.
  // Idempotenz: RevenueCat stellt Events mehrfach zu.
  await admin.from("payment_events").upsert({
    provider,
    provider_event_id: event.id,
    event_type: event.type,
    provider_subscription_id: event.original_transaction_id || event.transaction_id || null,
    verified: true,
    payload: event,
    processed_at: new Date().toISOString(),
  }, { onConflict: "provider,provider_event_id", ignoreDuplicates: true });

  /* TRANSFER: Ein Abo wechselt den Besitzer.
     
     RevenueCat kennt immer nur EINE Kennung gleichzeitig. Kauft jemand, waehrend
     die App noch auf eine andere Kennung angemeldet ist - etwa auf die anonyme
     vor der Anmeldung -, und wird danach umgemeldet, schiebt RevenueCat das Abo
     hinterher und meldet es als TRANSFER.
     
     Diese Ereignisse fielen bisher durch: Sie stehen in keiner der beiden
     Zuordnungstabellen, und sie tragen kein app_user_id, sondern die beiden
     Listen transferred_from und transferred_to. Beides zusammen hiess: als
     "ignoriert" abgehakt, das Abo blieb beim alten Besitzer haengen.
     
     Ein TRANSFER traegt weder Produkt noch Laufzeit. Es laesst sich daraus also
     kein Abo anlegen - wohl aber ein vorhandenes umhaengen, und genau das ist
     gemeint. */
  if (event.type === "TRANSFER") {
    const von: string[] = Array.isArray(event.transferred_from) ? event.transferred_from : [];
    const nach: string | undefined = Array.isArray(event.transferred_to) ? event.transferred_to[0] : undefined;
    if (!nach || !UUID.test(nach) || von.length === 0) {
      return NextResponse.json({ received: true, ignored: "transfer_unklar" });
    }

    const alteKennungen = von.filter((k) => UUID.test(k));
    if (alteKennungen.length === 0) {
      /* Die alte Kennung ist keine UUID - typischerweise die anonyme Kennung,
         die RevenueCat vor der ersten Anmeldung vergibt. Dann gibt es bei uns
         nichts umzuhaengen; das Abo kommt mit dem naechsten RENEWAL ordentlich
         an. */
      return NextResponse.json({ received: true, ignored: "transfer_ohne_alten_besitzer" });
    }

    const [{ data: verein }, { data: profil }] = await Promise.all([
      admin.from("clubs").select("id").eq("id", nach).maybeSingle(),
      admin.from("profiles").select("id").eq("id", nach).maybeSingle(),
    ]);

    if (verein) {
      const { error } = await admin.from("club_subscriptions").update({ club_id: nach }).in("club_id", alteKennungen);
      if (error) {
        console.error(`RevenueCat: Abo-Uebertrag auf Verein ${nach} fehlgeschlagen (Event ${event.id})`, error);
        return NextResponse.json({ error: "Could not transfer subscription" }, { status: 500 });
      }
      return NextResponse.json({ received: true, transferred: "club" });
    }
    if (profil) {
      const { error } = await admin.from("user_subscriptions").update({ profile_id: nach }).in("profile_id", alteKennungen);
      if (error) {
        console.error(`RevenueCat: Abo-Uebertrag auf Profil ${nach} fehlgeschlagen (Event ${event.id})`, error);
        return NextResponse.json({ error: "Could not transfer subscription" }, { status: 500 });
      }
      return NextResponse.json({ received: true, transferred: "member" });
    }

    console.error(`RevenueCat: Uebertrag auf unbekannte Kennung ${nach} (Event ${event.id})`);
    return NextResponse.json({ received: true, ignored: "transfer_ziel_unbekannt" });
  }

  if (!ownerId || !status) return NextResponse.json({ received: true, ignored: true });

  /* Sandbox-Käufe werden verbucht wie echte. Das klingt nach einer offenen Tür,
     ist aber keine: Eine aus dem App Store geladene App handelt immer über die
     Produktivumgebung. Ein SANDBOX-Ereignis kann nur aus einem Entwicklungs-
     oder TestFlight-Build stammen oder aus Apples Prüfung — und wer davon
     kauft, soll den Kauf auch freigeschaltet bekommen.

     Vorher wurden diese Käufe verworfen. Der Prüfer bei Apple hätte damit
     "Kauf erfolgreich" gelesen, während der Verein unverändert ohne Abo
     dagestanden hätte: ein Kauf, der nichts bewirkt, und damit ein Verstoss
     gegen Richtlinie 2.1.

     Unterscheidbar bleiben beide Umgebungen trotzdem, denn payment_events hält
     das vollständige Ereignis samt environment fest — für die Buchhaltung
     zählt also weiterhin nur, was aus PRODUCTION kam. Notfalls lässt sich die
     Annahme mit REVENUECAT_BLOCK_SANDBOX=true wieder abstellen. */
  if (event.environment === "SANDBOX" && process.env.REVENUECAT_BLOCK_SANDBOX === "true") {
    return NextResponse.json({ received: true, ignored: "sandbox" });
  }

  if (!productId) return NextResponse.json({ received: true });
  const { data: plan } = await admin.from("subscription_plans").select("id").eq("code", productId).maybeSingle();
  if (!plan) return NextResponse.json({ received: true, ignored: "unknown_product" });

  const providerSubscriptionId = event.original_transaction_id || event.transaction_id;
  if (!providerSubscriptionId) return NextResponse.json({ received: true });

  /* Die Kennung muss zur Produktart passen. Sie kommt vom Gerät und kann durch
     eine falsch zugeordnete Wiederherstellung oder ein TRANSFER-Event die
     falsche Art haben. Ungeprüft würde eine Profil-ID als club_id geschrieben —
     im besten Fall ein Fremdschlüsselfehler, im schlechtesten ein Abo, das dem
     falschen Verein gehört. */
  const forMember = productId.startsWith("member_");
  if (!UUID.test(ownerId)) return NextResponse.json({ received: true, ignored: "invalid_owner" });

  const ownerTable = forMember ? "profiles" : "clubs";
  const { data: owner } = await admin.from(ownerTable).select("id").eq("id", ownerId).maybeSingle();
  if (!owner) {
    // Kein 500: Ein erneuter Zustellversuch würde daran nichts ändern.
    console.error(`RevenueCat: ${ownerTable}-Eintrag ${ownerId} existiert nicht (Produkt ${productId}, Event ${event.id})`);
    return NextResponse.json({ received: true, ignored: "owner_not_found" });
  }

  const shared = {
    plan_id: plan.id,
    provider,
    provider_subscription_id: providerSubscriptionId,
    status,
    current_period_start: event.purchased_at_ms ? new Date(event.purchased_at_ms).toISOString() : null,
    current_period_end: event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null,
    last_payment_at: event.type === "INITIAL_PURCHASE" || event.type === "RENEWAL" ? new Date().toISOString() : undefined,
    cancel_at_period_end: event.type === "CANCELLATION",
    cancelled_at: event.type === "CANCELLATION" ? new Date().toISOString() : null,
  };

  const { error } = forMember
    ? await admin.from("user_subscriptions").upsert({ profile_id: ownerId, ...shared }, { onConflict: "provider,provider_subscription_id" })
    : await admin.from("club_subscriptions").upsert({ club_id: ownerId, ...shared }, { onConflict: "provider,provider_subscription_id" });

  /* Fehler nicht verschlucken: Mit 200 hakt RevenueCat das Event als zugestellt
     ab und versucht es nie wieder — der Kauf wäre bezahlt, aber nicht
     freigeschaltet. Mit 500 wird erneut zugestellt. */
  if (error) {
    console.error(`RevenueCat: Abo konnte nicht gespeichert werden (Event ${event.id})`, error);
    return NextResponse.json({ error: "Could not store subscription" }, { status: 500 });
  }

  return NextResponse.json({ received: true });
}
