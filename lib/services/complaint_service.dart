import 'dart:convert';
import 'package:http/http.dart' as http;

class ComplaintService {
  // [UPDATED] Base URL - Ab ye 'backend/api/' point kar raha hai
  static const String baseUrl = "https://amirdev.site/backend/api/";

  // --- [NEW FEATURE] FETCH FULL STUDENT HISTORY ---
  // Ye function nayi PHP file ko call karega aur Images + Remarks layega
  static Future<List<Map<String, dynamic>>> fetchStudentComplaints(
    String userId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse("${baseUrl}get_student_complaints.php?user_id=$userId"),
            headers: {"Accept": "application/json"},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // PHP se 'success' check karein
        if (body['success'] == true) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
      }
      return [];
    } catch (e) {
      print("Error fetching student complaints: $e");
      return [];
    }
  }

  // --- [OLD METHODS - KEPT FOR BACKUP] ---

  // Fetch complaints by roll number
  static Future<List<Map<String, dynamic>>> fetchComplaintsByRollNumber(
    String rollNumber,
  ) async {
    try {
      final response = await http.get(
        // Updated path based on new baseUrl
        Uri.parse('${baseUrl}get_complaint_status.php?roll_number=$rollNumber'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final dynamicData = jsonDecode(response.body);

        if (dynamicData is Map<String, dynamic> &&
            dynamicData.containsKey('complaint_id')) {
          return [_mapApiResponseToComplaint(dynamicData)];
        } else if (dynamicData is List) {
          return dynamicData
              .map(
                (item) =>
                    _mapApiResponseToComplaint(item as Map<String, dynamic>),
              )
              .toList();
        } else if (dynamicData is Map<String, dynamic> &&
            dynamicData.containsKey('message')) {
          if (dynamicData['message'] == 'Complaint not found.' ||
              dynamicData['message'].toString().toLowerCase().contains(
                'not found',
              )) {
            return [];
          }
        }
      }

      return [];
    } catch (e) {
      print('Error fetching complaints: $e');
      return [];
    }
  }

  // Helper method
  static Map<String, dynamic> _mapApiResponseToComplaint(
    Map<String, dynamic> apiResponse,
  ) {
    return {
      'complaint_id': apiResponse['complaint_id'] ?? '',
      'roll_number': apiResponse['roll_number'] ?? apiResponse['user_id'] ?? '',
      'complaint_type':
          apiResponse['complaint_type'] ??
          apiResponse['complaint_type_detail'] ??
          '',
      'description':
          apiResponse['description'] ?? apiResponse['description_detail'] ?? '',
      'status': apiResponse['status'] ?? 'Pending',
      'timestamp': apiResponse['created_at'] ?? DateTime.now().toString(),
      'image_path': apiResponse['image_path'],
    };
  }

  // Fetch all complaints
  static Future<List<Map<String, dynamic>>> fetchAllComplaints(
    String rollNumber,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}get_complaint_status.php?roll_number=$rollNumber'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final dynamicData = jsonDecode(response.body);
        if (dynamicData is List) {
          return dynamicData
              .map(
                (item) =>
                    _mapApiResponseToComplaint(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching all complaints: $e');
      return [];
    }
  }
}
