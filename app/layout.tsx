import type { Metadata, Viewport } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: "Club Member Organisation",
  description: "Mitglieder, Teams, Events und Vereinsverwaltung an einem Ort.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "CMO",
  },
};
export const viewport: Viewport = {
  themeColor: "#F7F4F5",
  // viewportFit: "cover" ist Voraussetzung dafür, dass env(safe-area-inset-*) auf
  // iOS überhaupt Werte liefert — ohne das liegen Knöpfe hinter Dynamic Island,
  // Notch oder Home-Indikator. maximumScale/userScalable verhindern, dass ein
  // Doppeltipp die native App wegzoomt.
  viewportFit: "cover",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};
export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  /* Kennung der Veroeffentlichung, die diese Seite ausgeliefert hat.
   *
   * Sie steht als Meta-Angabe im Dokument, nicht als eingebackene
   * Umgebungsvariable. Das ist kein Umweg, sondern genauer: Der Wert kommt von
   * genau dem Server, der auch das Buendel geliefert hat - Seite und Code
   * gehoeren damit nachweislich zusammen. Ueber next.config.ts einzublenden
   * waere die naheliegende Loesung gewesen, nur landet der Wert mit Turbopack
   * nicht im Buendel; nachgemessen im ausgelieferten Chunk.
   *
   * Die App vergleicht ihn spaeter mit dem, was /api/web-version meldet -
   * siehe useNeueFassung(). Fehlt die Variable, bleibt das Feld leer und die
   * Pruefung schweigt. */
  const veroeffentlichung = process.env.VERCEL_GIT_COMMIT_SHA || "";
  return (
    <html lang="de">
      <head>
        <meta name="cmo-build" content={veroeffentlichung} />
      </head>
      <body>{children}</body>
    </html>
  );
}
