importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js");

/* Eine angetippte Mitteilung fuehrt in die App - an die richtige Stelle.
 *
 * Bisher gab es hier keinen Zuhoerer fuer den Tipp: Die Mitteilung ging auf
 * und wieder zu, und bestenfalls oeffnete der Browser irgendein Fenster.
 *
 * WARUM NUR DIE KENNUNG IN DIE ADRESSE
 * In der Adresse steht ausschliesslich notification_id - kein Titel, kein
 * Text, kein Name. Adressen landen im Verlauf, in Protokollen und beim
 * Teilen; die Kennung allein verraet nichts. Die App laedt die Zeile nach der
 * Anmeldung selbst, und die Datenbank gibt sie nur ihrem Empfaenger heraus.
 *
 * WARUM DIESER ZUHOERER VOR firebase.messaging() STEHT
 * Firebase haengt beim Anlegen seinen eigenen notificationclick-Zuhoerer an.
 * Fuer Mitteilungen, die es selbst angezeigt hat, beendet er die Verarbeitung
 * (stopImmediatePropagation) und oeffnet nur einen fest hinterlegten Link -
 * den wir nicht setzen. Stuende unser Zuhoerer dahinter, kaeme er bei diesen
 * Mitteilungen nie zum Zug. Also zuerst unserer, und er nimmt beide Sorten:
 * die eigene aus onBackgroundMessage (data.notification_id) und die von
 * Firebase (data.FCM_MSG.data.notification_id). */
self.addEventListener("notificationclick", (ereignis) => {
  const daten = (ereignis.notification && ereignis.notification.data) || {};
  const vonFirebase = (daten.FCM_MSG && daten.FCM_MSG.data) || {};
  const kennung = String(daten.notification_id || vonFirebase.notification_id || "");
  ereignis.stopImmediatePropagation();
  ereignis.notification.close();

  ereignis.waitUntil((async () => {
    const fenster = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    const offen = fenster.find((f) => {
      try { return new URL(f.url).origin === self.location.origin; } catch (_) { return false; }
    });
    /* Ist die App schon offen, wird sie nach vorn geholt und bekommt die
       Kennung als Nachricht - ein Neuladen wuerfe weg, was dort gerade
       getippt wurde. */
    if (offen) {
      if (kennung) offen.postMessage({ typ: "cmo-meldung-angetippt", notification_id: kennung });
      if ("focus" in offen) await offen.focus();
      return;
    }
    const ziel = kennung ? `/?meldung=${encodeURIComponent(kennung)}` : "/";
    await self.clients.openWindow(ziel);
  })());
});

firebase.initializeApp({
  apiKey: "AIzaSyAj_dLdMdXCk-T5hO9TXMcIakPSych-mb0",
  authDomain: "club-member-organisation-acbf3.firebaseapp.com",
  projectId: "club-member-organisation-acbf3",
  storageBucket: "club-member-organisation-acbf3.firebasestorage.app",
  messagingSenderId: "852910274539",
  appId: "1:852910274539:web:bf5bb6eebd3fc61ffecbae",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || "CMO";
  const body = (payload.notification && payload.notification.body) || "";
  /* Die Kennung haengt an der Mitteilung, damit der Zuhoerer oben weiss,
     welche angetippt wurde. Mehr nicht: Titel und Text stehen ohnehin schon
     sichtbar auf dem Bildschirm. */
  const kennung = String((payload.data && payload.data.notification_id) || "");
  self.registration.showNotification(title, { body, data: { notification_id: kennung } });
});
