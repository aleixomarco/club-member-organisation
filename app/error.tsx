"use client";

/* Die Auffanglinie fuer die ganze Seite.
 *
 * app/page.tsx ist EIN Bauteil mit rund 14.000 Zeilen. Ohne Fehlergrenze
 * genuegte darin ein einziger TypeError beim Zeichnen, und der Browser zeigte
 * "This page couldn't load" - eine weisse Seite ohne Erklaerung und ohne Weg
 * zurueck. Genau das ist in dieser Sitzung zweimal passiert: einmal in
 * Verwaltung > Funktionen, einmal auf der Startseite.
 *
 * Next.js ruft diese Datei auf, sobald beim Zeichnen etwas wirft. Sie steht
 * bewusst OHNE Rueckgriff auf app/page.tsx da - eigene Farben, eigene
 * Schriften, kein Import. Wuerde sie aus derselben Datei laden, die gerade
 * abgestuerzt ist, koennte sie mit ihr fallen.
 *
 * "Erneut versuchen" ruft reset() - Next.js zeichnet den Zweig neu. Hilft das
 * nicht, laedt der zweite Knopf die App vollstaendig neu.
 */
export default function Fehlerseite({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div style={{
      minHeight: "100dvh", display: "flex", alignItems: "center", justifyContent: "center",
      padding: "24px", background: "#F7F4F6", color: "#14151A",
      fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
    }}>
      <div style={{ width: "100%", maxWidth: 380, textAlign: "center" }}>
        <div style={{
          width: 56, height: 56, borderRadius: 999, margin: "0 auto 18px",
          display: "flex", alignItems: "center", justifyContent: "center",
          background: "#FBE9EC", color: "#C8102E", fontSize: 28, fontWeight: 700,
        }}>!</div>
        <h1 style={{ fontSize: 20, fontWeight: 700, margin: "0 0 8px" }}>
          Da ist etwas schiefgelaufen
        </h1>
        <p style={{ fontSize: 14, lineHeight: 1.5, color: "#6B6570", margin: "0 0 22px" }}>
          Die Seite konnte nicht geladen werden. Deine Daten sind davon nicht
          betroffen — es ist ein Anzeigefehler.
        </p>
        <button onClick={reset} style={{
          width: "100%", padding: "13px 16px", borderRadius: 14, border: "none",
          background: "#14151A", color: "#fff", fontSize: 14, fontWeight: 700,
          cursor: "pointer", marginBottom: 10,
        }}>Erneut versuchen</button>
        <button onClick={() => window.location.reload()} style={{
          width: "100%", padding: "13px 16px", borderRadius: 14,
          border: "1px solid #E3DDE3", background: "transparent", color: "#6B6570",
          fontSize: 14, fontWeight: 700, cursor: "pointer",
        }}>App neu laden</button>
        {/* Die Kennung hilft beim Suchen im Protokoll - ohne sie muesste man
            raten, welcher Absturz gemeint ist. Sie steht klein und stumm da. */}
        {error?.digest && (
          <p style={{ fontSize: 11, color: "#9B94A0", marginTop: 18 }}>
            Fehlerkennung: {error.digest}
          </p>
        )}
      </div>
    </div>
  );
}
