import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // Import HTTP
import 'dart:convert';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // URL of your PHP Notification Script
  final String _notificationApiUrl =
      "https://amirdev.site/backend/api/send_chat_alert.php";

  // 1. Send Text Message
  Future<void> sendMessage({
    required String complaintId,
    required String senderId,
    required String senderName,
    required String text,
    required bool isResolver, // Pata chale kon bhej raha hai
  }) async {
    try {
      // A. Save to Firebase (Existing Logic)
      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .add({
            'senderId': senderId,
            'text': text,
            'type': 'text',
            'timestamp': FieldValue.serverTimestamp(),
          });

      // B. Trigger Notification (NEW ADDITION)
      _sendNotificationTrigger(
        complaintId: complaintId,
        message: text,
        senderName: senderName,
        role: isResolver ? 'resolver' : 'student',
      );
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  // 2. Send Image Message
  Future<void> sendImage({
    required String complaintId,
    required String senderId,
    required String senderName,
    required String imageUrl,
    required bool isResolver,
  }) async {
    try {
      await _firestore
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .add({
            'senderId': senderId,
            'text': '📷 Image',
            'type': 'image',
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // Trigger Notification for Image
      _sendNotificationTrigger(
        complaintId: complaintId,
        message: "Sent a photo 📷",
        senderName: senderName,
        role: isResolver ? 'resolver' : 'student',
      );
    } catch (e) {
      print("Error sending image: $e");
    }
  }

  // --- PRIVATE HELPER TO CALL PHP API ---
  Future<void> _sendNotificationTrigger({
    required String complaintId,
    required String message,
    required String senderName,
    required String role,
  }) async {
    try {
      var url = Uri.parse(_notificationApiUrl);
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "complaint_id": complaintId,
          "sender_role": role,
          "sender_name": senderName,
          "message": message,
        }),
      );
      print("Notification Trigger Status: ${response.statusCode}");
    } catch (e) {
      print("Failed to trigger notification: $e");
    }
  }
}
