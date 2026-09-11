import { NextResponse } from "next/server";
import { getSupabaseAdmin, mitZweitemVersuch } from "@/lib/supabase-admin";

export const dynamic = "force-dynamic";

function escapeIcs(value: unknown) {
  return String(value ?? "").replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/,/g, "\\,").replace(/;/g, "\\;");
}
/* Der Zeitversatz trifft nicht nur die erste Abfrage. Jede der sechs kann an
   "JWT issued at future" scheitern - vorher war nur das Abo geschuetzt: Traf es
   die Mitgliedschaft, stand dort "Mitgliedschaft nicht aktiv" (403), traf es
   die Termine, kam eine stumme 500 ohne Protokollzeile. Beides haelt ein
   Kalenderprogramm fuer dauerhaft, manche geben das Abo dann auf.
   Jetzt: jede Abfrage mit zweitem Versuch, jeder Fehler ins Protokoll, und ein
   anhaltender Versatz endet ueberall in derselben ehrlichen 503. */
class Zeitversatz extends Error {}
async function lies<T extends { error: { code?: string | null } | null }>(was: string, abfrage: () => PromiseLike<T>): Promise<T> {
  const ergebnis = await mitZweitemVersuch(abfrage);
  if (ergebnis.error) {
    console.error(`Kalender-Feed: ${was}`, ergebnis.error);
    if (ergebnis.error.code === "PGRST303") throw new Zeitversatz();
  }
  return ergebnis;
}
const spaeterNochmal = () => NextResponse.json({ error: "Kalender gerade nicht verfügbar" },
  { status: 503, headers: { "Retry-After": "60" } });

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
  /* Drei Faelle, drei Antworten - vorher liefen sie alle in dieselbe 404.
     Ein Datenbankfehler sah damit aus wie ein unbekannter Token, und die
     Ursache war von aussen nicht zu erkennen: Genau das hat die Suche nach
     dem fehlgeschlagenen Kalenderabo unnoetig lange gemacht. */
  const { data: subscription, error: leseFehler } = await mitZweitemVersuch(() => admin
    .from("calendar_subscriptions")
    .select("profile_id,club_id,enabled,sync_interval,event_types,team_ids")
    .eq("token", token)
    .maybeSingle());

  if (leseFehler) {
    console.error("Kalender-Feed: Abo konnte nicht gelesen werden", leseFehler);
    /* Ein Zeitversatz ist kein kaputter Server, sondern ein "gleich wieder".
       Mit 500 halten manche Kalenderprogramme das Abo fuer dauerhaft defekt
       und fragen seltener oder gar nicht mehr nach; 503 mit Retry-After sagt
       genau das Richtige. */
    if (leseFehler.code === "PGRST303") {
      return NextResponse.json({ error: "Kalender gerade nicht verfügbar" },
        { status: 503, headers: { "Retry-After": "60" } });
    }
    return NextResponse.json({ error: "Kalender konnte nicht geladen werden", code: leseFehler.code }, { status: 500 });
  }
  if (!subscription) return NextResponse.json({ error: "Kalenderverbindung nicht gefunden" }, { status: 404 });
  if (!subscription.enabled) return NextResponse.json({ error: "Kalenderverbindung ist deaktiviert" }, { status: 410 });
  try {
  const { data: membership, error: mitgliedFehler } = await lies("Mitgliedschaft konnte nicht gelesen werden", () => admin.from("club_memberships").select("id").eq("profile_id", subscription.profile_id).eq("club_id", subscription.club_id).eq("status", "active").maybeSingle());
  if (mitgliedFehler) return NextResponse.json({ error: "Kalender konnte nicht geladen werden" }, { status: 500 });
  if (!membership) return NextResponse.json({ error: "Mitgliedschaft nicht aktiv" }, { status: 403 });
  const { data: familyLinks } = await lies("Familienverbindungen konnten nicht gelesen werden", () => admin.from("family_links")
    .select("first_membership_id,second_membership_id,first_to_second,second_to_first")
    .eq("club_id", subscription.club_id)
    .or(`first_membership_id.eq.${membership.id},second_membership_id.eq.${membership.id}`));
  const relatedChildren = (familyLinks || []).flatMap((link) => {
    if (link.first_membership_id === membership.id && link.first_to_second === "eltern") return [link.second_membership_id];
    if (link.second_membership_id === membership.id && link.second_to_first === "eltern") return [link.first_membership_id];
    return [];
  });
  /* Welche Mannschaften landen im Kalender?
     Hat jemand ausdruecklich welche gewaehlt, gelten genau diese - auch solche,
     in denen er selbst nicht steht (ein Elternteil, das der Mannschaft des
     Kindes folgt, ein Vorstand, der eine Mannschaft beobachtet).
     Ohne Auswahl bleibt es beim bisherigen Verhalten: die eigenen Mannschaften
     und die der Kinder, mit denen eine Familienverbindung besteht. Bestehende
     Abos aendern sich dadurch nicht. */
  const gewaehlteTeams: string[] = Array.isArray(subscription.team_ids) ? subscription.team_ids : [];
  let teamIds: string[];
  if (gewaehlteTeams.length) {
    /* Nachpruefen statt vertrauen: Die Auswahl steht seit dem Speichern in der
       Datenbank, aber eine Mannschaft kann seither in einen anderen Verein
       verschoben oder geloescht worden sein. */
    const { data: erlaubt } = await lies("Mannschaften konnten nicht gelesen werden", () => admin.from("teams").select("id").eq("club_id", subscription.club_id).in("id", gewaehlteTeams));
    teamIds = (erlaubt || []).map((entry) => entry.id);
  } else {
    const relevantMembershipIds = [membership.id, ...relatedChildren];
    const { data: assignments } = await lies("Mannschaftszuordnungen konnten nicht gelesen werden", () => admin.from("team_members").select("team_id").in("membership_id", relevantMembershipIds));
    teamIds = [...new Set((assignments || []).map((entry) => entry.team_id))];
  }
  /* Nur die abonnierten Terminarten ausliefern. Ältere Abos ohne gespeicherte
     Auswahl bekommen weiterhin alles — sonst wäre ihr Gerätekalender nach der
     Umstellung stillschweigend leer. */
  const ALL_TYPES = ["training", "spiel", "event"];
  const chosenTypes: string[] = Array.isArray(subscription.event_types) && subscription.event_types.length
    ? subscription.event_types.filter((entry: string) => ALL_TYPES.includes(entry))
    : ALL_TYPES;

  /* Die Abfrage wird fuer jeden Versuch neu gebaut - ein zweites await auf
     dasselbe Objekt waere kein zweiter Versuch. */
  const termine = () => {
    const query = admin.from("events").select("id,title,description,starts_at,ends_at,location,status,type,team_id").eq("club_id", subscription.club_id).in("type", chosenTypes).gte("starts_at", new Date(Date.now() - 86400000).toISOString()).order("starts_at");
    return teamIds.length ? query.or(`team_id.is.null,team_id.in.(${teamIds.join(",")})`) : query.is("team_id", null);
  };
  const { data: events, error } = await lies("Termine konnten nicht gelesen werden", termine);
  if (error) return NextResponse.json({ error: "Kalender konnte nicht geladen werden" }, { status: 500 });
  const refreshInterval = { daily: "P1D", weekly: "P1W", monthly: "P1M", never: "P10Y" }[subscription.sync_interval] || "P1D";
  /* Der Name landet sichtbar im Gerätekalender — er soll verraten, was drinsteckt. */
  const typeLabels: Record<string, string> = { training: "Training", spiel: "Spiele", event: "Events" };
  const artenName = chosenTypes.length === ALL_TYPES.length
    ? "Termine"
    : chosenTypes.map((entry) => typeLabels[entry]).join(" & ");
  /* Bei ausgewaehlten Mannschaften deren Namen in den Kalendernamen. Wer zwei
     Abos im Geraet hat, muss sie auseinanderhalten koennen. */
  let mannschaftsName = "";
  if (gewaehlteTeams.length && teamIds.length) {
    const { data: namen } = await lies("Mannschaftsnamen konnten nicht gelesen werden", () => admin.from("teams").select("name").in("id", teamIds).order("name"));
    const liste = (namen || []).map((entry) => entry.name);
    mannschaftsName = liste.length <= 2 ? ` · ${liste.join(" & ")}` : ` · ${liste.length} Mannschaften`;
  }
  const calendarName = `CMO ${artenName}${mannschaftsName}`;
  const body = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//CMO//Club Member Organisation//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", `X-WR-CALNAME:${escapeIcs(calendarName)}`, `REFRESH-INTERVAL;VALUE=DURATION:${refreshInterval}`, `X-PUBLISHED-TTL:${refreshInterval}`,
    ...(events || []).flatMap((event) => ["BEGIN:VEVENT", `UID:${event.id}@cmo.app`, `DTSTAMP:${icsDate(new Date().toISOString())}`, `DTSTART:${icsDate(event.starts_at)}`, `DTEND:${icsDate(event.ends_at || new Date(new Date(event.starts_at).getTime()+7200000).toISOString())}`, `SUMMARY:${escapeIcs(event.status === "cancelled" ? `ABGESAGT: ${event.title}` : event.title)}`, `DESCRIPTION:${escapeIcs(event.description || "")}`, `LOCATION:${escapeIcs(event.location || "")}`, `STATUS:${event.status === "cancelled" ? "CANCELLED" : "CONFIRMED"}`, "END:VEVENT"]), "END:VCALENDAR", ""].join("\r\n");
  return new NextResponse(body, { headers: { "Content-Type": "text/calendar; charset=utf-8", "Content-Disposition": "inline; filename=CMO-Kalender.ics", "Cache-Control": "no-store" } });
  } catch (fehler) {
    if (fehler instanceof Zeitversatz) return spaeterNochmal();
    console.error("Kalender-Feed: unerwarteter Fehler", fehler);
    return NextResponse.json({ error: "Kalender konnte nicht geladen werden" }, { status: 500 });
  }
}
