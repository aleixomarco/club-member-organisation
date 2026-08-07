import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "@/lib/supabase-admin";
import { getPayPalSubscription, paypalPlanId, cancelPayPalSubscription, type PayPalPlanCode } from "@/lib/paypal";

export const dynamic = "force-dynamic";

const MANAGE_CLUB_ROLES = ["vereinsadmin", "sysadmin", "vorstand", "geschaeftsfuehrung"];

async function authenticatedUser(request: Request) {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!token || !url || !key) return null;
  const authClient = createClient(url, key, { auth: { persistSession: false } });
  const { data: { user } } = await authClient.auth.getUser(token);
  return user || null;
}

async function canManageClub(admin: ReturnType<typeof getSupabaseAdmin>, profileId: string, clubId: string) {
  const { data: membership } = await admin.from("club_memberships")
    .select("id,status").eq("profile_id", profileId).eq("club_id", clubId).maybeSingle();
  if (!membership || membership.status !== "active") return false;
  const { data: roles } = await admin.from("membership_roles")
    .select("role").eq("membership_id", membership.id).in("role", MANAGE_CLUB_ROLES);
  return Boolean(roles?.length);
}

const selection = `
  id, provider, provider_subscription_id, status, current_period_start, current_period_end,
  cancel_at_period_end, cancelled_at, last_payment_at, created_at, updated_at,
  subscription_plans ( code, name, interval, price_cents, currency )
`;

function safeGetSupabaseAdmin() {
  try {
    return { admin: getSupabaseAdmin() };
  } catch {
    return { error: NextResponse.json({ error: "Server configuration error" }, { status: 500 }) };
  }
}

export async function GET(request: Request) {
  const user = await authenticatedUser(request);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { admin, error: adminError } = safeGetSupabaseAdmin();
  if (adminError) return adminError;
  const clubId = new URL(request.url).searchParams.get("clubId");

  const { data: member, error: memberError } = await admin.from("user_subscriptions")
    .select(selection).eq("profile_id", user.id).order("created_at", { ascending: false });
  if (memberError) return NextResponse.json({ error: "Subscriptions could not be loaded" }, { status: 500 });

  let club: unknown[] = [];
  if (clubId && await canManageClub(admin, user.id, clubId)) {
    const { data, error } = await admin.from("club_subscriptions")
      .select(selection).eq("club_id", clubId).order("created_at", { ascending: false });
    if (error) return NextResponse.json({ error: "Club subscriptions could not be loaded" }, { status: 500 });
    club = data || [];
  }
  return NextResponse.json({ member: member || [], club });
}

export async function POST(request: Request) {
  const user = await authenticatedUser(request);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { subscriptionId, accountType, clubId } = await request.json();
  if (!subscriptionId || !["member", "club"].includes(accountType)) {
    return NextResponse.json({ error: "Invalid subscription" }, { status: 400 });
  }

  const { admin, error: adminError } = safeGetSupabaseAdmin();
  if (adminError) return adminError;
  if (accountType === "club" && (!clubId || !await canManageClub(admin, user.id, clubId))) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const details = await getPayPalSubscription(subscriptionId);
  const expectedCustomId = accountType === "club" ? clubId : user.id;
  if (details.custom_id !== expectedCustomId) {
    return NextResponse.json({ error: "Subscription owner does not match" }, { status: 403 });
  }

  const codes: PayPalPlanCode[] = ["member_monthly", "member_yearly", "club_monthly", "club_yearly"];
  const code = codes.find((candidate) => paypalPlanId(candidate) === details.plan_id);
  if (!code || (accountType === "club") !== code.startsWith("club_")) {
    return NextResponse.json({ error: "Unknown subscription plan" }, { status: 400 });
  }
  const { data: plan } = await admin.from("subscription_plans").select("id").eq("code", code).single();
  if (!plan) return NextResponse.json({ error: "Subscription plan is missing" }, { status: 500 });

  const statuses: Record<string, string> = {
    APPROVAL_PENDING: "pending", APPROVED: "pending", ACTIVE: "active",
    SUSPENDED: "suspended", CANCELLED: "cancelled", EXPIRED: "expired",
  };
  const record = {
    [accountType === "club" ? "club_id" : "profile_id"]: expectedCustomId,
    plan_id: plan.id,
    provider: "paypal",
    provider_subscription_id: subscriptionId,
    status: statuses[details.status] || "pending",
    current_period_start: details.start_time || null,
    current_period_end: details.billing_info?.next_billing_time || null,
    last_payment_at: details.billing_info?.last_payment?.time || null,
    cancel_at_period_end: details.status === "CANCELLED",
    cancelled_at: details.status === "CANCELLED" ? details.status_update_time || new Date().toISOString() : null,
  };
  const table = accountType === "club" ? "club_subscriptions" : "user_subscriptions";
  const { error } = await admin.from(table).upsert(record, { onConflict: "provider,provider_subscription_id" });
  if (error) return NextResponse.json({ error: "Subscription could not be saved" }, { status: 500 });
  return NextResponse.json({ saved: true });
}

export async function DELETE(request: Request) {
  const user = await authenticatedUser(request);
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const { subscriptionId, accountType, clubId } = await request.json();
  if (!subscriptionId || !["member", "club"].includes(accountType)) {
    return NextResponse.json({ error: "Invalid subscription" }, { status: 400 });
  }

  const { admin, error: adminError } = safeGetSupabaseAdmin();
  if (adminError) return adminError;
  const table = accountType === "club" ? "club_subscriptions" : "user_subscriptions";
  const ownerColumn = accountType === "club" ? "club_id" : "profile_id";
  const ownerId = accountType === "club" ? clubId : user.id;
  if (accountType === "club" && (!clubId || !await canManageClub(admin, user.id, clubId))) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const { data: existing } = await admin.from(table)
    .select("id,provider,provider_subscription_id,status")
    .eq("provider_subscription_id", subscriptionId).eq(ownerColumn, ownerId).maybeSingle();
  if (!existing) return NextResponse.json({ error: "Subscription not found" }, { status: 404 });
  if (["cancelled", "expired", "refunded"].includes(existing.status)) {
    return NextResponse.json({ error: "Subscription is already inactive" }, { status: 409 });
  }

  if (existing.provider === "paypal") {
    try {
      await cancelPayPalSubscription(existing.provider_subscription_id, "Cancelled by user in app");
    } catch {
      return NextResponse.json({ error: "PayPal cancellation failed" }, { status: 502 });
    }
  }

  const { error } = await admin.from(table).update({
    status: "cancelled",
    cancel_at_period_end: true,
    cancelled_at: new Date().toISOString(),
  }).eq("id", existing.id);
  if (error) return NextResponse.json({ error: "Subscription could not be updated" }, { status: 500 });
  return NextResponse.json({ cancelled: true });
}
