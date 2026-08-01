import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ERG Iserlohn Vereins-App",
  description: "Mitglieder, Teams, Events und Verwaltung der ERG Iserlohn an einem Ort.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
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
