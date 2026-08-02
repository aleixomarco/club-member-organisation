import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Impressum | Club Member Organisation" };
export default function ImprintPage() { return <LegalShell title="Impressum">
  <p><strong>{legal.name}</strong><br/>{legal.legalForm}<br/>{legal.address}</p><p>Kontakt: {legal.email}</p>
  <h2>Verantwortlich für Inhalte</h2><p>{legal.name}, Anschrift wie oben.</p>
  <p>Umsatzsteuer-Identifikationsnummer wird ergänzt, sofern vorhanden.</p>
</LegalShell>; }
