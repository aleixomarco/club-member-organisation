"use client";

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
  return (
    <html lang="de">
      <body style={{
        margin: 0, minHeight: "100dvh", display: "flex", alignItems: "center",
        justifyContent: "center", padding: 24, background: "#F7F4F6", color: "#14151A",
        fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
      }}>
        <div style={{ width: "100%", maxWidth: 380, textAlign: "center" }}>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: "0 0 8px" }}>
            Die App konnte nicht starten
          </h1>
          <p style={{ fontSize: 14, lineHeight: 1.5, color: "#6B6570", margin: "0 0 22px" }}>
            Bitte versuche es erneut. Deine Daten sind davon nicht betroffen.
          </p>
          <button onClick={reset} style={{
            width: "100%", padding: "13px 16px", borderRadius: 14, border: "none",
            background: "#14151A", color: "#fff", fontSize: 14, fontWeight: 700, cursor: "pointer",
          }}>Erneut versuchen</button>
          {error?.digest && (
            <p style={{ fontSize: 11, color: "#9B94A0", marginTop: 18 }}>
              Fehlerkennung: {error.digest}
            </p>
          )}
        </div>
      </body>
    </html>
  );
}
