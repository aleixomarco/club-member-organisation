import { NextResponse } from "next/server";
import { getSupabaseAdmin, mitZweitemVersuch } from "@/lib/supabase-admin";
import { spracheAusKopf, uebersetze } from "@/lib/sprachen";

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
    /* Zeitversatz und kurze Aussetzer bei Supabase ("Gateway Timeout", kein
       Code) sind ein "gleich wieder", kein kaputter Kalender - also 503. */
    const text = String((ergebnis.error as { message?: string }).message || "");
    if (ergebnis.error.code === "PGRST303" || /timeout|gateway|fetch failed|network/i.test(text)) throw new Zeitversatz();
  }
  return ergebnis;
}
const spaeterNochmal = (sprache: string) => NextResponse.json({ error: uebersetze(sprache, "kal.feed.nichtVerfuegbar") },
  { status: 503, headers: { "Retry-After": "60" } });

function icsDate(value: string) {
  return new Date(value).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

export async function GET(request: Request, context: { params: Promise<{ token: string }> }) {
  const { token } = await context.params;
  /* Fehlertexte in der Sprache des Aufrufers. Lesen kann sie nur, wer die
     Feed-Adresse im Browser oeffnet - Kalenderprogramme zeigen eigene
     Meldungen. Vor dem Tokenfund gibt es ohnehin nur den Kopf; fuer den
     Kalenderinhalt selbst gilt weiter unten die Sprache des Profils. */
  const kopfSprache = spracheAusKopf(request.headers.get("accept-language"));
  const meldung = (schluessel: string) => uebersetze(kopfSprache, schluessel);
  /* Der Token ist in der Datenbank eine UUID. Alles andere - ein abgeschnittener
     Link, ein Bot, der Adressen durchprobiert - liess Postgres mit 22P02
     ("invalid input syntax for type uuid") scheitern, und das endete als 500
     mit Fehlerzeile im Protokoll. Fuer den Aufrufer ist es aber schlicht eine
     unbekannte Kalenderverbindung: dieselbe 404 wie ein gueltiger, aber
     unbekannter Token, und ohne Datenbankabfrage. */
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(token)) {
    return NextResponse.json({ error: meldung("kal.feed.nichtGefunden") }, { status: 404 });
  }
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
    /* Auch ein kurzer Aussetzer bei Supabase ("Gateway Timeout", Netzfehler)
       ist ein "gleich wieder" - wie in lies() fuer alle weiteren Abfragen.
       Hier, bei der ersten Abfrage, fehlte das: am 12.09. kam dafuer 500. */
    const aussetzer = /timeout|gateway|fetch failed|network/i.test(String(leseFehler.message || ""));
    if (leseFehler.code === "PGRST303" || aussetzer) {
      return spaeterNochmal(kopfSprache);
    }
    return NextResponse.json({ error: meldung("kal.feed.ladenFehler"), code: leseFehler.code }, { status: 500 });
  }
  if (!subscription) return NextResponse.json({ error: meldung("kal.feed.nichtGefunden") }, { status: 404 });
  if (!subscription.enabled) return NextResponse.json({ error: meldung("kal.feed.deaktiviert") }, { status: 410 });
  try {
  const { data: membership, error: mitgliedFehler } = await lies("Mitgliedschaft konnte nicht gelesen werden", () => admin.from("club_memberships").select("id").eq("profile_id", subscription.profile_id).eq("club_id", subscription.club_id).eq("status", "active").maybeSingle());
  if (mitgliedFehler) return NextResponse.json({ error: meldung("kal.feed.ladenFehler") }, { status: 500 });
  if (!membership) return NextResponse.json({ error: meldung("kal.feed.mitgliedschaftInaktiv") }, { status: 403 });
  /* Fans sehen keine Trainings (Entscheidung vom 12.09.2026) - auch nicht im
     Geraetekalender. "Nur Fan" heisst: 'fan' ist die einzige Rolle dieser
     Mitgliedschaft in DIESEM Verein. Ein Lesefehler endet wie bei der
     Mitgliedschaft in einer 500 und nicht in einem Kalender voller Trainings,
     die dieser Mensch in der App gar nicht sieht. */
  const { data: rollen, error: rollenFehler } = await lies("Rollen konnten nicht gelesen werden", () => admin.from("membership_roles").select("role").eq("membership_id", membership.id));
  if (rollenFehler) return NextResponse.json({ error: meldung("kal.feed.ladenFehler") }, { status: 500 });
  const nurFan = (rollen || []).length > 0 && (rollen || []).every((eintrag) => eintrag.role === "fan");
  const { data: familyLinks } = await lies("Familienverbindungen konnten nicht gelesen werden", () => admin.from("family_links")
    .select("first_membership_id,second_membership_id,first_to_second,second_to_first")
    .eq("club_id", subscription.club_id)
    /* Nur bestaetigte Verknuepfungen bringen Termine eines Kindes in den
       Kalender (B2, 20260914110200). Eine offene Anfrage gibt keinen Zugriff. */
    .eq("bestaetigt", true)
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
  /* Ein Fan bekommt keine Trainings, auch wenn sein Abo sie noch fuehrt -
     etwa weil es aus der Zeit stammt, bevor er Fan wurde. */
  const lieferbareArten = nurFan ? chosenTypes.filter((entry) => entry !== "training") : chosenTypes;

  /* Die Abfrage wird fuer jeden Versuch neu gebaut - ein zweites await auf
     dasselbe Objekt waere kein zweiter Versuch. */
  const termine = () => {
    const basis = admin.from("events").select("id,title,description,starts_at,ends_at,location,status,type,team_id").eq("club_id", subscription.club_id).gte("starts_at", new Date(Date.now() - 86400000).toISOString()).order("starts_at");
    /* Bleibt keine Art uebrig (ein Fan, der nur Trainings abonniert hatte),
       wird der Kalender leer - ohne Abfrage mit leerer in-Liste, die PostgREST
       als "in.()" bekaeme. */
    const query = lieferbareArten.length ? basis.in("type", lieferbareArten) : basis.limit(0);
    return teamIds.length ? query.or(`team_id.is.null,team_id.in.(${teamIds.join(",")})`) : query.is("team_id", null);
  };
  /* Kalendername und der Vorsatz vor abgesagten Terminen folgen der Sprache
     des Abonnenten (profiles.language), nicht der des Geraets, das den Feed
     abholt. Parallel zu den Terminen, damit das Abo keine weitere Runde
     wartet. Ein anhaltender Aussetzer endet wie ueberall in der 503; jeder
     andere Lesefehler ist keinen leeren Kalender wert - dann bleibt es bei
     Deutsch, wie vor der Uebersetzung. */
  const [{ data: events, error }, { data: profil }] = await Promise.all([
    lies("Termine konnten nicht gelesen werden", termine),
    lies("Profilsprache konnte nicht gelesen werden", () => admin.from("profiles").select("language").eq("id", subscription.profile_id).maybeSingle()),
  ]);
  const sprache = String(profil?.language || "de");
  if (error) return NextResponse.json({ error: meldung("kal.feed.ladenFehler") }, { status: 500 });
  const refreshInterval = { daily: "P1D", weekly: "P1W", monthly: "P1M", never: "P10Y" }[subscription.sync_interval] || "P1D";
  /* Der Name landet sichtbar im Gerätekalender — er soll verraten, was drinsteckt. */
  const t = (schluessel: string) => uebersetze(sprache, schluessel);
  const typeLabels: Record<string, string> = { training: t("kal.feed.training"), spiel: t("kal.feed.spiele"), event: t("kal.feed.events") };
  /* Der Name folgt dem, was wirklich drinsteht - bei einem Fan also ohne
     "Training". Bleibt gar nichts, heisst der Kalender schlicht "Termine". */
  const artenName = lieferbareArten.length === ALL_TYPES.length || !lieferbareArten.length
    ? t("kal.feed.termine")
    : lieferbareArten.map((entry) => typeLabels[entry]).join(" & ");
  /* Bei ausgewaehlten Mannschaften deren Namen in den Kalendernamen. Wer zwei
     Abos im Geraet hat, muss sie auseinanderhalten koennen. */
  let mannschaftsName = "";
  if (gewaehlteTeams.length && teamIds.length) {
    const { data: namen } = await lies("Mannschaftsnamen konnten nicht gelesen werden", () => admin.from("teams").select("name").in("id", teamIds).order("name"));
    const liste = (namen || []).map((entry) => entry.name);
    mannschaftsName = liste.length <= 2 ? ` · ${liste.join(" & ")}` : ` · ${t("kal.feed.mannschaftenAnzahl").replace("{anzahl}", String(liste.length))}`;
  }
  const calendarName = `CMO ${artenName}${mannschaftsName}`;
  const abgesagt = t("kal.feed.abgesagt");
  const body = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//CMO//Club Member Organisation//DE", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", `X-WR-CALNAME:${escapeIcs(calendarName)}`, `REFRESH-INTERVAL;VALUE=DURATION:${refreshInterval}`, `X-PUBLISHED-TTL:${refreshInterval}`,
    ...(events || []).flatMap((event) => ["BEGIN:VEVENT", `UID:${event.id}@cmo.app`, `DTSTAMP:${icsDate(new Date().toISOString())}`, `DTSTART:${icsDate(event.starts_at)}`, `DTEND:${icsDate(event.ends_at || new Date(new Date(event.starts_at).getTime()+7200000).toISOString())}`, `SUMMARY:${escapeIcs(event.status === "cancelled" ? abgesagt.replace("{titel}", () => String(event.title)) : event.title)}`, `DESCRIPTION:${escapeIcs(event.description || "")}`, `LOCATION:${escapeIcs(event.location || "")}`, `STATUS:${event.status === "cancelled" ? "CANCELLED" : "CONFIRMED"}`, "END:VEVENT"]), "END:VCALENDAR", ""].join("\r\n");
  return new NextResponse(body, { headers: { "Content-Type": "text/calendar; charset=utf-8", "Content-Disposition": "inline; filename=CMO-Kalender.ics", "Cache-Control": "no-store" } });
  } catch (fehler) {
    if (fehler instanceof Zeitversatz) return spaeterNochmal(kopfSprache);
    console.error("Kalender-Feed: unerwarteter Fehler", fehler);
    return NextResponse.json({ error: meldung("kal.feed.ladenFehler") }, { status: 500 });
  }
}
