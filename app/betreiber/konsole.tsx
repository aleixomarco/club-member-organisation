"use client";

import { useCallback, useEffect, useState } from "react";

/* Die Verwaltung der Vereine, für den Betreiber.
 *
 * Getrennt vom Vereins-Login: Ein Konto in der App gehört immer zu einem
 * Verein, der Betreiber zu keinem. Diese Seite spricht deshalb nicht mit der
 * Datenbank, sondern nur mit dem eigenen Server — der arbeitet mit dem
 * Dienstschlüssel, den der Browser nie zu sehen bekommt.
 */

type Verein = {
  id: string; name: string; short_name: string | null; city: string | null; sport: string | null;
  created_at: string; vereinbarte_zugaenge: number | null; sponsoring_freigeschaltet: boolean;
  tarif: string; grenze: number; konten: number; laeuft_bis: string | null; beleg: string | null;
  referral_credit_months: number;
  mitglieder: number; offene_aufnahmen: number; eigene_sponsoren: number; ansprechpartner: string | null;
};

type Anzeige = {
  id: string; platz: string; titel: string; text: string | null; ziel_url: string | null;
  aktion_titel: string | null; laeuft_bis: string | null; aktiv: boolean;
  impressionen: number; klicks: number;
};

type Anfrage = {
  id: string; created_at: string; quelle: string | null; verein: string | null; club_id: string | null;
  contact_name: string; contact_email: string; contact_phone: string | null;
  expected_accounts: number | null; sponsoring_gewuenscht: boolean; note: string | null; status: string;
  konten_jetzt: number | null; tarif_jetzt: string | null; sponsoren_jetzt: boolean | null;
  rechnungsnummer: string | null; betrag: number | null; zahlweise: string | null;
  rechnung_erstellt_am: string | null; rechnung_versendet_am: string | null; bezahlt_am: string | null;
  freigeschaltet_am: string | null; bestaetigung_versendet_am: string | null; ablehnungsgrund: string | null;
};

type Mitglied = {
  id: string; name: string; email: string | null; status: string; mitglied_seit: number | null;
  mitgliedsnummer: string | null; geburtsdatum: string | null; alter_jahre: number | null;
  geschlecht: string | null; ort: string | null; rollen: string[]; mannschaften: string[];
  letzte_aenderung: string | null; geraete: number; punkte: number;
};

type Zielgruppe = {
  mitglieder: number; aktive: number;
  alter_unter_18: number; alter_18_29: number; alter_30_49: number; alter_50_plus: number;
  alter_unbekannt: number; durchschnittsalter: number | null;
  weiblich: number | null; maennlich: number | null; divers_oder_offen: number | null;
  mannschaften: number; groesste_mannschaft: string | null; groesste_mannschaft_groesse: number | null;
  aktiv_letzte_30_tage: number;
};

type Sponsor = {
  id: string; platz: string; titel: string; text: string | null; bild_url: string | null;
  ziel_url: string | null; aktion_titel: string | null; aktion_text: string | null; aktion_url: string | null;
  laeuft_bis: string | null; aktion_bis: string | null; aktiv: boolean;
  impressionen: number; klicks: number; laeuft_gerade: boolean;
};

/* Der Weg einer Anfrage. Die Reihenfolge steht so auch in der Datenbank
   (anfrage_weiter) - hier ist sie nur die Beschriftung dazu. */
const ABLAUF = [
  { status: "offen", label: "Angefragt", knopf: null as string | null },
  { status: "rechnung_erstellt", label: "Rechnung erstellt", knopf: "Rechnung erstellt" },
  { status: "rechnung_versendet", label: "Rechnung versendet", knopf: "Rechnung versendet" },
  { status: "rechnung_bezahlt", label: "Bezahlt", knopf: "Rechnung gezahlt" },
  { status: "freigeschaltet", label: "Freigeschaltet", knopf: null },
];

const PLATZ_NAMEN: Record<string, string> = {
  dashboard_top: "Start – oben", dashboard_bottom: "Start – unter den News",
  events_header: "Termine – Kopfbereich", profile_bottom: "Profil – unten",
};

const TARIF_NAMEN: Record<string, string> = {
  none: "kostenlos", basic: "Basic", plus: "Plus", pro: "Pro", premium: "Premium",
};

const datum = (wert: string | null) =>
  wert ? new Date(wert).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit", year: "numeric" }) : "—";

