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
    desc: "Für große Vereine. Alle Funktionen, bis zu 1.000 angemeldete Konten.",
  },
} as const;

/* Ein einziges Zusatzpaket, buchbar oben auf den laufenden Tarif.
 *
 * Der Preis ist bewusst so gewählt, dass sich ein Aufstieg immer eher lohnt
 * als Dazubuchen. Die Aufpreise zwischen den Stufen liegen bei 25 € (Basic auf
 * Plus) und 50 € (Plus auf Pro); ein Paket für 49,99 € ist damit an jeder
 * Stelle das schlechtere Geschäft, solange es noch eine größere Stufe gibt.
 *
 * Sinnvoll wird es erst oberhalb von Pro, wo kein Aufstieg mehr möglich ist.
 * Es lässt sich nicht mehrfach buchen - Apple erlaubt pro Abo-Gruppe nur ein
 * aktives Abonnement. Vereine über 1.100 Zugänge bekommen ein eigenes Angebot.
 */
export const CLUB_ADDON = {
  key: "addon_100",
  extra: 100,
  label: "Zusatzpaket",
  price: "49,99 €",
  desc: "100 weitere Zugänge, zusätzlich zum gebuchten Tarif.",
} as const;
