import { headers } from "next/headers";
import { LegalShell, legal } from "../legal-shell";
import { spracheAusKopf, uebersetze } from "@/lib/sprachen";

/* Diese Seite wird auf dem Server gezeichnet und oft von ausserhalb der App
   geoeffnet (Store-Eintrag "Konto loeschen"). Die Sprache kommt deshalb aus
   dem Browser. headers() macht die Seite dynamisch - bei dieser kleinen
   Seite unerheblich. */
async function seitenUebersetzer() {
  const sprache = spracheAusKopf((await headers()).get("accept-language"));
  return (schluessel: string) => uebersetze(sprache, schluessel);
}

/* Setzt ein Element (Fettdruck, Link) an die Stelle eines Platzhalters -
   so bleibt die Wortstellung je Sprache im Woerterbuch. */
function einsetzen(text: string, platzhalter: string, inhalt: React.ReactNode) {
  const [vor, ...nach] = text.split(platzhalter);
  return <>{vor}{inhalt}{nach.join(platzhalter)}</>;
}
export async function generateMetadata() {
  const t = await seitenUebersetzer();
  return { title: `${t("pf.kontoLoeschen")} | Club Member Organisation` };
}
export default async function DeleteAccountPage() {
  const t = await seitenUebersetzer();
  return <LegalShell title={t("pf.kontoLoeschen")} t={t}>
  <p>{t("konto.seite.intro")}</p>

  <h2>{t("konto.seite.soTitel")}</h2>
  <ol>
    <li>{t("konto.seite.schritt1")}</li>
    <li>{einsetzen(t("konto.seite.schritt2"), "{pfad}", <strong>{t("nav.profile")} → {t("pf.einstellungen")} → {t("pf.kontoLoeschen")}</strong>)}</li>
    <li>{t("konto.seite.schritt3")}</li>
    <li>{t("konto.seite.schritt4")}</li>
  </ol>
  <p>{t("konto.seite.wartend")}</p>
  <p><strong>{t("konto.seite.kostenTitel")}</strong> {t("konto.seite.kostenText")}</p>
  <p>{t("konto.seite.ohneAnmeldung").replace("{email}", () => legal.email)}</p>

  <h2>{t("konto.seite.datenTitel")}</h2>
  <p>{t("konto.seite.datenText")}</p>
  <p>{t("konto.seite.newsText")}</p>

  <h2>{t("konto.seite.aufbewahrenTitel")}</h2>
  <p>{t("konto.seite.aufbewahrenText")} {einsetzen(t("konto.seite.details"), "{link}", <a href="/datenschutz">{t("recht.datenschutzerklaerung")}</a>)}</p>

  <h2>{t("konto.seite.zeitTitel")}</h2>
  <p>{t("konto.seite.zeitText")}</p>
</LegalShell>; }
