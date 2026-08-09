import { NextResponse } from "next/server";
import { verifyPayPalWebhook } from "@/lib/paypal";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

const statusByEvent: Record<string, string> = {
  "BILLING.SUBSCRIPTION.ACTIVATED": "active",
  "BILLING.SUBSCRIPTION.UPDATED": "active",
  "BILLING.SUBSCRIPTION.SUSPENDED": "suspended",
  "BILLING.SUBSCRIPTION.CANCELLED": "cancelled",
  "BILLING.SUBSCRIPTION.EXPIRED": "expired",
  "BILLING.SUBSCRIPTION.PAYMENT.FAILED": "past_due",
  "PAYMENT.SALE.COMPLETED": "active",
  "PAYMENT.SALE.REFUNDED": "refunded",
  "PAYMENT.SALE.REVERSED": "refunded",
};

export async function POST(request: Request) {
  const event = await request.json();
  const verified = await verifyPayPalWebhook(request.headers, event).catch(() => false);
  if (!verified) return NextResponse.json({ error: "Invalid signature" }, { status: 400 });

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }
  const resource = event.resource || {};
  // Payment events carry the subscription as billing_agreement_id; resource.id is the sale id.
  const subscriptionId = resource.billing_agreement_id || resource.id;
  await admin.from("payment_events").upsert({
    provider: "paypal", provider_event_id: event.id, event_type: event.event_type,
    provider_subscription_id: subscriptionId || null, verified: true, payload: event, processed_at: new Date().toISOString(),
  }, { onConflict: "provider,provider_event_id", ignoreDuplicates: true });

  /* custom_id trägt beim Vereinsabo die Vereins-ID, beim persönlichen Basis-Abo die
     Profil-ID. Welche der beiden gemeint ist, verrät die PayPal-Plan-ID — deshalb
     wird sie hier auf den internen Plancode abgebildet. */
  const ownerId = resource.custom_id;
  const planId = resource.plan_id;
  const planCodes: Record<string, string> = {
    [process.env.PAYPAL_CLUB_BASIC_MONTHLY_PLAN_ID || "missing-club-basic-monthly"]: "club_basic_monthly",
    [process.env.PAYPAL_CLUB_BASIC_YEARLY_PLAN_ID || "missing-club-basic-yearly"]: "club_basic_yearly",
    [process.env.PAYPAL_CLUB_PREMIUM_MONTHLY_PLAN_ID || "missing-club-premium-monthly"]: "club_premium_monthly",
    [process.env.PAYPAL_CLUB_PREMIUM_YEARLY_PLAN_ID || "missing-club-premium-yearly"]: "club_premium_yearly",
    [process.env.PAYPAL_MEMBER_MONTHLY_PLAN_ID || "missing-member-monthly"]: "member_monthly",
    [process.env.PAYPAL_MEMBER_YEARLY_PLAN_ID || "missing-member-yearly"]: "member_yearly",
  };

  if (subscriptionId && ownerId && planId && event.event_type === "BILLING.SUBSCRIPTION.ACTIVATED") {
    const code = planCodes[planId];
    if (!code) return NextResponse.json({ error: "Unknown PayPal plan" }, { status: 400 });
    const { data: plan } = await admin.from("subscription_plans").select("id").eq("code", code).single();
    if (plan) {
      const shared = {
        plan_id: plan.id, provider: "paypal", provider_subscription_id: subscriptionId,
        status: "active",
        current_period_start: resource.start_time || new Date().toISOString(),
        current_period_end: resource.billing_info?.next_billing_time || null,
        last_payment_at: resource.billing_info?.last_payment?.time || null,
      };
      if (code.startsWith("member_")) {
        await admin.from("user_subscriptions").upsert({ profile_id: ownerId, ...shared },
          { onConflict: "provider,provider_subscription_id" });
      } else {
        await admin.from("club_subscriptions").upsert({ club_id: ownerId, ...shared },
          { onConflict: "provider,provider_subscription_id" });
      }
    }
  } else if (subscriptionId && statusByEvent[event.event_type]) {
    const subscriptionUpdate: Record<string, string | null> = {
      status: statusByEvent[event.event_type],
      cancelled_at: event.event_type === "BILLING.SUBSCRIPTION.CANCELLED" ? new Date().toISOString() : null,
    };
    if (event.event_type === "PAYMENT.SALE.COMPLETED") {
      subscriptionUpdate.last_payment_at = new Date().toISOString();
    }
    if (resource.billing_info?.next_billing_time) {
      subscriptionUpdate.current_period_end = resource.billing_info.next_billing_time;
    }
    /* Folge-Ereignisse (Zahlung, Kündigung, Ablauf) tragen keine Plan-ID mehr. Statt
       zu raten, wird in beiden Tabellen aktualisiert — die Abo-ID ist eindeutig, es
       trifft also immer nur eine davon. */
    await Promise.all([
      admin.from("club_subscriptions").update(subscriptionUpdate)
        .eq("provider", "paypal").eq("provider_subscription_id", subscriptionId),
      admin.from("user_subscriptions").update(subscriptionUpdate)
        .eq("provider", "paypal").eq("provider_subscription_id", subscriptionId),
    ]);
  }
  return NextResponse.json({ received: true });
}
