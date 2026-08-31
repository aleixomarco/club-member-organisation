# Einen Verein freischalten

Alles, was der Betreiber nach einer Anfrage tut. Auszuführen im SQL-Editor von
Supabase (dort gilt die Rolle `postgres`) — nicht aus der App heraus: Die
Funktionen sind für `authenticated` ausdrücklich gesperrt, sonst könnte sich
jeder Vereinsadmin selbst freischalten.

---

## 1. Offene Anfragen ansehen

```sql
select * from public.offene_freischaltungen;
```

Darin stehen Anfragen aus der App **und** von der Website. Website-Anfragen
haben keine `club_id`, wenn es den Verein zum Zeitpunkt der Anfrage noch nicht
gab — der Name steht trotzdem dabei.

Die Spalte `sponsoring_gewuenscht` sagt, ob der Verein eigene Sponsoren zeigen
will. Das sind **5 € im Monat über dem Tarif** und gehört auf die Rechnung.

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
  sponsoring  => true                 -- eigene Sponsoren, +5 €/Monat
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
