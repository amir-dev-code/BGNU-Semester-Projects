import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = "https://amirdev.site/api";

  // Professional Login: Sirf registered users ke liye
  static Future<Map<String, dynamic>> login(
    String emailOrPhone,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit_login.php'),
        body: {'email': emailOrPhone, 'password': password},
      );

      if (response.statusCode == 200) {
        // String response ko JSON map mein convert karna
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // CRITICAL CHECK: Database ka 'success' flag check karein
        if (responseData['success'] == true) {
          return responseData; // Login Success
        } else {
          // Database ne mana kar diya (Wrong Email/Password)
          return {
            'success': false,
            'message': responseData['message'] ?? 'Invalid Credentials',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Server Error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network Error: $e'};
    }
  }

  // Signup Function consistent naming ke saath
  static Future<Map<String, dynamic>> signup(
    String fullName,
    String cellNo,
    String email,
    String password,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/submit_registration.php').replace(
        queryParameters: {
          'full_name': fullName,
          'cellno': cellNo,
          'email': email,
          'password': password,
        },
      );
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Registration Failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network Error: $e'};
    }
  }
}
