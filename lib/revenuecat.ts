"use client";
import { Capacitor } from "@capacitor/core";
import { Purchases, LOG_LEVEL, type PurchasesPackage } from "@revenuecat/purchases-capacitor";

// Native In-App-Käufe (iOS/Android) über RevenueCat.
// Web bleibt bei PayPal (siehe SubscriptionPanel in app/page.tsx) — Apple und
// Google verlangen für digitale Abos innerhalb der nativen App zwingend den
// In-App-Kauf (Apple Guideline 3.1.1, Google Play Billing-Pflicht analog).
//
// Erwartete Einrichtung im RevenueCat-Dashboard (fehlt sie, liefern die
// fetch*-Funktionen leere Pakete — siehe docs/revenuecat.md):
//   - Drei Offerings mit den Identifiern "basic", "premium" und "member".
//   - Jedes Offering hat ein "Monthly"- und ein "Annual"-Package.
//   - Die Produkt-IDs in App Store Connect / Play Console müssen exakt den
//     subscription_plans.code-Werten in Supabase entsprechen:
//     club_basic_monthly, club_basic_yearly, club_premium_monthly,
//     club_premium_yearly, member_monthly, member_yearly.
//
// Der Freischalt-Status kommt NICHT von hier, sondern aus Supabase
// (club_subscription_tier() bzw. member_has_access()). RevenueCats Webhook
// schreibt jeden Kauf in club_subscriptions bzw. user_subscriptions, genau wie
// der PayPal-Webhook. Dieses Modul öffnet nur den nativen Kaufdialog.

/* ------------------------------------------------------------------ */
/* Nutzerkennung                                                       */
/*                                                                     */
/* RevenueCat kennt immer nur EINE Kennung gleichzeitig. Diese App hat */
/* aber zwei Käufer-Arten: das Vereinsabo läuft auf die Vereins-ID,    */
/* das persönliche Basis-Abo auf die Profil-ID. Der Webhook ordnet den */
/* Kauf später anhand des Produkt-Präfixes der richtigen Tabelle zu —  */
/* dafür MUSS beim Kauf die passende Kennung aktiv sein.               */
/*                                                                     */
/* Deshalb nimmt hier jede kaufende Funktion die Kennung ausdrücklich  */
/* entgegen und setzt sie unmittelbar davor. Früher hing es davon ab,  */
/* welche Angebote zuletzt geladen wurden — dann konnte ein Vereinskauf*/
/* auf der Profil-ID landen und der Webhook hätte eine Profil-ID als   */
/* club_id geschrieben.                                                */
/* ------------------------------------------------------------------ */

let sdkConfigured = false;
let currentAppUserId: string | null = null;

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
  const apiKey = currentApiKey();
  if (!apiKey) return false;

  // configure() darf pro Prozess nur einmal laufen. Jeder weitere Wechsel der
  // Kennung geht über logIn() — auch nach einem logOut(), denn das SDK bleibt
  // dann konfiguriert und arbeitet nur anonym weiter.
  if (!sdkConfigured) {
    await Purchases.configure({ apiKey, appUserID: appUserId });
    if (process.env.NODE_ENV !== "production") await Purchases.setLogLevel({ level: LOG_LEVEL.DEBUG });
    sdkConfigured = true;
    currentAppUserId = appUserId;
    return true;
  }
  if (currentAppUserId !== appUserId) {
    await Purchases.logIn({ appUserID: appUserId });
    currentAppUserId = appUserId;
  }
  return true;
}

/* Bei der Abmeldung trennen, sonst erbt die nächste Anmeldung auf demselben
   Gerät die Kennung der vorherigen — und deren Käufe. */
export async function logOutRevenueCat() {
  if (!sdkConfigured || currentAppUserId === null) return;
  try {
    await Purchases.logOut();
  } catch {
    // Wirft, wenn bereits anonym. Für uns nicht unterscheidbar und folgenlos.
  }
  currentAppUserId = null;
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

const NOT_AVAILABLE = "In-App-Käufe stehen auf diesem Gerät nicht zur Verfügung.";

/* ownerId ist die Kennung, auf die der Kauf gebucht wird: die Vereins-ID beim
   Vereinsabo, die Profil-ID beim persönlichen Zugang. */
export async function purchasePackageAs(ownerId: string, pkg: PurchasesPackage) {
  const ready = await ensureRevenueCatConfigured(ownerId);
  if (!ready) throw new Error(NOT_AVAILABLE);
  const { customerInfo } = await Purchases.purchasePackage({ aPackage: pkg });
  return customerInfo;
}

/* Wiederherstellen hängt die Käufe des Store-Kontos an die AKTIVE Kennung.
   Deshalb muss auch hier ausdrücklich stehen, um wessen Käufe es geht —
   sonst landet ein wiederhergestelltes Vereinsabo auf der Profil-ID. */
export async function restorePurchasesAs(ownerId: string) {
  const ready = await ensureRevenueCatConfigured(ownerId);
  if (!ready) throw new Error(NOT_AVAILABLE);
  const { customerInfo } = await Purchases.restorePurchases();
  return customerInfo;
}
