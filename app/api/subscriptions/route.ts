/* Liest die gebuchten Abonnements eines Vereins aus der Datenbank.
 *
 * Lag frueher unter /api/paypal/subscriptions, obwohl sie mit PayPal nichts zu
 * tun hat - sie liest club_subscriptions und user_subscriptions. Beim Ausbau
 * von PayPal ist sie hierher gezogen, damit "Meine Abonnements" weiterlaeuft.
 *
 * Abschliessen und Kuendigen gibt es hier bewusst nicht mehr: Gekauft wird
 * ueber den Store, gekuendigt in den Einstellungen des Apple- bzw.
 * Google-Kontos. Ein eigener Weg dafuer waere eine Tuer ohne Zweck.
 */
import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

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

  let club: unknown[] = [];
  if (clubId && await canManageClub(admin, user.id, clubId)) {
    const { data, error } = await admin.from("club_subscriptions")
      .select(selection).eq("club_id", clubId).order("created_at", { ascending: false });
    if (error) return NextResponse.json({ error: "Club subscriptions could not be loaded" }, { status: 500 });
    club = data || [];
  }

  // Das eigene Basis-Abo darf jedes Mitglied sehen — es zahlt es selbst.
  const { data: own } = await admin.from("user_subscriptions")
    .select(selection).eq("profile_id", user.id).order("created_at", { ascending: false });

  return NextResponse.json({ club, member: own || [] });
}
