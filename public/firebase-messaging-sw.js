importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js");

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
  self.registration.showNotification(title, { body });
});
