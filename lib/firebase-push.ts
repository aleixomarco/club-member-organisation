import { initializeApp, getApps } from "firebase/app";
import { getMessaging, getToken, isSupported } from "firebase/messaging";
import { supabase } from "@/lib/supabase";
import { Capacitor, type PluginListenerHandle } from "@capacitor/core";
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

/* Welcher Token GEHOERT DIESEM GERAET.
 *
 * Beim Abmelden muss genau eine Zeile aus push_subscriptions verschwinden -
 * die dieses Geraets. Dafuer braucht es den Token. Firebase liefert ihn
 * normalerweise auf Zuruf, aber ausgerechnet im haeufigsten Abmeldefall nicht:
 * Wer die Benachrichtigungen zuerst in den iOS-Einstellungen abschaltet und
 * den Schalter danach in der App umlegt, bekommt von getToken() keinen Token
 * mehr, weil die Erlaubnis schon weg ist.
 *
 * Vorher fiel der Code dann darauf zurueck, ALLE Zeilen des Mitglieds zu
 * loeschen. Wer die App auf iPhone und iPad hatte und sie auf dem iPad
 * abschaltete, bekam ab da auch auf dem iPhone nichts mehr - ohne jeden
 * Hinweis, dass etwas passiert ist.
 *
 * Deshalb merkt sich jedes Geraet seinen Token selbst. Der Schluessel traegt
 * die Mitgliedschaft, weil auf einem Geraet nacheinander verschiedene Konten
 * angemeldet sein koennen.
 *
 * Alle Zugriffe in try/catch: In einem privaten Fenster und in manchen
 * WebViews wirft schon das blosse Lesen von localStorage. Ein Merker, der
 * fehlschlagen darf, ist besser als einer, der die Abmeldung mitreisst. */
const tokenSchluessel = (membershipId: string) => `cmo.push.token.${membershipId}`;

function tokenMerken(membershipId: string, token: string) {
  try { window.localStorage.setItem(tokenSchluessel(membershipId), token); } catch { /* egal */ }
}

function gemerkterToken(membershipId: string): string {
  try { return window.localStorage.getItem(tokenSchluessel(membershipId)) || ""; } catch { return ""; }
}

function merkerVergessen(membershipId: string) {
  try { window.localStorage.removeItem(tokenSchluessel(membershipId)); } catch { /* egal */ }
}

