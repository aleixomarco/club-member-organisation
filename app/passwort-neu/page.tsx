"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";
import { gespeicherteSprache, uebersetze } from "@/lib/sprachen";

/* Zielseite des Links aus der Passwort-vergessen-E-Mail.
   Supabase hängt das Token als Fragment an die Adresse (#access_token=…) und
   der Client tauscht es beim Laden gegen eine Sitzung ein. Erst danach darf
   updateUser aufgerufen werden — deshalb wird hier auf das Ereignis
   PASSWORD_RECOVERY bzw. eine bestehende Sitzung gewartet, statt sofort ein
   Eingabefeld zu zeigen, das noch nicht funktionieren würde. */
export default function PasswordResetPage() {
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);
  const [next, setNext] = useState("");
  const [repeat, setRepeat] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [done, setDone] = useState(false);
  /* Kein SprachKontext hier - die Seite steht ausserhalb der App. Die Wahl
     liegt im Geraet (localStorage). Gelesen erst nach dem ersten Zeichnen:
     Der Server kennt sie nicht, und Server und Client muessen zuerst
     dasselbe zeichnen. Dasselbe Muster wie in ClubMemberOrganisationApp. */
  const [sprache, setSprache] = useState("de");
  useEffect(() => { setSprache(gespeicherteSprache() || "de"); }, []);
  const t = (schluessel: string) => uebersetze(sprache, schluessel);

  useEffect(() => {
    if (!supabase) { setFailed(true); return; }
    let settled = false;

    /* Der Nachweis muss aus dem LINK kommen, nicht aus einer beliebigen
       Anmeldung.
       Vorher stand hier "if (event === \"PASSWORD_RECOVERY\" || session)" -
       jede bestehende Sitzung schaltete das Formular frei. Wer ein
       entsperrtes Telefon in die Hand bekam, konnte diese Seite aufrufen und
       das Passwort des angemeldeten Kontos neu setzen, ohne das alte zu
       kennen. Der reguläre Weg (Profil > Konto > Passwort ändern) verlangt
       ausdrücklich das alte Passwort; hier ließ sich das umgehen.
       Supabase hängt das Token als Fragment an die Adresse
       (#access_token=…&type=recovery). Genau dieses "type=recovery" ist der
       Nachweis - eine Sitzung allein ist keiner. */
    const fragment = new URLSearchParams(window.location.hash.replace(/^#/, ""));
    const abfrage = new URLSearchParams(window.location.search);
    const ausLink = fragment.get("type") === "recovery"
      || abfrage.get("type") === "recovery"
      || !!fragment.get("access_token")
      || !!abfrage.get("code");

    const { data: sub } = supabase.auth.onAuthStateChange((event) => {
      /* setFailed(false): Kommt die Sitzung erst nach Ablauf der Wartezeit an
         (langsames Netz), stand vorher dauerhaft "Link abgelaufen" da, obwohl
         der Link gueltig war (konto-4). */
      if (event === "PASSWORD_RECOVERY") { settled = true; setFailed(false); setReady(true); }
    });
    if (ausLink) {
      supabase.auth.getSession().then(({ data }) => {
        if (data.session) { settled = true; setFailed(false); setReady(true); }
      });
    }
    /* Ohne gültiges Token bleibt sonst ein Ladezustand stehen, der nie endet.
       12 statt 4 Sekunden: Auf dem Telefon im Mobilnetz dauert der Tausch des
       Tokens gegen eine Sitzung spuerbar laenger. */
    const timer = setTimeout(() => { if (!settled) setFailed(true); }, 12000);
    return () => { sub.subscription.unsubscribe(); clearTimeout(timer); };
  }, []);

  const save = async () => {
    setMessage("");
    if (next.length < 8) { setMessage(t("reg.passwortMindestens8")); return; }
    if (next !== repeat) { setMessage(t("login.resetEingabenUngleich")); return; }
    setBusy(true);
    const { error } = await supabase!.auth.updateUser({ password: next });
    setBusy(false);
    if (error) {
      /* Vorher hiess jeder Fehler "Fordere den Link neu an". Wer bis hierher
         kommt, HATTE aber eine gueltige Sitzung - sonst waere oben schon
         setFailed(true) gefallen. Der Satz war also im Regelfall schlicht
         falsch, und bei einer Bremse wegen zu vieler Versuche loeste er noch
         mehr Mails aus.
         Achtung beim Ablauf der Sitzung: Die Bibliothek macht daraus einen
         AuthSessionMissingError mit Status 400 und ohne Code - auf 401/403 zu
         pruefen wuerde genau diesen Fall verfehlen. */
      const code = String((error as { code?: string }).code || "");
      const status = Number(error.status || 0);
      const text = String(error.message || "").toLowerCase();
      if (error.name === "AuthSessionMissingError" || code === "bad_jwt" || status === 401 || status === 403) {
        setMessage(t("login.resetLinkAbgelaufen"));
      } else if (code === "weak_password" || (/password/i.test(String(error.message || "")) && /short|weak|least|pwned/i.test(text))) {
        setMessage(t("sich.passwortSchwach"));
      } else if (code === "same_password") {
        setMessage(t("login.resetGleichesPasswort"));
      } else if (status === 429 || code === "over_request_rate_limit" || text.includes("rate limit")) {
        setMessage(t("sich.zuVieleVersuche"));
      } else if (status === 0 || text.includes("failed to fetch") || text.includes("network") || text.includes("load failed")) {
        setMessage(t("allg.keineVerbindung"));
      } else {
        setMessage(t("login.resetAendernFehler"));
      }
      return;
    }
    setDone(true);
  };

  const box: React.CSSProperties = {
    /* Sichere Bereiche, wie auf den Rechtsseiten: contentInset steht auf
       "never", die Webansicht reicht also unter Dynamic Island und
       Home-Indikator. */
    maxWidth: 380, margin: "0 auto",
    padding: "calc(env(safe-area-inset-top) + 28px) calc(env(safe-area-inset-right) + 24px) calc(env(safe-area-inset-bottom) + 48px) calc(env(safe-area-inset-left) + 24px)",
    fontFamily: "system-ui, -apple-system, sans-serif", color: "#2A2028",
  };
  const field: React.CSSProperties = {
    width: "100%", padding: "12px 14px", borderRadius: 14, fontSize: 14,
    background: "rgba(92,72,86,0.07)", border: "1px solid rgba(70,50,65,0.12)",
    outline: "none", marginBottom: 10, boxSizing: "border-box",
  };

  return (
    <main style={box}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>{t("ph.neuesPasswort")}</h1>

      {done ? (
        <>
          <p style={{ fontSize: 14, color: "#2F9E58", marginBottom: 20 }}>
            {t("login.resetGeaendert")}
          </p>
          <Link href="/" style={{ display: "block", textAlign: "center", padding: "12px 0", borderRadius: 14, background: "#2A2028", color: "#fff", fontWeight: 700, fontSize: 14, textDecoration: "none" }}>{t("login.resetZurAnmeldung")}</Link>
        </>
      ) : failed ? (
        <>
          <p style={{ fontSize: 14, color: "#8A7F85", marginBottom: 20 }}>
            {t("login.resetLinkUngueltig")}
          </p>
          <Link href="/" style={{ display: "block", textAlign: "center", padding: "12px 0", borderRadius: 14, background: "#2A2028", color: "#fff", fontWeight: 700, fontSize: 14, textDecoration: "none" }}>{t("login.resetZurAnmeldung")}</Link>
        </>
      ) : !ready ? (
        <p style={{ fontSize: 14, color: "#8A7F85" }}>{t("login.resetLinkPruefen")}</p>
      ) : (
        <>
          <p style={{ fontSize: 13, color: "#8A7F85", marginBottom: 18 }}>
            {t("login.resetHinweis")}
          </p>
          <input type="password" value={next} onChange={(e) => setNext(e.target.value)}
            placeholder={t("ph.neuesPasswort")} autoComplete="new-password" style={field} />
          <input type="password" value={repeat} onChange={(e) => setRepeat(e.target.value)}
            placeholder={t("ph.neuesPasswortWdh")} autoComplete="new-password" style={field} />
          {message && (
            <div role="status" style={{ fontSize: 12, color: "#C8102E", marginBottom: 12 }}>{message}</div>
          )}
          <button onClick={save} disabled={busy}
            style={{ width: "100%", padding: "12px 0", borderRadius: 14, background: "#2A2028", color: "#fff", fontWeight: 700, fontSize: 14, border: "none", opacity: busy ? 0.6 : 1 }}>
            {busy ? t("allg.wirdGespeichert") : t("login.resetSpeichern")}
          </button>
        </>
      )}
    </main>
  );
}
