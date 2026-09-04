import type { CapacitorConfig } from "@capacitor/cli";

// Die App läuft komplett serverseitig (Next.js API-Routen, Supabase),
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
    /* Ohne errorPath laedt Capacitor bei einem gescheiterten Ladevorgang gar
       nichts nach und schreibt nur eine Zeile ins Log (WebViewDelegationHandler,
       didFailProvisionalNavigation). Die Webansicht blieb dann weiss: Der
       Startbildschirm verschwand nach vier Sekunden, und dahinter kam nichts
       mehr - ohne Netz war die App also stumm kaputt, mit Beenden als einzigem
       Ausweg. Das ist genau das leere Bild, wegen dem Apple nach Richtlinie 2.1
       ablehnt.
       public/offline.html liegt im Bundle und kommt deshalb auch ohne Netz
       hoch; sie bietet einen Neuversuch an und laedt von selbst nach, sobald
       die Verbindung zurueck ist. */
    errorPath: "offline.html",
  },
  /* Verlangt @capacitor-firebase/messaging fuer iOS: Ohne symlink kollidiert
     die SwiftPM-Paketkennung des Plugins mit der des Firebase-SDK, und der
     Build bricht ab (capawesome-team/capacitor-firebase#959). Setzt
     Capacitor-CLI 8.4.0+ voraus - hier laeuft 8.5.0. */
  experimental: {
    ios: {
      spm: {
        packageOptions: {
          "@capacitor-firebase/messaging": { symlink: true },
        },
      },
    },
  } as never,
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
    /* Ohne dieses Plugin gilt das Standardverhalten von WKWebView: Die
       Webansicht behaelt ihre volle Hoehe, und iOS scrollt die GANZE Seite nach
       oben, um das Eingabefeld freizulegen. Im Chat schob sich dadurch die
       komplette App samt Navigationsleiste nach oben.

       resize: "native" verkleinert stattdessen die Webansicht selbst. Weil das
       Layout mit position: fixed und inset: 0 an dieser Flaeche haengt (siehe
       app/page.tsx), schrumpft die Nachrichtenliste, und das Schreibfeld sitzt
       direkt ueber der Tastatur - so wie man es von Messengern kennt.

       scrollAssist: false schaltet Apples automatisches Nachscrollen ab. Es
       wuerde sonst zusaetzlich verschieben, obwohl das Feld bereits sichtbar
       ist. */
    Keyboard: {
      resize: "native" as never,
      scrollAssist: false,
      resizeOnFullScreen: true,
    },
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
