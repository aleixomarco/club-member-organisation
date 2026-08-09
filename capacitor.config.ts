import type { CapacitorConfig } from "@capacitor/cli";

// Die App läuft komplett serverseitig (Next.js API-Routen, Supabase, PayPal),
// deshalb lädt die native Hülle die gehostete Web-App per URL, statt einen
// statischen Export mitzuliefern.
//
// Hier steht bewusst die PRODUKTIONS-Adresse (main-Branch) und nicht mehr die
// Vorschau-URL eines Branches: Vorschau-URLs verschwinden, sobald der Branch
// gelöscht wird — eine bereits veröffentlichte App wäre dann tot.
//
// Daraus folgt: Was in den Stores landet, zeigt immer den Stand von main.
// Vor dem Hochladen muss der Arbeitsbranch also nach main gemergt sein.
const config: CapacitorConfig = {
  appId: "de.idbranding.clubmemberorganisation",
  appName: "Club Member Organisation",
  webDir: "public",
  server: {
    url: "https://club-member-organisation.vercel.app",
    cleartext: false,
    androidScheme: "https",
  },
  ios: {
    contentInset: "automatic",
  },
};

export default config;
