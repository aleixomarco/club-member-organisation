import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Datenschutz | Club Member Organisation" };
export default function PrivacyPage() { return <LegalShell title="Datenschutzerklärung">
  <h2>1. Verantwortlicher</h2>
  <p>Verantwortlich im Sinne der DSGVO: <strong>{legal.name}</strong>{legal.representedBySelf ? "" : `, vertreten durch ${legal.representative}`}, {legal.address}, Kontakt: {legal.email}{legal.phone ? `, ${legal.phone}` : ""}.</p>
  <p>Ein Datenschutzbeauftragter ist nicht bestellt, da die gesetzlichen Voraussetzungen hierfür (§ 38 BDSG, Art. 37 DSGVO) nicht vorliegen.</p>

  <h2>2. Welche Daten wir verarbeiten und warum</h2>
  <p>Wir verarbeiten ausschließlich Daten, die für den Betrieb der Vereins-App erforderlich sind:</p>
  <ul>
    <li><strong>Konto- und Stammdaten</strong> (Name, E-Mail, Geburtsdatum, Adresse, Kontaktdaten, Mitgliedsnummer, Rollen, Mannschaftszugehörigkeit) — zur Erfüllung des Nutzungsvertrags und der Vereinsverwaltung, Art. 6 Abs. 1 lit. b DSGVO.</li>
    <li><strong>Familienverknüpfungen</strong> (Eltern-Kind-Zuordnungen) — zur Vereinsorganisation von Jugendmannschaften, Art. 6 Abs. 1 lit. b und f DSGVO.</li>
    <li><strong>Termine, Nachrichten, Chat- und News-Inhalte, Umfragen</strong> — zur internen Vereinskommunikation, Art. 6 Abs. 1 lit. b und f DSGVO.</li>
    <li><strong>Beitrags- und Strafdaten sowie der Freischaltstatus des Vereins</strong> — zur Vertragsabwicklung sowie zur Erfüllung handels- und steuerrechtlicher Aufbewahrungspflichten, Art. 6 Abs. 1 lit. b und c DSGVO.</li>
    <li><strong>Fahrgemeinschaften</strong> (Abfahrtsadresse, freie Plätze, Notiz, Mitfahrende) — zur Organisation gemeinsamer Fahrten zu Terminen, Art. 6 Abs. 1 lit. f DSGVO. Die Abfahrtsadresse gibst du selbst an und sie ist für die anderen Teilnehmenden des jeweiligen Termins sichtbar; sie wird mit der Fahrgemeinschaft gelöscht.</li>
    <li><strong>Push-Benachrichtigungs-Token</strong> — <em>in der App aus dem App Store derzeit nicht in Gebrauch.</em> Die Funktion ist angelegt, aber dort nicht erreichbar; es wird kein Token erzeugt und keiner an Google übermittelt. Benachrichtigungen innerhalb der App laufen ausschließlich über unsere eigene Datenbank. Sollte Push später aktiviert werden, geschieht das nur nach deiner ausdrücklichen Freigabe in den Benachrichtigungseinstellungen, Art. 6 Abs. 1 lit. a DSGVO.</li>
    <li><strong>Gerätekennung und technische Nutzungsdaten</strong> — jedes Konto darf auf höchstens zwei Geräten angemeldet sein. Dafür vergibt die App je Gerät eine zufällige Kennung, die im Gerät gespeichert und zusammen mit einer Gerätebezeichnung („iPhone", „Android", „Browser"), dem Zeitpunkt des letzten Zugriffs und deiner Konto-Kennung bei uns hinterlegt wird. Zusätzlich halten wir zu jedem Konto fest, von welchen Geräten es zuletzt genutzt wurde, einschließlich der Browserkennung (User-Agent) und der Zeitpunkte. Meldest du dich auf einem dritten Gerät an, wird das älteste abgemeldet. Zweck ist die sichere Bereitstellung des Dienstes und der Schutz vor der Weitergabe von Zugängen, Art. 6 Abs. 1 lit. f DSGVO. IP-Adressen speichern wir dabei nicht.</li>
    <li><strong>Bilder, die du hochlädst</strong> (Vereinslogo, Bilder zu Vereins-News, Sponsorenbilder) — zur Darstellung in der App, Art. 6 Abs. 1 lit. b und f DSGVO. Bitte beachte: Vereinslogos und Sponsorenbilder liegen in öffentlich lesbaren Speicherbereichen, wer die Adresse einer Datei kennt, kann sie also auch ohne Anmeldung abrufen. Bilder werden unverändert übernommen; darin enthaltene Zusatzinformationen der Kamera (etwa Aufnahmezeit oder Ortsangabe) werden von uns weder ausgewertet noch entfernt. Lade deshalb keine Bilder hoch, deren Zusatzinformationen du nicht weitergeben möchtest.</li>
    <li><strong>Zählung von Werbeeinblendungen</strong> — zu jeder Anzeige führen wir zwei Summen: wie oft sie gezeigt und wie oft sie angetippt wurde. Es werden weder Einzelereignisse noch ein Bezug zu deinem Konto gespeichert; aus diesen Summen lässt sich nicht ableiten, wer eine Anzeige gesehen hat. Art. 6 Abs. 1 lit. f DSGVO.</li>
  </ul>
  <p>Die Angabe der für die Vereinsverwaltung erforderlichen Daten ist Voraussetzung für die Nutzung der App; ohne sie können wir das Nutzungsverhältnis nicht durchführen.</p>

  <h2>3. Minderjährige und verwaltete Kinderprofile</h2>
  <p>Für Jugendmannschaften können Erziehungsberechtigte vorläufige Profile für ihre Kinder anlegen, bevor diese ein eigenes Konto übernehmen. Ebenso können Trainerinnen und Trainer Spielerinnen und Spieler ohne eigenes Konto in einer Mannschaft anlegen — etwa Kinder ohne eigenes Telefon. Für diese Personen werden Name und die für den Spielbetrieb nötigen Angaben verarbeitet; die Verantwortung für die Zulässigkeit dieser Eingabe liegt beim Verein. Die Nutzung durch Minderjährige erfolgt unter der Verantwortung und mit Zustimmung der Erziehungsberechtigten. Für eigene Konten von Kindern unter 16 Jahren ist gemäß Art. 8 DSGVO die Einwilligung der Erziehungsberechtigten erforderlich; der Verein kann dies im Rahmen der Mitgliedsaufnahme sicherstellen.</p>

  <h2>4. Empfänger und Auftragsverarbeiter</h2>
  <ul>
    <li><strong>Supabase</strong> — Authentifizierung, Datenbank und Dateispeicher.</li>
    <li><strong>Vercel</strong> — Hosting und Bereitstellung der Web-App.</li>
    <li><strong>Apple</strong> — Bereitstellung der App über den App Store.</li>
    <li><strong>Google Firebase</strong> — die App bindet Firebase ein; beim Start kann dabei eine technische Installationskennung an Google übermittelt werden. Push-Benachrichtigungen über Firebase Cloud Messaging werden in der App aus dem App Store <em>derzeit nicht genutzt</em>.</li>
  </ul>
  <p>Mit Supabase, Vercel und Google bestehen bzw. werden Auftragsverarbeitungsverträge nach Art. 28 DSGVO abgeschlossen. Die Abrechnung mit den Vereinen erfolgt auf Rechnung ausserhalb der App; Zahlungsdaten werden in der App nicht verarbeitet.</p>

  <h2>5. Datenübermittlung in Drittländer</h2>
  <p>Einzelne Dienstleister (u. a. Vercel, Google/Firebase, Apple) können Daten auch in den USA oder anderen Ländern außerhalb der EU/des EWR verarbeiten. Soweit dies der Fall ist, stützen wir uns auf Angemessenheitsbeschlüsse der EU-Kommission (z. B. EU-US Data Privacy Framework) oder auf EU-Standardvertragsklauseln gemäß Art. 46 DSGVO als geeignete Garantien.</p>

  <h2>6. Cookies, lokaler Speicher und Push-Token</h2>
  <p>Die App verwendet technisch notwendige Sitzungs-Cookies bzw. gleichwertige Speicherverfahren (localStorage) für die Anmeldung sowie zur Speicherung von Anzeigeeinstellungen (z. B. bevorzugte Mannschaft, zuletzt gewählter Verein). Diese sind gemäß § 25 Abs. 2 TTDSG für den Betrieb der App erforderlich und bedürfen keiner gesonderten Einwilligung. Zusätzlich legt die App im Gerät eine zufällige Gerätekennung ab (siehe Abschnitt 2), die die Begrenzung auf zwei Geräte je Konto ermöglicht. Ein Geräte-Token für Push-Benachrichtigungen wird in der App aus dem App Store derzeit nicht registriert.</p>

  <h2>7. Speicherdauer</h2>
  <p>Wir speichern personenbezogene Daten, solange dein Konto besteht und du Vereinsmitglied bist. Nach Löschung deines Kontos werden die Daten grundsätzlich unverzüglich gelöscht. Ausgenommen sind Daten, die wir aufgrund handels- und steuerrechtlicher Aufbewahrungspflichten (u. a. § 147 AO, § 257 HGB) für bis zu zehn Jahre weiter vorhalten müssen, etwa Rechnungsdaten des Vereins. Diese Daten werden nach Ablauf der Frist gelöscht und in der Zwischenzeit nur für die gesetzlich erforderlichen Zwecke verarbeitet.</p>

  <h2>8. Deine Rechte</h2>
  <p>Du hast das Recht auf Auskunft (Art. 15 DSGVO), Berichtigung (Art. 16), Löschung (Art. 17), Einschränkung der Verarbeitung (Art. 18), Datenübertragbarkeit (Art. 20) sowie Widerspruch gegen Verarbeitungen auf Grundlage berechtigten Interesses (Art. 21). Erteilte Einwilligungen (z. B. für Push-Benachrichtigungen) kannst du jederzeit mit Wirkung für die Zukunft widerrufen. Die vollständige Kontolöschung kannst du direkt im Profil oder über unser <a href="/konto-loeschen">Web-Formular zur Kontolöschung</a> beantragen.</p>
  <p>Du hast außerdem das Recht, dich bei einer Datenschutzaufsichtsbehörde zu beschweren, insbesondere in dem Mitgliedstaat deines gewöhnlichen Aufenthalts, Arbeitsplatzes oder des Orts des mutmaßlichen Verstoßes.</p>
</LegalShell>; }
