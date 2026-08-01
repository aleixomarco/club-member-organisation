import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Club Member Organisation",
  description: "Mitglieder, Teams, Events und Vereinsverwaltung an einem Ort.",
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
