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

  const admin = getSupabaseAdmin();
  const resource = event.resource || {};
  // Payment events carry the subscription as billing_agreement_id; resource.id is the sale id.
  const subscriptionId = resource.billing_agreement_id || resource.id;
  await admin.from("payment_events").upsert({
    provider: "paypal", provider_event_id: event.id, event_type: event.event_type,
    provider_subscription_id: subscriptionId || null, verified: true, payload: event, processed_at: new Date().toISOString(),
  }, { onConflict: "provider,provider_event_id", ignoreDuplicates: true });

  const profileId = resource.custom_id;
  const planId = resource.plan_id;
  if (subscriptionId && profileId && planId && event.event_type === "BILLING.SUBSCRIPTION.ACTIVATED") {
    const code = planId === process.env.PAYPAL_YEARLY_PLAN_ID ? "member_yearly" : "member_monthly";
    const { data: plan } = await admin.from("subscription_plans").select("id").eq("code", code).single();
    if (plan) await admin.from("user_subscriptions").upsert({
      profile_id: profileId, plan_id: plan.id, provider: "paypal", provider_subscription_id: subscriptionId,
      status: "active", current_period_start: resource.start_time || new Date().toISOString(),
    }, { onConflict: "provider,provider_subscription_id" });
  } else if (subscriptionId && statusByEvent[event.event_type]) {
    const subscriptionUpdate: Record<string, string | null> = {
      status: statusByEvent[event.event_type],
      cancelled_at: event.event_type === "BILLING.SUBSCRIPTION.CANCELLED" ? new Date().toISOString() : null,
    };
    if (event.event_type === "PAYMENT.SALE.COMPLETED") {
      subscriptionUpdate.last_payment_at = new Date().toISOString();
    }
    await admin.from("user_subscriptions").update(subscriptionUpdate)
      .eq("provider", "paypal").eq("provider_subscription_id", subscriptionId);
  }
  return NextResponse.json({ received: true });
}
