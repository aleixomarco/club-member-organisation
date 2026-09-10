"use client";

import { useCallback, useEffect, useRef, useState } from "react";

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
  /* Lebenszeichen. Ein Verein kann bezahlen und trotzdem still sein - das
     sieht man an keiner der Zahlen darueber. */
  hidden: boolean;
  letzte_aktivitaet: string | null; aktive_30: number; termine_30: number; nachrichten_30: number;
};

type Kennzahlen = {
  vereine: number; freigeschaltet: number; gesperrt: number; neu_30: number;
  konten: number; mitglieder: number;
  basic: number; plus: number; pro: number; ohne_tarif: number;
  still_30: number; fast_voll: number;
};

type Anzeige = {
  id: string; platz: string; titel: string; text: string | null; ziel_url: string | null;
  telefon: string | null; email: string | null;
  aktion_titel: string | null; laeuft_bis: string | null; aktiv: boolean;
  impressionen: number; klicks: number;
};

/* Ein Sponsor eines Vereins, so viel wie die Auswahlliste braucht. Nicht zu
   verwechseln mit dem Typ Sponsor weiter unten - der gehoert zur
   Vereinsansicht und traegt Bild, Aktionstext und Laufzeiten. */
type VereinsAnzeige = {
  id: string; platz: string; titel: string; aktiv: boolean; laeuft_bis: string | null;
  impressionen: number; klicks: number; club_id: string; verein: string;
};

/* Was anzeigen_kennzahlen() zurueckgibt. Die Datenbank rechnet, diese Seite
   stellt dar - deshalb steht hier keine einzige eigene Summe. */
