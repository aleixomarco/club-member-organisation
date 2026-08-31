import { LegalShell, legal } from "../legal-shell";
export const metadata = { title: "Konto löschen | Club Member Organisation" };
export default function DeleteAccountPage() { return <LegalShell title="Konto löschen">
  <p>Du kannst dein Konto bei der Club Member Organisation jederzeit dauerhaft löschen — auch wenn du die App nicht mehr installiert hast.</p>

  <h2>So löschst du dein Konto</h2>
  <ol>
    <li>Öffne <a href="/">club-member-organisation.vercel.app</a> im Browser oder in der App und melde dich mit deinem Konto an.</li>
    <li>Gehe zu <strong>Profil → Einstellungen → Konto löschen</strong>.</li>
    <li>Bestätige die endgültige Löschung. Dein Konto, deine Vereinsprofile und persönlichen Inhalte werden unwiderruflich gelöscht.</li>
  </ol>
  <p>Wartet deine Aufnahme noch auf die Freigabe durch den Verein, findest du die Löschfunktion direkt nach der Anmeldung auf dem Hinweisbildschirm.</p>
  <p><strong>Zu den Kosten:</strong> Für dich als Mitglied entstehen keine. Es gibt kein persönliches Abonnement, das mit deinem Konto endet oder weiterläuft — der Zugang wird vom Verein bezahlt, und der Vertrag besteht zwischen uns und dem Verein.</p>
  <p>Solltest du dich nicht mehr anmelden können (z. B. weil du keinen Zugriff mehr auf deine E-Mail-Adresse hast), schreibe uns an {legal.email}. Wir prüfen deine Identität und löschen dein Konto manuell.</p>

  <h2>Welche Daten gelöscht werden</h2>
  <p>Bei der Kontolöschung entfernen wir dauerhaft: deinen Zugang und dein Passwort, Stammdaten (Name, Kontaktdaten, Geburtsdatum, Adresse), Vereins- und Mannschaftszuordnungen, Familienverknüpfungen, von dir verfasste Nachrichten, News-Beiträge und Umfrageantworten, sowie deine Push-Benachrichtigungs-Registrierung.</p>

  <h2>Welche Daten wir aus rechtlichen Gründen weiter aufbewahren</h2>
  <p>Zahlungs- und Rechnungsdaten zu Abonnements müssen wir aufgrund handels- und steuerrechtlicher Aufbewahrungspflichten (u. a. § 147 AO, § 257 HGB) für bis zu zehn Jahre weiter vorhalten. Diese Daten werden ausschließlich für die gesetzlich erforderlichen Zwecke verarbeitet und anschließend gelöscht. Details findest du in unserer <a href="/datenschutz">Datenschutzerklärung</a>.</p>

  <h2>Zeitrahmen</h2>
  <p>Die Löschung über die App erfolgt sofort. Löschanfragen per E-Mail bearbeiten wir innerhalb von 30 Tagen.</p>
</LegalShell>; }
