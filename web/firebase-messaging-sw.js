importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

// --- AAPKI KEYS (Jo aapne di hain) ---
firebase.initializeApp({
  apiKey: "AIzaSyDpiZMMdAUKwhLQREWlKAwCVsi7ikF6rCU",
  authDomain: "complaintapp-21969.firebaseapp.com", // Ye Project ID se banta hai
  projectId: "complaintapp-21969",
  storageBucket: "complaintapp-21969.firebasestorage.app",
  messagingSenderId: "399417625561",
  appId: "1:399417625561:android:267b0d588b28237508e7c8"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // Icon folder check kar lena
  };

  return self.registration.showNotification(notificationTitle,
    notificationOptions);
});