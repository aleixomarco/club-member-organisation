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

export const CLUB_TIER_PRICES = {
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
} as const;

export const CLUB_TIER_INFO = {
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
    desc: "Für große Vereine. Alle Funktionen, bis zu 1.000 Konten — erweiterbar.",
  },
} as const;

/* Kostenlose Kleinstufe.
 *
 * Ein Verein ohne Abo wird nicht ausgesperrt, sondern darf bis zu dieser Zahl
 * Zugaenge anlegen. Damit kann ein kleiner Verein die App dauerhaft nutzen,
 * ohne zu zahlen - und waechst er darueber hinaus, wird daraus ein Angebot
 * statt einer Mauer. */
export const FREIE_ZUGAENGE = 10;

/* Zusatzpakete, buchbar nur zusaetzlich zum Pro-Tarif.
 *
 * Apple erlaubt pro Abo-Gruppe nur ein aktives Abonnement, und Mengenangaben
 * gibt es bei Abos nicht. Mehrfach buchen ist deshalb unmoeglich. Stattdessen
 * gibt es eine Leiter: Der Verein waehlt genau ein Paket und wechselt bei
 * Bedarf auf ein groesseres - Apple rechnet den Rest anteilig an.
 *
 * Der Preis setzt die Kurve der Tarife fort: 0,10 EUR pro Konto wie bei Pro,
 * und mit jedem groesseren Block etwas weniger. Das gibt einen Grund, gleich
 * den groesseren zu nehmen statt spaeter nachzukaufen. */
export const CLUB_ADDONS = [
  { key: "addon_500",  extra: 500,  total: 1500, label: "+500",   price: "49,99 €" },
  { key: "addon_1000", extra: 1000, total: 2000, label: "+1.000", price: "89,99 €" },
  { key: "addon_1500", extra: 1500, total: 2500, label: "+1.500", price: "129,99 €" },
  { key: "addon_2000", extra: 2000, total: 3000, label: "+2.000", price: "169,99 €" },
] as const;
