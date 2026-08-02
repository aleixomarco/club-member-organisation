import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Nutzungsbedingungen | Club Member Organisation" };
export default function TermsPage() { return <LegalShell title="Nutzungsbedingungen">
  <p>Diese Bedingungen gelten für die Nutzung der Club Member Organisation durch registrierte Vereinsmitglieder. Vertragspartner ist {legal.name}.</p>
  <h2>Abonnement für Nutzer</h2>
  <p><strong>Monatsabo:</strong> Das Monatsabo kostet 2,99 € pro Monat. Der Betrag wird monatlich abgerechnet und das Abonnement verlängert sich automatisch jeweils um einen weiteren Monat, sofern es nicht rechtzeitig gekündigt wird.</p>
  <p><strong>Jahresabo:</strong> Das Jahresabo entspricht einem Preis von 0,99 € pro Monat. Der Gesamtbetrag von 11,88 € für zwölf Monate wird vollständig im Voraus bezahlt. Das Jahresabo verlängert sich automatisch um weitere zwölf Monate zum dann geltenden Jahrespreis, sofern es nicht rechtzeitig gekündigt wird.</p>
  <p>In der iOS-App erfolgt die Abrechnung über Apple, in der Web-App über PayPal.</p>
  <h2>Kündigung</h2><p>Abonnements können über den jeweiligen Zahlungsanbieter verwaltet und zum Ende des laufenden Abrechnungszeitraums gekündigt werden. Gesetzliche Widerrufs- und Erstattungsrechte bleiben unberührt.</p>
  <h2>Verhaltensregeln</h2><p>Rechtswidrige, beleidigende oder fremde Rechte verletzende Inhalte sind untersagt. Vereinsadministratoren dürfen entsprechende Inhalte entfernen und Konten sperren.</p>
</LegalShell>; }
