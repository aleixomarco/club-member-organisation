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
    accounts: 700,
    accountLabel: "ab 700 Zugänge",
    desc: "Für große Vereine. Alle Funktionen, 700 Konten — mit Zusatzpaketen erweiterbar.",
  },
} as const;

/* Zusatzpakete zum Pro-Tarif.
 *
 * Sie liegen im App Store in einer eigenen Abo-Gruppe, weil Apple pro Gruppe
 * nur ein aktives Abonnement erlaubt. Aus demselben Grund lassen sie sich
 * nicht stapeln: Der Verein wählt genau ein Paket, nicht mehrere. */
export const CLUB_ADDONS = [
  { key: "addon_100", extra: 100, total: 800, label: "Pro +", price: "14,99 €" },
  { key: "addon_500", extra: 500, total: 1200, label: "Pro Max", price: "49,99 €" },
] as const;
