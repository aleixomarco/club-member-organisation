import type { Metadata } from "next";
import BetreiberKonsole from "./konsole";

/* Die Betreiber-Oberfläche gehört in keine Suchmaschine. Der Zugang hängt am
   Passwort, nicht an der Unauffindbarkeit — aber es gibt auch keinen Grund,
   die Adresse zu verbreiten. */
export const metadata: Metadata = {
  title: "Vereinsverwaltung",
  robots: { index: false, follow: false, nocache: true },
};

export default function BetreiberSeite() {
  return <BetreiberKonsole />;
}
