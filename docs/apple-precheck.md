# Vorab-Prüfung gegen die App-Store-Richtlinien

Durchgeführt am 25.08.2026 für Build 1.0 (4).
Grundlage: die Richtlinien, die für diese App einschlägig sind, geprüft am Code.

---

## Bestanden

| Richtlinie | Gegenstand | Beleg |
|---|---|---|
| 3.1.1 | Kein Zahlweg am App Store vorbei | Keine Nennung von PayPal o. ä. in app/page.tsx, keine externen Links |
| 3.1.2 | Preis, Laufzeit, automatische Verlängerung im Kaufbereich | lib/preise.ts, SubscriptionPanel |
| 3.1.2 | Link zu den Nutzungsbedingungen | 6 Verweise auf /nutzungsbedingungen |
| 3.1.2 | Käufe wiederherstellen | Knopf mit then/catch, ruft restorePurchasesAs |
| 1.2 | Melden von Inhalten | mailto je Nachricht |
| 1.2 | Blockieren von Personen | blockAuthor, lokal je Gerät |
| 1.2 | Verhaltensregeln | Abschnitt in den Nutzungsbedingungen |
| 5.1.1 (v) | Kontolöschung in der App | Profil → Konto löschen, dazu /konto-loeschen |
| 5.1.1 (v) | Löscht wirklich | auth.admin.deleteUser in api/account/delete |
| 5.1.1 | Berechtigungstexte | Foto und Kamera, je mit konkreter Begründung |
| — | Netzwerksicherheit | Keine ATS-Ausnahme in Info.plist |
| 2.1 | Prüfzugang erreicht den Kaufbereich | demo@idbranding.de hat vorstand und vereinsadmin |

---

## Gefunden und behoben

**Absturz im Chat ohne Kanäle.** ChatView berechnete `active` als
`visibleChannels[0]` und griff direkt auf `active.messages` zu. Ist die Liste
leer, blieb der Chat weiß. Seit die Sichtbarkeit an der Mannschaft hängt, tritt
das regelmäßig ein: ein Mitglied ohne Mannschaft, ein Elternteil ohne
Familienverknüpfung, ein frisch freigegebenes Konto. **Der schwerste Fund** —
ein Prüfer mit einem solchen Konto hätte die App wegbrechen sehen.

**Leerer Helferdienst.** `helperEvents` filterte das Demo-Feld nach
`helperSlots`; echte Termine tragen die Eigenschaft nicht. Gerendert wurde nur
die Liste, ohne Leerfassung.

**Demo-Termin in der Verwaltungsübersicht.** Die Kachel zeigte `EVENTS[0]` —
einen Termin, den es im echten Verein nie gab.

**Eigene Nachrichten als fremde erkannt.** Der Vergleich lief über den Namen;
Datenbank-Nachrichten tragen den Namen aus profiles, der Nutzer seinen
Anzeigenamen aus der Mitgliedschaft. Bei Abweichung erschienen Melden- und
Blockieren-Knopf an der eigenen Nachricht.

---

## Systematische Gegenproben ohne Befund

- Muster `|| liste[0]` mit anschließendem Direktzugriff: nur die behobene Stelle
- Ungesicherte `.find()`-Ergebnisse: drei Treffer, alle mit Rückfall abgesichert
- Externe Links in der App: keine
- Tabellen, die die App nie anspricht: sieben, keine davon prüfungsrelevant

---

## Was nur am lebenden System prüfbar ist

**Der Kauf in der Sandbox.** Ob RevenueCat das Offering `basic` liefert und der
Kauf über den Webhook in `club_subscriptions` landet. Erst seit der Reparatur
der Zugriffsrechte am 25.08. überhaupt möglich — vorher scheiterte jeder
Serverzugriff mit 42501.

Weg: In TestFlight mit demo@idbranding.de anmelden, Profil → Einstellungen →
Abo & Empfehlungen, Basic wählen, bis zum Kaufdialog gehen. Erscheint er mit
Preis, ist die Kette in Ordnung.

**Screenshots und Beschreibung** in App Store Connect. Die Bilder müssen die
App zeigen, wie sie heute ist.

---

## Bewertung

Der Ablehnungsgrund der ersten Einreichung — der fehlende Link zu den
Nutzungsbedingungen, Richtlinie 3.1.2 — ist behoben und belegt.

Von den vier neu gefundenen Fehlern hätte einer mit hoher Wahrscheinlichkeit
zur Ablehnung geführt: der weiße Bildschirm im Chat. Er war erst durch die
Umstellung auf mannschaftsbezogene Kanäle entstanden, also am selben Tag.
