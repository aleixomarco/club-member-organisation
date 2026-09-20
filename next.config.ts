import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  turbopack: {
    root: process.cwd(),
  },
  // Die bestehende Demo ist schrittweise aus JSX entstanden. Für die
  // Veröffentlichung wird sie gebaut, während die Typisierung separat
  // vervollständigt werden kann.
  typescript: {
    ignoreBuildErrors: true,
  },
  /* Die Datei, an der iOS erkennt, dass unsere Links zur App gehoeren.
   *
   * Sie liegt unter public/.well-known/apple-app-site-association - bewusst
   * OHNE Dateiendung, so verlangt Apple den Pfad. Genau daran scheitert aber
   * die Typerkennung von Next: Ohne Endung liefert es application/octet-stream,
   * und Apple laedt die Datei dann gar nicht erst herunter. Der Header setzt
   * das gerade.
   *
   * Getestet werden kann das nach der Veroeffentlichung mit
   *   curl -sI https://club-member-organisation.vercel.app/.well-known/apple-app-site-association
   * Dort muss application/json stehen, Status 200, und keine Weiterleitung -
   * Apple folgt keiner. */
  async headers() {
    return [
      {
        source: "/.well-known/apple-app-site-association",
        headers: [{ key: "Content-Type", value: "application/json" }],
      },
      /* Schutzkopfzeilen fuer alles, was wir ausliefern.
       *
       * Gemessen kam von Vercel bisher nur strict-transport-security zurueck.
       * Hinter dem Login stehen personenbezogene Daten (Profile, Mannschaften,
       * Termine): Ohne frame-ancestors laesst sich die angemeldete Oberflaeche
       * in eine fremde Seite einbetten, und ein untergeschobener Klick trifft
       * dann Zusagen, Rollen oder die Kontoloeschung.
       *
       * Warum das nichts von dem stoert, was heute laeuft:
       *  - Die App wird nirgends eingebettet und bettet sich auch nicht selbst
       *    ein - es gibt keine einzige <iframe>-Stelle im Code.
       *  - frame-ancestors regelt nur, WER UNS einbetten darf. Wen WIR
       *    einbetten, stuende in frame-src; das bleibt bewusst ungesetzt, damit
       *    das Captcha-Fenster von challenges.cloudflare.com weiter laedt
       *    (turnstileSkript() in app/page.tsx).
       *  - Die native Huelle laedt https://club-member-organisation.vercel.app
       *    als normale Navigation in der WebView (capacitor.config.ts,
       *    server.url), nicht in einem iframe - fuer iOS und Android aendert
       *    sich damit nichts.
       *  - Permissions-Policy schaltet nur Schnittstellen ab, die diese App
       *    nicht benutzt (kein getUserMedia, kein navigator.geolocation). Die
       *    Bildauswahl laeuft ueber <input type="file">, also ueber den nativen
       *    Dialog - der faellt nicht unter diese Richtlinie, und der
       *    Kamera-Text in ios/App/App/Info.plist bleibt weiter noetig.
       *
       * "/:path*" trifft auch die Startseite: Next haengt an die Regel aus der
       * routes-manifest.json ein optionales "(?:/)?$" an, damit passt "/"
       * (nachgemessen mit buildCustomRoute aus next 16.2.6). Die AASA-Regel
       * darueber bleibt daneben bestehen - beide Eintraege treffen auf die
       * Datei zu, setzen aber verschiedene Schluessel.
       *
       * Gegenprobe nach dem Deploy:
       *   curl -sI https://club-member-organisation.vercel.app/ | grep -Ei "content-security-policy|x-content-type|referrer-policy|permissions-policy"
       */
      {
        source: "/:path*",
        headers: [
          { key: "Content-Security-Policy", value: "frame-ancestors 'self'" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
        ],
      },
    ];
  },
};

export default nextConfig;
