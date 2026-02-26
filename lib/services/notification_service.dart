import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart'; // Web check

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // --- PROFESSIONAL CHANNEL SETUP ---
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important alerts like chat messages',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  static Future<void> initialize() async {
    // 1. Permissions Request
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('❌ User declined permission');
      return;
    }

    // 2. Setup Icons & Settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ✅ FIX: Yahan 'present' nahi 'request' aata hai
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("🔔 Notification Clicked: ${response.payload}");
      },
    );

    // 3. Create Channel (Android Only)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // 4. Foreground Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("📩 Foreground Message: ${message.notification?.title}");

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              styleInformation: BigTextStyleInformation(''),
            ),
            // ✅ FIX: 'present' yahan aata hai (Showing ke waqt)
            iOS: const DarwinNotificationDetails(
              presentSound: true,
              presentAlert: true,
              presentBadge: true,
            ),
          ),
        );
      }
    });
  }
}
