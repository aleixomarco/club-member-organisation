import Link from "next/link";

export function LegalShell({ title, children }: { title: string; children: React.ReactNode }) {
  /* Die sicheren Bereiche gehoeren hier hinein, weil contentInset in
     capacitor.config.ts auf "never" steht: Die Webansicht spannt sich ueber den
     ganzen Bildschirm, auch unter Dynamic Island und Home-Indikator. Mit den
     festen 48px oben konnte ausgerechnet "← Zur App" darunter verschwinden -
     und das ist auf diesen Seiten der einzige Rueckweg, denn im WebView gibt es
     keine Browserleiste. */
  return <main style={{ maxWidth: 760, margin: "0 auto", padding: "calc(env(safe-area-inset-top) + 28px) calc(env(safe-area-inset-right) + 22px) calc(env(safe-area-inset-bottom) + 80px) calc(env(safe-area-inset-left) + 22px)", fontFamily: "Arial, sans-serif", lineHeight: 1.65, color: "#14151A" }}>
    <Link href="/" style={{ color: "#C8102E", fontWeight: 700, textDecoration: "none" }}>← Zur App</Link>
    <h1 style={{ fontSize: 36, margin: "28px 0 22px" }}>{title}</h1>
    {children}
    <nav style={{ display: "flex", flexWrap: "wrap", gap: 16, marginTop: 42, paddingTop: 22, borderTop: "1px solid #ddd" }}>
      <Link href="/datenschutz">Datenschutz</Link><Link href="/impressum">Impressum</Link><Link href="/nutzungsbedingungen">Nutzungsbedingungen</Link><Link href="/konto-loeschen">Konto löschen</Link>
    </nav>
  </main>;
}

const name = process.env.NEXT_PUBLIC_LEGAL_NAME || "[Betreibername in Vercel eintragen]";

/* Die Vertretung faellt auf den Betreibernamen zurueck, statt einen Platzhalter
   anzuzeigen. Bei einem Einzelunternehmen sind beide dieselbe Person, und §5 DDG
   verlangt die Angabe ohnehin nur fuer juristische Personen.

   Vorher stand hier ein Platzhalter, und weil NEXT_PUBLIC_LEGAL_REPRESENTATIVE in
   Vercel nie gesetzt wurde, las man auf Impressum, Datenschutz UND
   Nutzungsbedingungen woertlich "[Vertretungsberechtigte Person in Vercel
   eintragen]". Apples Pruefer oeffnet die Nutzungsbedingungen - das war schon der
   Grund der Ablehnung nach Richtlinie 3.1.2 - und Platzhaltertext in einer
   fertigen App ist zusaetzlich ein Verstoss gegen Richtlinie 2.1. */
const representative = process.env.NEXT_PUBLIC_LEGAL_REPRESENTATIVE || name;

export const legal = {
  name,
  legalForm: process.env.NEXT_PUBLIC_LEGAL_FORM || "[Rechtsform in Vercel eintragen]",
  address: process.env.NEXT_PUBLIC_LEGAL_ADDRESS || "[Anschrift in Vercel eintragen]",
  email: process.env.NEXT_PUBLIC_LEGAL_EMAIL || "[Kontakt-E-Mail in Vercel eintragen]",
  representative,
  /* Wahr, solange Betreiber und Vertretung dieselbe Person sind. Dann erspart sich
     der Satz "Marco Aleixo, vertreten durch Marco Aleixo". */
  representedBySelf: representative === name,
  phone: process.env.NEXT_PUBLIC_LEGAL_PHONE || "",
  register: process.env.NEXT_PUBLIC_LEGAL_REGISTER || "",
  vatId: process.env.NEXT_PUBLIC_LEGAL_VAT_ID || "",
};
