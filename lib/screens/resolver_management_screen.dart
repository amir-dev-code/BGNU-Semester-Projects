import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert'; // ✅ Added for Hive
import 'package:hive_flutter/hive_flutter.dart'; // ✅ Added for Hive

class ResolverManagementScreen extends StatefulWidget {
  const ResolverManagementScreen({super.key});

  @override
  State<ResolverManagementScreen> createState() =>
      _ResolverManagementScreenState();
}

class _ResolverManagementScreenState extends State<ResolverManagementScreen> {
  List<dynamic> resolvers = [];
  bool _isLoading = true;

  // 🔥 Professional Departments List (Matching your PHP Mapping)
  final List<String> _departmentList = [
    "Fee / Accounts Problem",
    "Examination Issue",
    "Course Content Problem",
    "Harassment Complaint",
    "Result / Marks Issue",
    "Faculty Behavior Issue",
    "Timetable / Scheduling Issue",
    "Attendance Issue",
    "Other Academic Issue",
  ];

  @override
  void initState() {
    super.initState();
    _loadResolvers();
  }

  // --- 🔥 HIVE NOSQL CACHING LOGIC ---
  Future<void> _loadResolvers() async {
    var box = Hive.box('appBox');
    const String cacheKey = 'resolvers_list';

    // 1. INSTANT LOAD FROM HIVE
    String? cachedData = box.get(cacheKey);
    if (cachedData != null) {
      try {
        List<dynamic> localData = jsonDecode(cachedData);
        if (mounted) {
          setState(() {
            resolvers = localData;
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
      final data = await ApiService.getAllResolvers();

      // 3. SAVE NAYA DATA TO HIVE
      box.put(cacheKey, jsonEncode(data));

      if (mounted) {
        setState(() {
          resolvers = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && cachedData == null) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRes(String id) async {
    bool confirmed =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text("Remove Staff Member?"),
            content: const Text(
              "This action will remove the resolver from the system. Future complaints for their department will fallback to Admin.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  "DELETE",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      bool success = await ApiService.deleteResolver(id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Resolver Removed Successfully"),
            backgroundColor: Colors.green,
          ),
        );
        _loadResolvers(); // Will auto-refresh cache
      }
    }
  }

  void _showAddResolverDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedDept = _departmentList[0]; // Default selection

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // ✅ Zaruri for Dropdown state inside dialog
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(Icons.person_add, size: 40, color: Color(0xFF0D47A1)),
              SizedBox(height: 10),
              Text(
                "Register New Resolver",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: "University Email",
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Assign Department",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedDept,
                      items: _departmentList.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          selectedDept = newValue!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                    labelText: "Assign Password",
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
              ),
              onPressed: () async {
                if (nameCtrl.text.isEmpty ||
                    emailCtrl.text.isEmpty ||
                    passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Fill all fields!")),
                  );
                  return;
                }

                final result = await ApiService.addResolver(
                  nameCtrl.text.trim(),
                  emailCtrl.text.trim(),
                  selectedDept,
                  passCtrl.text.trim(),
                );

                if (result['success'] == true) {
                  Navigator.pop(context);
                  _loadResolvers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Resolver Added!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? "Error"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                "REGISTER",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text(
          "Management Team",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddResolverDialog,
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "ADD RESOLVER",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadResolvers,
              child: resolvers.isEmpty
                  ? const Center(child: Text("No Resolvers Found"))
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: resolvers.length,
                      itemBuilder: (context, index) {
                        final res = resolvers[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.blue.shade50,
                              child: Text(
                                res['name']?[0].toUpperCase() ?? "R",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                            title: Text(
                              res['name'] ?? "No Name",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                "📌 ${res['department']}\n✉️ ${res['email']}",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            isThreeLine: true,
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_sweep,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _deleteRes(res['id'].toString()),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
