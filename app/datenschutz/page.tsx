import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Datenschutz | Club Member Organisation" };
export default function PrivacyPage() { return <LegalShell title="Datenschutzerklärung">
  <h2>1. Verantwortlicher</h2>
  <p>Verantwortlich im Sinne der DSGVO: <strong>{legal.name}</strong>, vertreten durch {legal.representative}, {legal.address}, Kontakt: {legal.email}{legal.phone ? `, ${legal.phone}` : ""}.</p>
  <p>Ein Datenschutzbeauftragter ist nicht bestellt, da die gesetzlichen Voraussetzungen hierfür (§ 38 BDSG, Art. 37 DSGVO) nicht vorliegen.</p>

  <h2>2. Welche Daten wir verarbeiten und warum</h2>
  <p>Wir verarbeiten ausschließlich Daten, die für den Betrieb der Vereins-App erforderlich sind:</p>
  <ul>
    <li><strong>Konto- und Stammdaten</strong> (Name, E-Mail, Geburtsdatum, Adresse, Kontaktdaten, Mitgliedsnummer, Rollen, Mannschaftszugehörigkeit) — zur Erfüllung des Nutzungsvertrags und der Vereinsverwaltung, Art. 6 Abs. 1 lit. b DSGVO.</li>
    <li><strong>Familienverknüpfungen</strong> (Eltern-Kind-Zuordnungen) — zur Vereinsorganisation von Jugendmannschaften, Art. 6 Abs. 1 lit. b und f DSGVO.</li>
    <li><strong>Termine, Nachrichten, Chat- und News-Inhalte, Umfragen</strong> — zur internen Vereinskommunikation, Art. 6 Abs. 1 lit. b und f DSGVO.</li>
    <li><strong>Beitrags-, Straf- und Abonnementdaten</strong> — zur Vertrags- und Zahlungsabwicklung sowie zur Erfüllung handels- und steuerrechtlicher Aufbewahrungspflichten, Art. 6 Abs. 1 lit. b und c DSGVO.</li>
    <li><strong>Push-Benachrichtigungs-Token</strong> — nur nach deiner ausdrücklichen Freigabe in den Benachrichtigungseinstellungen, Art. 6 Abs. 1 lit. a DSGVO.</li>
    <li><strong>Technische Nutzungsdaten</strong> (z. B. Anmeldezeitpunkt, Geräteinformationen bei Push) — zur sicheren Bereitstellung des Dienstes, Art. 6 Abs. 1 lit. f DSGVO.</li>
  </ul>
  <p>Die Angabe der für die Vereinsverwaltung erforderlichen Daten ist Voraussetzung für die Nutzung der App; ohne sie können wir das Nutzungsverhältnis nicht durchführen.</p>

  <h2>3. Minderjährige und verwaltete Kinderprofile</h2>
  <p>Für Jugendmannschaften können Erziehungsberechtigte vorläufige Profile für ihre Kinder anlegen, bevor diese ein eigenes Konto übernehmen. Die Nutzung durch Minderjährige erfolgt unter der Verantwortung und mit Zustimmung der Erziehungsberechtigten. Für eigene Konten von Kindern unter 16 Jahren ist gemäß Art. 8 DSGVO die Einwilligung der Erziehungsberechtigten erforderlich; der Verein kann dies im Rahmen der Mitgliedsaufnahme sicherstellen.</p>

  <h2>4. Empfänger und Auftragsverarbeiter</h2>
  <ul>
    <li><strong>Supabase</strong> — Authentifizierung, Datenbank und Dateispeicher.</li>
    <li><strong>Vercel</strong> — Hosting und Bereitstellung der Web-App.</li>
    <li><strong>RevenueCat</strong> — Abwicklung und Statusverwaltung von In-App-Abonnements in der iOS- und Android-App. Übermittelt werden eine pseudonyme Vereins- bzw. Profilkennung sowie Kauf- und Abostatus.</li>
    <li><strong>Apple</strong> — Zahlungsabwicklung für Abonnements in der iOS-App.</li>
    <li><strong>Google Firebase Cloud Messaging</strong> — Zustellung von Push-Benachrichtigungen, sofern aktiviert.</li>
  </ul>
  <p>Mit Supabase, Vercel und Google bestehen bzw. werden Auftragsverarbeitungsverträge nach Art. 28 DSGVO abgeschlossen. Apple und Google verarbeiten Zahlungsdaten als jeweils eigenständig Verantwortliche gemäß ihrer eigenen Datenschutzerklärungen; mit RevenueCat besteht ein Auftragsverarbeitungsvertrag nach Art. 28 DSGVO.</p>

  <h2>5. Datenübermittlung in Drittländer</h2>
  <p>Einzelne Dienstleister (u. a. Vercel, Google/Firebase, Apple, RevenueCat) können Daten auch in den USA oder anderen Ländern außerhalb der EU/des EWR verarbeiten. Soweit dies der Fall ist, stützen wir uns auf Angemessenheitsbeschlüsse der EU-Kommission (z. B. EU-US Data Privacy Framework) oder auf EU-Standardvertragsklauseln gemäß Art. 46 DSGVO als geeignete Garantien.</p>

  <h2>6. Cookies, lokaler Speicher und Push-Token</h2>
  <p>Die App verwendet technisch notwendige Sitzungs-Cookies bzw. gleichwertige Speicherverfahren (localStorage) für die Anmeldung sowie zur Speicherung von Anzeigeeinstellungen (z. B. bevorzugte Mannschaft, zuletzt gewählter Verein). Diese sind gemäß § 25 Abs. 2 TTDSG für den Betrieb der App erforderlich und bedürfen keiner gesonderten Einwilligung. Für Push-Benachrichtigungen wird nach deiner Zustimmung ein Geräte-Token bei Google Firebase Cloud Messaging registriert.</p>

  <h2>7. Speicherdauer</h2>
  <p>Wir speichern personenbezogene Daten, solange dein Konto besteht und du Vereinsmitglied bist. Nach Löschung deines Kontos werden die Daten grundsätzlich unverzüglich gelöscht. Ausgenommen sind Daten, die wir aufgrund handels- und steuerrechtlicher Aufbewahrungspflichten (u. a. § 147 AO, § 257 HGB) für bis zu zehn Jahre weiter vorhalten müssen, etwa Zahlungs- und Rechnungsdaten zu Abonnements. Diese Daten werden nach Ablauf der Frist gelöscht und in der Zwischenzeit nur für die gesetzlich erforderlichen Zwecke verarbeitet.</p>

  <h2>8. Deine Rechte</h2>
  <p>Du hast das Recht auf Auskunft (Art. 15 DSGVO), Berichtigung (Art. 16), Löschung (Art. 17), Einschränkung der Verarbeitung (Art. 18), Datenübertragbarkeit (Art. 20) sowie Widerspruch gegen Verarbeitungen auf Grundlage berechtigten Interesses (Art. 21). Erteilte Einwilligungen (z. B. für Push-Benachrichtigungen) kannst du jederzeit mit Wirkung für die Zukunft widerrufen. Die vollständige Kontolöschung kannst du direkt im Profil oder über unser <a href="/konto-loeschen">Web-Formular zur Kontolöschung</a> beantragen.</p>
  <p>Du hast außerdem das Recht, dich bei einer Datenschutzaufsichtsbehörde zu beschweren, insbesondere in dem Mitgliedstaat deines gewöhnlichen Aufenthalts, Arbeitsplatzes oder des Orts des mutmaßlichen Verstoßes.</p>
</LegalShell>; }
