import { NextResponse } from "next/server";
import { getSupabaseAdmin } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

function escapeIcs(value: unknown) {
  return String(value ?? "").replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/,/g, "\\,").replace(/;/g, "\\;");
}
function icsDate(value: string) {
  return new Date(value).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

export async function GET(_request: Request, context: { params: Promise<{ token: string }> }) {
  const { token } = await context.params;
  let admin: ReturnType<typeof getSupabaseAdmin>;
  try {
    admin = getSupabaseAdmin();
  } catch {
    return NextResponse.json({ error: "Server configuration error" }, { status: 500 });
  }
  const { data: subscription } = await admin.from("calendar_subscriptions").select("profile_id,club_id,enabled,sync_interval,event_types").eq("token", token).maybeSingle();
  if (!subscription?.enabled) return NextResponse.json({ error: "Kalenderverbindung nicht gefunden" }, { status: 404 });
  const { data: membership } = await admin.from("club_memberships").select("id").eq("profile_id", subscription.profile_id).eq("club_id", subscription.club_id).eq("status", "active").maybeSingle();
  if (!membership) return NextResponse.json({ error: "Mitgliedschaft nicht aktiv" }, { status: 403 });
  const { data: familyLinks } = await admin.from("family_links")
    .select("first_membership_id,second_membership_id,first_to_second,second_to_first")
    .eq("club_id", subscription.club_id)
    .or(`first_membership_id.eq.${membership.id},second_membership_id.eq.${membership.id}`);
  const relatedChildren = (familyLinks || []).flatMap((link) => {
    if (link.first_membership_id === membership.id && link.first_to_second === "eltern") return [link.second_membership_id];
    if (link.second_membership_id === membership.id && link.second_to_first === "eltern") return [link.first_membership_id];
    return [];
  });
  const relevantMembershipIds = [membership.id, ...relatedChildren];
  const { data: assignments } = await admin.from("team_members").select("team_id").in("membership_id", relevantMembershipIds);
  const teamIds = [...new Set((assignments || []).map((entry) => entry.team_id))];
  /* Nur die abonnierten Terminarten ausliefern. Ältere Abos ohne gespeicherte
     Auswahl bekommen weiterhin alles — sonst wäre ihr Gerätekalender nach der
     Umstellung stillschweigend leer. */
  const ALL_TYPES = ["training", "spiel", "event"];
  const chosenTypes: string[] = Array.isArray(subscription.event_types) && subscription.event_types.length
    ? subscription.event_types.filter((entry: string) => ALL_TYPES.includes(entry))
    : ALL_TYPES;

  let query = admin.from("events").select("id,title,description,starts_at,ends_at,location,status,type,team_id").eq("club_id", subscription.club_id).in("type", chosenTypes).gte("starts_at", new Date(Date.now() - 86400000).toISOString()).order("starts_at");
  query = teamIds.length ? query.or(`team_id.is.null,team_id.in.(${teamIds.join(",")})`) : query.is("team_id", null);
  const { data: events, error } = await query;
  if (error) return NextResponse.json({ error: "Kalender konnte nicht geladen werden" }, { status: 500 });
  const refreshInterval = { daily: "P1D", weekly: "P1W", monthly: "P1M", never: "P10Y" }[subscription.sync_interval] || "P1D";
  /* Der Name landet sichtbar im Gerätekalender — er soll verraten, was drinsteckt. */
  const typeLabels: Record<string, string> = { training: "Training", spiel: "Spiele", event: "Events" };
  const calendarName = chosenTypes.length === ALL_TYPES.length
    ? "CMO Termine"
    : `CMO ${chosenTypes.map((entry) => typeLabels[entry]).join(" & ")}`;
  const body = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//CMO//Club Member Organisation//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", `X-WR-CALNAME:${escapeIcs(calendarName)}`, `REFRESH-INTERVAL;VALUE=DURATION:${refreshInterval}`, `X-PUBLISHED-TTL:${refreshInterval}`,
    ...(events || []).flatMap((event) => ["BEGIN:VEVENT", `UID:${event.id}@cmo.app`, `DTSTAMP:${icsDate(new Date().toISOString())}`, `DTSTART:${icsDate(event.starts_at)}`, `DTEND:${icsDate(event.ends_at || new Date(new Date(event.starts_at).getTime()+7200000).toISOString())}`, `SUMMARY:${escapeIcs(event.status === "cancelled" ? `ABGESAGT: ${event.title}` : event.title)}`, `DESCRIPTION:${escapeIcs(event.description || "")}`, `LOCATION:${escapeIcs(event.location || "")}`, `STATUS:${event.status === "cancelled" ? "CANCELLED" : "CONFIRMED"}`, "END:VEVENT"]), "END:VCALENDAR", ""].join("\r\n");
  return new NextResponse(body, { headers: { "Content-Type": "text/calendar; charset=utf-8", "Content-Disposition": "inline; filename=CMO-Kalender.ics", "Cache-Control": "no-store" } });
}
