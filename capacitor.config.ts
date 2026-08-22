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
    /* "never" statt "automatic": Bei "automatic" rueckt iOS die Webansicht
       selbst um Statusleiste und Home-Indikator ein. Die Seite wird dadurch
       oben und unten beschnitten, und dahinter kommt der schwarze
       Fensterhintergrund zum Vorschein.
       Diese App bringt die sicheren Bereiche schon selbst unter - siehe die
       env(safe-area-inset-*)-Regeln in app/page.tsx. Beides zusammen rueckt
       doppelt ein. Mit "never" spannt sich die Webansicht ueber den ganzen
       Bildschirm, und das CSS haelt die Inhalte aus Dynamic Island und
       gerundeten Ecken heraus. */
    contentInset: "never",
  },
  plugins: {
    /* Der native Startbildschirm bleibt stehen, bis die Web-Oberfläche selbst
       Bescheid gibt (SplashScreen.hide() in app/page.tsx). Ohne launchAutoHide
       blendet iOS ihn aus, sobald das App-Fenster steht — also bevor die Seite
       über das Netz geladen ist. Dazwischen sah man eine weiße Fläche, bei
       langsamer Verbindung mehrere Sekunden lang.
       Hintergrundfarbe und Marke entsprechen der Web-Animation, damit der
       Übergang nicht als Bildwechsel auffällt. */
    SplashScreen: {
      /* Bewusst NICHT launchAutoHide:false. Damit bliebe der Startbildschirm
         stehen, bis die Web-Oberfläche ihn ausblendet — lädt die Seite nicht
         (kein Netz, Server nicht erreichbar), liefe kein JavaScript und die App
         wirkte dauerhaft eingefroren.
         Stattdessen eine Obergrenze: Normalerweise blendet app/page.tsx den
         Startbildschirm nach etwa einer Sekunde selbst aus, sobald die
         Animation steht. Klappt das nicht, verschwindet er spätestens nach
         4 Sekunden von allein und der Nutzer sieht wenigstens die Fehlerseite. */
      launchAutoHide: true,
      launchShowDuration: 4000,
      backgroundColor: "#F7F4F5",
      showSpinner: false,
      splashFullScreen: false,
      splashImmersive: false,
    },
  },
};

export default config;
