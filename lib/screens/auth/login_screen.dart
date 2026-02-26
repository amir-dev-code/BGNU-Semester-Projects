import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../dashboard_screen.dart';
import 'signup_screen.dart';
import '../resolver_dashboard_screen.dart';
import '../super_admin_dashboard.dart'; // ✅ Import for Admin Dashboard
import 'dart:convert';

// --- IMPORTS FOR NOTIFICATIONS ---
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
// -----------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- TOKEN SYNC FUNCTION ---
  Future<void> _sendTokenToServer(String email) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        print("🔔 FCM Token Generated: $token");

        var url = Uri.parse(
          "https://amirdev.site/backend/api/update_fcm_token.php",
        );

        await http.post(url, body: {"user_email": email, "token": token});
        print("✅ Token synced with Server successfully!");
      }
    } catch (e) {
      print("❌ Error sending token: $e");
    }
  }
  // -----------------------------

  void _login() async {
    // 1. Check Empty Fields
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    // 2. KEYBOARD BAND KARO (Fixes Assertion Error)
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    // 3. Login API Call
    final result = await AuthService.login(
      _emailController.text,
      _passwordController.text,
    );

    // Agar widget destroy ho chuka ha to setState na karein (Safety)
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      String userEmail = _emailController.text.trim().toLowerCase();
      String userRole = (result['role'] ?? 'student')
          .toString()
          .toLowerCase()
          .trim();

      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', userRole);
      await prefs.setString('userEmail', userEmail);
      await prefs.setString('userName', result['full_name'] ?? 'User');

      // Sync Token
      _sendTokenToServer(userEmail);

      Map<String, dynamic> userData = {
        'name': result['full_name'] ?? 'User',
        'identifier': userEmail,
        'role': userRole,
      };

      // 4. Navigation (Safe Check)
      if (!mounted) return;

      // 🔥 FIXED NAVIGATION LOGIC: First check if email is admin
      if (userEmail == 'admin@university.com') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminDashboard()),
        );
      }
      // Then check for other roles
      else if (userRole == 'resolver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResolverDashboard(resolverId: userEmail),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(userData: userData),
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? "Login Failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade900, Colors.blue.shade500],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school, size: 80, color: Colors.blue),
                    const SizedBox(height: 20),
                    const Text(
                      "Portal Login",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person),
                        labelText: "Email or Phone",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        labelText: "Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "LOGIN",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                      child: const Text("New Student? Create Account"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
