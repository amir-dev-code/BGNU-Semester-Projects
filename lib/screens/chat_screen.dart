import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'full_screen_image_viewer.dart';
import 'package:http/http.dart' as http; // <--- NEW IMPORT ADDED
import 'dart:convert'; // <--- NEW IMPORT ADDED

class ChatScreen extends StatefulWidget {
  final String complaintId;
  final String currentUserId;
  final String chatPartnerName;
  final bool isResolver;

  const ChatScreen({
    Key? key,
    required this.complaintId,
    required this.currentUserId,
    required this.chatPartnerName,
    this.isResolver = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUploading = false;
  Map<String, dynamic>? _replyMessage;

  // --- NEW: NOTIFICATION TRIGGER FUNCTION 🔔 ---
  Future<void> _sendNotificationAPI(String messageContent) async {
    try {
      final url = Uri.parse(
        'https://amirdev.site/backend/api/send_chat_alert.php',
      );

      // Determine Role & Name for Notification
      String role = widget.isResolver ? 'resolver' : 'student';
      String name = widget.isResolver ? 'Resolver' : 'Student';

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "complaint_id": widget.complaintId,
          "sender_role": role,
          "sender_name": name,
          "message": messageContent,
        }),
      );
      print("🔔 Notification Response: ${response.body}");
    } catch (e) {
      print("❌ Notification Error: $e");
    }
  }

  // --- 1. CLOUDINARY UPLOAD LOGIC (Kept Intact) ---
  Future<void> _uploadAndSendFile(
    File file,
    String msgType, {
    String? fileName,
  }) async {
    setState(() => _isUploading = true);
    try {
      final cloudinary = CloudinaryPublic(
        'dql0vmw7j',
        'complian_portal',
        cache: false,
      );
      CloudinaryResponse response;

      if (msgType == 'video') {
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            folder: 'chat_videos',
            resourceType: CloudinaryResourceType.Video,
          ),
        );
      } else if (msgType == 'document') {
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            folder: 'chat_documents',
            resourceType: CloudinaryResourceType.Auto,
          ),
        );
      } else {
        response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            file.path,
            folder: 'chat_images',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
      }

      _sendMessage(
        fileUrl: response.secureUrl,
        type: msgType,
        fileName: fileName,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Upload Failed. Check Internet.")),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- 2. PICKERS ---
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 160,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _menuOption(
              Icons.image,
              Colors.purple,
              "Gallery",
              () => _pickImage(ImageSource.gallery),
            ),
            _menuOption(
              Icons.camera_alt,
              Colors.pink,
              "Camera",
              () => _pickImage(ImageSource.camera),
            ),
            _menuOption(Icons.videocam, Colors.red, "Video", _pickVideo),
            _menuOption(
              Icons.insert_drive_file,
              Colors.blue,
              "File",
              _pickDocument,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuOption(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: source, imageQuality: 70);
    if (img != null) await _uploadAndSendFile(File(img.path), 'image');
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) await _uploadAndSendFile(File(video.path), 'video');
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      await _uploadAndSendFile(
        File(result.files.single.path!),
        'document',
        fileName: result.files.single.name,
      );
    }
  }

  // --- 3. SEND MESSAGE (UPDATED WITH NOTIFICATION) ---
  void _sendMessage({
    String? text,
    String? fileUrl,
    String? type,
    String? fileName,
  }) {
    if ((text == null || text.trim().isEmpty) && fileUrl == null) return;

    Map<String, dynamic> data = {
      'text': text ?? '',
      'fileUrl': fileUrl ?? '',
      'fileName': fileName ?? '',
      'senderId': widget.currentUserId,
      'type': type ?? 'text',
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (_replyMessage != null) {
      data['replyTo'] = {
        'text': _replyMessage!['text'],
        'senderId': _replyMessage!['senderId'],
        'type': _replyMessage!['type'],
      };
    }

    // 1. Save to Firestore (Existing Logic)
    _firestore
        .collection('complaints')
        .doc(widget.complaintId)
        .collection('messages')
        .add(data);

    // 2. 🔥 TRIGGER NOTIFICATION (New Logic) 🔥
    String msgPreview = text ?? "Sent a ${type ?? 'file'}";
    if (msgPreview.isEmpty) msgPreview = "Sent an attachment";
    _sendNotificationAPI(msgPreview);

    _msgController.clear();
    setState(() => _replyMessage = null);
  }

  void _openFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open file.")));
    }
  }

  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text("Reply"),
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyMessage = data);
            },
          ),
          if (data['type'] == 'text')
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("Copy"),
              onTap: () {
                Clipboard.setData(ClipboardData(text: data['text']));
                Navigator.pop(context);
              },
            ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete"),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(doc.id);
              },
            ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Message?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _firestore
                  .collection('complaints')
                  .doc(widget.complaintId)
                  .collection('messages')
                  .doc(id)
                  .delete();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resolveFromChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Resolution"),
        content: const Text("Mark this complaint as Resolved?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.resolveComplaint(
                widget.complaintId,
                remarks: "Resolved via Chat",
                proofLink: "No Image",
              );
              _sendMessage(text: "✅ SYSTEM: Complaint Marked as Resolved");
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5), // WhatsApp Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(
                widget.chatPartnerName.isNotEmpty
                    ? widget.chatPartnerName[0].toUpperCase()
                    : "?",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.chatPartnerName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isResolver)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _resolveFromChat,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(color: Color(0xFF128C7E)),

          // --- FIX IS HERE (EXPANDED + REVERSE + SORTING) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // 1. Fetch NEWEST First (Descending)
              stream: _firestore
                  .collection('complaints')
                  .doc(widget.complaintId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                // 2. GroupedListView Settings for "Bottom-to-Top" Chat
                return GroupedListView<QueryDocumentSnapshot, DateTime>(
                  elements: snapshot.data!.docs,

                  // CRITICAL SETTING:
                  // reverse: true -> List starts sticking to the BOTTOM (Like WhatsApp)
                  // order: DESC -> Ensures 'Today' is at the bottom (visually newest)
                  reverse: true,
                  order: GroupedListOrder.DESC,

                  useStickyGroupSeparators: true,
                  floatingHeader: true,

                  groupBy: (msg) {
                    Timestamp? ts = msg['timestamp'];
                    // Agar timestamp null hai (sending state), to abhi ka waqt lo
                    DateTime date = ts?.toDate() ?? DateTime.now();
                    return DateTime(date.year, date.month, date.day);
                  },

                  groupSeparatorBuilder: (DateTime date) => Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCF8C6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        DateFormat('dd MMM').format(date),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),

                  itemBuilder: (context, QueryDocumentSnapshot msg) =>
                      _buildMessageItem(msg),

                  // Sort Inside Group to ensure order remains correct even with null timestamps
                  itemComparator: (item1, item2) {
                    Timestamp? t1 = item1['timestamp'];
                    Timestamp? t2 = item2['timestamp'];
                    DateTime d1 = t1?.toDate() ?? DateTime.now();
                    DateTime d2 = t2?.toDate() ?? DateTime.now();
                    // Descending sort for inside items because list is reversed
                    return d1.compareTo(d2);
                  },
                );
              },
            ),
          ),

          if (_replyMessage != null) _buildReplyPreview(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(DocumentSnapshot msg) {
    Map<String, dynamic> data = msg.data() as Map<String, dynamic>;
    bool isMe = data['senderId'] == widget.currentUserId;
    bool isSystem = data['senderId'] == "SYSTEM";
    String type = data['type'] ?? 'text';

    if (isSystem)
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            data['text'],
            style: TextStyle(
              color: Colors.amber.shade900,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

    Widget content;
    if (type == 'image') {
      content = GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(imageUrl: data['fileUrl']),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: data['fileUrl'],
            height: 200,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (c, u) =>
                Container(height: 200, width: 200, color: Colors.grey[200]),
            errorWidget: (c, u, e) => const Icon(Icons.error),
          ),
        ),
      );
    } else if (type == 'video') {
      content = _buildFileBubble(
        data,
        Icons.play_circle_fill,
        Colors.red,
        "Video",
      );
    } else if (type == 'document') {
      content = _buildFileBubble(
        data,
        Icons.picture_as_pdf,
        Colors.redAccent,
        "Document",
      );
    } else {
      content = Text(data['text'], style: const TextStyle(fontSize: 16));
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 1)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.containsKey('replyTo')) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    border: const Border(
                      left: BorderSide(color: Colors.teal, width: 3),
                    ),
                  ),
                  child: Text(
                    "Replying to: ${data['replyTo']['type'] == 'text' ? data['replyTo']['text'] : 'Media'}",
                    style: const TextStyle(fontSize: 10, color: Colors.teal),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Padding(padding: const EdgeInsets.all(4), child: content),
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(
                        (data['timestamp'] as Timestamp?)?.toDate() ??
                            DateTime.now(),
                      ),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (isMe)
                      const Icon(Icons.done_all, size: 14, color: Colors.blue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileBubble(
    Map<String, dynamic> data,
    IconData icon,
    Color color,
    String typeLabel,
  ) {
    return GestureDetector(
      onTap: () => _openFile(data['fileUrl']),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['fileName'] ?? typeLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Tap to view",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      child: Row(
        children: [
          const Icon(Icons.reply, color: Colors.teal),
          const SizedBox(width: 8),
          const Expanded(
            child: Text("Replying...", style: TextStyle(color: Colors.teal)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _replyMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _isUploading ? null : _showAttachmentMenu,
          ),
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF075E54),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(text: _msgController.text.trim()),
            ),
          ),
        ],
      ),
    );
  }
}
