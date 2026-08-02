import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Datenschutz | Club Member Organisation" };
export default function PrivacyPage() { return <LegalShell title="Datenschutzerklärung">
  <p>Verantwortlich: <strong>{legal.name}</strong>, {legal.address}, Kontakt: {legal.email}.</p>
  <h2>Verarbeitete Daten</h2><p>Wir verarbeiten Konto- und Kontaktdaten, Vereinszugehörigkeit, Rollen, Mannschaften, Familienverknüpfungen, Termine, Nachrichten, Umfragen, Beitragsinformationen und Abonnementstatus, soweit dies für die Vereinsorganisation erforderlich ist.</p>
  <h2>Dienstleister</h2><p>Supabase dient der Anmeldung und Datenspeicherung, Vercel der Bereitstellung der Web-App, PayPal der Zahlungsabwicklung im Web und Apple der Zahlungsabwicklung auf iOS. Zahlungsdaten werden unmittelbar durch den jeweiligen Zahlungsanbieter verarbeitet.</p>
  <h2>Zweck und Speicherdauer</h2><p>Die Verarbeitung erfolgt zur Vertragserfüllung, sicheren Bereitstellung und Vereinsverwaltung. Daten werden gelöscht, wenn das Konto gelöscht wird und keine gesetzlichen Aufbewahrungspflichten entgegenstehen.</p>
  <h2>Deine Rechte</h2><p>Du kannst Auskunft, Berichtigung, Löschung, Einschränkung und Datenübertragbarkeit verlangen sowie einer Verarbeitung widersprechen. Die vollständige Kontolöschung kann direkt im Profil gestartet werden.</p>
</LegalShell>; }

