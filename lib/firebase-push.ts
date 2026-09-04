import { initializeApp, getApps } from "firebase/app";
import { getMessaging, getToken, isSupported } from "firebase/messaging";
import { supabase } from "@/lib/supabase";
import { Capacitor } from "@capacitor/core";
import { FirebaseMessaging } from "@capacitor-firebase/messaging";

/* Zwei Wege zum selben Ziel - und bis zum 04.09.2026 gab es nur den falschen.
 *
 * Der Code hier war reiner Firebase-WEB-Push: Service Worker plus VAPID-
 * Schluessel. Das funktioniert im Browser, aber NICHT in der WKWebView einer
 * iOS-App - isSupported() liefert dort false, und die Funktion brach gleich in
 * der ersten Zeile ab. In der App aus dem App Store konnte sich also kein
 * einziges Geraet registrieren. Passend dazu war der Schalter im Profil hinter
 * !Capacitor.isNativePlatform() versteckt, also ausgerechnet dort unsichtbar,
 * wo die echten Nutzer sind.
 *
 * Nativ laeuft es ueber @capacitor-firebase/messaging: Das Plugin holt die
 * Erlaubnis beim System, nimmt den Geraetetoken von Apple entgegen (den der
 * AppDelegate weiterreicht) und tauscht ihn gegen einen FCM-Token. Derselbe
 * Token-Typ wie im Web - die Tabelle push_subscriptions und der spaetere
 * Versender kennen den Unterschied also nicht.
 */
const imGeraet = () => Capacitor.isNativePlatform();

async function tokenSpeichern(membershipId: string, token: string) {
  if (!supabase) return false;
  const plattform = Capacitor.getPlatform();
  const { error } = await supabase
    .from("push_subscriptions")
    .upsert(
      { membership_id: membershipId, fcm_token: token, platform: plattform, last_seen_at: new Date().toISOString() },
      { onConflict: "membership_id,fcm_token" }
    );
  return !error;
}

const firebaseConfig = {
  apiKey: "AIzaSyAj_dLdMdXCk-T5hO9TXMcIakPSych-mb0",
  authDomain: "club-member-organisation-acbf3.firebaseapp.com",
  projectId: "club-member-organisation-acbf3",
  storageBucket: "club-member-organisation-acbf3.firebasestorage.app",
  messagingSenderId: "852910274539",
  appId: "1:852910274539:web:bf5bb6eebd3fc61ffecbae",
};

const VAPID_KEY = "BJUz40s_jQFx67i9o2h-hkLyFMY9Q9hWWxUekLYavTcz9LImbdHqPYkfa-OCfPC7safypanAE-8gYv2UzSyElhI";

export type EnablePushResult = { token?: string; error?: string };

export async function enablePushNotifications(membershipId: string): Promise<EnablePushResult> {
  if (typeof window === "undefined") return { error: "not_browser" };

  if (imGeraet()) {
    try {
      /* checkPermissions zuerst: Hat der Nutzer die Erlaubnis in den
         iOS-Einstellungen dauerhaft verweigert, oeffnet requestPermissions
         keinen Dialog mehr und liefert stumm "denied". Dann soll die App das
         auch sagen koennen, statt scheinbar nichts zu tun. */
      let stand = await FirebaseMessaging.checkPermissions();
      if (stand.receive === "prompt" || stand.receive === "prompt-with-rationale") {
        stand = await FirebaseMessaging.requestPermissions();
      }
      if (stand.receive !== "granted") return { error: "denied" };

      const { token } = await FirebaseMessaging.getToken();
      if (!token) return { error: "no_token" };
      if (!(await tokenSpeichern(membershipId, token))) return { error: "save_failed" };
      return { token };
    } catch {
      return { error: "setup_failed" };
    }
  }

  if (!("Notification" in window) || !("serviceWorker" in navigator)) return { error: "unsupported" };
  const supported = await isSupported().catch(() => false);
  if (!supported) return { error: "unsupported" };

  const permission = await Notification.requestPermission();
  if (permission !== "granted") return { error: "denied" };

  try {
    const registration = await navigator.serviceWorker.register("/firebase-messaging-sw.js");
    const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
    const messaging = getMessaging(app);
    const token = await getToken(messaging, { vapidKey: VAPID_KEY, serviceWorkerRegistration: registration });
    if (!token) return { error: "no_token" };

    const ua = navigator.userAgent || "";
    const platform = /iphone|ipad|ipod/i.test(ua) ? "ios" : /android/i.test(ua) ? "android" : "web";

    const { error } = await supabase
      .from("push_subscriptions")
      .upsert(
        { membership_id: membershipId, fcm_token: token, platform, last_seen_at: new Date().toISOString() },
        { onConflict: "membership_id,fcm_token" }
      );
    if (error) return { error: "save_failed" };

    return { token };
  } catch (err) {
    return { error: "setup_failed" };
  }
}

export function listenForForegroundMessages() {
  if (typeof window === "undefined") return;

  if (imGeraet()) {
    /* iOS zeigt eine Mitteilung NICHT von selbst an, solange die App im
       Vordergrund ist. Ohne diesen Zuhoerer bekaeme man sie nur, wenn die App
       geschlossen ist - was beim Testen zuverlaessig fuer Verwirrung sorgt. */
    FirebaseMessaging.addListener("notificationReceived", () => {}).catch(() => {});
    return;
  }

  isSupported().then((supported) => {
    if (!supported) return;
    const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
    const messaging = getMessaging(app);
    import("firebase/messaging").then(({ onMessage }) => {
      onMessage(messaging, (payload) => {
        const title = payload.notification?.title || "CMO";
        const body = payload.notification?.body || "";
        if (Notification.permission === "granted") {
          new Notification(title, { body });
        }
      });
    });
  });
}

export async function disablePushNotifications(membershipId: string): Promise<{ success?: boolean; error?: string }> {
  if (typeof window === "undefined") return { error: "not_browser" };

  if (imGeraet()) {
    try {
      /* Erst die Zeile loeschen, dann den Token wegwerfen. Andersherum kennt
         man den Token nicht mehr und muesste alle Zeilen dieses Mitglieds
         loeschen - damit floege auch die Anmeldung eines zweiten Geraets raus. */
      const { token } = await FirebaseMessaging.getToken().catch(() => ({ token: "" }));
      if (supabase) {
        if (token) {
          await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId).eq("fcm_token", token);
        } else {
          await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId);
        }
      }
      await FirebaseMessaging.deleteToken().catch(() => {});
      return { success: true };
    } catch {
      return { error: "failed" };
    }
  }

  try {
    const supported = await isSupported().catch(() => false);
    if (!supported) return { error: "unsupported" };
    const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
    const messaging = getMessaging(app);
    const registration = await navigator.serviceWorker.getRegistration("/firebase-messaging-sw.js");
    const token = await getToken(messaging, { vapidKey: VAPID_KEY, serviceWorkerRegistration: registration || undefined }).catch(() => null);
    const { deleteToken } = await import("firebase/messaging");
    await deleteToken(messaging).catch(() => {});
    if (token) {
      await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId).eq("fcm_token", token);
    } else {
      await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId);
    }
    return { success: true };
  } catch (err) {
    return { error: "failed" };
  }
}
