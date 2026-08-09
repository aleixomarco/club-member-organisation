"use client";
import { Capacitor } from "@capacitor/core";
import { Purchases, LOG_LEVEL, type PurchasesPackage } from "@revenuecat/purchases-capacitor";

// Native In-App-Käufe (iOS/Android) für das Vereinsabo über RevenueCat.
// Web bleibt bei PayPal (siehe SubscriptionPanel in app/page.tsx) — Apple/
// Google verlangen In-App-Kauf für digitale Abos innerhalb der nativen App
// (Apple Guideline 3.1.1, Google Play Billing-Pflicht analog).
//
// Erwartete Einrichtung im RevenueCat-Dashboard (muss dort so angelegt
// werden, sonst liefert fetchTierOfferings() leere Pakete):
//   - Zwei Offerings mit den Identifiern "basic" und "premium".
//   - Jedes Offering hat ein "Monthly"- und ein "Annual"-Package.
//   - Die zugrundeliegenden Produkt-IDs in App Store Connect / Play Console
//     müssen exakt den subscription_plans.code-Werten in Supabase
//     entsprechen: club_basic_monthly, club_basic_yearly,
//     club_premium_monthly, club_premium_yearly.
//
// Der eigentliche Freischalt-Status kommt NICHT von hier, sondern weiterhin
// aus club_subscription_tier() in Supabase — RevenueCats Webhook
// (app/api/revenuecat/webhook/route.ts) schreibt jeden Kauf in
// club_subscriptions, genau wie der bestehende PayPal-Webhook. Dieses Modul
// dient nur dazu, den nativen Kaufdialog überhaupt zu öffnen.

// Zusätzlich zum Vereinsabo gibt es das persönliche Basis-Abo jedes Mitglieds.
// Dafür braucht RevenueCat ein drittes Offering "member" mit Monthly- und
// Annual-Package; die Produkt-IDs müssen member_monthly und member_yearly heißen.
//
// Wichtig: RevenueCat kennt immer nur EINE Nutzerkennung gleichzeitig. Beim
// Vereinsabo ist das die Vereins-ID, beim persönlichen Abo die Profil-ID —
// zwischen beiden wird per logIn umgeschaltet. Der Webhook unterscheidet
// anschließend anhand des Produkt-Präfixes, in welche Tabelle der Kauf gehört.

let configuredForUser: string | null = null;

export function nativePurchasesSupported() {
  if (typeof window === "undefined") return false;
  return Capacitor.isNativePlatform() && ["ios", "android"].includes(Capacitor.getPlatform());
}

function currentApiKey() {
  const platform = Capacitor.getPlatform();
  if (platform === "ios") return process.env.NEXT_PUBLIC_REVENUECAT_IOS_KEY || "";
  if (platform === "android") return process.env.NEXT_PUBLIC_REVENUECAT_ANDROID_KEY || "";
  return "";
}

export async function ensureRevenueCatConfigured(appUserId: string) {
  if (!nativePurchasesSupported() || !appUserId) return false;
  if (configuredForUser === appUserId) return true;
  const apiKey = currentApiKey();
  if (!apiKey) return false;
  if (configuredForUser === null) {
    await Purchases.configure({ apiKey, appUserID: appUserId });
    if (process.env.NODE_ENV !== "production") await Purchases.setLogLevel({ level: LOG_LEVEL.DEBUG });
  } else {
    // Bereits eingerichtet, aber auf eine andere Kennung — umschalten statt neu einrichten.
    await Purchases.logIn({ appUserID: appUserId });
  }
  configuredForUser = appUserId;
  return true;
}

export type ClubTierOfferings = {
  basic: { monthly: PurchasesPackage | null; yearly: PurchasesPackage | null };
  premium: { monthly: PurchasesPackage | null; yearly: PurchasesPackage | null };
};

export async function fetchTierOfferings(clubId: string): Promise<ClubTierOfferings | null> {
  const ready = await ensureRevenueCatConfigured(clubId);
  if (!ready) return null;
  const offerings = await Purchases.getOfferings();
  const basicOffering = offerings.all["basic"] || null;
  const premiumOffering = offerings.all["premium"] || null;
  return {
    basic: { monthly: basicOffering?.monthly || null, yearly: basicOffering?.annual || null },
    premium: { monthly: premiumOffering?.monthly || null, yearly: premiumOffering?.annual || null },
  };
}

/* Persönliches Basis-Abo: läuft auf die Profil-ID, nicht auf den Verein. */
export type MemberOffering = { monthly: PurchasesPackage | null; yearly: PurchasesPackage | null };

export async function fetchMemberOffering(profileId: string): Promise<MemberOffering | null> {
  const ready = await ensureRevenueCatConfigured(profileId);
  if (!ready) return null;
  const offerings = await Purchases.getOfferings();
  const memberOffering = offerings.all["member"] || null;
  return { monthly: memberOffering?.monthly || null, yearly: memberOffering?.annual || null };
}

export async function purchaseTierPackage(pkg: PurchasesPackage) {
  const { customerInfo } = await Purchases.purchasePackage({ aPackage: pkg });
  return customerInfo;
}

export async function restoreNativePurchases() {
  const { customerInfo } = await Purchases.restorePurchases();
  return customerInfo;
}
