import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  // Aapka Apps Script URL (Confirm this is the latest deployment URL)
  static const String _scriptUrl =
      "https://script.google.com/macros/s/AKfycbz2kyuMVQr35o25fPs1V-koRyuqHWG1bHdsqADkU8uoEjedf8h-Xb0wK7Oqo1Xflss/exec";

  static Future<String?> uploadImageToDrive(File imageFile) async {
    try {
      print("Starting secure upload to Drive...");
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      var response = await http
          .post(
            Uri.parse(_scriptUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "image": base64Image,
              "filename":
                  "complaint_${DateTime.now().millisecondsSinceEpoch}.jpg",
              "folderId": "1kvGc1kFbB_atO2pO7mQkIX-BUtIMTWbc",
            }),
          )
          .timeout(const Duration(seconds: 120)); // Professional Timeout

      print("Drive API Response Code: ${response.statusCode}");

      // 1. Handling Redirects/HTML Warnings
      if (response.body.trim().startsWith("<")) {
        print(
          "Error: Script returned HTML. Check if 'Anyone' has access in Apps Script.",
        );
        return "error_html_response";
      }

      // 2. Extracting Link from JSON
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['status'] == 'success') {
        String driveLink = jsonResponse['link'];
        print("Success! Drive Link: $driveLink");
        return driveLink;
      } else {
        print("Script error message: ${jsonResponse['message']}");
        return "error_${jsonResponse['message']}";
      }
    } catch (e) {
      print("Drive Upload Exception: $e");
      return "exception_$e";
    }
  }
}
