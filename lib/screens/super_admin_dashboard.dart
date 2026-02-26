import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart'; // 🔥 CHART IMPORT ADDED
import 'auth/login_screen.dart';
import '../services/api_service.dart';
import 'resolver_management_screen.dart';
import 'assignment_control_screen.dart';
import 'dart:convert'; // ✅ Added for Hive
import 'package:hive_flutter/hive_flutter.dart'; // ✅ Added for Hive

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});
  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  Map<String, dynamic> stats = {
    "total": 0,
    "pending": 0,
    "resolved": 0,
    "departments": [],
  };

  List<dynamic> _filteredDepts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _searchController.addListener(_runFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runFilter() {
    final String query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredDepts = List.from(stats['departments'] ?? []);
      } else {
        _filteredDepts = (stats['departments'] as List).where((dept) {
          final String label = (dept['label'] ?? "General")
              .toString()
              .toLowerCase();
          return label.contains(query);
        }).toList();
      }
    });
  }

  // --- 🔥 HIVE NOSQL CACHING LOGIC ---
  Future<void> _fetchStats() async {
    if (!mounted) return;

    var box = Hive.box('appBox');
    const String cacheKey = 'admin_master_stats';

    // 1. INSTANT LOAD FROM HIVE
    String? cachedData = box.get(cacheKey);
    if (cachedData != null) {
      try {
        Map<String, dynamic> localData = jsonDecode(cachedData);
        if (mounted) {
          setState(() {
            stats = localData;
            _filteredDepts = List.from(stats['departments'] ?? []);
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
      Map<String, dynamic> freshStats = {
        "total": result['total'] ?? 0,
        "pending": result['pending'] ?? 0,
        "resolved": result['resolved'] ?? 0,
        "departments": result['departments'] ?? [],
      };

      // 3. SAVE TO HIVE & UPDATE UI SILENTLY
      box.put(cacheKey, jsonEncode(freshStats));

      if (mounted) {
        setState(() {
          stats = freshStats;
          _filteredDepts = List.from(stats['departments']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && cachedData == null) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          "Command Center",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 🔍 SEARCH BAR
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search categories...",
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.indigo,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // 2. ⚡ ACTION CARDS
              _buildHeavyActionCard(
                "Manage Team",
                "Register or Remove Resolvers",
                Icons.people_alt_rounded,
                const Color(0xFF6366F1),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResolverManagementScreen(),
                  ),
                ).then((_) => _fetchStats()),
              ),
              _buildHeavyActionCard(
                "Assignment Rules",
                "Define Department Routing",
                Icons.alt_route_rounded,
                const Color(0xFF0EA5E9),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AssignmentControlScreen(),
                  ),
                ).then((_) => _fetchStats()),
              ),

              const SizedBox(height: 30),

              // 🔥 3. UPGRADED PREMIUM PIE CHART
              const Text(
                "Analytics Overview",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 15),
              _buildDepartmentPieChart(),
              const SizedBox(height: 30),

              // 4. 📊 STATS TILES
              Row(
                children: [
                  _buildStatTile(
                    "Total",
                    stats['total'].toString(),
                    const Color(0xFF3B82F6),
                    Icons.analytics_outlined,
                  ),
                  const SizedBox(width: 10),
                  _buildStatTile(
                    "Pending",
                    stats['pending'].toString(),
                    const Color(0xFFF59E0B),
                    Icons.pending_outlined,
                  ),
                  const SizedBox(width: 10),
                  _buildStatTile(
                    "Resolved",
                    stats['resolved'].toString(),
                    const Color(0xFF10B981),
                    Icons.check_circle_outline,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // 5. 📂 DEPARTMENT LIST
              const Text(
                "Category Breakdown",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 15),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredDepts.length,
                      itemBuilder: (context, index) {
                        var dept = _filteredDepts[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.folder_rounded,
                                color: Colors.indigo,
                              ),
                            ),
                            title: Text(
                              dept['label'] ?? "General",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${dept['value']}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 🔥 PIE CHART WIDGET LOGIC (NEW RESPONSIVE UI) ---
  Widget _buildDepartmentPieChart() {
    if (_filteredDepts.isEmpty) return const SizedBox();

    // 🎨 Premium Professional Colors
    List<Color> colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF43F5E), // Rose
    ];

    int total = int.tryParse(stats['total'].toString()) ?? 1;
    if (total == 0) total = 1;

    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];

    // Filter and Sort: Only show depts that have complaints
    var activeDepts = _filteredDepts
        .where((d) => (int.tryParse(d['value'].toString()) ?? 0) > 0)
        .toList();
    activeDepts.sort(
      (a, b) => (int.tryParse(b['value'].toString()) ?? 0).compareTo(
        int.tryParse(a['value'].toString()) ?? 0,
      ),
    );

    for (int i = 0; i < activeDepts.length; i++) {
      var dept = activeDepts[i];
      double count = double.tryParse(dept['value'].toString()) ?? 0;
      double percentage = (count / total) * 100;
      Color currentColor = colors[i % colors.length];

      // Add to Chart
      sections.add(
        PieChartSectionData(
          color: currentColor,
          value: count,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
      );

      // Add to Legend (Wrap logic for long names)
      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "${dept['label'] ?? 'Dept'} ($count)",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (sections.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 3,
              ),
            ),
          ),
          const SizedBox(height: 25),
          // Legend below the chart in a Wrap layout
          Wrap(
            spacing: 15,
            runSpacing: 5,
            alignment: WrapAlignment.center,
            children: legendItems,
          ),
        ],
      ),
    );
  }

  // --- 📊 STATS TILES UI ---
  Widget _buildStatTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ⚡ ACTION CARDS UI ---
  Widget _buildHeavyActionCard(
    String title,
    String sub,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
