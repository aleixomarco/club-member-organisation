import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

// RevenueCat-Events, die den Abo-Status in club_subscriptions ändern.
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

export async function POST(request: Request) {
  const secret = process.env.REVENUECAT_WEBHOOK_SECRET;
  if (!secret) return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  const authHeader = request.headers.get("authorization") || "";
  if (authHeader !== secret) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const body = await request.json().catch(() => null);
  const event = body?.event;
  if (!event) return NextResponse.json({ error: "Invalid payload" }, { status: 400 });

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }

  // app_user_id wird clientseitig via Purchases.logIn(clubId) gesetzt — siehe lib/revenuecat.ts.
  const clubId: string | undefined = event.app_user_id;
  const productId: string | undefined = event.product_id;
  const status = STATUS_BY_EVENT[event.type];
  if (!clubId || !status) return NextResponse.json({ received: true, ignored: true });

  // Idempotenz: jedes RevenueCat-Event hat eine eigene id, mehrfaches Zustellen ist möglich.
  await admin.from("payment_events").upsert({
    provider: PROVIDER_BY_STORE[event.store] || "apple",
    provider_event_id: event.id,
    event_type: event.type,
    provider_subscription_id: event.original_transaction_id || event.transaction_id || null,
    verified: true,
    payload: event,
    processed_at: new Date().toISOString(),
  }, { onConflict: "provider,provider_event_id", ignoreDuplicates: true });

  if (!productId) return NextResponse.json({ received: true });
  const { data: plan } = await admin.from("subscription_plans").select("id").eq("code", productId).maybeSingle();
  if (!plan) return NextResponse.json({ received: true, ignored: "unknown_product" });

  const providerSubscriptionId = event.original_transaction_id || event.transaction_id;
  if (!providerSubscriptionId) return NextResponse.json({ received: true });

  await admin.from("club_subscriptions").upsert({
    club_id: clubId,
    plan_id: plan.id,
    provider: PROVIDER_BY_STORE[event.store] || "apple",
    provider_subscription_id: providerSubscriptionId,
    status,
    current_period_start: event.purchased_at_ms ? new Date(event.purchased_at_ms).toISOString() : null,
    current_period_end: event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null,
    last_payment_at: event.type === "INITIAL_PURCHASE" || event.type === "RENEWAL" ? new Date().toISOString() : undefined,
    cancel_at_period_end: event.type === "CANCELLATION",
    cancelled_at: event.type === "CANCELLATION" ? new Date().toISOString() : null,
  }, { onConflict: "provider,provider_subscription_id" });

  return NextResponse.json({ received: true });
}
