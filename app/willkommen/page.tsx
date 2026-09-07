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

export default async function Willkommen({ searchParams }: { searchParams: Promise<{ verein?: string }> }) {
  const { verein } = await searchParams;
  /* Die Vereinskennung wird durchgereicht, damit der Weg im Browser direkt
     bei der Beitrittsanfrage endet statt in der Vereinssuche. Geprueft wird
     sie hier auf ihre Form - was hier hineingegeben wird, landet in einer
     Adresse. */
  const vereinsLink = verein && /^[0-9a-fA-F-]{36}$/.test(verein)
    ? `/?verein=${encodeURIComponent(verein)}` : "/";
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
        <p style={{ fontSize: 13, marginBottom: 28, lineHeight: 1.6, color: gedaempft }}>
          Termine, Mannschaften, Helferdienste und Vereinsnachrichten an einem Ort.
          Es gibt sie als App fürs Smartphone — und im Browser.
        </p>

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
