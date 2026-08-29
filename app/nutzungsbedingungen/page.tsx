import { LegalShell, legal } from "../legal-shell";
import { CLUB_TIER_PRICES, CLUB_TIER_INFO, KAUFBARE_TARIFE, FREIE_ZUGAENGE } from "@/lib/preise";
export const metadata = { title: "Nutzungsbedingungen | Club Member Organisation" };
export default function TermsPage() { return <LegalShell title="Nutzungsbedingungen">
  <p>Diese Bedingungen gelten für die Nutzung der Club Member Organisation durch registrierte Vereinsmitglieder. Vertragspartner ist {legal.name}{legal.representedBySelf ? "" : `, vertreten durch ${legal.representative}`}.</p>

  <h2>Kostenloser Testzeitraum</h2>
  <p>Neu angelegte Vereine können die App vierzehn Tage ab Registrierung kostenlos und in vollem Umfang nutzen. Danach ist ein Abonnement erforderlich. Der Testzeitraum endet automatisch und geht nicht in ein kostenpflichtiges Abonnement über.</p>

  <h2>Für Mitglieder kostenlos</h2>
  <p>Mitglieder zahlen nichts. Der Zugang wird vom Verein bezahlt; ein eigenes Abonnement ist nicht erforderlich und wird auch nicht angeboten. Welche Funktionen ein Mitglied nutzen kann, ergibt sich aus seinen Rollen im Verein.</p>

  <h2>Abonnement für Vereine</h2>
  <p>Der Verein zahlt nach der Zahl der Zugänge. Als Zugang zählt jedes selbst angemeldete Konto. Wer ohne eigenen Zugang eingetragen wird — etwa ein Kind, das ein Elternteil anlegt —, zählt nicht mit. Alle Tarife enthalten denselben Funktionsumfang; sie unterscheiden sich ausschließlich in der Zahl der Zugänge.</p>
  {KAUFBARE_TARIFE.map((t) => (
    <p key={t}><strong>{CLUB_TIER_INFO[t].label}</strong> ({CLUB_TIER_INFO[t].accountLabel}): {CLUB_TIER_PRICES[t].monthly.price} pro Monat oder {CLUB_TIER_PRICES[t].yearly.price} für zwölf Monate im Voraus ({CLUB_TIER_PRICES[t].yearly.equivalent}).</p>
  ))}
  <p>Alle Preise verstehen sich inklusive der gesetzlichen Umsatzsteuer. Abonnements verlängern sich automatisch um den jeweils gebuchten Zeitraum zum dann geltenden Preis, sofern nicht rechtzeitig gekündigt wird. Abschließen und kündigen können nur Mitglieder mit der Rolle Vorstand, Vereinsadmin oder Geschäftsführung.</p>

  <h2>Mehr Zugänge</h2>
  <p>Vereine, die mehr Zugänge benötigen, als der größte angebotene Tarif umfasst, erhalten auf Anfrage ein individuelles Angebot.</p>

  <h2>Kostenlose Nutzung für kleine Vereine</h2>
  <p>Ohne Abonnement stehen dauerhaft {FREIE_ZUGAENGE} Zugänge zur Verfügung. Vereine bis zu dieser Größe können die App kostenlos und mit vollem Funktionsumfang nutzen.</p>

  <h2>Erreichen der Zugangsgrenze</h2>
  <p>Ist die Zahl der Zugänge des gebuchten Tarifs erreicht, lassen sich keine weiteren Konten anlegen oder freigeben. Bestehende Zugänge bleiben unverändert nutzbar. Der Verein kann jederzeit in einen größeren Tarif wechseln.</p>

  <p>Die Abrechnung erfolgt über Apples In-App-Kauf-System beziehungsweise über Google Play und deren eigene Nutzungs- und Zahlungsbedingungen.</p>

  <h2>Kündigung</h2>
  <p>Abonnements verwaltest und kündigst du in den Einstellungen deines Apple- beziehungsweise Google-Kontos. Das Abonnement bleibt bis zum Ende des bereits bezahlten Zeitraums nutzbar und verlängert sich danach nicht mehr. Das gesetzliche Widerrufsrecht nach den folgenden Bestimmungen bleibt hiervon unberührt.</p>

  <h2>Widerrufsbelehrung</h2>
  <p><strong>Widerrufsrecht:</strong> Du hast das Recht, binnen vierzehn Tagen ohne Angabe von Gründen diesen Vertrag zu widerrufen. Die Widerrufsfrist beträgt vierzehn Tage ab dem Tag des Vertragsschlusses.</p>
  <p>Um dein Widerrufsrecht auszuüben, musst du uns ({legal.name}, {legal.address}, E-Mail: {legal.email}{legal.phone ? `, Telefon: ${legal.phone}` : ""}) mittels einer eindeutigen Erklärung (z. B. per E-Mail oder Brief) über deinen Entschluss, diesen Vertrag zu widerrufen, informieren. Du kannst dafür das Muster-Widerrufsformular am Ende dieses Abschnitts verwenden, das jedoch nicht vorgeschrieben ist. Zur Wahrung der Widerrufsfrist reicht es aus, dass du die Mitteilung über die Ausübung des Widerrufsrechts vor Ablauf der Widerrufsfrist absendest.</p>
  <p><strong>Folgen des Widerrufs:</strong> Wenn du diesen Vertrag widerrufst, erstatten wir dir alle Zahlungen, die wir von dir erhalten haben, unverzüglich und spätestens binnen vierzehn Tagen ab dem Tag, an dem die Mitteilung über deinen Widerruf bei uns eingegangen ist. Für diese Rückzahlung verwenden wir dasselbe Zahlungsmittel, das du bei der ursprünglichen Zahlung eingesetzt hast, soweit nicht ausdrücklich etwas anderes vereinbart wurde.</p>
  <p>Hast du verlangt, dass die Nutzung der App bereits während der Widerrufsfrist beginnen soll, so hast du uns einen angemessenen Betrag zu zahlen, der dem Anteil der bis zum Zeitpunkt deines Widerrufs bereits erbrachten Leistung im Vergleich zum Gesamtumfang der im Vertrag vorgesehenen Leistung entspricht. Mit dem Abschluss des Abonnements über den Store erklärst du dich ausdrücklich damit einverstanden, dass wir mit der Ausführung des Vertrags vor Ablauf der Widerrufsfrist beginnen; dein Widerrufsrecht bleibt hiervon unberührt, erlischt jedoch, sobald wir den Vertrag mit deiner ausdrücklichen Zustimmung vollständig erfüllt haben.</p>
  <p><strong>Muster-Widerrufsformular</strong> (wenn du den Vertrag widerrufen willst, fülle bitte dieses Formular aus und sende es an die oben genannte Kontaktadresse):</p>
  <p>An {legal.name}, {legal.address}, {legal.email}:<br/>
  Hiermit widerrufe ich den von mir abgeschlossenen Vertrag über die Erbringung der folgenden Dienstleistung (Abonnement der Club Member Organisation).<br/>
  Bestellt am: _____________<br/>
  Name des Verbrauchers: _____________<br/>
  Anschrift des Verbrauchers: _____________<br/>
  Datum: _____________</p>

  <h2>Preise</h2>
  <p>Alle genannten Preise verstehen sich in Euro inklusive der gesetzlichen Umsatzsteuer. Eine Einrichtungsgebühr oder sonstige einmalige Gebühr wird nicht erhoben. Außerhalb Deutschlands kann der Preis abweichen; maßgeblich ist der Betrag, der dir vor dem Kauf im Store angezeigt wird.</p>

  <h2>Verhaltensregeln</h2>
  <p>Rechtswidrige, beleidigende oder fremde Rechte verletzende Inhalte sind untersagt. Nutzer:innen können unangemessene Inhalte oder Verhalten über die Funktion „Fehler melden" im Profil an uns melden. Vereinsadministratoren dürfen entsprechende Inhalte entfernen und Konten sperren.</p>

  <h2>Haftung</h2>
  <p>Wir haften unbeschränkt für Vorsatz und grobe Fahrlässigkeit sowie nach den Vorschriften des Produkthaftungsgesetzes. Für leichte Fahrlässigkeit haften wir nur bei Verletzung einer wesentlichen Vertragspflicht (Kardinalpflicht), begrenzt auf den vertragstypisch vorhersehbaren Schaden.</p>

  <h2>Schlussbestimmungen</h2>
  <p>Es gilt deutsches Recht unter Ausschluss des UN-Kaufrechts. Zwingende verbraucherschützende Bestimmungen deines gewöhnlichen Aufenthaltsstaats bleiben unberührt. Sollte eine Bestimmung dieser Nutzungsbedingungen unwirksam sein, bleibt die Wirksamkeit der übrigen Bestimmungen unberührt.</p>
</LegalShell>; }
