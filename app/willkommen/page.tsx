/* Die Hinweisseite "gibt es als App fürs Smartphone".
 *
 * Sie stand früher VOR der ganzen App: Jeder Browserbesuch endete hier, auch
 * der Klick auf einen Bestätigungslink aus einer Registrierungsmail — eine
 * Sackgasse, aus der niemand herausfand.
 *
 * Jetzt läuft die App im Browser, und diese Seite hat ihren eigenen Ort. Sie
 * ist die richtige Antwort für alle, die von der Werbung kommen und noch kein
 * Konto haben — nicht für jemanden, der sich anmelden will.
 *
 * Bewusst OHNE Import aus app/page.tsx: Dort steht die gesamte App in einer
 * Client-Komponente. Ein Import von dort zöge sie komplett in diese Seite —
 * für eine Textseite mit drei Links wäre das ein Megabyte JavaScript. */

export const metadata = {
  title: "Club Member Organisation",
  description: "Die Vereins-App für Termine, Mannschaften, Helferdienste und Vereinsnachrichten.",
};

const tinte = "#2A2028";
const gedaempft = "#6B5F67";
const grund = "#F7F4F6";
const rot = "#C8102E";

/* Die Adresse im App Store ist keine Konfiguration, sondern eine Tatsache:
   Sie steht fest, seit die App dort liegt, und aendert sich nicht mehr.
   Bisher hing sie an NEXT_PUBLIC_APP_STORE_URL - und weil die Variable
   nirgends gesetzt ist, blieb der Knopf unsichtbar. Wer den Einladungslink
   eines Freundes oeffnete, bekam die App gar nicht angeboten.
   Die Variable darf weiterhin uebersteuern; ohne sie gilt der feste Wert. */
const APP_STORE = "https://apps.apple.com/de/app/club-member-organisation/id6801881765";
/* Bei Google Play liegt die App noch nicht. Ein Link dorthin fuehrte auf eine
   Fehlerseite - schlimmer als kein Link. Sobald sie dort ist, kommt die
   Adresse hier hinein (oder in NEXT_PUBLIC_PLAY_STORE_URL). */
const PLAY_STORE: string | null = null;

/* Zu WELCHEM Verein wurde eingeladen?
 *
 * Universal Links loesen den Fall "App ist schon da" - der Link oeffnet dann
 * die App mitsamt Vereinskennung. Sie loesen NICHT den Fall "App wird erst
 * installiert": Nach dem Weg ueber den App Store ist die Kennung verloren,
 * iOS reicht sie nicht in die frische Installation weiter.
 *
 * Was bleibt, ist der Name. Wer hier liest "Du wurdest zu ERG Iserlohn
 * eingeladen", findet den Verein nach der Installation in der Vereinssuche -
 * statt zu raten, wie der Verein wohl genau geschrieben wird.
 *
 * Die Vereinsliste ist absichtlich oeffentlich lesbar ("clubs are
 * discoverable", using true) - genau dafuer. Beitreten kann trotzdem nur, wen
 * die Vereinsleitung freigibt. */
async function vereinLaden(kennung: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  try {
    const antwort = await fetch(
      `${url}/rest/v1/clubs?id=eq.${encodeURIComponent(kennung)}&select=name,city`,
      { headers: { apikey: key, Authorization: `Bearer ${key}` }, cache: "no-store",
        signal: AbortSignal.timeout(4000) },
    );
    if (!antwort.ok) return null;
    const zeilen = await antwort.json();
    return zeilen?.[0]?.name ? zeilen[0] : null;
  } catch {
    /* Der Name ist Beiwerk. Faellt die Abfrage aus, bleibt die Seite genau so
       brauchbar wie vorher - nur ohne Vereinsnamen. */
    return null;
  }
}

