import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "@/lib/supabase-admin";
import { cancelPayPalSubscription } from "@/lib/paypal";

export const dynamic = "force-dynamic";

export async function DELETE(request: Request) {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!token || !url || !key) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const authClient = createClient(url, key, { auth: { persistSession: false } });
  const { data: { user }, error } = await authClient.auth.getUser(token);
  if (error || !user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const admin = getSupabaseAdmin();
  const { data: subscriptions } = await admin.from("user_subscriptions")
    .select("provider,provider_subscription_id,status").eq("profile_id", user.id).in("status", ["active", "past_due", "suspended"]);
  for (const subscription of subscriptions || []) {
    if (subscription.provider === "paypal") await cancelPayPalSubscription(subscription.provider_subscription_id);
  }
  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id);
  if (deletionError) return NextResponse.json({ error: "Deletion failed" }, { status: 500 });
  return NextResponse.json({ deleted: true });
}

