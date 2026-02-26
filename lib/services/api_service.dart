import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class ApiService {
  static const String baseUrl = "https://amirdev.site/backend/api/";

  // Universal Headers for all requests
  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  // 1. STUDENT: Submit Complaint
  static Future<Map<String, dynamic>> submitComplaint(
    String roll,
    String type,
    String desc, {
    String? driveLink,
    String? base64Image,
  }) async {
    try {
      Map<String, dynamic> requestData = {
        "roll_number": roll,
        "complaint_type": type,
        "description": desc,
        "drive_link": driveLink ?? "No image",
        "image_data": base64Image,
      };

      final response = await http
          .post(
            Uri.parse("${baseUrl}submit_complaint.php"),
            headers: _headers,
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error': 'Server Error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection Failed: $e'};
    }
  }

  // 2. RESOLVER: Fetch Assigned Tasks
  static Future<List<dynamic>> fetchAssignedTasks(String resolverId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              "${baseUrl}get_resolver_tasks.php?resolver_id=$resolverId",
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) return body['tasks'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 3. RESOLVER: Resolve Complaint Action
  static Future<String> resolveComplaint(
    dynamic id, {
    String remarks = "Resolved",
    String? proofLink,
  }) async {
    try {
      Map<String, dynamic> data = {
        "detail_id": id.toString(),
        "status": "Resolved",
        "remarks": remarks,
        "resolution_image": proofLink ?? "No Image",
      };

      final response = await http
          .post(
            Uri.parse("${baseUrl}update_status.php"),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true)
          return "Success";
        else
          return body['message'] ?? "Error";
      }
      return "Server Error";
    } catch (e) {
      return "Network Error";
    }
  }

  // 4. STUDENT: Submit Feedback & Rating
  static Future<Map<String, dynamic>> submitFeedback(
    String id,
    int rating,
    String feedback,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("${baseUrl}submit_feedback.php"),
            headers: _headers,
            body: jsonEncode({
              "detail_id": id,
              "rating": rating,
              "feedback": feedback,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "success": false,
          "message": "Server Error: ${response.statusCode}",
        };
      }
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  // 5. STUDENT: Re-open Complaint Logic
  static Future<bool> reopenComplaint(String id, String reason) async {
    try {
      final response = await http
          .post(
            Uri.parse("${baseUrl}reopen_complaint.php"),
            headers: _headers,
            body: jsonEncode({"detail_id": id, "reason": reason}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 6. SUPER ADMIN: Fetch University-wide Master Stats (Fixes 0 Values)
  static Future<Map<String, dynamic>> fetchAdminMasterStats() async {
    try {
      final response = await http
          .get(Uri.parse("${baseUrl}get_admin_stats.php"), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        "success": false,
        "total": 0,
        "pending": 0,
        "resolved": 0,
        "departments": [],
      };
    } catch (e) {
      print("FetchStats Error: $e");
      return {
        "success": false,
        "total": 0,
        "pending": 0,
        "resolved": 0,
        "departments": [],
      };
    }
  }

  // 7. SUPER ADMIN: Get List of All Active Resolvers
  static Future<List<dynamic>> getAllResolvers() async {
    try {
      final response = await http
          .get(Uri.parse("${baseUrl}get_all_resolvers.php"), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['resolvers'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // 8. SUPER ADMIN: Add/Register New Resolver Staff
  static Future<Map<String, dynamic>> addResolver(
    String name,
    String email,
    String dept,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("${baseUrl}add_resolver.php"),
            headers: _headers,
            body: jsonEncode({
              "name": name,
              "email": email,
              "department": dept,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        "success": false,
        "message": "Server Error: ${response.statusCode}",
      };
    } catch (e) {
      return {"success": false, "message": "Connection Failed: $e"};
    }
  }

  // 9. SUPER ADMIN: Delete/Remove Resolver from System
  static Future<bool> deleteResolver(String id) async {
    try {
      final response = await http
          .post(
            Uri.parse("${baseUrl}delete_resolver.php"),
            headers: _headers,
            body: jsonEncode({"id": id}),
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      return body['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // 10. SUPER ADMIN: Update Assignment Mapping (Logic Rules)
  static Future<Map<String, dynamic>> updateAssignment(
    String type,
    String email,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("${baseUrl}update_assignment.php"),
            headers: _headers,
            body: jsonEncode({"complaint_type": type, "new_email": email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {"success": false, "message": "Server Error"};
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }
}