type Kpi = {
  stand: string;
  anzeige: { id: string; titel: string; platz: string; herkunft: string; aktiv: boolean;
    laeuft_von: string | null; laeuft_bis: string | null; laeuft_gerade: boolean;
    ziel_url: string | null; telefon: string | null; email: string | null };
  zeitraum: { von: string; bis: string; tage: number };
  gesamt: { impressionen: number; klicks: number };
  fenster: { impressionen: number; klicks: number; oeffnungen: number; kontakte: number; tage_mit_kontakt: number };
  verlauf: { tag: string; impressionen: number; klicks: number }[];
  elemente: { element: string; klicks: number }[];
  vereine: { verein: string; club_id: string; impressionen: number; klicks: number }[];
  reichweite: number;
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

/* Die Elemente einer Anzeige, ausgeschrieben. "telefon" ist ein Spaltenwert,
   "Angerufen" ist eine Auskunft. */
const ELEMENT_NAMEN: Record<string, string> = {
  anzeige: "Anzeige geöffnet", website: "Website", telefon: "Angerufen",
  email: "E-Mail", aktion: "Zur Aktion",
};

const TARIF_NAMEN: Record<string, string> = {
  none: "kostenlos", basic: "Basic", plus: "Plus", pro: "Pro", premium: "Premium",
};

/* Wie lebendig ist der Verein?
 *
 * Drei Stufen, keine Punktzahl. Eine Zahl von 0 bis 100 sieht praeziser aus,
 * als sie ist - was der Betreiber wissen will, ist "muss ich hier anrufen?".
 *
 * still   Seit 30 Tagen hat niemand etwas getan. Das ist der Verein, der
 *         kuendigt, bevor jemand mit ihm geredet hat.
 * ruhig   Zwei Wochen nichts. Kann Sommerpause sein, kann der Anfang vom
 *         Ende sein - einmal hinsehen lohnt.
 * aktiv   Es passiert etwas.
 */
function zustand(v: Verein): { still: boolean; label: string; farbe: string } {
  if (!v.letzte_aktivitaet) return { still: true, label: "nie", farbe: "#B3261E" };
  const tage = Math.floor((Date.now() - new Date(v.letzte_aktivitaet).getTime()) / 86400000);
  if (tage > 30) return { still: true, label: `${tage} Tage still`, farbe: "#B3261E" };
  if (tage > 14) return { still: false, label: `${tage} Tage her`, farbe: "#8A5A00" };
  return { still: false, label: tage <= 1 ? "heute" : `vor ${tage} Tagen`, farbe: "#1E6B3A" };
}

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
  const [sponsoren, setSponsoren] = useState<VereinsAnzeige[]>([]);
  /* Zwei Reiter, weil die Konsole zwei Aufgaben hat, die nichts miteinander
     zu tun haben: Vereine betreuen und Werbung verkaufen. Untereinander auf
     einer Seite hiess das bisher, an fuenf Vereinstabellen vorbeizuscrollen,
     um eine Anzeige zu bearbeiten. */
  const [reiter, setReiter] = useState<"vereine" | "werbung">("vereine");
  const [anzeigeOffen, setAnzeigeOffen] = useState<Partial<Anzeige> | null>(null);
  const [detail, setDetail] = useState<{ verein: Verein; mitglieder: Mitglied[]; zielgruppe: Zielgruppe | null; sponsoren: Sponsor[] } | null>(null);
  const [suche, setSuche] = useState("");
  const [offen, setOffen] = useState<Verein | null>(null);
  const [meldung, setMeldung] = useState("");
  const [kennzahlen, setKennzahlen] = useState<Kennzahlen | null>(null);
  const [exportLaeuft, setExportLaeuft] = useState(false);
  const [nurStille, setNurStille] = useState(false);
  const [nachricht, setNachricht] = useState<Verein | null>(null);

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
    setVereine(inhalt.vereine || []); setAnfragen(inhalt.anfragen || []); setAnzeigen(inhalt.anzeigen || []);
    setSponsoren(inhalt.sponsoren || []);
    setKennzahlen(inhalt.kennzahlen || null); setFehler("");
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

  /* Der Export laeuft ueber einen unsichtbaren Link, nicht ueber
     window.open: Ein neues Fenster wuerde vom Browser als Aufklappfenster
     blockiert, sobald zwischen Klick und Antwort mehr als ein Augenblick
     liegt - und die Mappe zu bauen dauert genau das.
     Der Dateiname kommt aus der Antwort (Content-Disposition); ihn hier noch
     einmal zu bilden hiesse, ihn an zwei Stellen zu pflegen. */
  const exportieren = async () => {
    if (exportLaeuft) return;
    setExportLaeuft(true);
    setFehler("");
    try {
      const antwort = await fetch("/api/betreiber/export");
      if (!antwort.ok) {
        const inhalt = await antwort.json().catch(() => null);
        setFehler(inhalt?.error || "Der Export konnte nicht erstellt werden.");
        return;
      }
      const kopf = antwort.headers.get("Content-Disposition") || "";
      const name = /filename="([^"]+)"/.exec(kopf)?.[1] || "CMO-Vereinsdaten.xlsx";
      const daten = await antwort.blob();
      const adresse = URL.createObjectURL(daten);
      const link = document.createElement("a");
      link.href = adresse;
      link.download = name;
      document.body.appendChild(link);
      link.click();
      link.remove();
      /* Die Adresse wieder freigeben - sonst haelt der Browser die ganze
         Mappe im Speicher, bis die Seite neu geladen wird. */
      URL.revokeObjectURL(adresse);
    } catch {
      setFehler("Der Export konnte nicht erstellt werden.");
    } finally {
      setExportLaeuft(false);
    }
  };

  const abmelden = async () => {
    await fetch("/api/betreiber/abmelden", { method: "POST" });
    setAngemeldet(false); setVereine([]); setAnfragen([]); setAnzeigen([]); setSponsoren([]); setKennzahlen(null);
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

  const gesucht = suche.trim()
    ? vereine.filter((v) => `${v.name} ${v.short_name || ""} ${v.city || ""}`.toLowerCase().includes(suche.trim().toLowerCase()))
    : vereine;
  const gefiltert = nurStille ? gesucht.filter((v) => zustand(v).still) : gesucht;
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
        {/* Der Export steht neben dem Abmelden, nicht bei den Vereinen:
            Er betrifft ALLE Daten, nicht den Verein, den man gerade ansieht.
            Ein Knopf in einer Vereinszeile haette das Gegenteil nahegelegt. */}
        <button onClick={exportieren} disabled={exportLaeuft}
          style={{ ...knopfLeise, marginLeft: "auto", opacity: exportLaeuft ? 0.6 : 1 }}
          title="Alle Vereinsdaten als Excel-Mappe herunterladen">
          {exportLaeuft ? "Mappe wird gebaut …" : "Excel-Export"}
        </button>
        <button onClick={abmelden} style={knopfLeise}>Abmelden</button>
      </header>

      {/* Die zwei Aufgaben der Konsole. Vorher lagen sie untereinander auf
          einer Seite: Wer eine Anzeige aendern wollte, scrollte an der
          Vereinstabelle vorbei - und wer einen Verein suchte, an der
          Werbung. */}
      <nav style={{ display: "flex", gap: 6, marginBottom: 20 }}>
        {([["vereine", "Vereine"], ["werbung", "Werbeanzeigen"]] as const).map(([wert, label]) => (
          <button key={wert} onClick={() => setReiter(wert)} aria-pressed={reiter === wert}
            style={reiter === wert ? reiterAktiv : reiterLeise}>{label}</button>
        ))}
      </nav>

      {/* Die Zahlen ueber alle Vereine. Sie stehen bewusst VOR den Anfragen:
          Die Anfragen sagen, was heute zu tun ist - diese Zeile sagt, wie es
          um das Ganze steht. */}
      {reiter === "vereine" && kennzahlen && (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(132px, 1fr))", gap: 10, marginBottom: 24 }}>
          {[
            { wert: kennzahlen.vereine, titel: "Vereine", unten: `${kennzahlen.neu_30} neu in 30 Tagen`, warnung: false },
            { wert: kennzahlen.freigeschaltet, titel: "Freigeschaltet",
              unten: `${kennzahlen.basic} Basic · ${kennzahlen.plus} Plus · ${kennzahlen.pro} Pro`, warnung: false },
            { wert: kennzahlen.konten, titel: "Konten", unten: `bei ${kennzahlen.mitglieder} Mitgliedern`, warnung: false },
            { wert: kennzahlen.still_30, titel: "Still", unten: "30 Tage ohne Regung", warnung: kennzahlen.still_30 > 0 },
            { wert: kennzahlen.fast_voll, titel: "Fast voll", unten: "90 % der Zugänge belegt", warnung: kennzahlen.fast_voll > 0 },
            { wert: kennzahlen.gesperrt, titel: "Gesperrt", unten: `${kennzahlen.ohne_tarif} ohne Tarif`, warnung: false },
          ].map((k) => (
            <div key={k.titel} style={{ ...karte, padding: "12px 14px" }}>
              <div style={{ fontSize: 24, fontWeight: 700, lineHeight: 1.1, color: k.warnung ? "#B3261E" : "#2A2028" }}>{k.wert}</div>
              <div style={{ fontSize: 12, fontWeight: 700, color: "#4A424A", marginTop: 2 }}>{k.titel}</div>
              <div style={{ fontSize: 11, color: "#8A7F85", marginTop: 2 }}>{k.unten}</div>
            </div>
          ))}
        </div>
      )}

      {fehler && <p role="status" style={fehlerText}>{fehler}</p>}
      {meldung && <p role="status" style={{ ...fehlerText, background: "rgba(231,243,236,0.72)", color: "#1E6B3A" }}>{meldung}</p>}

      {reiter === "vereine" && (<>
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
          <label style={{ fontSize: 12, color: "#4A424A", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
            <input type="checkbox" checked={nurStille} onChange={(e) => setNurStille(e.target.checked)} />
            nur stille Vereine
          </label>
        </div>

        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, minWidth: 720 }}>
            <thead>
              <tr style={{ textAlign: "left", color: "#8A7F85", fontSize: 11, textTransform: "uppercase", letterSpacing: ".06em" }}>
                <th style={zelle}>Verein</th><th style={zelle}>Tarif</th><th style={zelle}>Zugänge</th>
                <th style={zelle}>Leben</th>
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
                    {/* Was hier steht, sagt mehr als der Tarif daneben: Ein
                        Verein mit 80 Mitgliedern und drei aktiven Nutzern ist
                        ein anderer Fall als einer mit 80 und 60 - auch wenn
                        beide dasselbe zahlen. */}
                    <td style={zelle}>
                      <div style={{ fontWeight: 700, color: zustand(v).farbe }}>{zustand(v).label}</div>
                      <div style={{ fontSize: 11, color: "#8A7F85" }}>
                        {v.aktive_30} von {v.mitglieder} aktiv · {v.termine_30} Term. · {v.nachrichten_30} Nachr.
                      </div>
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
                      <button style={knopfLeise} disabled={laeuft} onClick={() => setNachricht(v)}>Nachricht …</button>
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
      </>)}

      {reiter === "werbung" && (
        <WerbeReiter
          anzeigen={anzeigen}
          sponsoren={sponsoren}
          laeuft={laeuft}
          onNeu={() => setAnzeigeOffen({ platz: "dashboard_top", aktiv: true })}
          onBearbeiten={(a) => setAnzeigeOffen(a)}
          onFehler={setFehler}
        />
      )}

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

      {nachricht && (
        <NachrichtDialog
          verein={nachricht}
          laeuft={laeuft}
          onAbbrechen={() => setNachricht(null)}
          onSenden={async (werte) => {
            const ergebnis = await aktion({ art: "nachricht", verein: nachricht.id, ...werte });
            if (ergebnis) {
              setMeldung(`An ${ergebnis.empfaenger ?? 0} Person(en) in ${nachricht.name} verschickt.`);
              setNachricht(null);
            }
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
/* Eine Kennzahl mit Beschriftung. Stand vorher INNERHALB von VereinsDetail:
   Damit war es bei jedem Rendern eine neue Komponente, und React baute alle
   Kacheln jedes Mal neu auf statt sie zu aktualisieren. Hier schadet das
   nichts - die Kacheln haben weder Zustand noch Eingabefelder -, aber auf
   Modulebene ist es schlicht richtig. */
const Zahl = ({ wert, label }: { wert: React.ReactNode; label: string }) => (
  <div style={{ ...karte, padding: 12, minWidth: 116, flex: "1 1 116px" }}>
    <div style={{ fontSize: 20, fontWeight: 700 }}>{wert}</div>
    <div style={{ fontSize: 11, color: "#8A7F85", marginTop: 2 }}>{label}</div>
  </div>
);

/* ------------------------------------------------------------------ */
/* Reiter "Werbeanzeigen"                                              */
/* ------------------------------------------------------------------ */
/* Zwei Ansichten auf dieselbe Sache.
 *
 * "Anzeigen" ist die Verwaltung: anlegen, ändern, abschalten.
 * "KPI" ist die Auswertung — und die beginnt mit einer Auswahl, weil es keine
 * sinnvolle Sammelzahl über alle Anzeigen gibt. Ein Sponsor der Bäckerei und
 * eine Aktion des Betreibers laufen auf verschiedenen Plätzen, in
 * verschiedenen Vereinen und über verschiedene Zeiträume; ihre Klicks zu
 * addieren ergäbe eine Zahl, die niemandem gehört.
 *
 * Die Auswahl führt beides auf: die eigene Werbung zuerst, darunter die
 * Sponsoren der Vereine. Letztere stehen hier, weil beim Verkauf eines
 * Werbeplatzes die Frage aufkommt, was auf den anderen Plätzen schon läuft. */
function WerbeReiter({ anzeigen, sponsoren, laeuft, onNeu, onBearbeiten, onFehler }: {
  anzeigen: Anzeige[]; sponsoren: VereinsAnzeige[]; laeuft: boolean;
  onNeu: () => void; onBearbeiten: (a: Anzeige) => void; onFehler: (text: string) => void;
}) {
  const [unterReiter, setUnterReiter] = useState<"anzeigen" | "kpi">("anzeigen");
  const [gewaehlt, setGewaehlt] = useState("");
  const [tage, setTage] = useState(30);
  const [kpi, setKpi] = useState<Kpi | null>(null);
  const [kpiLaeuft, setKpiLaeuft] = useState(false);

  /* Der Merker fängt wirklich ab: Wer schnell zwischen zwei Anzeigen wechselt,
     bekäme sonst die Antwort der ersten Abfrage über die zweite geschrieben —
     und sähe die Zahlen einer Anzeige unter dem Namen einer anderen. */
  const laufendeAbfrage = useRef(0);

  const kpiLaden = useCallback(async (ziel: string, zeitraum: number) => {
    if (!ziel) { setKpi(null); return; }
    const meine = ++laufendeAbfrage.current;
    setKpiLaeuft(true);
    const antwort = await fetch(`/api/betreiber/kpi?anzeige=${encodeURIComponent(ziel)}&tage=${zeitraum}`).catch(() => null);
    if (meine !== laufendeAbfrage.current) return;
    setKpiLaeuft(false);
    if (!antwort) { onFehler("Keine Verbindung zum Server."); return; }
    const inhalt = await antwort.json().catch(() => ({}));
    if (meine !== laufendeAbfrage.current) return;
    if (!antwort.ok) { onFehler(inhalt.error || "Die Kennzahlen konnten nicht geladen werden."); setKpi(null); return; }
    setKpi(inhalt.kennzahlen || null);
  }, [onFehler]);

  useEffect(() => { kpiLaden(gewaehlt, tage); }, [gewaehlt, tage, kpiLaden]);

  const waehlen = (ziel: string) => { setGewaehlt(ziel); if (ziel) setUnterReiter("kpi"); };

  return (
    <>
      <div style={{ display: "flex", gap: 6, marginBottom: 18 }}>
        {([["anzeigen", "Anzeigen"], ["kpi", "KPI"]] as const).map(([wert, label]) => (
          <button key={wert} onClick={() => setUnterReiter(wert)}
            style={unterReiter === wert ? reiterAktiv : reiterLeise}>{label}</button>
        ))}
      </div>

      {unterReiter === "anzeigen" && (
        <>
          <section>
            <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 10, flexWrap: "wrap" }}>
              <h2 style={{ ...ueberschrift, marginBottom: 0 }}>Eigene Werbeplätze</h2>
              <button style={knopfLeise} disabled={laeuft} onClick={onNeu}>Neue Anzeige</button>
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
                    <button style={knopfLeise} onClick={() => waehlen(a.id)}>Kennzahlen</button>
                    <button style={knopfLeise} disabled={laeuft} onClick={() => onBearbeiten(a)}>Bearbeiten</button>
                  </div>
                ))}
              </div>
            )}
          </section>

          <section style={{ marginTop: 28 }}>
            <h2 style={ueberschrift}>Sponsoren der Vereine</h2>
            <p style={{ ...hinweis, marginTop: -4 }}>
              Von den Vereinen selbst eingetragen. Sie lassen sich hier nicht ändern — nur nachsehen, was wo läuft.
            </p>
            {sponsoren.length === 0 ? (
              <p style={{ ...karte, color: "#8A7F85", fontSize: 13 }}>Kein Verein hat bisher einen eigenen Sponsor eingetragen.</p>
            ) : (
              <div style={{ display: "grid", gap: 8 }}>
                {sponsoren.map((a) => (
                  <div key={a.id} style={{ ...karte, display: "flex", gap: 12, alignItems: "baseline", flexWrap: "wrap" }}>
                    <span style={abzeichen}>{PLATZ_NAMEN[a.platz] || a.platz}</span>
                    <b style={{ fontSize: 14 }}>{a.titel}</b>
                    <span style={{ fontSize: 12, color: "#8A7F85" }}>{a.verein}</span>
                    {!a.aktiv && <span style={{ ...abzeichen, background: "#F0EBEE" }}>ausgeschaltet</span>}
                    <span style={{ fontSize: 12, color: "#8A7F85", marginLeft: "auto" }}>{a.impressionen} Einblendungen · {a.klicks} Klicks</span>
                    <button style={knopfLeise} onClick={() => waehlen(a.id)}>Kennzahlen</button>
                  </div>
                ))}
              </div>
            )}
          </section>
        </>
      )}

      {unterReiter === "kpi" && (
        <section>
          <h2 style={ueberschrift}>Kennzahlen</h2>
          <div style={{ ...karte, display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap", marginBottom: 14 }}>
            <label style={{ fontSize: 13, color: "#4A424A", fontWeight: 600 }}>Anzeige</label>
            <select value={gewaehlt} onChange={(e) => setGewaehlt(e.target.value)} style={{ ...feld, margin: 0, maxWidth: 420, flex: "1 1 260px" }}>
              <option value="">— bitte wählen —</option>
              {anzeigen.length > 0 && (
                <optgroup label="Eigene Werbung">
                  {anzeigen.map((a) => (
                    <option key={a.id} value={a.id}>{a.titel} · {PLATZ_NAMEN[a.platz] || a.platz}{a.aktiv ? "" : " (aus)"}</option>
                  ))}
                </optgroup>
              )}
              {sponsoren.length > 0 && (
                <optgroup label="Sponsoren der Vereine">
                  {sponsoren.map((a) => (
                    <option key={a.id} value={a.id}>{a.titel} · {a.verein}{a.aktiv ? "" : " (aus)"}</option>
                  ))}
                </optgroup>
              )}
            </select>
            <div style={{ display: "flex", gap: 6, marginLeft: "auto" }}>
              {[7, 30, 90, 365].map((n) => (
                <button key={n} onClick={() => setTage(n)} style={tage === n ? reiterAktiv : reiterLeise}>
                  {n === 365 ? "1 Jahr" : `${n} Tage`}
                </button>
              ))}
            </div>
          </div>

          {!gewaehlt && (
            <p style={{ ...karte, color: "#8A7F85", fontSize: 13 }}>
              Wählen Sie oben eine Anzeige. Eine Sammelzahl über alle Anzeigen gäbe es zwar,
              sie würde aber Plätze, Vereine und Laufzeiten vermischen und niemandem gehören.
            </p>
          )}

          {gewaehlt && kpiLaeuft && !kpi && <p style={{ ...karte, color: "#8A7F85", fontSize: 13 }}>Wird geladen …</p>}

          {gewaehlt && kpi && <KpiAnsicht kpi={kpi} laedt={kpiLaeuft} onNeuLaden={() => kpiLaden(gewaehlt, tage)} />}
        </section>
      )}
    </>
  );
}

