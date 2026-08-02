import Link from "next/link";

export function LegalShell({ title, children }: { title: string; children: React.ReactNode }) {
  return <main style={{ maxWidth: 760, margin: "0 auto", padding: "48px 22px 80px", fontFamily: "Arial, sans-serif", lineHeight: 1.65, color: "#14151A" }}>
    <Link href="/" style={{ color: "#C8102E", fontWeight: 700, textDecoration: "none" }}>← Zur App</Link>
    <h1 style={{ fontSize: 36, margin: "28px 0 22px" }}>{title}</h1>
    {children}
    <nav style={{ display: "flex", flexWrap: "wrap", gap: 16, marginTop: 42, paddingTop: 22, borderTop: "1px solid #ddd" }}>
      <Link href="/datenschutz">Datenschutz</Link><Link href="/impressum">Impressum</Link><Link href="/nutzungsbedingungen">Nutzungsbedingungen</Link>
    </nav>
  </main>;
}

export const legal = {
  name: process.env.NEXT_PUBLIC_LEGAL_NAME || "[Betreibername in Vercel eintragen]",
  legalForm: process.env.NEXT_PUBLIC_LEGAL_FORM || "[Rechtsform in Vercel eintragen]",
  address: process.env.NEXT_PUBLIC_LEGAL_ADDRESS || "[Anschrift in Vercel eintragen]",
  email: process.env.NEXT_PUBLIC_LEGAL_EMAIL || "[Kontakt-E-Mail in Vercel eintragen]",
};
