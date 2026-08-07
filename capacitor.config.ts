import type { CapacitorConfig } from "@capacitor/cli";

// WICHTIG: sobald die Produktions-Domain (main-Branch) feststeht, hier die
// echte URL eintragen. Bis dahin zeigt die native Hülle auf die aktuelle
// Vercel-Vorschau. Die App läuft komplett serverseitig (Next.js API-Routen,
// Supabase, PayPal) — deshalb lädt die native App die live gehostete
// Web-App per URL, statt einen statischen Export mitzuliefern.
const config: CapacitorConfig = {
  appId: "de.idbranding.clubmemberorganisation",
  appName: "Club Member Organisation",
  webDir: "public",
  server: {
    url: "https://club-member-organisation-git-pay-a13416-marco-aleixo-s-projects.vercel.app",
    cleartext: false,
    androidScheme: "https",
  },
  ios: {
    contentInset: "automatic",
  },
};

export default config;
