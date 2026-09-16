"use client";

import { useEffect, useState } from "react";
import { gespeicherteSprache, uebersetze } from "@/lib/sprachen";

/* Die letzte Auffanglinie.
 *
 * app/error.tsx faengt Fehler INNERHALB der Seite. Wirft dagegen das Grundgeruest
 * selbst - app/layout.tsx -, kommt error.tsx gar nicht mehr zum Zug, weil es in
 * ebendiesem Geruest haengt. Dafuer gibt es global-error.tsx: Es ersetzt das
 * Geruest und muss deshalb <html> und <body> selbst mitbringen.
 *
 * Sie greift selten. Aber wenn, dann ist die Alternative eine vollstaendig
 * weisse Seite ohne einen einzigen Knopf.
 */
export default function GlobalerFehler({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  /* Sprache aus dem Geraet, nach dem ersten Zeichnen gelesen (wie in der App). */
  const [sprache, setSprache] = useState("de");
  useEffect(() => { setSprache(gespeicherteSprache() || "de"); }, []);
  const t = (schluessel: string) => uebersetze(sprache, schluessel);
  return (
    <html lang={sprache}>
      <body style={{
        margin: 0, minHeight: "100dvh", display: "flex", alignItems: "center",
        justifyContent: "center", padding: 24, background: "#F7F4F6", color: "#14151A",
        fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
      }}>
        <div style={{ width: "100%", maxWidth: 380, textAlign: "center" }}>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: "0 0 8px" }}>
            {t("fehler.appStartTitel")}
          </h1>
          <p style={{ fontSize: 14, lineHeight: 1.5, color: "#6B6570", margin: "0 0 22px" }}>
            {t("fehler.appStartText")}
          </p>
          <button onClick={reset} style={{
            width: "100%", padding: "13px 16px", borderRadius: 14, border: "none",
            background: "#14151A", color: "#fff", fontSize: 14, fontWeight: 700, cursor: "pointer",
          }}>{t("fehler.erneutVersuchen")}</button>
          {error?.digest && (
            <p style={{ fontSize: 11, color: "#9B94A0", marginTop: 18 }}>
              {t("fehler.kennung").replace("{kennung}", () => error.digest || "")}
            </p>
          )}
        </div>
      </body>
    </html>
  );
}
