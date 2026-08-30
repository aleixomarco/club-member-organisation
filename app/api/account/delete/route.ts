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
  if (deletionError) {
    /* Ein Fremdschluessel kann die Loeschung blockieren. Bekannter Fall:
       news_posts.author_id verwies mit "on delete restrict" auf profiles - wer je
       eine Neuigkeit verfasst hatte, kam nicht mehr aus dem Verein heraus. Die
       Migration 20260829120000_news_author_loeschbar.sql stellt das auf
       "set null" um.
       Solange sie nicht eingespielt ist, soll wenigstens im Log stehen, WARUM es
       scheitert - "Deletion failed" allein hat niemandem geholfen und sah nach
       einem Serverfehler aus, obwohl es einer an einer bestimmten Stelle ist. */
    const blockiert = /foreign key|violates|constraint/i.test(deletionError.message || "");
    console.error(`Kontoloeschung fehlgeschlagen fuer ${user.id}${blockiert ? " - ein Fremdschluessel blockiert sie" : ""}:`, deletionError.message);
    return NextResponse.json({
      error: blockiert
        ? "Dein Konto konnte nicht gelöscht werden, weil noch Beiträge daran hängen. Wir haben den Fall protokolliert — melde dich bitte kurz beim Verein, dann erledigen wir es von Hand."
        : "Deletion failed",
    }, { status: 500 });
  }
  return NextResponse.json({ deleted: true });
}

