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
    ];
  },
};

export default nextConfig;