export default function BetreiberKonsole() {
  const [angemeldet, setAngemeldet] = useState<boolean | null>(null);
  const [passwort, setPasswort] = useState("");
  const [fehler, setFehler] = useState("");
  const [laeuft, setLaeuft] = useState(false);
  const [vereine, setVereine] = useState<Verein[]>([]);
  const [anfragen, setAnfragen] = useState<Anfrage[]>([]);
  const [anzeigen, setAnzeigen] = useState<Anzeige[]>([]);
  const [anzeigeOffen, setAnzeigeOffen] = useState<Partial<Anzeige> | null>(null);
  const [detail, setDetail] = useState<{ verein: Verein; mitglieder: Mitglied[]; zielgruppe: Zielgruppe | null; sponsoren: Sponsor[] } | null>(null);
  const [suche, setSuche] = useState("");
  const [offen, setOffen] = useState<Verein | null>(null);
  const [meldung, setMeldung] = useState("");

  const laden = useCallback(async () => {
    const antwort = await fetch("/api/betreiber/daten").catch(() => null);
    if (!antwort) { setAngemeldet(true); setFehler("Keine Verbindung zum Server."); return; }
    if (antwort.status === 401) { setAngemeldet(false); return; }
    /* Alles ausser 401 heisst: Die Sitzung gilt, aber etwas anderes ging schief.
       Diese Unterscheidung muss sein - sonst haenge die Seite bei einem
       Serverfehler ewig auf "Wird geladen", und der Fehler waere unsichtbar. */
    setAngemeldet(true);
    const inhalt = await antwort.json().catch(() => ({}));
    if (!antwort.ok) { setFehler(inhalt.error || "Die Übersicht konnte nicht geladen werden."); return; }
    setVereine(inhalt.vereine || []); setAnfragen(inhalt.anfragen || []); setAnzeigen(inhalt.anzeigen || []); setFehler("");
  }, []);

  useEffect(() => { laden(); }, [laden]);

  const anmelden = async (e: React.FormEvent) => {
    e.preventDefault();
    setLaeuft(true); setFehler("");
    const antwort = await fetch("/api/betreiber/anmelden", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ passwort }),
    });
    const inhalt = await antwort.json().catch(() => ({}));
    setLaeuft(false);
    if (!antwort.ok) { setFehler(inhalt.error || "Anmeldung fehlgeschlagen."); return; }
    setPasswort(""); await laden();
  };

  const abmelden = async () => {
    await fetch("/api/betreiber/abmelden", { method: "POST" });
    setAngemeldet(false); setVereine([]); setAnfragen([]); setAnzeigen([]);
  };

  const vereinOeffnen = async (v: Verein) => {
    setLaeuft(true); setFehler("");
    const antwort = await fetch("/api/betreiber/aktion", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ art: "verein", verein: v.id }),
    }).catch(() => null);
    setLaeuft(false);
    if (!antwort) { setFehler("Keine Verbindung zum Server."); return; }
    if (antwort.status === 401) { setAngemeldet(false); return; }
    const inhalt = await antwort.json().catch(() => ({}));
    if (!antwort.ok) { setFehler(inhalt.error || "Die Vereinsansicht konnte nicht geladen werden."); return; }
    setDetail({ verein: v, mitglieder: inhalt.mitglieder || [], zielgruppe: inhalt.zielgruppe, sponsoren: inhalt.sponsoren || [] });
  };

  const aktion = async (rumpf: Record<string, unknown>) => {
    setLaeuft(true); setMeldung(""); setFehler("");
    /* Ohne dieses catch bliebe laeuft bei einem Netzwerkfehler fuer immer true:
       Jeder Knopf waere ausgegraut, und nur ein Neuladen der Seite brachte die
       Konsole zurueck. */
    const antwort = await fetch("/api/betreiber/aktion", {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(rumpf),
    }).catch(() => null);
    if (!antwort) { setLaeuft(false); setFehler("Keine Verbindung zum Server. Die Aktion wurde nicht ausgeführt."); return null; }
    if (antwort.status === 401) { setLaeuft(false); setAngemeldet(false); return null; }
    const inhalt = await antwort.json().catch(() => ({}));
    setLaeuft(false);
    if (!antwort.ok) { setFehler(inhalt.error || "Die Aktion ist fehlgeschlagen."); return null; }
    await laden();
    return inhalt;
  };

  if (angemeldet === null) {
    return <main style={huelle}><p style={{ color: "#8A7F85" }}>Wird geladen …</p></main>;
  }

  if (!angemeldet) {
    return (
      <main style={huelle}>
        <form onSubmit={anmelden} style={{ ...karte, maxWidth: 380, margin: "10vh auto 0" }}>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: "0 0 4px" }}>Vereinsverwaltung</h1>
          <p style={{ fontSize: 13, color: "#8A7F85", margin: "0 0 18px" }}>
            Zugang für den Betreiber. Nicht dasselbe wie ein Vereinskonto.
          </p>
          <input
            type="password" value={passwort} onChange={(e) => setPasswort(e.target.value)}
            placeholder="Passwort" autoFocus autoComplete="current-password" style={feld}
          />
          {fehler && <p role="status" style={fehlerText}>{fehler}</p>}
          <button type="submit" disabled={laeuft || !passwort} style={{ ...knopf, width: "100%", marginTop: 12, opacity: laeuft || !passwort ? 0.6 : 1 }}>
            {laeuft ? "Einen Moment …" : "Anmelden"}
          </button>
        </form>
      </main>
    );
  }

  const gefiltert = suche.trim()
    ? vereine.filter((v) => `${v.name} ${v.short_name || ""} ${v.city || ""}`.toLowerCase().includes(suche.trim().toLowerCase()))
    : vereine;
  const freigeschaltet = vereine.filter((v) => v.tarif !== "none").length;
  const amLimit = vereine.filter((v) => v.konten >= v.grenze).length;

  return (
    <main style={huelle}>
      <header style={{ display: "flex", alignItems: "baseline", gap: 12, flexWrap: "wrap", marginBottom: 20 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>Vereinsverwaltung</h1>
        <span style={{ fontSize: 13, color: "#8A7F85" }}>
          {vereine.length} Vereine · {freigeschaltet} freigeschaltet · {anfragen.length} offene Anfragen
          {amLimit > 0 && <> · <b style={{ color: "#B3261E" }}>{amLimit} an der Grenze</b></>}
        </span>
        <button onClick={abmelden} style={{ ...knopfLeise, marginLeft: "auto" }}>Abmelden</button>
      </header>

      {fehler && <p role="status" style={fehlerText}>{fehler}</p>}
      {meldung && <p role="status" style={{ ...fehlerText, background: "rgba(231,243,236,0.72)", color: "#1E6B3A" }}>{meldung}</p>}

      {/* Anfragen zuerst: Sie sind das Einzige, was auf eine Reaktion wartet. */}
      <section style={{ marginBottom: 28 }}>
        <h2 style={ueberschrift}>Offene Anfragen</h2>
        {anfragen.length === 0 ? (
          <p style={{ ...karte, color: "#8A7F85", fontSize: 13 }}>Keine offenen Anfragen.</p>
        ) : anfragen.map((a) => (
          <div key={a.id} style={{ ...karte, marginBottom: 10 }}>
            <div style={{ display: "flex", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>
              <b style={{ fontSize: 15 }}>{a.verein || "Verein ohne Zuordnung"}</b>
              <span style={abzeichen}>{a.status === "berechnet" ? "Rechnung gestellt" : "offen"}</span>
              <span style={{ ...abzeichen, background: "#EEE9EC" }}>{a.quelle === "website" ? "Website" : "App"}</span>
              {a.sponsoring_gewuenscht && <span style={{ ...abzeichen, background: "rgba(255,240,214,0.9)", color: "#8A5A00" }}>+ eigene Sponsoren, 5 €/Monat</span>}
              <span style={{ fontSize: 12, color: "#8A7F85", marginLeft: "auto" }}>{datum(a.created_at)}</span>
            </div>
            <div style={{ fontSize: 13, color: "#4A424A", marginTop: 6, lineHeight: 1.6 }}>
              {a.contact_name} · <a href={`mailto:${a.contact_email}`} style={{ color: "#B3261E" }}>{a.contact_email}</a>
              {a.contact_phone && <> · {a.contact_phone}</>}
              {a.expected_accounts != null && <> · <b>{a.expected_accounts} Zugänge gewünscht</b></>}
              {a.club_id && <> · aktuell {a.konten_jetzt} Konten, Tarif {TARIF_NAMEN[a.tarif_jetzt || "none"] || a.tarif_jetzt}</>}
              {!a.club_id && <> · <i>Verein noch nicht in der App</i></>}
            </div>
            {a.note && <p style={{ fontSize: 13, color: "#4A424A", background: "#F5F2F4", borderRadius: 8, padding: "8px 10px", margin: "8px 0 0" }}>{a.note}</p>}
            <AnfrageAblauf anfrage={a} laeuft={laeuft} vereine={vereine}
              onSchritt={aktion} onFreischalten={setOffen} onMeldung={setMeldung} />
          </div>
        ))}
      </section>

      <section>
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 10, flexWrap: "wrap" }}>
          <h2 style={{ ...ueberschrift, marginBottom: 0 }}>Vereine</h2>
          <input value={suche} onChange={(e) => setSuche(e.target.value)} placeholder="Suchen …"
            style={{ ...feld, width: 200, marginBottom: 0, padding: "8px 10px" }} />
        </div>

        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, minWidth: 720 }}>
            <thead>
              <tr style={{ textAlign: "left", color: "#8A7F85", fontSize: 11, textTransform: "uppercase", letterSpacing: ".06em" }}>
                <th style={zelle}>Verein</th><th style={zelle}>Tarif</th><th style={zelle}>Zugänge</th>
                <th style={zelle}>Sponsoren</th><th style={zelle}>Läuft bis</th><th style={zelle}>Guthaben</th><th style={zelle}>Ansprechpartner</th><th style={zelle} />
              </tr>
            </thead>
            <tbody>
              {gefiltert.map((v) => {
                const voll = v.konten >= v.grenze;
                return (
                  <tr key={v.id} style={{ borderTop: "1px solid #E9E4E7" }}>
                    <td style={zelle}>
                      <button onClick={() => vereinOeffnen(v)} disabled={laeuft}
                        style={{ background: "none", border: "none", padding: 0, cursor: "pointer", font: "inherit", textAlign: "left" as const }}>
                        <b style={{ borderBottom: "1px dotted #B3261E" }}>{v.name}</b>
                      </button>
                      <div style={{ color: "#8A7F85", fontSize: 12 }}>
                        {v.city || "—"}{v.offene_aufnahmen > 0 && <> · <b style={{ color: "#8A5A00" }}>{v.offene_aufnahmen} Aufnahme(n) offen</b></>}
                      </div>
                    </td>
                    <td style={zelle}>{TARIF_NAMEN[v.tarif] || v.tarif}</td>
                    <td style={{ ...zelle, color: voll ? "#B3261E" : undefined, fontWeight: voll ? 700 : 400 }}>
                      {v.konten} / {v.grenze}
                      {v.vereinbarte_zugaenge != null && <div style={{ fontSize: 11, color: "#8A7F85" }}>vereinbart</div>}
                    </td>
                    <td style={zelle}>{v.sponsoring_freigeschaltet ? `ja (${v.eigene_sponsoren})` : "—"}</td>
                    <td style={zelle}>{datum(v.laeuft_bis)}</td>
                    {/* Offenes Empfehlungsguthaben. Es stand bisher in keiner
                        Uebersicht - die App sagt dem Werber aber zu, es werde
                        "automatisch beruecksichtigt". Wer die Rechnung
                        schreibt, muss es sehen. */}
                    <td style={zelle}>
                      {v.referral_credit_months > 0 ? (
                        <button style={{ ...knopfLeise, marginRight: 0, color: "#8A5A00" }} disabled={laeuft}
                          onClick={async () => {
                            if (!window.confirm(`${v.referral_credit_months} Gutschriftsmonate für „${v.name}" jetzt an die Laufzeit anhängen?`)) return;
                            const e = await aktion({ art: "guthaben", verein: v.id });
                            if (e) setMeldung(`${e.ergebnis?.eingeloest ?? 0} Monate angehängt, ${e.ergebnis?.rest ?? 0} übrig.`);
                          }}>
                          {v.referral_credit_months} Mon. einlösen
                        </button>
                      ) : "—"}
                    </td>
                    <td style={{ ...zelle, color: "#8A7F85", fontSize: 12 }}>{v.ansprechpartner || "—"}</td>
                    <td style={{ ...zelle, whiteSpace: "nowrap" }}>
                      <button style={knopfLeise} disabled={laeuft} onClick={() => setOffen(v)}>Freischalten …</button>
                      {v.tarif !== "none" && (
                        <button style={{ ...knopfLeise, color: "#B3261E" }} disabled={laeuft}
                          onClick={async () => {
                            if (!window.confirm(`\u201e${v.name}\u201c sperren?\n\nDer Verein fällt auf die kostenlose Stufe zurück: drei Zugänge, nur Trainings- und Spielpläne. Bestehende Konten bleiben bestehen, neue lassen sich nicht mehr anlegen.\n\nAusserdem wird zurückgesetzt:\n· die vereinbarte Zugangszahl${v.vereinbarte_zugaenge != null ? ` (derzeit ${v.vereinbarte_zugaenge})` : ""}\n· der Sponsorenzusatz${v.sponsoring_freigeschaltet ? " (derzeit freigeschaltet)" : ""}\n\nBeides muss beim erneuten Freischalten neu eingetragen werden.`)) return;
                            const ok = await aktion({ art: "sperren", verein: v.id });
                            if (ok) setMeldung(`${v.name} ist gesperrt.`);
                          }}>Sperren</button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      {/* Die eigene Werbung. Sie gilt in jedem Verein und tritt zurueck, sobald
          ein Verein einen eigenen Sponsor auf denselben Platz setzt. Bisher
          liess sie sich nur von Hand im SQL-Editor anlegen. */}
      <section style={{ marginTop: 28 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 10, flexWrap: "wrap" }}>
          <h2 style={{ ...ueberschrift, marginBottom: 0 }}>Eigene Werbeplätze</h2>
          <button style={knopfLeise} disabled={laeuft} onClick={() => setAnzeigeOffen({ platz: "dashboard_top", aktiv: true })}>Neue Anzeige</button>
        </div>
        <p style={{ ...hinweis, marginTop: -4 }}>
          Gilt in jedem Verein. Wo ein Verein einen eigenen, laufenden Sponsor auf demselben Platz hat, tritt Ihre Anzeige zurück.
        </p>
        {anzeigen.length === 0 ? (
          <p style={{ ...karte, color: "#8A7F85", fontSize: 13 }}>Noch keine eigene Anzeige — die Plätze bleiben leer, solange kein Verein sie belegt.</p>
        ) : (
          <div style={{ display: "grid", gap: 8 }}>
            {anzeigen.map((a) => (
              <div key={a.id} style={{ ...karte, display: "flex", gap: 12, alignItems: "baseline", flexWrap: "wrap" }}>
                <span style={abzeichen}>{PLATZ_NAMEN[a.platz] || a.platz}</span>
                <b style={{ fontSize: 14 }}>{a.titel}</b>
                {!a.aktiv && <span style={{ ...abzeichen, background: "#F0EBEE" }}>ausgeschaltet</span>}
                {a.laeuft_bis && <span style={{ fontSize: 12, color: "#8A7F85" }}>bis {datum(a.laeuft_bis)}</span>}
                <span style={{ fontSize: 12, color: "#8A7F85", marginLeft: "auto" }}>{a.impressionen} Einblendungen · {a.klicks} Klicks</span>
                <button style={knopfLeise} disabled={laeuft} onClick={() => setAnzeigeOffen(a)}>Bearbeiten</button>
              </div>
            ))}
          </div>
        )}
      </section>

      {detail && <VereinsDetail daten={detail} onSchliessen={() => setDetail(null)} />}

      {anzeigeOffen && (
        <AnzeigeDialog
          anzeige={anzeigeOffen}
          laeuft={laeuft}
          onAbbrechen={() => setAnzeigeOffen(null)}
          onSpeichern={async (werte) => {
            const ok = await aktion({ art: "anzeige", anzeige: anzeigeOffen.id, ...werte });
            if (ok) { setAnzeigeOffen(null); setMeldung("Anzeige gespeichert."); }
          }}
          onEntfernen={async () => {
            if (!anzeigeOffen.id || !window.confirm(`Anzeige \u201e${anzeigeOffen.titel}\u201c entfernen?`)) return;
            const ok = await aktion({ art: "anzeige", anzeige: anzeigeOffen.id, entfernen: true });
            if (ok) { setAnzeigeOffen(null); setMeldung("Anzeige entfernt."); }
          }}
        />
      )}

      {offen && (
        <FreischaltDialog
          verein={offen}
          laeuft={laeuft}
          onAbbrechen={() => setOffen(null)}
          onFreischalten={async (werte) => {
            const ergebnis = await aktion({ art: "freischalten", verein: offen.id, ...werte });
            if (ergebnis) {
              const r = ergebnis.ergebnis;
              setMeldung(r
                ? `${r.verein}: ${TARIF_NAMEN[r.tarif] || r.tarif}, ${r.grenze} Zugänge${r.sponsoren ? ", eigene Sponsoren" : ""}, bis ${datum(r.laeuft_bis)}.`
                : "Freigeschaltet.");
              setOffen(null);
            }
          }}
        />
      )}
    </main>
  );
}

/* Der Rechnungsablauf einer Anfrage.
 *
 * Bewusst als sichtbare Kette und nicht als Auswahlfeld: Der Betreiber soll auf
 * einen Blick sehen, wo dieser Vorgang steht und was als Naechstes dran ist.
 * Was moeglich ist, entscheidet die Datenbank - hier steht nur, was sie sagt. */
/* Alles über einen Verein.
 *
 * Zwei Teile, und die Trennung ist Absicht: Oben das Zielgruppenprofil — Zahlen
 * ohne Namen, das ist das, was man einem Werbepartner zeigen kann. Unten die
 * Mitgliederliste für den Betrieb. Die Mitglieder haben ihre Daten dem VEREIN
 * gegeben, nicht dessen Sponsoren; wer beides vermischt, gibt irgendwann eine
 * Liste weiter, die niemand weitergeben darf. */
function VereinsDetail({ daten, onSchliessen }: {
  daten: { verein: Verein; mitglieder: Mitglied[]; zielgruppe: Zielgruppe | null; sponsoren: Sponsor[] };
  onSchliessen: () => void;
}) {
  const { verein, mitglieder, zielgruppe, sponsoren } = daten;
  const [suche, setSuche] = useState("");
  const [rolle, setRolle] = useState("");
  const [team, setTeam] = useState("");

  const rollen = [...new Set(mitglieder.flatMap((m) => m.rollen))].sort();
  const teams = [...new Set(mitglieder.flatMap((m) => m.mannschaften))].sort();
  const gefiltert = mitglieder.filter((m) =>
    (!suche.trim() || `${m.name} ${m.email || ""} ${m.ort || ""}`.toLowerCase().includes(suche.trim().toLowerCase()))
    && (!rolle || m.rollen.includes(rolle))
    && (!team || m.mannschaften.includes(team)));

  const Zahl = ({ wert, label }: { wert: React.ReactNode; label: string }) => (
    <div style={{ ...karte, padding: 12, minWidth: 116, flex: "1 1 116px" }}>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{wert}</div>
      <div style={{ fontSize: 11, color: "#8A7F85", marginTop: 2 }}>{label}</div>
    </div>
  );

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(20,21,26,.5)", display: "flex", alignItems: "flex-start", justifyContent: "center", padding: 16, overflowY: "auto" }}
         onClick={onSchliessen}>
      <div role="dialog" aria-modal="true" aria-label={verein.name} onClick={(e) => e.stopPropagation()}
           style={{ ...karte, width: "100%", maxWidth: 900, marginTop: 24, marginBottom: 24 }}>
        <div style={{ display: "flex", alignItems: "baseline", gap: 12, flexWrap: "wrap", marginBottom: 4 }}>
          <h2 style={{ fontSize: 19, fontWeight: 700, margin: 0 }}>{verein.name}</h2>
          <span style={{ fontSize: 13, color: "#8A7F85" }}>
            {verein.city || "—"} · {TARIF_NAMEN[verein.tarif] || verein.tarif} · {verein.konten} von {verein.grenze} Zugängen
          </span>
          <button onClick={onSchliessen} style={{ ...knopfLeise, marginLeft: "auto", marginRight: 0 }}>Schließen</button>
        </div>

        {/* --- Zielgruppe: Zahlen ohne Namen --- */}
        <h3 style={{ ...ueberschrift, marginTop: 18 }}>Zielgruppe</h3>
        <p style={{ ...hinweis, marginTop: -6 }}>
          Diese Zahlen können Sie einem Werbepartner zeigen. Gruppen unter fünf Personen werden
          nicht ausgewiesen — bei zwei Frauen in einem Verein ist „zwei Frauen“ keine Statistik mehr,
          sondern ein Hinweis auf zwei bestimmte Personen.
        </p>
        {zielgruppe ? (
          <>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 10 }}>
              <Zahl wert={zielgruppe.mitglieder} label="Mitglieder" />
              <Zahl wert={zielgruppe.aktive} label="davon aktiv" />
              <Zahl wert={zielgruppe.durchschnittsalter ?? "—"} label="Durchschnittsalter" />
              <Zahl wert={zielgruppe.mannschaften} label="Mannschaften" />
              <Zahl wert={zielgruppe.aktiv_letzte_30_tage} label="App-Nutzung, 30 Tage" />
            </div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 10 }}>
              <Zahl wert={zielgruppe.alter_unter_18} label="unter 18" />
              <Zahl wert={zielgruppe.alter_18_29} label="18 – 29" />
              <Zahl wert={zielgruppe.alter_30_49} label="30 – 49" />
              <Zahl wert={zielgruppe.alter_50_plus} label="50 und älter" />
              <Zahl wert={zielgruppe.alter_unbekannt} label="ohne Angabe" />
            </div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              <Zahl wert={zielgruppe.weiblich ?? "—"} label="weiblich" />
              <Zahl wert={zielgruppe.maennlich ?? "—"} label="männlich" />
              <Zahl wert={zielgruppe.groesste_mannschaft || "—"} label={`größte Mannschaft (${zielgruppe.groesste_mannschaft_groesse ?? 0})`} />
            </div>
          </>
        ) : <p style={{ ...karte, fontSize: 13, color: "#8A7F85" }}>Keine Angaben.</p>}

        {/* --- Sponsoren, nur mit freigeschaltetem Zusatz --- */}
        <h3 style={{ ...ueberschrift, marginTop: 22 }}>Gebuchte Sponsoren</h3>
        {!verein.sponsoring_freigeschaltet ? (
          <p style={{ ...karte, fontSize: 13, color: "#8A7F85" }}>
            Der Sponsorenzusatz ist für diesen Verein nicht freigeschaltet (9 € im Monat oder 80 € im Jahr).
            Er kann zwar Sponsoren vorbereiten, angezeigt wird davon nichts.
          </p>
        ) : sponsoren.length === 0 ? (
          <p style={{ ...karte, fontSize: 13, color: "#8A7F85" }}>Freigeschaltet, aber noch kein Sponsor eingetragen.</p>
        ) : (
          <div style={{ display: "grid", gap: 8 }}>
            {sponsoren.map((sp) => (
              <div key={sp.id} style={{ ...karte, display: "flex", gap: 12 }}>
                {sp.bild_url && <img src={sp.bild_url} alt="" style={{ width: 72, height: 72, objectFit: "cover", borderRadius: 10, flexShrink: 0 }} />}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", gap: 8, alignItems: "baseline", flexWrap: "wrap" }}>
                    <span style={abzeichen}>{PLATZ_NAMEN[sp.platz] || sp.platz}</span>
                    <b style={{ fontSize: 14 }}>{sp.titel}</b>
                    <span style={{ ...abzeichen, background: sp.laeuft_gerade ? "rgba(231,243,236,0.9)" : "#F0EBEE", color: sp.laeuft_gerade ? "#1E6B3A" : "#8A7F85" }}>
                      {sp.laeuft_gerade ? "läuft" : "läuft nicht"}
                    </span>
                    <span style={{ fontSize: 12, color: "#8A7F85", marginLeft: "auto" }}>{sp.impressionen} Einblendungen · {sp.klicks} Klicks</span>
                  </div>
                  {sp.text && <p style={{ fontSize: 13, color: "#4A424A", margin: "6px 0 0" }}>{sp.text}</p>}
                  {sp.ziel_url && <p style={{ fontSize: 12, margin: "4px 0 0" }}><a href={sp.ziel_url} target="_blank" rel="noopener noreferrer" style={{ color: "#B3261E" }}>{sp.ziel_url}</a></p>}
                  {sp.aktion_titel && (
                    <p style={{ fontSize: 12, margin: "6px 0 0", color: "#8A5A00" }}>
                      <b>Aktion:</b> {sp.aktion_titel}
                      {sp.aktion_text && <> — {sp.aktion_text}</>}
                      {sp.aktion_bis && <> (bis {datum(sp.aktion_bis)})</>}
                    </p>
                  )}
                  {sp.laeuft_bis && <p style={{ ...hinweis, margin: "4px 0 0" }}>Sponsor steht bis {datum(sp.laeuft_bis)}</p>}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* --- Mitglieder: fuer den Betrieb, nicht fuer Werbepartner --- */}
        <h3 style={{ ...ueberschrift, marginTop: 22 }}>Mitglieder ({mitglieder.length})</h3>
        <p style={{ ...hinweis, marginTop: -6 }}>
          Personenbezogene Daten. Für Rückfragen und Betrieb — nicht dafür gedacht, sie nach außen zu geben.
        </p>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 8 }}>
          <input value={suche} onChange={(e) => setSuche(e.target.value)} placeholder="Suchen …"
            style={{ ...feld, width: 180, marginBottom: 0, padding: "8px 10px" }} />
          <select value={rolle} onChange={(e) => setRolle(e.target.value)} style={{ ...feld, width: 160, marginBottom: 0, padding: "8px 10px" }}>
            <option value="">alle Rollen</option>
            {rollen.map((r) => <option key={r} value={r}>{r}</option>)}
          </select>
          <select value={team} onChange={(e) => setTeam(e.target.value)} style={{ ...feld, width: 170, marginBottom: 0, padding: "8px 10px" }}>
            <option value="">alle Mannschaften</option>
            {teams.map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
          <span style={{ ...hinweis, alignSelf: "center", margin: 0 }}>{gefiltert.length} von {mitglieder.length}</span>
        </div>

        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, minWidth: 760 }}>
            <thead>
              <tr style={{ textAlign: "left" as const, color: "#8A7F85", fontSize: 11, textTransform: "uppercase" as const, letterSpacing: ".06em" }}>
                <th style={zelle}>Name</th><th style={zelle}>Status</th><th style={zelle}>Seit</th>
                <th style={zelle}>Alter</th><th style={zelle}>Rollen</th><th style={zelle}>Mannschaft</th>
                <th style={zelle}>Punkte</th><th style={zelle}>Geräte</th>
              </tr>
            </thead>
            <tbody>
              {gefiltert.map((m) => (
                <tr key={m.id} style={{ borderTop: "1px solid #E9E4E7" }}>
                  <td style={zelle}>
                    <b>{m.name}</b>
                    <div style={{ fontSize: 12, color: "#8A7F85" }}>{m.email || "—"}{m.ort ? ` · ${m.ort}` : ""}</div>
                  </td>
                  <td style={zelle}>{m.status}</td>
                  <td style={zelle}>{m.mitglied_seit ?? "—"}</td>
                  <td style={zelle}>{m.alter_jahre ?? "—"}</td>
                  <td style={{ ...zelle, fontSize: 12 }}>{m.rollen.join(", ") || "—"}</td>
                  <td style={{ ...zelle, fontSize: 12 }}>{m.mannschaften.join(", ") || "—"}</td>
                  <td style={zelle}>{m.punkte}</td>
                  <td style={zelle}>{m.geraete}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function AnfrageAblauf({ anfrage, laeuft, vereine, onSchritt, onFreischalten, onMeldung }: {
  anfrage: Anfrage; laeuft: boolean; vereine: Verein[];
  onSchritt: (r: Record<string, unknown>) => Promise<Record<string, unknown> | null>;
  onFreischalten: (v: Verein) => void;
  onMeldung: (t: string) => void;
}) {
  const [nummer, setNummer] = useState(anfrage.rechnungsnummer || "");
  const [betrag, setBetrag] = useState(anfrage.betrag != null ? String(anfrage.betrag) : "");
  const [zahlweise, setZahlweise] = useState(anfrage.zahlweise || "jaehrlich");
  const [grund, setGrund] = useState("");
  const [ablehnen, setAblehnen] = useState(false);

  const jetzt = ABLAUF.findIndex((x) => x.status === anfrage.status);
  const naechster = jetzt >= 0 && jetzt < ABLAUF.length - 1 ? ABLAUF[jetzt + 1] : null;
  const abgelehnt = anfrage.status === "abgelehnt";
  const bezahlt = anfrage.status === "rechnung_bezahlt";
  const frei = anfrage.status === "freigeschaltet";
  const zeit = (w: string | null) => (w ? new Date(w).toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" }) : null);

  return (
    <div style={{ marginTop: 12 }}>
      {/* Die Kette. Erledigte Schritte tragen ihr Datum. */}
      <div style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap", marginBottom: 10 }}>
        {ABLAUF.map((schritt, i) => {
          const erledigt = !abgelehnt && jetzt >= i;
          const wann = zeit(
            schritt.status === "rechnung_erstellt" ? anfrage.rechnung_erstellt_am :
            schritt.status === "rechnung_versendet" ? anfrage.rechnung_versendet_am :
            schritt.status === "rechnung_bezahlt" ? anfrage.bezahlt_am :
            schritt.status === "freigeschaltet" ? anfrage.freigeschaltet_am :
            anfrage.created_at
          );
          return (
            <span key={schritt.status} style={{ display: "flex", alignItems: "center", gap: 6 }}>
              {i > 0 && <span style={{ color: "#DDD6DA" }}>›</span>}
              <span style={{
                fontSize: 11, fontWeight: 700, padding: "3px 9px", borderRadius: 999,
                background: erledigt ? "rgba(231,243,236,0.9)" : "#F2EEF0",
                color: erledigt ? "#1E6B3A" : "#8A7F85",
              }}>
                {schritt.label}{erledigt && wann ? ` · ${wann}` : ""}
              </span>
            </span>
          );
        })}
        {abgelehnt && (
          <span style={{ fontSize: 11, fontWeight: 700, padding: "3px 9px", borderRadius: 999, background: "rgba(253,236,236,0.9)", color: "#B3261E" }}>
            Abgelehnt{zeit(anfrage.created_at) ? "" : ""}
          </span>
        )}
      </div>

      {abgelehnt && anfrage.ablehnungsgrund && (
        <p style={{ ...hinweis, marginTop: -4 }}>Grund: {anfrage.ablehnungsgrund}</p>
      )}

      {/* Beim Erstellen der Rechnung werden Nummer und Betrag mitgegeben -
          spaeter muss niemand mehr danach suchen. */}
      {anfrage.status === "offen" && (
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 8 }}>
          <input value={nummer} onChange={(e) => setNummer(e.target.value)} placeholder="Rechnungsnummer"
            style={{ ...feld, width: 170, marginBottom: 0, padding: "8px 10px" }} />
          <input value={betrag} onChange={(e) => setBetrag(e.target.value)} placeholder="Betrag €" inputMode="decimal"
            style={{ ...feld, width: 110, marginBottom: 0, padding: "8px 10px" }} />
          <select value={zahlweise} onChange={(e) => setZahlweise(e.target.value)}
            style={{ ...feld, width: 130, marginBottom: 0, padding: "8px 10px" }}>
            <option value="jaehrlich">jährlich</option>
            <option value="monatlich">monatlich</option>
          </select>
        </div>
      )}

      {(anfrage.rechnungsnummer || anfrage.betrag != null) && anfrage.status !== "offen" && (
        <p style={{ ...hinweis, marginTop: -2 }}>
          Rechnung {anfrage.rechnungsnummer || "ohne Nummer"}
          {anfrage.betrag != null && <> · {anfrage.betrag.toLocaleString("de-DE", { minimumFractionDigits: 2 })} €</>}
          {anfrage.zahlweise && <> · {anfrage.zahlweise}</>}
        </p>
      )}

      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        {naechster?.knopf && !abgelehnt && (
          <button style={knopf} disabled={laeuft}
            onClick={async () => {
              const ok = await onSchritt({
                art: "anfrage", anfrage: anfrage.id, verein: anfrage.club_id, status: naechster.status,
                rechnungsnummer: nummer, betrag, zahlweise,
              });
              if (ok) onMeldung(`${naechster.label}.`);
            }}>{naechster.knopf}</button>
        )}

        {/* Freischalten wird erst hier angeboten - vorher weist die Datenbank
            es ohnehin ab, und ein Knopf, der nicht darf, ist ein Aergernis. */}
        {bezahlt && anfrage.club_id && (
          <button style={knopf} disabled={laeuft}
            onClick={() => {
              const v = vereine.find((x) => x.id === anfrage.club_id);
              if (v) onFreischalten(v);
            }}>Verein freischalten …</button>
        )}
        {bezahlt && !anfrage.club_id && (
          <span style={{ ...hinweis, alignSelf: "center" }}>
            Der Verein ist noch nicht in der App. Sobald er angelegt ist, lässt er sich hier freischalten.
          </span>
        )}

        {frei && !anfrage.bestaetigung_versendet_am && (
          <button style={knopf} disabled={laeuft}
            onClick={async () => {
              const ok = await onSchritt({ art: "bestaetigung", anfrage: anfrage.id });
              if (ok) onMeldung("Bestätigungsmail vermerkt.");
            }}>Bestätigungsmail versendet</button>
        )}
        {frei && anfrage.bestaetigung_versendet_am && (
          <span style={{ ...hinweis, alignSelf: "center", color: "#1E6B3A" }}>
            Bestätigung versendet am {new Date(anfrage.bestaetigung_versendet_am).toLocaleDateString("de-DE")} — erledigt.
          </span>
        )}

        {!abgelehnt && !frei && (
          ablehnen ? (
            <span style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
              <input value={grund} onChange={(e) => setGrund(e.target.value)} placeholder="Grund (bleibt hinterlegt)"
                style={{ ...feld, width: 220, marginBottom: 0, padding: "8px 10px" }} />
              <button style={{ ...knopf, background: "#B3261E" }} disabled={laeuft}
                onClick={async () => {
                  const ok = await onSchritt({ art: "anfrage", anfrage: anfrage.id, verein: anfrage.club_id, status: "abgelehnt", grund });
                  if (ok) { setAblehnen(false); onMeldung("Abgelehnt. Der Verein kann jederzeit neu anfragen."); }
                }}>Ablehnen</button>
              <button style={knopfLeise} onClick={() => setAblehnen(false)}>Zurück</button>
            </span>
          ) : (
            <button style={{ ...knopfLeise, color: "#B3261E" }} disabled={laeuft} onClick={() => setAblehnen(true)}>Ablehnen …</button>
          )
        )}
      </div>
    </div>
  );
}

function AnzeigeDialog({ anzeige, laeuft, onAbbrechen, onSpeichern, onEntfernen }: {
  anzeige: Partial<Anzeige>; laeuft: boolean;
  onAbbrechen: () => void;
  onSpeichern: (werte: Record<string, unknown>) => void;
  onEntfernen: () => void;
}) {
  const [platz, setPlatz] = useState(anzeige.platz || "dashboard_top");
  const [titel, setTitel] = useState(anzeige.titel || "");
  const [text, setText] = useState(anzeige.text || "");
  const [zielUrl, setZielUrl] = useState(anzeige.ziel_url || "");
  const [bis, setBis] = useState(anzeige.laeuft_bis ? anzeige.laeuft_bis.slice(0, 10) : "");
  const [aktiv, setAktiv] = useState(anzeige.aktiv !== false);
  const [fehler, setFehler] = useState("");

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(20,21,26,.5)", display: "flex", alignItems: "center", justifyContent: "center", padding: 16 }}
         onClick={onAbbrechen}>
      <div role="dialog" aria-modal="true" aria-label="Anzeige bearbeiten" onClick={(e) => e.stopPropagation()}
           style={{ ...karte, width: "100%", maxWidth: 460, maxHeight: "90vh", overflowY: "auto" }}>
        <h2 style={{ fontSize: 17, fontWeight: 700, margin: "0 0 14px" }}>{anzeige.id ? "Anzeige bearbeiten" : "Neue Anzeige"}</h2>

        <label style={beschriftung}>Werbeplatz</label>
        <select value={platz} onChange={(e) => setPlatz(e.target.value)} style={feld}>
          {Object.entries(PLATZ_NAMEN).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>

        <label style={beschriftung}>Titel</label>
        <input value={titel} onChange={(e) => setTitel(e.target.value)} maxLength={120} style={feld} />

        <label style={beschriftung}>Text (optional)</label>
        <textarea value={text} onChange={(e) => setText(e.target.value)} maxLength={400} rows={3}
          style={{ ...feld, resize: "vertical" as const }} />

        <label style={beschriftung}>Ziel-Adresse (optional)</label>
        <input type="url" value={zielUrl} onChange={(e) => setZielUrl(e.target.value)} placeholder="https://…" style={feld} />

        <label style={beschriftung}>Läuft bis (optional)</label>
        <input type="date" value={bis} onChange={(e) => setBis(e.target.value)} style={feld} />
        <p style={hinweis}>Ohne Datum bleibt die Anzeige stehen, bis Sie sie entfernen.</p>

        <button type="button" onClick={() => setAktiv(!aktiv)}
          style={{ ...knopfLeise, width: "100%", marginRight: 0, marginBottom: 4, textAlign: "left" as const }}>
          {aktiv ? "Eingeschaltet" : "Ausgeschaltet"}
        </button>

        {fehler && <p role="status" style={fehlerText}>{fehler}</p>}

        <div style={{ display: "flex", gap: 8, marginTop: 14 }}>
          <button style={{ ...knopfLeise, flex: 1 }} onClick={onAbbrechen}>Abbrechen</button>
          <button style={{ ...knopf, flex: 1, opacity: laeuft ? 0.6 : 1 }} disabled={laeuft}
            onClick={() => {
              if (!titel.trim()) { setFehler("Ohne Titel geht es nicht."); return; }
              onSpeichern({ platz, titel, text, ziel_url: zielUrl, laeuft_bis: bis, aktiv });
            }}>{laeuft ? "…" : "Speichern"}</button>
        </div>
        {anzeige.id && (
          <button onClick={onEntfernen} disabled={laeuft}
            style={{ ...knopfLeise, width: "100%", marginTop: 8, marginRight: 0, color: "#B3261E" }}>Anzeige entfernen</button>
        )}
      </div>
    </div>
  );
}

function FreischaltDialog({ verein, laeuft, onAbbrechen, onFreischalten }: {
  verein: Verein; laeuft: boolean;
  onAbbrechen: () => void;
  onFreischalten: (werte: Record<string, unknown>) => void;
}) {
  /* Vorbelegt mit dem Tarif, den der Verein HAT - nicht mit dem billigsten.
     Vorher stand hier immer "basic": Wer die Jahresrechnung eines Pro-Vereins
     verlaengern wollte und die Auswahl nicht bemerkte, stufte ihn dabei von
     1.000 auf 100 Zugaenge herab. Bei 600 Mitgliedern heisst das: ab sofort
     kein einziges neues Konto mehr, und niemand weiss, warum. */
  const RANG: Record<string, number> = { none: 0, basic: 1, plus: 2, pro: 3 };
  const [stufe, setStufe] = useState(RANG[verein.tarif] ? verein.tarif : "basic");
  const stuftHerab = RANG[verein.tarif] > 0 && RANG[stufe] < RANG[verein.tarif];
  const [laufzeit, setLaufzeit] = useState("jahr");
  const [zugaenge, setZugaenge] = useState("");
  const [belegnummer, setBelegnummer] = useState("");
  const [sponsoring, setSponsoring] = useState("unveraendert");

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(20,21,26,.5)", display: "flex", alignItems: "center", justifyContent: "center", padding: 16 }}
         onClick={onAbbrechen}>
      <div role="dialog" aria-modal="true" aria-label={`${verein.name} freischalten`}
           onClick={(e) => e.stopPropagation()}
           style={{ ...karte, width: "100%", maxWidth: 460, maxHeight: "90vh", overflowY: "auto" }}>
        <h2 style={{ fontSize: 17, fontWeight: 700, margin: "0 0 2px" }}>{verein.name} freischalten</h2>
        <p style={{ fontSize: 12, color: "#8A7F85", margin: "0 0 16px" }}>
          Aktuell {TARIF_NAMEN[verein.tarif] || verein.tarif}, {verein.konten} von {verein.grenze} Zugängen belegt
          {verein.laeuft_bis && <> · läuft bis {datum(verein.laeuft_bis)}</>}
        </p>

        <label style={beschriftung}>Stufe</label>
        <select value={stufe} onChange={(e) => setStufe(e.target.value)} style={feld}>
          <option value="basic">Basic — bis 100 Zugänge</option>
          <option value="plus">Plus — bis 350 Zugänge</option>
          <option value="pro">Pro — bis 1.000 Zugänge</option>
        </select>
        {stuftHerab && (
          <p role="status" style={{ ...hinweis, color: "#B3261E", fontWeight: 600, marginTop: -6 }}>
            Achtung: Das ist eine Herabstufung von {TARIF_NAMEN[verein.tarif]} auf {TARIF_NAMEN[stufe]}.
            {verein.konten > (stufe === "basic" ? 100 : stufe === "plus" ? 350 : 1000) && !zugaenge && (
              <> Der Verein hat {verein.konten} Konten und läge damit über der Grenze — neue Mitglieder ließen sich nicht mehr aufnehmen.</>
            )}
          </p>
        )}

        <label style={beschriftung}>Laufzeit</label>
        <select value={laufzeit} onChange={(e) => setLaufzeit(e.target.value)} style={feld}>
          <option value="monat">1 Monat</option>
          <option value="quartal">3 Monate</option>
          <option value="halbjahr">6 Monate</option>
          <option value="jahr">1 Jahr</option>
          <option value="zwei_jahre">2 Jahre</option>
        </select>

        <label style={beschriftung}>Vereinbarte Zugänge</label>
        <input type="number" min="0" value={zugaenge} onChange={(e) => setZugaenge(e.target.value)}
               placeholder={verein.vereinbarte_zugaenge != null ? `derzeit ${verein.vereinbarte_zugaenge}` : "leer = Zahl des Tarifs"} style={feld} />
        <p style={hinweis}>
          Leer lassen ändert nichts an einer bestehenden Vereinbarung — wichtig bei Verlängerungen.
          {" "}<b>0</b> setzt auf die Zahl des Tarifs zurück.
        </p>

        <label style={beschriftung}>Eigene Sponsoren (+ 5 €/Monat)</label>
        <select value={sponsoring} onChange={(e) => setSponsoring(e.target.value)} style={feld}>
          <option value="unveraendert">unverändert ({verein.sponsoring_freigeschaltet ? "derzeit freigeschaltet" : "derzeit nicht"})</option>
          <option value="an">freischalten</option>
          <option value="aus">wegnehmen</option>
        </select>

        <label style={beschriftung}>Rechnungsnummer</label>
        <input value={belegnummer} onChange={(e) => setBelegnummer(e.target.value)} placeholder="z. B. RE-2026-0042" style={feld} />
        <p style={hinweis}>Ohne Angabe wird eine erzeugt. Zwei Vereine dürfen nicht dieselbe bekommen.</p>

        <div style={{ display: "flex", gap: 8, marginTop: 16 }}>
          <button style={{ ...knopfLeise, flex: 1 }} onClick={onAbbrechen}>Abbrechen</button>
          <button style={{ ...knopf, flex: 1, opacity: laeuft ? 0.6 : 1 }} disabled={laeuft}
            onClick={() => onFreischalten({
              stufe, laufzeit, zugaenge, belegnummer,
              sponsoring: sponsoring === "unveraendert" ? null : sponsoring === "an",
            })}>
            {laeuft ? "…" : "Freischalten"}
          </button>
        </div>
      </div>
    </div>
  );
}

/* Eigene Gestaltung statt der Vereinsfarben: Diese Seite gehört keinem Verein,
   und sie soll auch nicht so aussehen. */
const huelle: React.CSSProperties = {
  fontFamily: "ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
  color: "#2A2028", background: "#FAF8F9", minHeight: "100vh", padding: "28px 20px 60px",
  maxWidth: 1100, margin: "0 auto",
};
const karte: React.CSSProperties = { background: "#FFFFFF", border: "1px solid #E9E4E7", borderRadius: 14, padding: 16 };
const feld: React.CSSProperties = {
  width: "100%", padding: "10px 12px", borderRadius: 10, border: "1px solid #DDD6DA",
  background: "#FFFFFF", fontSize: 14, marginBottom: 10, boxSizing: "border-box", color: "#2A2028",
};
const knopf: React.CSSProperties = {
  padding: "9px 14px", borderRadius: 10, border: "none", background: "#2A2028", color: "#FFFFFF",
  fontSize: 13, fontWeight: 700, cursor: "pointer",
};
const knopfLeise: React.CSSProperties = {
  padding: "8px 12px", borderRadius: 10, border: "1px solid #DDD6DA", background: "#FFFFFF",
  color: "#2A2028", fontSize: 13, fontWeight: 600, cursor: "pointer", marginRight: 6,
};
const ueberschrift: React.CSSProperties = { fontSize: 13, textTransform: "uppercase", letterSpacing: ".07em", color: "#8A7F85", marginBottom: 10 };
const zelle: React.CSSProperties = { padding: "10px 8px", verticalAlign: "top" };
const abzeichen: React.CSSProperties = { fontSize: 11, fontWeight: 700, background: "#F0EBEE", borderRadius: 999, padding: "2px 8px" };
const fehlerText: React.CSSProperties = { fontSize: 13, background: "rgba(253,236,236,0.9)", color: "#B3261E", borderRadius: 10, padding: "9px 12px", margin: "0 0 12px" };
const beschriftung: React.CSSProperties = { display: "block", fontSize: 12, fontWeight: 700, marginBottom: 4, color: "#4A424A" };
const hinweis: React.CSSProperties = { fontSize: 11, color: "#8A7F85", margin: "-4px 0 12px", lineHeight: 1.5 };
