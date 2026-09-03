"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { supabase } from "@/lib/supabase";

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

  useEffect(() => {
    if (!supabase) { setFailed(true); return; }
    let settled = false;
    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "PASSWORD_RECOVERY" || session) { settled = true; setReady(true); }
    });
    supabase.auth.getSession().then(({ data }) => {
      if (data.session) { settled = true; setReady(true); }
    });
    /* Ohne gültiges Token bleibt sonst ein Ladezustand stehen, der nie endet. */
    const timer = setTimeout(() => { if (!settled) setFailed(true); }, 4000);
    return () => { sub.subscription.unsubscribe(); clearTimeout(timer); };
  }, []);

  const save = async () => {
    setMessage("");
    if (next.length < 8) { setMessage("Das Passwort muss mindestens 8 Zeichen haben."); return; }
    if (next !== repeat) { setMessage("Die beiden Eingaben stimmen nicht überein."); return; }
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
        setMessage("Der Link ist abgelaufen oder wurde schon verwendet. Fordere auf dem Anmeldebildschirm über „Passwort vergessen?“ einen neuen an.");
      } else if (code === "weak_password" || (/password/i.test(String(error.message || "")) && /short|weak|least|pwned/i.test(text))) {
        setMessage("Das neue Passwort ist zu schwach. Nimm ein längeres oder ungewöhnlicheres.");
      } else if (code === "same_password") {
        setMessage("Das ist dein bisheriges Passwort. Wähle ein anderes.");
      } else if (status === 429 || code === "over_request_rate_limit" || text.includes("rate limit")) {
        setMessage("Zu viele Versuche. Warte einen Moment und versuche es dann noch einmal.");
      } else if (status === 0 || text.includes("failed to fetch") || text.includes("network") || text.includes("load failed")) {
        setMessage("Keine Verbindung. Prüfe dein Internet und versuche es noch einmal.");
      } else {
        setMessage("Das Passwort konnte nicht geändert werden. Bitte versuche es in ein paar Minuten noch einmal.");
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
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>Neues Passwort</h1>

      {done ? (
        <>
          <p style={{ fontSize: 14, color: "#2F9E58", marginBottom: 20 }}>
            Dein Passwort wurde geändert. Du kannst dich jetzt damit anmelden.
          </p>
          <Link href="/" style={{ display: "block", textAlign: "center", padding: "12px 0", borderRadius: 14, background: "#2A2028", color: "#fff", fontWeight: 700, fontSize: 14, textDecoration: "none" }}>Zur Anmeldung</Link>
        </>
      ) : failed ? (
        <>
          <p style={{ fontSize: 14, color: "#8A7F85", marginBottom: 20 }}>
            Dieser Link ist abgelaufen oder wurde bereits verwendet. Fordere auf
            dem Anmeldebildschirm über „Passwort vergessen?“ einen neuen an.
          </p>
          <Link href="/" style={{ display: "block", textAlign: "center", padding: "12px 0", borderRadius: 14, background: "#2A2028", color: "#fff", fontWeight: 700, fontSize: 14, textDecoration: "none" }}>Zur Anmeldung</Link>
        </>
      ) : !ready ? (
        <p style={{ fontSize: 14, color: "#8A7F85" }}>Link wird geprüft …</p>
      ) : (
        <>
          <p style={{ fontSize: 13, color: "#8A7F85", marginBottom: 18 }}>
            Mindestens 8 Zeichen. Nach dem Speichern meldest du dich mit dem
            neuen Passwort an.
          </p>
          <input type="password" value={next} onChange={(e) => setNext(e.target.value)}
            placeholder="Neues Passwort" autoComplete="new-password" style={field} />
          <input type="password" value={repeat} onChange={(e) => setRepeat(e.target.value)}
            placeholder="Neues Passwort wiederholen" autoComplete="new-password" style={field} />
          {message && (
            <div role="status" style={{ fontSize: 12, color: "#C8102E", marginBottom: 12 }}>{message}</div>
          )}
          <button onClick={save} disabled={busy}
            style={{ width: "100%", padding: "12px 0", borderRadius: 14, background: "#2A2028", color: "#fff", fontWeight: 700, fontSize: 14, border: "none", opacity: busy ? 0.6 : 1 }}>
            {busy ? "Wird gespeichert …" : "Passwort speichern"}
          </button>
        </>
      )}
    </main>
  );
}