async function tokenSpeichern(membershipId: string, token: string) {
  if (!supabase) return false;
  const plattform = Capacitor.getPlatform();
  const { error } = await supabase
    .from("push_subscriptions")
    .upsert(
      { membership_id: membershipId, fcm_token: token, platform: plattform, last_seen_at: new Date().toISOString() },
      { onConflict: "membership_id,fcm_token" }
    );
  if (!error) tokenMerken(membershipId, token);
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

/* grund traegt die Originalmeldung der Laufzeitumgebung mit.
   Bisher endete jeder Fehler im nativen Zweig als blosses "setup_failed" -
   die Oberflaeche sagte "Push konnte nicht eingerichtet werden" und sonst
   nichts. Damit laesst sich nicht arbeiten: Ob das Plugin fehlt, die
   Erlaubnis verweigert wurde oder Firebase keinen Token liefert, sind drei
   voellig verschiedene Ursachen mit drei verschiedenen Loesungen. */
export type EnablePushResult = { token?: string; error?: string; grund?: string };

/* Den Token stillschweigend auffrischen - bei jedem Start.
 *
 * WARUM DAS NOETIG IST
 * Bisher wurde der Token NUR geholt, wenn jemand im Profil auf "Push
 * aktivieren" tippte. Das hat zwei Folgen, und beide sind still:
 *
 * 1. Wer die Erlaubnis laengst erteilt hat, aber den Schalter nie gefunden
 *    hat, bekommt nie einen Push. Die App fragt nicht nach.
 * 2. FCM-Token bleiben nicht. Sie wechseln bei einer Neuinstallation, beim
 *    Zurueckspielen eines Backups, nach langer Untaetigkeit - und mit jedem
 *    App-Update kann ein neuer kommen. Der gespeicherte Token ist dann tot,
 *    der Versand laeuft ins Leere, und niemand merkt es: In der Glocke steht
 *    die Meldung ja, sie kommt nur nicht auf dem Sperrbildschirm an.
 *
 * Genau das ist passiert: Ein abgesagtes Spiel erzeugte die Benachrichtigung
 * korrekt, aber push_subscriptions war leer - kein einziges Geraet.
 *
 * WAS DIESE FUNKTION TUT UND WAS NICHT
 * Sie fragt NIE nach der Erlaubnis. Ist sie nicht erteilt, tut sie nichts -
 * ein Erlaubnisdialog beim Start ist eine Zumutung und wird weggeklickt.
 * Ist sie erteilt, holt sie den aktuellen Token und schreibt ihn weg. Damit
 * heilt sich ein gewechselter Token beim naechsten Oeffnen von selbst.
 */
export async function pushTokenAuffrischen(membershipId: string): Promise<boolean> {
  if (typeof window === "undefined" || !supabase || !membershipId) return false;

  try {
    if (imGeraet()) {
      const stand = await FirebaseMessaging.checkPermissions();
      if (stand.receive !== "granted") return false;
      const { token } = await FirebaseMessaging.getToken();
      if (!token) return false;
      return await tokenSpeichern(membershipId, token);
    }

    /* Im Browser dasselbe, nur ueber den Service Worker. Notification.permission
       zu LESEN oeffnet keinen Dialog - im Gegensatz zu requestPermission(). */
    if (!("Notification" in window) || !("serviceWorker" in navigator)) return false;
    if (Notification.permission !== "granted") return false;
    if (!(await isSupported().catch(() => false))) return false;

    const registration = await navigator.serviceWorker.getRegistration("/firebase-messaging-sw.js")
      ?? await navigator.serviceWorker.register("/firebase-messaging-sw.js");
    const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
    const token = await getToken(getMessaging(app), { vapidKey: VAPID_KEY, serviceWorkerRegistration: registration });
    if (!token) return false;

    const ua = navigator.userAgent || "";
    const platform = /iphone|ipad|ipod/i.test(ua) ? "ios" : /android/i.test(ua) ? "android" : "web";
    const { error } = await supabase.from("push_subscriptions").upsert(
      { membership_id: membershipId, fcm_token: token, platform, last_seen_at: new Date().toISOString() },
      { onConflict: "membership_id,fcm_token" },
    );
    if (!error) tokenMerken(membershipId, token);
    return !error;
  } catch {
    /* Still. Das hier laeuft im Hintergrund beim Start; ein Fehler darf den
       Start nicht stoeren und niemanden mit einer Meldung behelligen. */
    return false;
  }
}

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
    } catch (fehler) {
      return { error: "setup_failed", grund: String((fehler as Error)?.message ?? fehler) };
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

    /* Ohne Datenbank gibt es keine Zeile zu schreiben. Vorher warf die naechste
       Zeile hier eine Ausnahme, die der umgebende catch zu "setup_failed"
       machte - eine irrefuehrende Meldung fuer einen Betrieb ohne Datenbank. */
    if (!supabase) return { error: "save_failed" };
    const { error } = await supabase
      .from("push_subscriptions")
      .upsert(
        { membership_id: membershipId, fcm_token: token, platform, last_seen_at: new Date().toISOString() },
        { onConflict: "membership_id,fcm_token" }
      );
    if (error) return { error: "save_failed" };
    tokenMerken(membershipId, token);

    return { token };
  } catch (err) {
    return { error: "setup_failed" };
  }
}

/* Eine angetippte Mitteilung - wohin sie fuehren soll.
 *
 * Die Felder kommen aus push-versenden (FCM data) und sind dort immer
 * Zeichenketten; ein fehlender Wert ist "". Aeltere Pushes - verschickt, bevor
 * push-versenden das Ziel mitschickte - haben nur notification_id; dann laedt
 * die App die Zeile nach und liest das Ziel von dort. */
export type MeldungsTipp = { notification_id: string; club_id: string; ziel_art: string; ziel_id: string };

const TIPP_EREIGNIS = "cmo-meldung-angetippt";

function tippAusDaten(daten: unknown): MeldungsTipp | null {
  if (!daten || typeof daten !== "object") return null;
  const d = daten as Record<string, unknown>;
  const text = (x: unknown) => (typeof x === "string" ? x : "");
  const tipp = { notification_id: text(d.notification_id), club_id: text(d.club_id), ziel_art: text(d.ziel_art), ziel_id: text(d.ziel_id) };
  return tipp.notification_id || tipp.ziel_art ? tipp : null;
}