/* Die Auswertung selbst.
 *
 * Gerechnet wird hier nichts, was die Datenbank schon gerechnet hat — bis auf
 * die Klickrate, und die nur, wo sie etwas bedeutet: Bei zwölf Einblendungen
 * ist "25 %" keine Quote, sondern ein Zufall, und in einem Angebot an ein
 * Unternehmen eine Zahl, die beim nächsten Mal zusammenbricht. */
function KpiAnsicht({ kpi, laedt, onNeuLaden }: { kpi: Kpi; laedt: boolean; onNeuLaden: () => void }) {
  /* Ein Trichter, drei Stufen - jede eine Teilmenge der vorigen. Die Zahlen
     kommen fertig aus der Datenbank; diese Ansicht rechnet nur noch die Quote,
     und die aus Öffnungen, nicht aus Klicks. Vorher teilte sie die Klicks aller
     fünf Elemente durch die Einblendungen, die es nur an einem gibt - und stand
     dadurch bei einem lebhaften Inserat über 100 %. */
  const einblendungen = Number(kpi.fenster?.impressionen) || 0;
  const oeffnungen = Number(kpi.fenster?.oeffnungen) || 0;
  const kontakte = Number(kpi.fenster?.kontakte) || 0;
  const quote = einblendungen >= 20 ? (oeffnungen / einblendungen) * 100 : null;
  const bester = (kpi.verlauf || []).reduce<{ tag: string; klicks: number } | null>(
    (beste, v) => ((Number(v.klicks) || 0) > (Number(beste?.klicks) || 0) ? { tag: v.tag, klicks: Number(v.klicks) || 0 } : beste), null);
  const zahl = (n: unknown) => Number(n || 0).toLocaleString("de-DE");

  const kacheln = [
    { wert: zahl(einblendungen), titel: "Einblendungen", unten: `${zahl(kpi.gesamt?.impressionen)} seit Beginn` },
    { wert: zahl(oeffnungen), titel: "Öffnungen", unten: "Inserat aufgeklappt" },
    { wert: quote === null ? "—" : `${quote.toFixed(1).replace(".", ",")} %`, titel: "Öffnungsrate",
      unten: quote === null ? "zu wenige Einblendungen" : "Geöffnet je Einblendung" },
    { wert: zahl(kontakte), titel: "Kontakte", unten: "Website, Anruf, E-Mail, Aktion" },
    { wert: zahl(kpi.reichweite), titel: "Mögliche Reichweite", unten: "Mitglieder, die sie sehen können" },
    { wert: bester && bester.klicks > 0 ? datum(bester.tag) : "—", titel: "Bester Tag",
      unten: bester && bester.klicks > 0 ? `${zahl(bester.klicks)} Klicks` : "noch kein Klick" },
  ];

  return (
    <>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap", marginBottom: 10 }}>
        <b style={{ fontSize: 16 }}>{kpi.anzeige?.titel}</b>
        <span style={abzeichen}>{PLATZ_NAMEN[kpi.anzeige?.platz] || kpi.anzeige?.platz}</span>
        <span style={{ ...abzeichen, background: kpi.anzeige?.laeuft_gerade ? "rgba(231,243,236,0.9)" : "#F0EBEE", color: kpi.anzeige?.laeuft_gerade ? "#1E6B3A" : "#8A7F85" }}>
          {kpi.anzeige?.laeuft_gerade ? "läuft" : "läuft nicht"}
        </span>
        <span style={{ fontSize: 12, color: "#8A7F85" }}>
          {datum(kpi.zeitraum?.von)} – {datum(kpi.zeitraum?.bis)}
        </span>
        <span style={{ fontSize: 12, color: "#8A7F85", marginLeft: "auto" }}>
          Stand {kpi.stand ? new Date(kpi.stand).toLocaleTimeString("de-DE") : "—"}
        </span>
        <button style={{ ...knopfLeise, opacity: laedt ? 0.6 : 1 }} disabled={laedt} onClick={onNeuLaden}>Aktualisieren</button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))", gap: 10, marginBottom: 18 }}>
        {kacheln.map((k) => (
          <div key={k.titel} style={{ ...karte, padding: "12px 14px" }}>
            <div style={{ fontSize: 24, fontWeight: 700, lineHeight: 1.1, color: "#2A2028" }}>{k.wert}</div>
            <div style={{ fontSize: 12, fontWeight: 700, color: "#4A424A", marginTop: 2 }}>{k.titel}</div>
            <div style={{ fontSize: 11, color: "#8A7F85", marginTop: 2 }}>{k.unten}</div>
          </div>
        ))}
      </div>

      <div style={{ ...karte, marginBottom: 14 }}>
        <h3 style={{ fontSize: 14, fontWeight: 700, margin: "0 0 10px" }}>Verlauf</h3>
        {einblendungen === 0 && (Number(kpi.fenster?.klicks) || 0) === 0
          ? <p style={{ fontSize: 13, color: "#8A7F85", margin: 0 }}>In diesem Zeitraum wurde die Anzeige nicht gesehen.</p>
          : <KpiVerlauf verlauf={kpi.verlauf || []} />}
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))", gap: 14 }}>
        <div style={karte}>
          <h3 style={{ fontSize: 14, fontWeight: 700, margin: "0 0 10px" }}>Was angetippt wurde</h3>
          {(kpi.elemente || []).length === 0 ? (
            <p style={{ fontSize: 13, color: "#8A7F85", margin: 0 }}>Noch nichts angetippt.</p>
          ) : (
            <KpiBalken zeilen={(kpi.elemente || []).map((e) => ({
              name: ELEMENT_NAMEN[e.element] || e.element, wert: Number(e.klicks) || 0,
            }))} />
          )}
        </div>

        <div style={karte}>
          <h3 style={{ fontSize: 14, fontWeight: 700, margin: "0 0 10px" }}>Nach Verein</h3>
          {(kpi.vereine || []).length === 0 ? (
            <p style={{ fontSize: 13, color: "#8A7F85", margin: 0 }}>Noch kein Verein mit Kontakten.</p>
          ) : (
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
              <thead>
                <tr>
                  <th style={{ ...spaltenKopf, textAlign: "left" }}>Verein</th>
                  <th style={{ ...spaltenKopf, textAlign: "right" }}>Einbl.</th>
                  <th style={{ ...spaltenKopf, textAlign: "right" }}>Klicks</th>
                </tr>
              </thead>
              <tbody>
                {(kpi.vereine || []).map((v) => (
                  <tr key={v.club_id}>
                    <td style={{ padding: "6px 0", borderTop: "1px solid #EFE9ED" }}>{v.verein}</td>
                    <td style={{ padding: "6px 0", borderTop: "1px solid #EFE9ED", textAlign: "right", fontVariantNumeric: "tabular-nums" }}>{zahl(v.impressionen)}</td>
                    <td style={{ padding: "6px 0", borderTop: "1px solid #EFE9ED", textAlign: "right", fontVariantNumeric: "tabular-nums", fontWeight: 700 }}>{zahl(v.klicks)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      <p style={{ ...hinweis, marginTop: 14 }}>
        Gezählt wird als Tagessumme je Anzeige, Verein und Element — ohne Bezug zu einzelnen
        Mitgliedern. „Mögliche Reichweite" ist keine gemessene Zahl, sondern wie viele
        Mitglieder die Anzeige überhaupt sehen können.
      </p>
    </>
  );
}

/* Säulen für den Verlauf. Ohne Diagrammbibliothek: 365 Rechtecke rechtfertigen
   kein weiteres Paket im Bündel. Die helle Säule ist die Einblendung, die
   dunkle der Klick — der Klick ist immer die kleinere Zahl und liegt deshalb
   sichtbar davor. */
function KpiVerlauf({ verlauf }: { verlauf: { tag: string; impressionen: number; klicks: number }[] }) {
  if (verlauf.length === 0) return null;
  const hoehe = 120;
  const groesste = Math.max(1, ...verlauf.map((v) => Number(v.impressionen) || 0), ...verlauf.map((v) => Number(v.klicks) || 0));
  const breite = 100 / verlauf.length;
  return (
    <>
      <svg viewBox={`0 0 100 ${hoehe}`} preserveAspectRatio="none" style={{ width: "100%", height: 150, display: "block" }} role="img" aria-label="Verlauf der Einblendungen und Klicks">
        {verlauf.map((v, i) => {
          const e = ((Number(v.impressionen) || 0) / groesste) * (hoehe - 2);
          const k = ((Number(v.klicks) || 0) / groesste) * (hoehe - 2);
          return (
            <g key={v.tag}>
              <rect x={i * breite} y={hoehe - e} width={Math.max(breite * 0.72, 0.3)} height={e} fill="#E7D9E1" />
              <rect x={i * breite} y={hoehe - k} width={Math.max(breite * 0.72, 0.3)} height={k} fill="#B3261E" />
            </g>
          );
        })}
      </svg>
      <div style={{ display: "flex", justifyContent: "space-between", fontSize: 11, color: "#8A7F85", marginTop: 4 }}>
        <span>{datum(verlauf[0].tag)}</span>
        <span>{datum(verlauf[verlauf.length - 1].tag)}</span>
      </div>
      <div style={{ display: "flex", gap: 16, marginTop: 8, fontSize: 12, color: "#8A7F85" }}>
        <span><span style={{ display: "inline-block", width: 10, height: 10, background: "#E7D9E1", borderRadius: 2, marginRight: 6 }} />Einblendungen</span>
        <span><span style={{ display: "inline-block", width: 10, height: 10, background: "#B3261E", borderRadius: 2, marginRight: 6 }} />Klicks</span>
      </div>
    </>
  );
}

function KpiBalken({ zeilen }: { zeilen: { name: string; wert: number }[] }) {
  const groesste = Math.max(1, ...zeilen.map((z) => z.wert));
  return (
    <div style={{ display: "grid", gap: 10 }}>
      {zeilen.map((z) => (
        <div key={z.name}>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 13, marginBottom: 4 }}>
            <span>{z.name}</span>
            <b style={{ fontVariantNumeric: "tabular-nums" }}>{z.wert.toLocaleString("de-DE")}</b>
          </div>
          <div style={{ height: 6, borderRadius: 999, background: "#F0EBEE", overflow: "hidden" }}>
            <div style={{ height: "100%", width: `${Math.round((z.wert / groesste) * 100)}%`, background: "#B3261E", borderRadius: 999 }} />
          </div>
        </div>
      ))}
    </div>
  );
}

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

/* Eine Nachricht an einen Verein.
 *
 * Sie geht standardmaessig nur an die Vereinsleitung. Das ist die
 * vorsichtige Voreinstellung, und sie ist mit Absicht so: Eine Nachricht
 * vom Betreiber an ALLE Mitglieder eines fremden Vereins ist etwas, das man
 * ausdruecklich wollen muss. Wer den Haken setzt, sieht daneben, wie viele
 * Menschen das sind. */
function NachrichtDialog({ verein, laeuft, onAbbrechen, onSenden }: {
  verein: Verein; laeuft: boolean;
  onAbbrechen: () => void;
  onSenden: (werte: Record<string, unknown>) => void;
}) {
  const [titel, setTitel] = useState("");
  const [text, setText] = useState("");
  const [alle, setAlle] = useState(false);
  const [fehler, setFehler] = useState("");

  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(20,21,26,.5)", display: "flex", alignItems: "center", justifyContent: "center", padding: 16 }}
         onClick={onAbbrechen}>
      <div role="dialog" aria-modal="true" aria-label={`Nachricht an ${verein.name}`}
           onClick={(e) => e.stopPropagation()}
           style={{ ...karte, width: "100%", maxWidth: 460, maxHeight: "88vh", overflowY: "auto" }}>
        <h2 style={{ fontSize: 17, fontWeight: 700, margin: "0 0 4px" }}>Nachricht an {verein.name}</h2>
        <p style={{ fontSize: 12, color: "#8A7F85", margin: "0 0 16px", lineHeight: 1.5 }}>
          Landet in der Glocke der App und löst dieselbe Push-Meldung aus wie
          jede andere Nachricht. Der Vereinsname steht automatisch davor.
        </p>

        <label style={beschriftung}>Titel</label>
        <input value={titel} onChange={(e) => setTitel(e.target.value)} maxLength={120}
               placeholder="z. B. Eure Zugänge sind fast voll" style={feld} autoFocus />

        <label style={beschriftung}>Text</label>
        <textarea value={text} onChange={(e) => setText(e.target.value)} maxLength={1000} rows={5}
                  placeholder="Was der Verein wissen soll."
                  style={{ ...feld, resize: "vertical" as const, fontFamily: "inherit" }} />

        <label style={{ fontSize: 13, color: "#4A424A", display: "flex", alignItems: "flex-start", gap: 8, margin: "4px 0 16px", cursor: "pointer" }}>
          <input type="checkbox" checked={alle} onChange={(e) => setAlle(e.target.checked)} style={{ marginTop: 3 }} />
          <span>
            An alle {verein.mitglieder} Mitglieder statt nur an die Vereinsleitung
            <span style={{ display: "block", fontSize: 11, color: "#8A7F85" }}>
              Ohne Haken geht die Nachricht nur an die Vereinsadministration.
            </span>
          </span>
        </label>

        {fehler && <p role="status" style={fehlerText}>{fehler}</p>}

        <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
          <button style={knopfLeise} onClick={onAbbrechen} disabled={laeuft}>Abbrechen</button>
          <button style={knopf} disabled={laeuft}
            onClick={() => {
              if (!titel.trim() || !text.trim()) { setFehler("Titel und Text dürfen nicht leer sein."); return; }
              if (alle && !window.confirm(`Die Nachricht geht an alle ${verein.mitglieder} Mitglieder von „${verein.name}". Wirklich senden?`)) return;
              setFehler("");
              onSenden({ titel: titel.trim(), text: text.trim(), alle });
            }}>
            {laeuft ? "Wird gesendet …" : "Senden"}
          </button>
        </div>
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
const spaltenKopf: React.CSSProperties = { fontSize: 11, textTransform: "uppercase", letterSpacing: ".06em", color: "#8A7F85", fontWeight: 700, padding: "0 0 6px" };
/* Reiter. Der aktive ist gefuellt, nicht nur unterstrichen: Auf hellem Grund
   ist eine Linie unter einem Wort schnell die Linie unter dem falschen Wort. */
const reiterAktiv: React.CSSProperties = {
  padding: "8px 16px", borderRadius: 999, border: "1px solid #2A2028", background: "#2A2028",
  color: "#FFFFFF", fontSize: 13, fontWeight: 700, cursor: "pointer",
};
const reiterLeise: React.CSSProperties = {
  padding: "8px 16px", borderRadius: 999, border: "1px solid #DDD6DA", background: "#FFFFFF",
  color: "#4A424A", fontSize: 13, fontWeight: 600, cursor: "pointer",
};
