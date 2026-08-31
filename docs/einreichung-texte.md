# Texte für die Einreichung

Stand: 31.08.2026, nach dem Umbau auf das Rechnungsmodell.

**In der App wird nichts verkauft.** Kein Kaufbereich, keine Preise, kein
In-App-Kauf. Der Verein fragt den Vollzugang an, bekommt eine Rechnung und wird
vom Betreiber freigeschaltet. Alles, was hier früher zu Abonnements stand, ist
gegenstandslos — der alte Text schickte den Prüfer zu „Profil → Einstellungen →
Abo & Empfehlungen", und diesen Bereich gibt es nicht mehr.

> **Bevor Sie einreichen:** In App Store Connect müssen die beiden Abo-Posten
> und die Abo-Gruppe **aus der Version genommen** werden. Ein Prüfer, der ein
> eingereichtes In-App-Produkt in der App nicht findet, lehnt ab — „unable to
> locate the in-app purchase" ist der häufigste Ablehnungsgrund überhaupt.

---

## Was ist neu in dieser Version

```
Die App ist für Mitglieder kostenlos, und sie bleibt es. Es gibt keine Käufe
in der App.

Den Zugang bezahlt der Verein: Die Vereinsleitung fragt ihn an, bekommt ein
Angebot und eine Rechnung. Ohne Freischaltung stehen dauerhaft drei Zugänge
kostenlos zur Verfügung, mit denen sich Trainings- und Spielpläne führen und
einsehen lassen. Einen befristeten Testzeitraum gibt es nicht.

Neu ist außerdem: Man meldet sich zuerst mit seinem Konto an und wählt danach
den Verein. Wer in zwei Vereinen ist, sieht beide.
```

---

## Prüfhinweise (App-Prüfungsinformationen → Hinweise)

```
Anmeldung
Die App erfordert ein Konto. Bitte die unten hinterlegten Zugangsdaten
verwenden. Die Anmeldung ist der erste Bildschirm; nach dem Anmelden wird der
Verein automatisch geöffnet, weil das Demo-Konto nur einem Verein angehört.

Es wird nichts in der App verkauft
Diese App enthält keinen In-App-Kauf und keine Kaufaufforderung. Es gibt in der
App weder Preise noch einen Kaufbereich noch einen Verweis auf eine
Zahlungsseite.

Der Dienst wird ausschließlich an Vereine als Organisationen verkauft, nicht an
die einzelnen Mitglieder. Die Mitglieder zahlen nichts. Der Vertrag besteht
zwischen dem Anbieter und dem Verein; abgerechnet wird auf Rechnung außerhalb
der App (Richtlinie 3.1.3, Verkauf an Organisationen).

Was die Vereinsleitung in der App tun kann, ist eine Freischaltung ANFRAGEN:
Profil (unten rechts) → Einstellungen → Zugang & Empfehlungen. Dort steht ein
Kontaktformular ohne Preise und ohne Zahlungsmittel. Der Anbieter erstellt
daraufhin ein Angebot und schaltet nach Zahlungseingang frei.

Kostenlos nutzbar
Ohne Freischaltung stehen dauerhaft drei Zugänge zur Verfügung. Es gibt keinen
befristeten Testzeitraum, der abläuft.

Konto löschen
Profil → Einstellungen → Konto löschen. Die Löschung ist sofort wirksam und
vollständig. Wer noch zu keinem Verein gehört, kommt gar nicht erst so weit —
für ihn steht dieselbe Funktion auf jedem Bildschirm, den er in diesem Zustand
sieht: auf dem Hinweisbildschirm nach der Anmeldung, in der Vereinssuche und
unter „Meine Vereine".

Nutzergenerierte Inhalte
Im Chat lässt sich jede Nachricht melden und jede Person für die eigene Ansicht
ausblenden (beides unter der jeweiligen Nachricht). Die Vereinsleitung kann
Nachrichten entfernen und Personen aus dem Verein ausschließen.

Nutzungsbedingungen und Datenschutz
Beide sind in der App verlinkt (Profil → Einstellungen) und öffentlich
erreichbar:
https://club-member-organisation.vercel.app/nutzungsbedingungen
https://club-member-organisation.vercel.app/datenschutz
```

---

## Demo-Zugang

Trage unter *App-Prüfungsinformationen* Benutzername und Passwort eines
Kontos ein, das

1. angemeldet werden kann,
2. in einem Verein **aktives** Mitglied ist (nicht „wartet auf Freigabe"),
3. dort die Rolle Vorstand, Vereinsadmin oder Geschäftsführung hat, damit der
   Prüfer auch den Anfragebereich sieht,
4. in PROD existiert, nicht nur in der Testdatenbank,
5. in einem Verein ist, der **freigeschaltet** ist — sonst sieht der Prüfer
   überall nur „Diesen Bereich schaltet der Verein frei" und hält die App für
   unfertig.

Ohne funktionierenden Zugang lehnt Apple ab, ohne die App gesehen zu haben —
das ist die häufigste Ablehnung überhaupt.

**Vorher selbst prüfen:** abmelden, mit genau diesen Daten anmelden, und
schauen, ob der Verein direkt aufgeht und die Kacheln gefüllt sind.

### Die Zwei-Geräte-Grenze und das Prüfkonto

Ein Konto darf auf höchstens zwei Geräten angemeldet sein; ein drittes verdrängt
das älteste. Apple prüft regelmäßig auf iPhone **und** iPad — das sind bereits
zwei. Kommt ein dritter Anlauf dazu, wird der Prüfer abgemeldet und liest „Dieses
Gerät wurde abgemeldet, weil dein Konto inzwischen auf zwei anderen Geräten
angemeldet ist". Das sieht aus wie ein Fehler.

Vor der Einreichung deshalb entweder das Prüfkonto von der Grenze ausnehmen oder
die eigenen Geräte des Kontos vorher entfernen:

```sql
delete from public.user_devices
 where profile_id = (select id from auth.users where email = '<demo@…>');
```
