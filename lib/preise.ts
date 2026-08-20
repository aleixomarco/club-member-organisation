/* Einzige Quelle für alle Preisangaben.
 *
 * Vorher standen die Preise doppelt: in app/page.tsx (Tarifübersicht und
 * Kaufmaske) und in app/nutzungsbedingungen/page.tsx (rechtsverbindlicher
 * Text). Beide waren auseinandergelaufen. Deshalb hier zentral: Ändert sich
 * ein Preis im App Store, wird er an genau einer Stelle nachgezogen.
 *
 * Die Werte müssen den deutschen App-Store-Preisen entsprechen. Die native
 * App zeigt in der Kaufmaske den echten Store-Preis (über RevenueCat), in der
 * Tarifübersicht und in den Nutzungsbedingungen dagegen diese Werte. Weichen
 * sie ab, widerspricht sich die App selbst.
 *
 * Die Tarife unterscheiden sich ausschließlich in der Zahl der Zugänge, nicht
 * im Funktionsumfang: Jeder zahlende Verein bekommt alles.
 */

export type Abrechnung = "monthly" | "yearly";
export type Vereinstarif = "basic" | "plus" | "pro";

export const CLUB_TIERS: Vereinstarif[] = ["basic", "plus", "pro"];

/* Welche Tarife sich gerade kaufen lassen.
 *
 * Die Datenbank kennt weiterhin alle drei Stufen - ein Verein mit einem
 * Plus-Abo behaelt seine 350 Zugaenge. Hier steht nur, was die App zum Kauf
 * anbietet, und das haengt daran, welche Produkte im App Store angelegt und
 * freigegeben sind.
 *
 * Sobald club_plus_* und club_pro_* dort stehen, diese Liste auf
 * CLUB_TIERS erweitern - Tarifuebersicht, Kaufmaske und Nutzungsbedingungen
 * ziehen automatisch nach. */
export const KAUFBARE_TARIFE: Vereinstarif[] = ["basic"];

/* Als Record statt "as const": Die Oberflaeche greift mit einer Variablen zu
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

/* Ueber 1000 Zugaenge hinaus gibt es kein Produkt im Store, sondern ein
   Gespraech. Das darf in der App genannt, aber nicht mit Kaufknopf oder Link
   beworben werden - Apple untersagt das Vorbeileiten am In-App-Kauf. */
export const UEBER_MAX_HINWEIS = "Mehr als 1.000 Zugänge? Sprich uns an.";