/* Meldet jeden Tipp auf eine Mitteilung - in der App wie im Browser.
 *
 * NATIV: "notificationActionPerformed" aus @capacitor-firebase/messaging.
 * Das Plugin haelt das Ereignis fest, bis jemand zuhoert (iOS
 * retainUntilConsumed, Android notifyListeners(..., true)). Ein Tipp, der die
 * App erst STARTET, geht deshalb nicht verloren, auch wenn dieser Zuhoerer
 * erst nach dem ersten Bild angemeldet wird. Die App merkt sich den Tipp und
 * springt, sobald jemand angemeldet und der Verein geladen ist.
 *
 * BROWSER: Der Service Worker schickt die Kennung als Nachricht, wenn die App
 * schon offen war (sonst oeffnet er sie mit ?meldung=...). Dazu kommt das
 * Fensterereignis aus listenForForegroundMessages.
 *
 * Gibt eine Funktion zum Abmelden zurueck - fuer das Aufraeumen im Effekt. */
export function meldungsTippsAbonnieren(beiTipp: (tipp: MeldungsTipp) => void): () => void {
  if (typeof window === "undefined") return () => {};

  if (imGeraet()) {
    let griff: PluginListenerHandle | null = null;
    let beendet = false;
    FirebaseMessaging.addListener("notificationActionPerformed", (ereignis) => {
      const tipp = tippAusDaten(ereignis?.notification?.data);
      if (tipp) beiTipp(tipp);
    }).then((g) => { if (beendet) g.remove(); else griff = g; }).catch(() => {});
    return () => { beendet = true; griff?.remove(); };
  }

  const ausFenster = (ereignis: Event) => {
    const tipp = tippAusDaten((ereignis as CustomEvent).detail);
    if (tipp) beiTipp(tipp);
  };
  window.addEventListener(TIPP_EREIGNIS, ausFenster);

  const container = "serviceWorker" in navigator ? navigator.serviceWorker : null;
  const ausWorker = (ereignis: MessageEvent) => {
    const d = ereignis.data;
    if (!d || typeof d !== "object" || d.typ !== TIPP_EREIGNIS) return;
    const tipp = tippAusDaten(d);
    if (tipp) beiTipp(tipp);
  };
  if (container) {
    container.addEventListener("message", ausWorker);
    /* Mit addEventListener (statt onmessage) stellt der Browser Nachrichten
       erst nach startMessages() zu - sonst bliebe ein Tipp in der Warteschlange. */
    try { container.startMessages(); } catch { /* aeltere Browser: dort ohnehin automatisch */ }
  }
  return () => {
    window.removeEventListener(TIPP_EREIGNIS, ausFenster);
    container?.removeEventListener("message", ausWorker);
  };
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
          /* Auch die Mitteilung, die die offene Seite selbst zeigt, fuehrt
             beim Antippen an ihr Ziel. Sie geht als Fensterereignis an
             meldungsTippsAbonnieren - derselbe Weg wie ein Tipp aus dem
             Service Worker, damit es nur EINE Stelle gibt, die springt. */
          const mitteilung = new Notification(title, { body });
          mitteilung.onclick = () => {
            window.focus();
            mitteilung.close();
            window.dispatchEvent(new CustomEvent(TIPP_EREIGNIS, { detail: payload.data || {} }));
          };
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
         man den Token nicht mehr.
         Liefert Firebase keinen - der Regelfall, wenn die Erlaubnis in den
         iOS-Einstellungen schon entzogen wurde -, greift der eigene Merker.
         Erst wenn auch der leer ist, bleibt nichts als alle Zeilen zu
         loeschen; dann ist dieses Geraet das einzige, von dem wir je etwas
         wussten. */
      const { token } = await FirebaseMessaging.getToken().catch(() => ({ token: "" }));
      const meiner = token || gemerkterToken(membershipId);
      if (supabase) {
        if (meiner) {
          await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId).eq("fcm_token", meiner);
        } else {
          await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId);
        }
      }
      merkerVergessen(membershipId);
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
    const meiner = token || gemerkterToken(membershipId);
    if (supabase) {
      if (meiner) {
        await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId).eq("fcm_token", meiner);
      } else {
        await supabase.from("push_subscriptions").delete().eq("membership_id", membershipId);
      }
    }
    merkerVergessen(membershipId);
    return { success: true };
  } catch (err) {
    return { error: "failed" };
  }
}
