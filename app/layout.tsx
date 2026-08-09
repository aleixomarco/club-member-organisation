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
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
