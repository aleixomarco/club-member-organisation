const isLive = process.env.PAYPAL_ENVIRONMENT === "live";
const apiBase = isLive ? "https://api-m.paypal.com" : "https://api-m.sandbox.paypal.com";

export async function paypalAccessToken() {
  const clientId = process.env.PAYPAL_CLIENT_ID;
  const secret = process.env.PAYPAL_CLIENT_SECRET;
  if (!clientId || !secret) throw new Error("PayPal server configuration is missing");
  const authorization = Buffer.from(`${clientId}:${secret}`).toString("base64");
  const response = await fetch(`${apiBase}/v1/oauth2/token`, {
    method: "POST",
    headers: { Authorization: `Basic ${authorization}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: "grant_type=client_credentials",
    cache: "no-store",
  });
  if (!response.ok) throw new Error("PayPal authentication failed");
  return (await response.json()).access_token as string;
}

/* Der Verein bucht eine Groessenstufe (club_*). Mitglieder zahlen nichts mehr.
 *
 * member_monthly und member_yearly bleiben nur als Altbestand stehen: Zu ihnen
 * koennen in der Produktion noch laufende PayPal-Abos gehoeren, deren Ereignisse
 * der Webhook weiterhin zuordnen koennen muss. Neu abgeschlossen werden koennen
 * sie nicht - der Weg dorthin ist in app/api/paypal/subscriptions geschlossen.
 *
 * club_premium_* ist ebenfalls Altbestand aus dem vorherigen Modell und wird in
 * der Datenbank auf die Stufe "plus" abgebildet. */
export type PayPalClubPlanCode =
  | "club_basic_monthly" | "club_basic_yearly"
  | "club_plus_monthly"  | "club_plus_yearly"
  | "club_pro_monthly"   | "club_pro_yearly"
  | "club_premium_monthly" | "club_premium_yearly";
export type PayPalMemberPlanCode = "member_monthly" | "member_yearly";
export type PayPalPlanCode = PayPalClubPlanCode | PayPalMemberPlanCode;

export function paypalPlanId(code: PayPalPlanCode) {
  const variables: Record<PayPalPlanCode, string | undefined> = {
    club_basic_monthly: process.env.PAYPAL_CLUB_BASIC_MONTHLY_PLAN_ID,
    club_basic_yearly: process.env.PAYPAL_CLUB_BASIC_YEARLY_PLAN_ID,
    club_plus_monthly: process.env.PAYPAL_CLUB_PLUS_MONTHLY_PLAN_ID,
    club_plus_yearly: process.env.PAYPAL_CLUB_PLUS_YEARLY_PLAN_ID,
    club_pro_monthly: process.env.PAYPAL_CLUB_PRO_MONTHLY_PLAN_ID,
    club_pro_yearly: process.env.PAYPAL_CLUB_PRO_YEARLY_PLAN_ID,
    club_premium_monthly: process.env.PAYPAL_CLUB_PREMIUM_MONTHLY_PLAN_ID,
    club_premium_yearly: process.env.PAYPAL_CLUB_PREMIUM_YEARLY_PLAN_ID,
    member_monthly: process.env.PAYPAL_MEMBER_MONTHLY_PLAN_ID,
    member_yearly: process.env.PAYPAL_MEMBER_YEARLY_PLAN_ID,
  };
  const value = variables[code];
  if (!value) throw new Error(`PayPal plan is missing: ${code}`);
  return value;
}

export const isMemberPlanCode = (code: string): code is PayPalMemberPlanCode =>
  code === "member_monthly" || code === "member_yearly";

export async function verifyPayPalWebhook(headers: Headers, event: unknown) {
  const webhookId = process.env.PAYPAL_WEBHOOK_ID;
  if (!webhookId) throw new Error("PayPal webhook ID is missing");
  const token = await paypalAccessToken();
  const response = await fetch(`${apiBase}/v1/notifications/verify-webhook-signature`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      transmission_id: headers.get("paypal-transmission-id"),
      transmission_time: headers.get("paypal-transmission-time"),
      cert_url: headers.get("paypal-cert-url"),
      auth_algo: headers.get("paypal-auth-algo"),
      transmission_sig: headers.get("paypal-transmission-sig"),
      webhook_id: webhookId,
      webhook_event: event,
    }),
  });
  if (!response.ok) return false;
  return (await response.json()).verification_status === "SUCCESS";
}

export async function cancelPayPalSubscription(subscriptionId: string, reason = "Account deleted by user") {
  const token = await paypalAccessToken();
  const response = await fetch(`${apiBase}/v1/billing/subscriptions/${encodeURIComponent(subscriptionId)}/cancel`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ reason }),
    cache: "no-store",
  });
  if (!response.ok && response.status !== 422) throw new Error("PayPal cancellation failed");
}

export async function getPayPalSubscription(subscriptionId: string) {
  const token = await paypalAccessToken();
  const response = await fetch(`${apiBase}/v1/billing/subscriptions/${encodeURIComponent(subscriptionId)}`, {
    headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    cache: "no-store",
  });
  if (!response.ok) throw new Error("PayPal subscription could not be loaded");
  return response.json();
}
