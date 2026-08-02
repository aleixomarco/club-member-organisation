import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Nutzungsbedingungen | Club Member Organisation" };
export default function TermsPage() { return <LegalShell title="Nutzungsbedingungen">
  <p>Diese Bedingungen gelten für die Nutzung der Club Member Organisation durch registrierte Vereinsmitglieder. Vertragspartner ist {legal.name}.</p>
  <h2>Abonnement</h2><p>Das Monatsabo kostet 2,99 € und verlängert sich monatlich. Das Jahresabo kostet 11,88 € im Voraus und verlängert sich automatisch um weitere zwölf Monate, sofern es nicht rechtzeitig gekündigt wird. In der iOS-App erfolgt die Abrechnung über Apple, in der Web-App über PayPal.</p>
  <h2>Kündigung</h2><p>Abonnements können über den jeweiligen Zahlungsanbieter verwaltet und zum Ende des laufenden Abrechnungszeitraums gekündigt werden. Gesetzliche Widerrufs- und Erstattungsrechte bleiben unberührt.</p>
  <h2>Verhaltensregeln</h2><p>Rechtswidrige, beleidigende oder fremde Rechte verletzende Inhalte sind untersagt. Vereinsadministratoren dürfen entsprechende Inhalte entfernen und Konten sperren.</p>
</LegalShell>; }
