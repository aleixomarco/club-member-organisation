# Einen Verein freischalten

## Der normale Weg: die Betreiber-Oberfläche

**<https://club-member-organisation.vercel.app/betreiber>**

Eigener Zugang mit eigenem Passwort, unabhängig von jedem Vereinskonto. Dort
stehen die offenen Anfragen oben und darunter alle Vereine mit Tarif, belegten
Zugängen, Sponsorenzusatz, Laufzeit und Ansprechpartner. Freischalten,
verlängern, sperren und Anfragen abhaken geht mit einem Knopf.

### Einrichten

Zwei Umgebungsvariablen in Vercel (Project → Settings → Environment Variables),
danach einmal neu deployen:

| Variable | Inhalt |
|---|---|
| `BETREIBER_PASSWORT` | Das Passwort. **Mindestens 16 Zeichen**, selbst gewählt, nirgendwo sonst verwendet. |
| `BETREIBER_SESSION_SECRET` | Eine lange Zufallszeichenkette, mindestens 32 Zeichen. Signiert nur das Sitzungs-Cookie; sie wird nie getippt. |

**Passwort vergessen oder wechseln?** Kein Problem und kein Support nötig — es
gibt hier nichts wiederherzustellen. Neuen Wert in Vercel eintragen, neu
deployen, fertig. Der Ablauf und alles zum sicheren Aufbewahren steht in
[betreiber-zugaenge.md](betreiber-zugaenge.md).

Einen Zufallswert für das zweite Feld erzeugt man am schnellsten im Terminal:

```bash
openssl rand -base64 48
```

Solange beide fehlen, antwortet die Seite mit „Der Betreiberzugang ist nicht
eingerichtet." — sie geht also nicht versehentlich ungeschützt online.

Die Oberfläche spricht nie selbst mit der Datenbank. Sie fragt den eigenen
Server, und nur der hat den Dienstschlüssel. Deshalb steht in keinem
Browser-Tab ein Schlüssel, mit dem sich mehr anfangen ließe als das, was die
Seite ohnehin anzeigt.

---

## Der Weg von Hand

Falls die Oberfläche einmal nicht erreichbar ist oder etwas gebraucht wird, was
sie nicht kann. Auszuführen im SQL-Editor von Supabase (dort gilt die Rolle
`postgres`) — nicht aus der App heraus: Die Funktionen sind für `authenticated`
ausdrücklich gesperrt, sonst könnte sich jeder Vereinsadmin selbst freischalten.

---

## 1. Offene Anfragen ansehen

```sql
select * from public.offene_freischaltungen;
```

Darin stehen Anfragen aus der App **und** von der Website. Website-Anfragen
haben keine `club_id`, wenn es den Verein zum Zeitpunkt der Anfrage noch nicht
gab — der Name steht trotzdem dabei.

Die Spalte `sponsoring_gewuenscht` sagt, ob der Verein eigene Sponsoren zeigen
will. Das sind **9 € im Monat** oder **80 € im Jahr** über dem Tarif und gehört auf die Rechnung.

## 2. Rechnung stellen

Außerhalb der App. Danach den Vorgang markieren, damit der Verein sieht, dass
etwas passiert:

```sql
update public.club_access_requests
   set status = 'berechnet', handled_at = now()
 where id = '<Anfrage-ID>';
```

In der App steht dann „Rechnung ist unterwegs".

## 3. Nach Zahlungseingang freischalten

```sql
select * from public.verein_freischalten(
  target_club => '<Vereins-ID>',
  stufe       => 'plus',              -- basic, plus oder pro
  zugaenge    => null,                -- null = Zahl des Tarifs behalten
  laufzeit    => '1 year',
  belegnummer => 'RE-2026-0042',
  sponsoring  => true                 -- eigene Sponsoren, +9 €/Monat bzw. +80 €/Jahr
);
```

Ein Aufruf erledigt alles: laufende Freischaltung beenden, neue anlegen,
Zugangszahl und Sponsorenzusatz setzen, offene Anfragen abhaken — auch die von
der Website, die über den Vereinsnamen zugeordnet werden.

Die Rückgabe zeigt, was daraus geworden ist:

| Spalte | Bedeutung |
|---|---|
| `verein` | Name |
| `tarif` | die erkannte Stufe |
| `grenze` | wie viele Zugänge jetzt gelten |
| `sponsoren` | ob eigene Sponsoren erlaubt sind |
| `laeuft_bis` | Ende der Laufzeit |

### Die Parameter im Einzelnen

**`zugaenge`** — `null` lässt eine bestehende Vereinbarung unangetastet. Das ist
der wichtige Fall: Ein Verein mit 2.000 vereinbarten Zugängen behält sie bei der
Verlängerung. `0` setzt auf die Zahl des Tarifs zurück, jede andere Zahl
vereinbart genau diese.

**`sponsoring`** — `null` lässt den Zusatz, wie er ist. `true` schaltet ihn frei,
`false` nimmt ihn weg.

**`belegnummer`** — die Rechnungsnummer. Ohne sie wird eine erzeugt. Zwei
Vereine dürfen nicht dieselbe bekommen; der eindeutige Index weist das ab.

## 4. Verlängern

Derselbe Aufruf. Ohne `zugaenge` und ohne `sponsoring` bleibt alles Vereinbarte
bestehen, nur die Laufzeit ist neu.

## 5. Sperren

```sql
select * from public.verein_sperren('<Vereins-ID>');
```

Beendet die Freischaltung, nimmt die vereinbarte Zugangszahl und den
Sponsorenzusatz weg. Der Verein fällt auf die kostenlose Stufe zurück: drei
Zugänge, Trainings- und Spielpläne. Bestehende Konten bleiben bestehen — die
Grenze wirkt beim Anlegen, nicht rückwirkend.

---

## Was der Verein selbst nicht darf

`vereinbarte_zugaenge`, `sponsoring_freigeschaltet` und
`referral_credit_months` sind gegen Änderungen aus der App geschützt (Trigger
`clubs_betreiberfelder`). Ohne diesen Schutz könnte ein Vereinsadmin

```sql
update clubs set vereinbarte_zugaenge = 100000 where id = <sein Verein>;
```

ausführen und sich von der Stufe basic auf beliebig viele Zugänge stellen.

---

## Anfragen von der Website

Das Formular auf der Website schickt an
`POST /api/vereinsanfrage` mit `Authorization: Bearer <WEBSITE_ANFRAGE_SECRET>`.
Die Felder stehen in `docs/onepage-prompt.md` unter „Wohin das Formular geht".

Der Schlüssel liegt in den Umgebungsvariablen des Vercel-Projekts. Er darf nicht
im Seitenquelltext stehen — das Formular muss serverseitig weiterleiten, sonst
kann jeder in die Tabelle schreiben.
