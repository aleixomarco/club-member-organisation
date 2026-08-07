import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Impressum | Club Member Organisation" };
export default function ImprintPage() { return <LegalShell title="Impressum">
  <h2>Angaben gemäß § 5 DDG</h2>
  <p><strong>{legal.name}</strong><br/>{legal.legalForm}<br/>{legal.address}</p>
  <p>Vertreten durch: {legal.representative}</p>
  {legal.register && <p>Registereintrag: {legal.register}</p>}
  <h2>Kontakt</h2>
  <p>E-Mail: {legal.email}{legal.phone && <><br/>Telefon: {legal.phone}</>}</p>
  <h2>Umsatzsteuer-Identifikationsnummer</h2>
  <p>{legal.vatId ? <>Umsatzsteuer-Identifikationsnummer gemäß § 27a UStG: {legal.vatId}</> : "Keine Umsatzsteuer-Identifikationsnummer vorhanden."}</p>
  <h2>Verantwortlich für den Inhalt</h2>
  <p>{legal.representative}, Anschrift wie oben.</p>
  <h2>EU-Streitschlichtung</h2>
  <p>Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit: <a href="https://ec.europa.eu/consumers/odr/" target="_blank" rel="noreferrer">https://ec.europa.eu/consumers/odr/</a>. Unsere E-Mail-Adresse findest du oben unter Kontakt.</p>
  <h2>Verbraucherstreitbeilegung</h2>
  <p>Wir sind nicht verpflichtet und nicht bereit, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle im Sinne des Verbraucherstreitbeilegungsgesetzes (VSBG) teilzunehmen.</p>
  <h2>Haftung für Inhalte und Links</h2>
  <p>Als Diensteanbieter sind wir für eigene Inhalte auf diesen Seiten nach den allgemeinen Gesetzen verantwortlich. Für Inhalte externer Links, auf die wir verweisen, übernehmen wir keine Gewähr; für den Inhalt verlinkter Seiten sind ausschließlich deren Betreiber verantwortlich.</p>
</LegalShell>; }
