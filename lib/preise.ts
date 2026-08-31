/* Einzige Quelle für die Stufen und ihre Preise.
 *
 * Seit dem 31.08.2026 wird in der App nichts mehr verkauft. Die Vereinsleitung
 * fragt den Vollzugang an, der Betreiber macht ein Angebot und stellt eine
 * Rechnung, und danach wird freigeschaltet.
 *
 * Die Preise hier sind deshalb keine Ladenpreise mehr, sondern die Grundlage
 * für Angebote und für die Website. In der App erscheint keiner von ihnen —
 * dort steht nur, was freigeschaltet ist und wie viele Zugänge belegt sind.
 * Apple lässt einen Dienst, der an Organisationen verkauft wird, nur unter
 * dieser Bedingung zu: in der App weder kaufen noch zum Kauf auffordern.
 *
 * Die Stufen unterscheiden sich ausschließlich in der Zahl der Zugänge, nicht
 * im Funktionsumfang: Jeder freigeschaltete Verein bekommt alles.
 *
 * Über 1.000 Zugängen gibt es keine Staffel mehr, sondern ein Angebot. Die
 * vereinbarte Zahl steht dann am Verein selbst (clubs.vereinbarte_zugaenge)
 * und geht der Staffel vor.
 */

export type Vereinstarif = "basic" | "plus" | "pro";

/* Welche Stufen im Angebot stehen.
 *
 * Nicht mehr "was die App verkauft" - sie verkauft nichts -, sondern welche
 * Stufen der Betreiber anbietet. Die Datenbank kennt sie ohnehin alle. */
export const ANGEBOTENE_TARIFE: Vereinstarif[] = ["basic", "plus", "pro"];

/* Als Record statt "as const": Es wird mit einer Variablen zugegriffen
   (CLUB_TIER_PRICES[tier]), und ein Literal-Objekt laesst das nicht zu. */
type Preisangabe = { monthly: { price: string }; yearly: { price: string; equivalent: string } };

export const CLUB_TIER_PRICES: Record<string, Preisangabe> = {
  basic: {
    monthly: { price: "24,99 €" },
    yearly: { price: "239,99 €", equivalent: "19,99 € / Monat" },
  },
  plus: {
    monthly: { price: "49,99 €" },
    yearly: { price: "479,99 €", equivalent: "39,99 € / Monat" },
  },
  pro: {
    monthly: { price: "99,99 €" },
    yearly: { price: "959,99 €", equivalent: "79,99 € / Monat" },
  },
};

type Tarifangabe = { label: string; accounts: number; accountLabel: string; desc: string };

export const CLUB_TIER_INFO: Record<string, Tarifangabe> = {
  basic: {
    label: "Basic",
    accounts: 100,
    accountLabel: "bis 100 Zugänge",
    desc: "Für kleine Vereine. Alle Funktionen, bis zu 100 angemeldete Konten.",
  },
  plus: {
    label: "Plus",
    accounts: 350,
    accountLabel: "bis 350 Zugänge",
    desc: "Für mittlere Vereine. Alle Funktionen, bis zu 350 angemeldete Konten.",
  },
  pro: {
    label: "Pro",
    accounts: 1000,
    accountLabel: "bis 1.000 Zugänge",
    desc: "Für große Vereine. Alle Funktionen, bis zu 1.000 angemeldete Konten.",
  },
};

/* Kostenlose Kleinstufe.
 *
 * Ein Verein ohne Abo wird nicht ausgesperrt, sondern darf bis zu dieser Zahl
 * Zugaenge anlegen. Damit kann ein kleiner Verein die App dauerhaft nutzen,
 * ohne zu zahlen - und waechst er darueber hinaus, wird daraus ein Angebot
 * statt einer Mauer. */
export const FREIE_ZUGAENGE = 3;

/* Ueber Pro hinaus gibt es keine Staffel, sondern ein Angebot. Die vereinbarte
   Zahl steht dann am Verein selbst (clubs.vereinbarte_zugaenge) und geht der
   Staffel vor. */
export const UEBER_MAX_HINWEIS = "Mehr als 1.000 Zugänge? Sprich uns an.";

export const INDIVIDUELL = {
  label: "Individuell",
  accountLabel: "mehr als 1.000 Zugänge",
  desc: "Für große Vereine und Mehrspartenvereine. Alle Funktionen, die Zahl der Zugänge nach Absprache.",
  preis: "auf Anfrage",
};

/* Der Sponsorenzusatz.
 *
 * Fünf Euro im Monat auf jede Stufe. Damit darf der Verein die vier
 * Werbeplätze in der App mit eigenen Sponsoren belegen — dort, wo sonst die
 * Werbung des Betreibers steht — und dazu Aktionen mit eigenem Zeitraum
 * schalten.
 *
 * Bewusst ein Aufschlag und keine eigene Stufenreihe: Er hängt nicht an der
 * Vereinsgröße, sondern daran, ob der Verein Sponsoren hat. Ein Verein mit 80
 * Mitgliedern und drei Sponsoren zahlt dafür dasselbe wie einer mit 800.
 */
export const SPONSOREN_ZUSATZ = {
  label: "Eigene Sponsoren",
  monatlich: "+ 5,00 €",
  jaehrlich: "+ 60,00 €",
  desc: "Die Werbeplätze in der App mit euren eigenen Sponsoren belegen, inklusive Aktionen mit eigenem Zeitraum. Aufschlag auf jede Stufe.",
  werbeplaetze: 4,
};

/* Was eine Stufe mit dem Zusatz kostet - ausgerechnet statt abgeschrieben,
   damit die beiden Preisreihen nicht auseinanderlaufen koennen. */
export function preisMitSponsoren(tarif: Vereinstarif, zeitraum: "monthly" | "yearly" = "monthly"): string {
  const roh = CLUB_TIER_PRICES[tarif]?.[zeitraum]?.price;
  if (!roh) return "";
  const zahl = Number(roh.replace(/[^\d,]/g, "").replace(",", "."));
  const aufschlag = zeitraum === "yearly" ? 60 : 5;
  /* Ueber Tausend braucht es den Punkt: "1019,99 €" liest sich wie ein
     Tippfehler, "1.019,99 €" wie ein Preis. */
  return `${new Intl.NumberFormat("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(zahl + aufschlag)} €`;
}
