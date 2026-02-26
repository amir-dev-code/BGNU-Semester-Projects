import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  static const String _imagePathKey = 'Complaint_Image_Path';

  // --- AAPKA ORIGINAL PICK IMAGE LOGIC (UNCHANGED) ---
  static Future<String?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'complaint_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String imagePath = '${appDir.path}/$fileName';
      await File(image.path).copy(imagePath);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_imagePathKey, imagePath);
      return imagePath;
    }
    return null;
  }

  static Future<File?> getImageFile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? imagePath = prefs.getString(_imagePathKey);
    if (imagePath != null) {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) return imageFile;
    }
    return null;
  }

  static Future<void> clearImage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_imagePathKey);
  }

  // --- 100% FIXED: DIRECT LINK CONVERTER FOR FLUTTER CARD ---
  static String getDirectLink(String driveUrl) {
    if (driveUrl.isEmpty || driveUrl == "No image") return "";

    try {
      String fileId = "";
      // Link se ID nikalne ka logic handle karna
      if (driveUrl.contains("id=")) {
        fileId = driveUrl.split("id=")[1].split("&")[0];
      } else if (driveUrl.contains("/d/")) {
        fileId = driveUrl.split("/d/")[1].split("/")[0];
      }

      if (fileId.isNotEmpty) {
        // Yeh direct rendering link Flutter Image.network mein 100% chalta hai
        return "https://drive.google.com/uc?export=view&id=$fileId";
      }
    } catch (e) {
      return driveUrl; // Fallback to original link if error
    }
    return driveUrl;
  }
}