export default async function Willkommen({ searchParams }: { searchParams: Promise<{ verein?: string }> }) {
  const { verein } = await searchParams;
  /* Die Vereinskennung wird durchgereicht, damit der Weg im Browser direkt
     bei der Beitrittsanfrage endet statt in der Vereinssuche. Geprueft wird
     sie hier auf ihre Form - was hier hineingegeben wird, landet in einer
     Adresse. */
  const gueltig = !!verein && /^[0-9a-fA-F-]{36}$/.test(verein);
  const vereinsLink = gueltig ? `/?verein=${encodeURIComponent(verein!)}` : "/";
  const eingeladenZu = gueltig ? await vereinLaden(verein!) : null;
  const appStore = process.env.NEXT_PUBLIC_APP_STORE_URL || APP_STORE;
  const playStore = process.env.NEXT_PUBLIC_PLAY_STORE_URL || PLAY_STORE;
  const linkStil = {
    display: "block", textAlign: "center" as const, padding: "12px 16px",
    borderRadius: 14, background: tinte, color: "#fff", fontWeight: 700,
    fontSize: 13, textDecoration: "none", marginBottom: 10,
  };

  return (
    <div style={{ minHeight: "100vh", width: "100%", display: "flex", alignItems: "center",
                  justifyContent: "center", padding: "0 24px", background: grund,
                  fontFamily: "-apple-system, Helvetica Neue, Arial, sans-serif" }}>
      <div style={{ width: "100%", maxWidth: 384, textAlign: "center" }}>
        <div style={{ margin: "0 auto 24px", width: 76, height: 76, borderRadius: 24,
                      background: "#fff", display: "flex", alignItems: "center",
                      justifyContent: "center", boxShadow: "0 8px 28px rgba(60,30,45,.12)" }}>
          <span style={{ fontSize: 40, fontWeight: 700, color: rot, lineHeight: 1 }}>C</span>
        </div>
        <h1 style={{ fontSize: 22, marginBottom: 8, fontWeight: 700, color: tinte }}>
          Club Member Organisation
        </h1>
        {eingeladenZu ? (
          <>
            <p style={{ fontSize: 14, marginBottom: 6, lineHeight: 1.6, color: tinte }}>
              Du wurdest eingeladen zu
            </p>
            <p style={{ fontSize: 19, marginBottom: 8, fontWeight: 700, color: rot }}>
              {eingeladenZu.name}
            </p>
            {/* Der Name steht hier nicht als Zierde: Nach der Installation aus
                dem Store ist die Vereinskennung weg, und dann ist der Name das
                Einzige, womit man den Verein in der Suche wiederfindet. */}
            <p style={{ fontSize: 13, marginBottom: 28, lineHeight: 1.6, color: gedaempft }}>
              Lade die App, erstelle dein Konto und suche dort nach
              „{eingeladenZu.name}“{eingeladenZu.city ? ` (${eingeladenZu.city})` : ""}.
              Die Vereinsleitung gibt dich anschließend frei.
            </p>
          </>
        ) : (
          <p style={{ fontSize: 13, marginBottom: 28, lineHeight: 1.6, color: gedaempft }}>
            Termine, Mannschaften, Helferdienste und Vereinsnachrichten an einem Ort.
            Es gibt sie als App fürs Smartphone — und im Browser.
          </p>
        )}

        {appStore && <a href={appStore} style={linkStil}>Im App&nbsp;Store laden</a>}
        {playStore && <a href={playStore} style={linkStil}>Bei Google&nbsp;Play laden</a>}
        <a href={vereinsLink} style={{ ...linkStil, background: "#fff", color: tinte, border: "1px solid #E6E0E3" }}>
          Im Browser öffnen
        </a>
        {!playStore && (
          <p style={{ fontSize: 12, marginTop: 14, lineHeight: 1.6, color: gedaempft }}>
            Für Android kommt die App noch in den Play&nbsp;Store. Bis dahin läuft sie
            im Browser — mit demselben Konto und allen Funktionen.
          </p>
        )}

        <div style={{ marginTop: 28, fontSize: 12 }}>
          <a href="/nutzungsbedingungen" style={{ color: gedaempft, margin: "0 8px" }}>Nutzungsbedingungen</a>
          <a href="/datenschutz" style={{ color: gedaempft, margin: "0 8px" }}>Datenschutz</a>
          <a href="/impressum" style={{ color: gedaempft, margin: "0 8px" }}>Impressum</a>
        </div>
      </div>
    </div>
  );
}
