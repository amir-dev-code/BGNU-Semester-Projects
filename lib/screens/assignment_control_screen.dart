import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert'; // ✅ Added for Hive
import 'package:hive_flutter/hive_flutter.dart'; // ✅ Added for Hive

class AssignmentControlScreen extends StatefulWidget {
  const AssignmentControlScreen({super.key});

  @override
  State<AssignmentControlScreen> createState() =>
      _AssignmentControlScreenState();
}

class _AssignmentControlScreenState extends State<AssignmentControlScreen> {
  // 🔥 Ye aapki poori original list hai, ise 1% bhi kam nahi kiya
  Map<String, String> currentMapping = {
    "Result / Marks Issue": "exams@university.com",
    "Examination Issue": "exams@university.com",
    "Fee / Accounts Problem": "accounts@university.com",
    "Harassment Complaint": "discipline@university.com",
    "Faculty Behavior Issue": "discipline@university.com",
    "Teacher Misconduct": "discipline@university.com",
    "Course Content Problem": "hod_cs@university.com",
    "Timetable / Scheduling Issue": "hod_cs@university.com",
    "Attendance Issue": "hod_cs@university.com",
    "Other Academic Issue": "student_affairs@university.com",
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMappingRules(); // Screen khulte hi database se latest check karein
  }

  // --- 🔥 HIVE NOSQL CACHING LOGIC ADDED HERE ---
  Future<void> _fetchMappingRules() async {
    var box = Hive.box('appBox');
    const String cacheKey = 'admin_assignment_rules';

    // 1. INSTANT LOAD FROM HIVE
    String? cachedData = box.get(cacheKey);
    if (cachedData != null) {
      try {
        Map<String, dynamic> dbData = jsonDecode(cachedData);
        if (mounted) {
          setState(() {
            dbData.forEach((key, value) {
              if (currentMapping.containsKey(key)) {
                currentMapping[key] = value.toString();
              }
            });
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Hive Error: $e");
      }
    } else {
      setState(() => _isLoading = true);
    }

    // 2. BACKGROUND FETCH FROM SERVER
    try {
      final result = await ApiService.fetchAdminMasterStats();
      if (result['success'] == true && result['mapping'] != null) {
        Map<String, dynamic> dbData = result['mapping'];

        // 3. SAVE TO HIVE
        box.put(cacheKey, jsonEncode(dbData));

        if (mounted) {
          setState(() {
            dbData.forEach((key, value) {
              if (currentMapping.containsKey(key)) {
                currentMapping[key] = value.toString();
              }
            });
            _isLoading = false;
          });
        }
      } else {
        if (mounted && cachedData == null) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted && cachedData == null) setState(() => _isLoading = false);
    }
  }

  // 🔥 YAHAN MAIN CACHE UPDATE FIX LAGAYA HAI
  void _editMapping(String type) {
    final emailCtrl = TextEditingController(text: currentMapping[type]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Route: $type",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter resolver email for this category:",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: "Resolver Email",
                prefixIcon: const Icon(Icons.alternate_email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              if (emailCtrl.text.isEmpty) return;

              // 🔥 API Call for update
              final res = await ApiService.updateAssignment(
                type,
                emailCtrl.text.trim(),
              );

              if (res['success'] == true) {
                // 1. Update UI Instantly
                setState(() => currentMapping[type] = emailCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Routing Rule Updated! ✅"),
                    backgroundColor: Colors.green,
                  ),
                );

                // 2. 🔥 FIX: Update Hive Cache Immediately! (Bina purana data load kiye)
                var box = Hive.box('appBox');
                String? cachedData = box.get('admin_assignment_rules');
                if (cachedData != null) {
                  try {
                    Map<String, dynamic> dbData = jsonDecode(cachedData);
                    dbData[type] = emailCtrl.text.trim();
                    box.put(
                      'admin_assignment_rules',
                      jsonEncode(dbData),
                    ); // Cache mein naya email save
                  } catch (e) {}
                }

                // 3. Silent sync without disrupting the user
                ApiService.fetchAdminMasterStats().then((result) {
                  if (result['success'] == true && result['mapping'] != null) {
                    box.put(
                      'admin_assignment_rules',
                      jsonEncode(result['mapping']),
                    );
                  }
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Failed to update server"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              "UPDATE RULE",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Routing Logic Center",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMappingRules,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.indigo,
            width: double.infinity,
            child: const Text(
              "Define which department handles which type of issue. This directly affects auto-assignment.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: currentMapping.length,
              itemBuilder: (context, index) {
                String type = currentMapping.keys.elementAt(index);
                String email = currentMapping[type]!;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0E7FF),
                      child: Icon(Icons.route_rounded, color: Colors.indigo),
                    ),
                    title: Text(
                      type,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Assigned to: $email",
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.blue,
                    ),
                    onTap: () => _editMapping(type),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
