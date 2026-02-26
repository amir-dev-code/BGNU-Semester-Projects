import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Logout ke liye zaroori
import '../services/api_service.dart';
import 'auth/login_screen.dart';
import 'full_screen_image_viewer.dart';
import 'chat_screen.dart';
import 'complaint_form.dart';
import 'package:app1/services/pdf_service.dart';
import 'dart:convert'; // ✅ Added for Hive
import 'package:hive_flutter/hive_flutter.dart'; // ✅ Added for Hive

class ResolverDashboard extends StatefulWidget {
  final String resolverId;
  const ResolverDashboard({super.key, required this.resolverId});

  @override
  State<ResolverDashboard> createState() => _ResolverDashboardState();
}

class _ResolverDashboardState extends State<ResolverDashboard>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> _allTasks = [];
  List<dynamic> _filteredTasks = [];
  bool _isLoading = true;

  String _searchQuery = "";
  String _currentFilter = "Pending";

  // Analytics Stats
  int _totalCount = 0;
  int _resolvedCount = 0;
  int _pendingCount = 0;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- 🔥 HIVE NOSQL CACHING LOGIC ADDED HERE ---
  Future<void> _loadTasks() async {
    var box = Hive.box('appBox');
    final String cacheKey = 'resolver_tasks_${widget.resolverId}';

    // 1. INSTANT LOAD FROM HIVE
    String? cachedData = box.get(cacheKey);
    if (cachedData != null) {
      try {
        List<dynamic> localData = jsonDecode(cachedData);

        int total = localData.length;
        int resolved = 0;
        int pending = 0;
        for (var t in localData) {
          if (safeString(t['status']) == 'Resolved') {
            resolved++;
          } else {
            pending++;
          }
        }

        if (mounted) {
          setState(() {
            _allTasks = localData;
            _totalCount = total;
            _resolvedCount = resolved;
            _pendingCount = pending;
            _applyFilters();
            _isLoading = false;
            _controller.forward(from: 0);
          });
        }
      } catch (e) {
        debugPrint("Hive Error: $e");
      }
    } else {
      if (_allTasks.isEmpty) setState(() => _isLoading = true);
    }

    // 2. BACKGROUND FETCH FROM SERVER
    try {
      final tasks = await ApiService.fetchAssignedTasks(widget.resolverId);

      int total = 0;
      int resolved = 0;
      int pending = 0;

      if (tasks != null) {
        total = tasks.length;
        for (var t in tasks) {
          if (safeString(t['status']) == 'Resolved') {
            resolved++;
          } else {
            pending++;
          }
        }

        // 3. SAVE TO HIVE & UPDATE SILENTLY
        box.put(cacheKey, jsonEncode(tasks));
      }

      if (mounted) {
        setState(() {
          _allTasks = tasks ?? [];
          _totalCount = total;
          _resolvedCount = resolved;
          _pendingCount = pending;
          _applyFilters();
          _isLoading = false;
          _controller.forward(from: 0);
        });
      }
    } catch (e) {
      if (mounted && cachedData == null) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTasks = _allTasks.where((task) {
        if (task == null) return false;

        String status = safeString(task['status']);
        bool statusMatch = true;

        if (_currentFilter == "Pending") {
          statusMatch = status != "Resolved";
        } else if (_currentFilter == "Resolved") {
          statusMatch = status == "Resolved";
        }

        bool searchMatch = true;
        if (_searchQuery.isNotEmpty) {
          String query = _searchQuery.toLowerCase();
          String name = safeString(task['student_name']).toLowerCase();
          String roll = safeString(task['roll_number']).toLowerCase();
          String email = safeString(task['user_id']).toLowerCase();
          String type = safeString(task['complaint_type_detail']).toLowerCase();
          String id = safeString(task['detail_id']).toLowerCase();

          searchMatch =
              name.contains(query) ||
              roll.contains(query) ||
              email.contains(query) ||
              type.contains(query) ||
              id.contains(query);
        }

        return statusMatch && searchMatch;
      }).toList();
    });
  }

  void _onFilterTap(String filter) {
    setState(() {
      _currentFilter = filter;
      _applyFilters();
    });
  }

  // --- REPORT GENERATION ---
  Future<void> _generateReport() async {
    if (_allTasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No data to export!")));
      return;
    }

    try {
      List<Map<String, dynamic>> tasksForPdf = _allTasks.map((task) {
        return Map<String, dynamic>.from(task);
      }).toList();

      await PdfService().generateResolverReport(
        resolverId: widget.resolverId,
        tasks: tasksForPdf,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("PDF Generation Failed: $e")));
    }
  }

  // --- HELPER FUNCTIONS ---
  String safeString(dynamic value) {
    if (value == null) return "";
    if (value.toString().toLowerCase() == "null") return "";
    return value.toString();
  }

  String getTimeAgo(String dateString) {
    if (dateString.isEmpty) return "Just now";
    try {
      DateTime eventTime = DateTime.parse(dateString);
      Duration diff = DateTime.now().difference(eventTime);
      if (diff.inDays > 0) return "${diff.inDays}d ago";
      if (diff.inHours > 0) return "${diff.inHours}h ago";
      if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
      return "Just now";
    } catch (e) {
      return "Just now";
    }
  }

  Future<void> _handleResolve(int index, String taskId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirm Resolution"),
        content: const Text(
          "Are you sure you want to mark this complaint as Resolved?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text(
              "YES, RESOLVE",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      String result = await ApiService.resolveComplaint(
        taskId,
        remarks: "Resolved by Admin via Dashboard",
        proofLink: "Check Chat for details",
      );

      if (!mounted) return;

      if (result == "Success") {
        int realIndex = _allTasks.indexWhere(
          (t) =>
              (safeString(t['detail_id']) == taskId ||
              safeString(t['id']) == taskId),
        );
        if (realIndex != -1) {
          _allTasks[realIndex]['status'] = 'Resolved';
          _loadTasks();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Complaint Resolved! ✅"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: $result"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF2F5F8),
      // --- DRAWER ---
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                ),
              ),
              accountName: const Text(
                "Resolver Panel",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(widget.resolverId),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: Colors.blueGrey),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.indigo),
              title: const Text("File a Complaint"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComplaintForm(
                      rollNumber: widget.resolverId,
                      userName: "Resolver/Admin",
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: () async {
                // ✅ SECURE LOGOUT LOGIC ADDED
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                if (!context.mounted) return;
                Navigator.pop(context);
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

      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF002171)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Dashboard",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.print, color: Colors.white),
                        tooltip: "Export Monthly Report",
                        onPressed: _generateReport,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    _buildColoredCard(
                      "Total",
                      _totalCount,
                      Colors.blue,
                      "All",
                      Icons.assignment,
                    ),
                    const SizedBox(width: 10),
                    _buildColoredCard(
                      "Pending",
                      _pendingCount,
                      Colors.orange,
                      "Pending",
                      Icons.warning_amber_rounded,
                    ),
                    const SizedBox(width: 10),
                    _buildColoredCard(
                      "Resolved",
                      _resolvedCount,
                      Colors.green,
                      "Resolved",
                      Icons.check_circle_outline,
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: "Search Student, ID or Type...",
                prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchQuery = "";
                          _applyFilters();
                        },
                      )
                    : null,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$_currentFilter Tasks",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "${_filteredTasks.length} found",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    color: const Color(0xFF1565C0),
                    backgroundColor: Colors.white,
                    child: _filteredTasks.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.15,
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.assignment_turned_in,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "No $_currentFilter tasks",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 5, 16, 20),
                            itemCount: _filteredTasks.length,
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              return AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      0,
                                      50 * (1 - _controller.value),
                                    ),
                                    child: Opacity(
                                      opacity: _controller.value,
                                      child: _buildProfessionalCard(index),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildColoredCard(
    String title,
    int count,
    Color color,
    String filterKey,
    IconData icon,
  ) {
    bool isSelected = _currentFilter == filterKey;
    Gradient bgGradient;
    if (color == Colors.blue) {
      bgGradient = const LinearGradient(
        colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (color == Colors.orange) {
      bgGradient = const LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFF57C00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      bgGradient = const LinearGradient(
        colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _onFilterTap(filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected ? bgGradient : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 24),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white.withOpacity(0.9)
                      : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 🔥 UPDATED: HIGH-CLASS PROFESSIONAL CARD WITH AUTO-ESCALATION ---
  Widget _buildProfessionalCard(int index) {
    final task = _filteredTasks[index];
    if (task == null) return const SizedBox();

    String taskId = safeString(task['detail_id']);
    if (taskId.isEmpty) taskId = safeString(task['id']);
    String cType = safeString(task['complaint_type_detail']);
    if (cType.isEmpty) cType = safeString(task['complaint_type']);
    String cDesc = safeString(task['description_detail']);
    if (cDesc.isEmpty) cDesc = safeString(task['description']);
    String cStatus = safeString(task['status']);
    if (cStatus.isEmpty) cStatus = "Pending";
    String cName = safeString(task['student_name']);
    if (cName.isEmpty) cName = "Student";
    String firstLetter = cName.isNotEmpty ? cName[0].toUpperCase() : "S";
    String cIdentity = safeString(task['roll_number']);
    if (cIdentity.isEmpty) cIdentity = safeString(task['user_id']);
    String cDate = safeString(task['created_at']);
    bool isResolved = cStatus == 'Resolved';
    int rating = int.tryParse(safeString(task['rating'])) ?? 0;
    String feedback = safeString(task['student_feedback']);
    String rawLink = safeString(task['image_path']);
    if (rawLink.isEmpty) rawLink = safeString(task['resolution_notes']);

    // 🔥 AUTO-ESCALATION CHECK (From Database)
    bool isUrgent = (safeString(task['is_escalated']) == '1');

    bool hasImage =
        rawLink.isNotEmpty &&
        rawLink.length > 5 &&
        !rawLink.toLowerCase().contains("no image");

    String displayLink = rawLink;
    if (hasImage && !rawLink.startsWith('http')) {
      displayLink =
          "https://amirdev.site/backend/api/view_image.php?url=$rawLink";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        // 🔴 LOGIC: If Urgent -> Light Red Background, Else White
        color: isUrgent ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        // 🔴 LOGIC: If Urgent -> Solid Red Border
        border: isUrgent
            ? Border.all(color: Colors.red, width: 2)
            : (!isResolved
                  ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1)
                  : null),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status Strip
          Container(
            height: 6,
            decoration: BoxDecoration(
              // 🔴 LOGIC: If Urgent -> Red Gradient
              gradient: isUrgent
                  ? const LinearGradient(
                      colors: [Colors.red, Colors.deepOrange],
                    )
                  : (isResolved
                        ? const LinearGradient(
                            colors: [Colors.green, Colors.lightGreen],
                          )
                        : const LinearGradient(
                            colors: [Colors.deepOrange, Colors.orange],
                          )),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 SLA BREACHED BADGE (Only if Urgent)
                if (isUrgent)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          "SLA BREACHED / HIGH PRIORITY",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Header with ID & Time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "ID: #$taskId",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          // 🔴 Urgent -> Red Clock
                          color: isUrgent ? Colors.red : Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          getTimeAgo(cDate),
                          style: TextStyle(
                            color: isUrgent ? Colors.red : Colors.grey[400],
                            fontSize: 12,
                            fontWeight: isUrgent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Student Info Row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      // 🔴 Urgent -> Red Avatar
                      backgroundColor: isUrgent
                          ? Colors.red.shade100
                          : Colors.blue.shade50,
                      child: Text(
                        firstLetter,
                        style: TextStyle(
                          color: isUrgent
                              ? Colors.red.shade900
                              : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            cIdentity,
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Divider(height: 1),
                ),

                Text(
                  cType,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    // 🔴 Urgent -> Red Heading
                    color: isUrgent
                        ? Colors.red.shade900
                        : const Color(0xFF263238),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "PROBLEM DETAILS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade300,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        cDesc,
                        style: TextStyle(
                          color: Colors.blueGrey.shade800,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (hasImage)
                  GestureDetector(
                    onTap: () => _openLink(displayLink),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          image: DecorationImage(
                            image: NetworkImage(displayLink),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (rating > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFECB3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Student Feedback",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF8F00),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < rating ? Icons.star : Icons.star_border,
                                  size: 18,
                                  color: const Color(0xFFFFC107),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (feedback.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '"$feedback"',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.blue,
                        ),
                        tooltip: "Chat with Student",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                complaintId: taskId,
                                chatPartnerName: cName,
                                currentUserId: widget.resolverId,
                                isResolver: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isResolved
                            ? null
                            : () => _handleResolve(index, taskId),
                        icon: Icon(
                          isResolved ? Icons.check_circle : Icons.task_alt,
                          size: 16,
                        ),
                        label: Text(isResolved ? "COMPLETED" : "RESOLVE"),
                        style: ElevatedButton.styleFrom(
                          // 🔴 Urgent -> Red Button until Resolved
                          backgroundColor: (isUrgent && !isResolved)
                              ? Colors.red
                              : const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
