import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

export async function DELETE(request: Request) {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!token || !url || !key) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const authClient = createClient(url, key, { auth: { persistSession: false } });
  const { data: { user }, error } = await authClient.auth.getUser(token);
  if (error || !user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }
  /* Frueher wurden hier laufende PayPal-Abos beendet. PayPal ist ausgebaut,
     und Store-Abos kann diese Route nicht kuendigen - das geht nur in den
     Einstellungen des Apple- bzw. Google-Kontos. Die Oberflaeche weist beim
     Loeschen ausdruecklich darauf hin. */

  // Vereinsverantwortliche informieren, bevor das Konto gelöscht wird. Best effort:
  // ein Fehler hier darf die eigentliche Löschung nicht verhindern.
  try {
    const { data: memberships } = await admin.from("club_memberships")
      .select("id,club_id,display_name,status").eq("profile_id", user.id);
    for (const membership of memberships || []) {
      if (membership.status !== "active") continue;
      const { data: clubMembers } = await admin.from("club_memberships")
        .select("id,membership_roles(role)").eq("club_id", membership.club_id).eq("status", "active");
      const recipients = (clubMembers || [])
        .filter((m) => m.id !== membership.id && (m.membership_roles || []).some((r: { role: string }) => ["vereinsadmin", "sysadmin", "vorstand", "geschaeftsfuehrung"].includes(r.role)))
        .map((m) => m.id);
      if (recipients.length) {
        await admin.rpc("notify_many", {
          target_memberships: recipients, p_notif_type: "membership",
          p_title: "Konto gelöscht", p_body: `${membership.display_name} hat das eigene Konto dauerhaft gelöscht.`,
        });
      }
    }
  } catch {
    // Benachrichtigung ist nicht kritisch für die Löschung selbst.
  }

  const { error: deletionError } = await admin.auth.admin.deleteUser(user.id);
  if (deletionError) return NextResponse.json({ error: "Deletion failed" }, { status: 500 });
  return NextResponse.json({ deleted: true });
}

