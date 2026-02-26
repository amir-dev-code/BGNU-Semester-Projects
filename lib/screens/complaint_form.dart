import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app1/services/api_service.dart';
import 'package:app1/services/complaint_service.dart';
import 'package:app1/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login_screen.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:url_launcher/url_launcher.dart';
import 'full_screen_image_viewer.dart';
import 'chat_screen.dart';
import 'package:app1/services/pdf_service.dart';
import 'package:app1/services/notification_service.dart';
import 'dart:convert'; // 🔥 For Caching
import 'package:hive_flutter/hive_flutter.dart'; // 🔥 For Hive

class ComplaintForm extends StatefulWidget {
  final String? rollNumber;
  final String? userName;

  const ComplaintForm({Key? key, this.rollNumber, this.userName})
    : super(key: key);

  @override
  _ComplaintFormState createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<ComplaintForm> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  String? _selectedComplaint;
  final _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isFetching = true;

  List<Map<String, dynamic>> _allComplaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];

  String _statusFilter = 'All';
  String _categoryFilter = 'All';

  final List<String> _quickCategories = [
    'All',
    'Fee',
    'Exam',
    'Result',
    'Faculty',
    'Timetable',
    'Other',
  ];

  int _totalCount = 0;
  int _resolvedCount = 0;
  int _pendingCount = 0;

  File? _selectedFile;
  Uint8List? _webFileBytes;
  String? _fileType;
  String? _fileName;

  String? myRollNumber;
  String? myUserName;

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Future<void> _getUserData() async {
    if (widget.rollNumber != null && widget.rollNumber!.isNotEmpty) {
      setState(() {
        myRollNumber = widget.rollNumber;
        myUserName = widget.userName;
      });
      _loadHistory();
    } else {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('userEmail') ?? prefs.getString('user_id');
      String? name =
          prefs.getString('userName') ?? prefs.getString('user_name');
      String? role =
          prefs.getString('userRole') ?? prefs.getString('user_role');

      if (id != null && (role == 'student' || role == null)) {
        setState(() {
          myRollNumber = id;
          myUserName = name;
        });
        _loadHistory();
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    }
  }

  // --- 🔥 HIVE NOSQL CACHING (STUDENT) ---
  Future<void> _loadHistory() async {
    if (myRollNumber == null) return;

    var box = Hive.box('appBox');
    final String cacheKey = 'student_history_$myRollNumber';

    // 1. INSTANT LOAD FROM HIVE
    String? cachedData = box.get(cacheKey);
    if (cachedData != null) {
      try {
        List<dynamic> decodedData = jsonDecode(cachedData);
        List<Map<String, dynamic>> localData = List<Map<String, dynamic>>.from(
          decodedData,
        );

        int cResolved = 0;
        int cPending = 0;
        for (var item in localData) {
          if (item['status'] == 'Resolved') {
            cResolved++;
          } else {
            cPending++;
          }
        }

        if (mounted) {
          setState(() {
            _allComplaints = localData;
            _totalCount = localData.length;
            _resolvedCount = cResolved;
            _pendingCount = cPending;
            _isFetching = false;
            _applyFilter();
          });
        }
      } catch (e) {
        debugPrint("Hive Error: $e");
      }
    } else {
      if (_allComplaints.isEmpty) setState(() => _isFetching = true);
    }

    // 2. BACKGROUND FETCH FROM SERVER
    try {
      final freshData = await ComplaintService.fetchStudentComplaints(
        myRollNumber!,
      );

      freshData.sort((a, b) {
        String dateA = a['created_at'] ?? a['timestamp'] ?? "";
        String dateB = b['created_at'] ?? b['timestamp'] ?? "";
        return dateB.compareTo(dateA);
      });

      int resolved = 0;
      int pending = 0;
      for (var item in freshData) {
        if (item['status'] == 'Resolved') {
          resolved++;
        } else {
          pending++;
        }
      }

      // 3. SAVE NAYA DATA TO HIVE
      box.put(cacheKey, jsonEncode(freshData));

      if (mounted) {
        setState(() {
          _allComplaints = freshData;
          _totalCount = freshData.length;
          _resolvedCount = resolved;
          _pendingCount = pending;
          _isFetching = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted && cachedData == null) setState(() => _isFetching = false);
    }
  }

  void _applyFilter() {
    String query = _searchController.text.toLowerCase();

    setState(() {
      _filteredComplaints = _allComplaints.where((item) {
        bool statusMatch = true;
        if (_statusFilter == 'Resolved') {
          statusMatch = item['status'] == 'Resolved';
        } else if (_statusFilter == 'Pending') {
          statusMatch = item['status'] != 'Resolved';
        }

        bool categoryMatch = true;
        if (_categoryFilter != 'All') {
          String type = (item['type'] ?? '').toString();
          categoryMatch = type.contains(_categoryFilter);
        }

        bool searchMatch = true;
        if (query.isNotEmpty) {
          String type = (item['type'] ?? '').toLowerCase();
          String desc = (item['description'] ?? '').toLowerCase();
          String id = (item['detail_id']?.toString() ?? '').toLowerCase();
          searchMatch =
              type.contains(query) ||
              desc.contains(query) ||
              id.contains(query);
        }

        return statusMatch && categoryMatch && searchMatch;
      }).toList();
    });
  }

  void _openComplaintForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "New Complaint",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedComplaint,
                        items: complaintTypes
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedComplaint = v),
                        decoration: InputDecoration(
                          labelText: 'Select Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Describe your issue details...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          alignLabelWithHint: true,
                        ),
                        validator: (v) =>
                            (v == null || v.length < 5) ? 'Too short' : null,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _showAttachmentMenu,
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.5),
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blue.shade50,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _fileType == 'video'
                                    ? Icons.videocam
                                    : (_fileType == 'document'
                                          ? Icons.insert_drive_file
                                          : Icons.camera_alt),
                                color: Colors.blue[800],
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  _fileName ?? "Tap to Attach Evidence",
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_fileName != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: _clearAttachment,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  _submitComplaint();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "SUBMIT COMPLAINT",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              Icons.camera_alt,
              Colors.pink,
              "Camera",
              () => _pickImage(ImageSource.camera),
            ),
            _menuOption(
              Icons.image,
              Colors.purple,
              "Gallery",
              () => _pickImage(ImageSource.gallery),
            ),
            _menuOption(Icons.videocam, Colors.red, "Video", _pickVideo),
            _menuOption(
              Icons.insert_drive_file,
              Colors.blue,
              "Document",
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
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (image != null) {
      var f = await image.readAsBytes();
      setState(() {
        _webFileBytes = f;
        if (!kIsWeb) _selectedFile = File(image.path);
        _fileType = 'image';
        _fileName = "Photo Attached";
      });
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video != null) {
      var f = await video.readAsBytes();
      setState(() {
        _webFileBytes = f;
        if (!kIsWeb) _selectedFile = File(video.path);
        _fileType = 'video';
        _fileName = "Video Attached";
      });
    }
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        _webFileBytes = file.bytes;
        if (!kIsWeb && file.path != null) _selectedFile = File(file.path!);
        _fileType = 'document';
        _fileName = file.name;
      });
    }
  }

  void _clearAttachment() {
    setState(() {
      _selectedFile = null;
      _webFileBytes = null;
      _fileType = null;
      _fileName = null;
    });
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      _openComplaintForm();
      return;
    }
    if (myRollNumber == null) return;
    setState(() => _isLoading = true);
    try {
      String finalLink = "No image";
      if (_selectedFile != null || _webFileBytes != null) {
        final cloudinary = CloudinaryPublic(
          'dql0vmw7j',
          'complian_portal',
          cache: false,
        );
        CloudinaryResponse response;
        CloudinaryResourceType resourceType = CloudinaryResourceType.Image;
        if (_fileType == 'video') resourceType = CloudinaryResourceType.Video;
        if (_fileType == 'document') resourceType = CloudinaryResourceType.Auto;
        if (kIsWeb && _webFileBytes != null) {
          response = await cloudinary.uploadFile(
            CloudinaryFile.fromByteData(
              ByteData.view(_webFileBytes!.buffer),
              identifier: 'complaint_${DateTime.now().millisecondsSinceEpoch}',
              folder: 'complaints',
              resourceType: resourceType,
            ),
          );
        } else {
          response = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(
              _selectedFile!.path,
              folder: 'complaints',
              resourceType: resourceType,
            ),
          );
        }
        finalLink = response.secureUrl;
      }
      final result = await ApiService.submitComplaint(
        myRollNumber!,
        _selectedComplaint!,
        _descriptionController.text.trim(),
        driveLink: finalLink,
      );
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint Submitted Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _descriptionController.clear();
        _clearAttachment();
        _loadHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${result['error']}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showRatingDialog(String detailId) {
    if (detailId.isEmpty || detailId == "0") return;
    int selectedStars = 0;
    TextEditingController feedbackCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Center(
              child: Text(
                "Rate Resolution",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "How satisfied are you?",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      icon: Icon(
                        index < selectedStars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () =>
                          setDialogState(() => selectedStars = index + 1),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: feedbackCtrl,
                  decoration: InputDecoration(
                    hintText: "Optional comment...",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: (selectedStars == 0 || isSubmitting)
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        final response = await ApiService.submitFeedback(
                          detailId,
                          selectedStars,
                          feedbackCtrl.text,
                        );
                        setDialogState(() => isSubmitting = false);
                        if (response['success'] == true) {
                          Navigator.pop(context);
                          _loadHistory();
                        }
                      },
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReopenDialog(String detailId) {
    TextEditingController reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Re-open Complaint"),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: "Reason for reopening...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.isEmpty) return;
              Navigator.pop(context);
              await ApiService.reopenComplaint(detailId, reasonCtrl.text);
              _loadHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Re-open", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openLink(String url) {
    if (url.isEmpty || url.toLowerCase().contains("no image")) return;
    bool isImage =
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.jpeg');
    if (isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: url)),
      );
    } else {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildStatusCard(
    String title,
    int count,
    Color color,
    IconData icon,
    String filterType,
  ) {
    bool isSelected = _statusFilter == filterType;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _statusFilter = filterType;
          });
          _applyFilter();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              else
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
            ],
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 5),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickCategories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          String cat = _quickCategories[index];
          bool isSelected = _categoryFilter == cat;
          return GestureDetector(
            onTap: () {
              setState(() {
                _categoryFilter = cat;
              });
              _applyFilter();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1565C0) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewComplaintCard() {
    return GestureDetector(
      onTap: _openComplaintForm,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade800, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Have an issue?",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 5),
                const Text(
                  "File New Complaint",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(
    String title,
    bool isActive,
    bool isLast,
    bool isPast,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isActive || isPast ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  if (isActive)
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: (isActive || isPast)
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: isPast ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive || isPast ? Colors.black87 : Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
              ),
              accountName: Text(
                myUserName ?? "Student",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              accountEmail: Text(myRollNumber ?? ""),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Color(0xFF1565C0)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blueGrey),
              title: const Text("Portal Home"),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted)
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text(
          "Student Portal",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, ${myUserName ?? 'Student'}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 15),

              _buildNewComplaintCard(),

              const SizedBox(height: 25),

              Row(
                children: [
                  _buildStatusCard(
                    "All",
                    _totalCount,
                    Colors.blue,
                    Icons.list_alt,
                    'All',
                  ),
                  const SizedBox(width: 10),
                  _buildStatusCard(
                    "Resolved",
                    _resolvedCount,
                    Colors.green,
                    Icons.check_circle_outline,
                    'Resolved',
                  ),
                  const SizedBox(width: 10),
                  _buildStatusCard(
                    "Pending",
                    _pendingCount,
                    Colors.orange,
                    Icons.hourglass_empty,
                    'Pending',
                  ),
                ],
              ),
              const SizedBox(height: 25),

              TextField(
                controller: _searchController,
                onChanged: (val) => _applyFilter(),
                decoration: InputDecoration(
                  hintText: "Search ID, Type...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 15,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              _buildCategorySelector(),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent History",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              _isFetching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _filteredComplaints.isEmpty
                  ? Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          Icon(
                            Icons.folder_open,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No complaints found",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredComplaints.length,
                      itemBuilder: (context, index) =>
                          _buildProfessionalHistoryCard(
                            _filteredComplaints[index],
                          ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalHistoryCard(Map<String, dynamic> item) {
    String detailId = item['detail_id']?.toString() ?? '';
    String status = item['status'] ?? 'Pending';
    bool isResolved = status == 'Resolved';
    String desc = item['description'] ?? '';
    int userRating = item['rating'] != null
        ? int.tryParse(item['rating'].toString()) ?? 0
        : 0;
    String remarks = item['remarks'] ?? 'No remarks';
    String stuImg = item['student_image'] ?? '';
    String resImg = item['proof_image'] ?? '';
    String rawDate = item['created_at'] ?? item['timestamp'] ?? "2026-01-01";
    String displayDate = rawDate.split(' ')[0];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isResolved
                ? Colors.green
                : (status == 'Reopened' ? Colors.red : Colors.orange),
            width: 5,
          ),
        ),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        title: Text(
          item['type'] ?? 'Complaint',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status,
                style: TextStyle(
                  color: isResolved ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "#$detailId",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "ID: #$detailId",
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      "Date: $displayDate",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 20),
                const Text(
                  "Description:",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 10),

                const SizedBox(height: 15),
                const Text(
                  "Tracking Status:",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    // 🔥 LOGIC FIXED: Auto-assigned means Step 1 & 2 are always true
                    bool isSubmitted = true;
                    bool isAssigned = true;
                    bool isCompleted = status == 'Resolved';

                    return Column(
                      children: [
                        _buildTimelineStep(
                          "Complaint Submitted",
                          isSubmitted,
                          false,
                          isSubmitted,
                        ),
                        _buildTimelineStep(
                          "Staff Assigned & Notified",
                          isAssigned,
                          false,
                          isAssigned,
                        ),
                        _buildTimelineStep(
                          "Resolution Completed",
                          isCompleted,
                          true,
                          isCompleted,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                if (stuImg.length > 5)
                  GestureDetector(
                    onTap: () => _openLink(stuImg),
                    child: Row(
                      children: const [
                        Icon(Icons.attach_file, size: 16, color: Colors.blue),
                        SizedBox(width: 5),
                        Text(
                          "View My Attachment",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            complaintId: detailId,
                            currentUserId: myRollNumber!,
                            chatPartnerName: "Admin",
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text("Chat with Resolver"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[800],
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                if (isResolved || status == 'Reopened')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.verified, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "Official Resolution",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Remarks: $remarks",
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        if (resImg.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: () => _openLink(resImg),
                              child: const Text(
                                "View Proof Image",
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 15),
                        if (status == 'Resolved' && userRating == 0)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _showReopenDialog(detailId),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  child: const Text("Not Satisfied?"),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showRatingDialog(detailId),
                                  child: const Text("Rate Service"),
                                ),
                              ),
                            ],
                          )
                        else if (userRating > 0)
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < userRating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              ),
                            ),
                          ),
                        if (isResolved)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 15),
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.print_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text("DOWNLOAD OFFICIAL LETTER"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                PdfService().generateResolutionLetter(
                                  studentName: myUserName ?? "Student",
                                  complaintId: detailId,
                                  issue: item['type'] ?? "Complaint",
                                  resolutionRemarks: remarks,
                                  date: displayDate,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
