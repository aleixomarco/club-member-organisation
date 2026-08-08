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

let configuredForClub: string | null = null;

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

export async function ensureRevenueCatConfigured(clubId: string) {
  if (!nativePurchasesSupported() || configuredForClub === clubId) return true;
  const apiKey = currentApiKey();
  if (!apiKey) return false;
  await Purchases.configure({ apiKey, appUserID: clubId });
  if (process.env.NODE_ENV !== "production") await Purchases.setLogLevel({ level: LOG_LEVEL.DEBUG });
  configuredForClub = clubId;
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

export async function purchaseTierPackage(pkg: PurchasesPackage) {
  const { customerInfo } = await Purchases.purchasePackage({ aPackage: pkg });
  return customerInfo;
}

export async function restoreNativePurchases() {
  const { customerInfo } = await Purchases.restorePurchases();
  return customerInfo;
}
