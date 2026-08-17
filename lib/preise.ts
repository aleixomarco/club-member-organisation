/* Einzige Quelle für alle Preisangaben.
 *
 * Vorher standen die Preise doppelt: in app/page.tsx (Tarifübersicht und
 * Kaufmaske) und in app/nutzungsbedingungen/page.tsx (rechtsverbindlicher
 * Text). Beide waren auseinandergelaufen — die Nutzungsbedingungen nannten
 * einen einzigen Vereinspreis von 29,99 € und eine Einrichtungsgebühr, die
 * die App nie erhoben hat und über den In-App-Kauf auch gar nicht erheben
 * kann. Genau diese Seite muss der Käufer vor dem Kauf per Häkchen
 * akzeptieren.
 *
 * Deshalb hier zentral. Ändert sich ein Preis im App Store, wird er an genau
 * einer Stelle nachgezogen und wirkt überall.
 *
 * WICHTIG: Die Werte müssen den deutschen App-Store-Preisen entsprechen. Die
 * native App zeigt in der Kaufmaske den echten Store-Preis (über RevenueCat),
 * in der Tarifübersicht und in den Nutzungsbedingungen dagegen diese Werte.
 * Weichen sie ab, widerspricht sich die App selbst.
 */

export type Abrechnung = "monthly" | "yearly";

export const CLUB_TIER_PRICES = {
  basic: {
    monthly: { price: "34,99 €" },
    yearly: { price: "299,99 €", equivalent: "rund 25 € / Monat" },
  },
  premium: {
    monthly: { price: "39,99 €" },
    yearly: { price: "359,99 €", equivalent: "rund 30 € / Monat" },
  },
} as const;

/* Persönliches Abo jedes Mitglieds — zusätzlich zum Vereinsabo. Nur eine
   Stufe: Was ein Mitglied damit tun darf, ergibt sich aus seinen Rollen. */
export const MEMBER_PLAN_PRICES = {
  monthly: { price: "2,99 €", note: "pro Monat" },
  yearly: { price: "14,99 €", note: "jährlich im Voraus", equivalent: "rund 1,25 € / Monat" },
} as const;
