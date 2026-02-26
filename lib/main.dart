import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/resolver_dashboard_screen.dart';
import 'screens/super_admin_dashboard.dart';
import 'services/notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔥 Hive Import

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();

  // 🔥 Hive Initialization
  await Hive.initFlutter();
  await Hive.openBox('appBox');

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? role = prefs.getString('userRole');
  String? email = prefs.getString('userEmail');
  String? name = prefs.getString('userName');

  runApp(
    ComplaintApp(isLoggedIn: isLoggedIn, role: role, email: email, name: name),
  );
}

class ComplaintApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final String? email;
  final String? name;

  const ComplaintApp({
    super.key,
    required this.isLoggedIn,
    this.role,
    this.email,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    Widget homeWidget;

    if (isLoggedIn && email != null) {
      if (email == 'admin@university.com') {
        homeWidget = const SuperAdminDashboard();
      } else if (role == 'resolver') {
        homeWidget = ResolverDashboard(resolverId: email!);
      } else {
        homeWidget = DashboardScreen(
          userData: {
            'name': name ?? 'User',
            'identifier': email,
            'role': role ?? 'student',
          },
        );
      }
    } else {
      homeWidget = const LoginScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'University Complaint Portal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: homeWidget,
    );
  }
}
