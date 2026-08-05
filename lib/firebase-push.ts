import { initializeApp, getApps } from "firebase/app";
import { getMessaging, getToken, isSupported } from "firebase/messaging";
import { supabase } from "@/lib/supabase";

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
