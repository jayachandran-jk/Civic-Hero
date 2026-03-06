import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../auth_service.dart';
import '../data_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Stats & Filter State
  String sortType = "Priority";
  int agingDays = 0;
  String searchQuery = '';
  
  // View State
  bool _darkMode = false;
  bool _showHeatmap = true;
  bool _showPrediction = false;

  // Real Filter Settings
  List<String> _selectedCategories = [];
  List<String> _selectedStatuses = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final dataService = Provider.of<DataService>(context, listen: false);
      dataService.fetchData().then((_) {
        dataService.sortData("Priority");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors (Premium Palette)
    // User requested "any other shade of grey" for cards.
    // We use Slate-50 for cards and Slate-200 for background to create a premium grey-on-grey layered look.
    final bgCol = _darkMode ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0); // Slate-900 or Slate-200
    final cardCol = _darkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC); // Slate-800 or Slate-50
    final textCol = _darkMode ? Colors.white : const Color(0xFF0F172A);
    final accentCol = _darkMode ? const Color(0xFF818CF8) : const Color(0xFF4F46E5); // Indigo-400 or Indigo-600

    return Scaffold(
      backgroundColor: bgCol,
      body: Consumer<DataService>(
        builder: (_, ds, __) {
          if (ds.isLoading) return const Center(child: CircularProgressIndicator());
          
          // --- Data Preparation ---
          final filteredIssues = _filterIssues(ds.data);
          
          // Separate Active vs Resolved
          final activeIssues = filteredIssues.where((i) => (i['status'] ?? '').toString().toLowerCase() != 'resolved').toList();
          final resolvedIssues = filteredIssues.where((i) => (i['status'] ?? '').toString().toLowerCase() == 'resolved').toList();

          final clusteredList = _groupIssuesForList(activeIssues);
          final clusteredResolvedList = _groupIssuesForList(resolvedIssues);

          final urgencyCounts = _calculateUrgencyCounts(ds.data);
          final riskZones = _calculateRiskZones(activeIssues);

          return Row(
            children: [
              // ===== SIDEBAR (Navigation & Controls) =====
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: cardCol,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: accentCol, size: 28),
                          const SizedBox(width: 12),
                          Text("CivicAdmin", 
                            style: TextStyle(color: textCol, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)
                          ),
                        ],
                      ),
                    ),
                    
                    // Main Menu
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildSectionHeader("OVERVIEW", textCol),
                          _buildStatRow("Total Reports", ds.data.length, textCol, accentCol),
                          _buildStatRow("Visible Issues", filteredIssues.length, textCol, Colors.orange),
                          
                          const SizedBox(height: 24),
                          _buildSectionHeader("PRIORITY STATUS", textCol),
                          ...['Critical', 'High', 'Medium', 'Low'].map((lvl) => 
                              _buildUrgencyRow(lvl, urgencyCounts[lvl] ?? 0, textCol)),

                          const SizedBox(height: 24),
                          _buildSectionHeader("DEPARTMENT LEADERBOARD", textCol),
                          _buildLeaderboard(ds.data, textCol),
                        ],
                      ),
                    ),

                    // Bottom Controls (Organized)
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: textCol.withOpacity(0.1)))
                        ),
                        child: Column(
                            children: [
                                _buildToggleRow("Dark Mode", _darkMode, (v) => setState(() => _darkMode = v), textCol, Icons.dark_mode),
                                _buildToggleRow("AI Risk Map", _showPrediction, (v) => setState(() => _showPrediction = v), textCol, Icons.auto_graph),
                                _buildToggleRow("Show Map", _showHeatmap, (v) => setState(() => _showHeatmap = v), textCol, Icons.map),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => Provider.of<AuthService>(context, listen: false).signOut(),
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: const Text("Sign Out"),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                      side: const BorderSide(color: Colors.redAccent),
                                      minimumSize: const Size(double.infinity, 40)
                                  ),
                                )
                            ],
                        ),
                    )
                  ],
                ),
              ),

              // ===== MAIN CONTENT =====
              Expanded(
                child: Column(
                  children: [
                    // Top Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardCol,
                        border: Border(bottom: BorderSide(color: textCol.withOpacity(0.05))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: textCol),
                              decoration: InputDecoration(
                                hintText: "Search issues by type or address...",
                                hintStyle: TextStyle(color: textCol.withOpacity(0.4)),
                                prefixIcon: Icon(Icons.search, color: textCol.withOpacity(0.4)),
                                border: InputBorder.none,
                                filled: true,
                                fillColor: bgCol,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: accentCol)),
                              ),
                              onChanged: (v) => setState(() => searchQuery = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(Icons.filter_list, color: textCol.withOpacity(0.7)),
                            onPressed: () => _openFilterDialog(context, ds),
                            tooltip: "Filters",
                          ),
                           IconButton(
                            icon: Icon(Icons.refresh, color: textCol.withOpacity(0.7)),
                            onPressed: () {
                                ds.fetchData().then((_) => ds.sortData("Priority"));
                            },
                             tooltip: "Refresh",
                          ),
                        ],
                      ),
                    ),

                    // Content Area (Scrollable)
                    Expanded(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    if (_showHeatmap) ...[
                                        Text("Geospatial Overview", style: TextStyle(color: textCol, fontSize: 18, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 16),
                                        Container(
                                            height: 300, // Reduced from 400
                                            decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                                            ),
                                            child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: Stack(
                                                    children: [
                                                        FlutterMap(
                                                            options: MapOptions(
                                                                initialCenter: const LatLng(20.5937, 78.9629),
                                                                initialZoom: 5,
                                                            ),
                                                            children: [
                                                                TileLayer(
                                                                    urlTemplate: _darkMode 
                                                                        ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" // Dark map tiles
                                                                        : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                                                                    subdomains: const ['a', 'b', 'c'],
                                                                ),
                                                                
                                                                // AI Prediction Layer (Dynamic)
                                                                if (_showPrediction)
                                                                    CircleLayer(circles: riskZones),

                                                                // Main Markers
                                                                MarkerClusterLayerWidget(
                                                                    options: MarkerClusterLayerOptions(
                                                                        maxClusterRadius: 80,
                                                                        size: const Size(44, 44),
                                                                        markers: filteredIssues.map((i) => _buildMarker(i)).toList(),
                                                                        builder: (context, markers) => _buildClusterMarker(markers),
                                                                    ),
                                                                ),
                                                            ],
                                                        ),
                                                        if (_showPrediction)
                                                            Positioned(
                                                                top: 16, right: 16,
                                                                child: _buildRiskLegend(),
                                                            )
                                                    ],
                                                ),
                                            ),
                                        ),
                                        const SizedBox(height: 32),
                                    ],

                                    Row(
                                        children: [
                                            Text("Incident Feed", style: TextStyle(color: textCol, fontSize: 18, fontWeight: FontWeight.w600)),
                                            const Spacer(),
                                            PopupMenuButton<String>(
                                                icon: Icon(Icons.sort, color: textCol),
                                                onSelected: (val) {
                                                    setState(() => sortType = val);
                                                    _sortData(ds, val);
                                                },
                                                itemBuilder: (_) => ["Priority", "Latest", "Oldest"].map((t) => PopupMenuItem(value: t, child: Text(t))).toList(),
                                            )
                                        ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    if (activeIssues.isEmpty && resolvedIssues.isEmpty)
                                        Center(child: Padding(
                                          padding: const EdgeInsets.all(32.0),
                                          child: Text("No issues found matching criteria", style: TextStyle(color: textCol.withOpacity(0.5))),
                                        ))
                                    else ...[
                                        // Active Section
                                        ...clusteredList.map((item) => 
                                            item.isCluster 
                                                ? _buildClusterCardUI(item, cardCol, textCol)
                                                : _buildIssueCardUI(item.issue!, cardCol, textCol, accentCol)
                                        ),

                                        if (resolvedIssues.isNotEmpty) ...[
                                            const SizedBox(height: 32),
                                            Row(
                                                children: [
                                                    Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text("Resolved Archive", style: TextStyle(color: textCol, fontSize: 18, fontWeight: FontWeight.w600)),
                                                ],
                                            ),
                                            const SizedBox(height: 16),
                                            ...clusteredResolvedList.map((item) => 
                                                item.isCluster 
                                                    ? _buildClusterCardUI(item, cardCol, textCol)
                                                    : _buildIssueCardUI(item.issue!, cardCol, textCol, accentCol)
                                            ),
                                        ]
                                    ],
                                ],
                            ),
                        ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============== LOGIC & HELPERS ==============

  List<Map<String, dynamic>> _filterIssues(List<Map<String, dynamic>> all) {
      final now = DateTime.now();
      return all.where((issue) {
            if (agingDays != 0) {
              final reported = DateTime.tryParse(issue['reported_date'] ?? '');
              if (reported == null || now.difference(reported).inDays > agingDays) return false;
            }
            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              final type = (issue['issue_type'] ?? '').toString().toLowerCase();
              final addr = (issue['address'] ?? '').toString().toLowerCase();
              if (!type.contains(q) && !addr.contains(q)) return false;
            }
            // Category & Status Filters
            if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(issue['issue_type'])) return false;
            if (_selectedStatuses.isNotEmpty && !_selectedStatuses.contains(issue['status'])) return false;

            return true;
      }).toList();
  }

  void _updateClusterStatus(BuildContext context, List<Map<String, dynamic>> group, String newStatus) async {
    final ds = Provider.of<DataService>(context, listen: false);
    int count = 0;
    for (var issue in group) {
      if ((issue['status'] ?? '').toString().toLowerCase() != newStatus.toLowerCase()) {
        await ds.updateIssueStatus(issue['id'], newStatus);
        count++;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Updated $count issues to $newStatus."),
      backgroundColor: newStatus == 'Resolved' ? Colors.green : (newStatus == 'In Progress' ? Colors.orange : Colors.blue),
    ));
  }

  // --- Dynamic AI Risk Calculation ---
  List<CircleMarker> _calculateRiskZones(List<Map<String, dynamic>> issues) {
      if (issues.isEmpty) return [];
      
      // 1. Filter for High/Critical issues
      final riskyIssues = issues.where((i) {
          final u = _getDynamicUrgency(i);
          return u == 'Critical' || u == 'High';
      }).toList();

      if (riskyIssues.isEmpty) return [];

      // 2. Simple Grid Clustering (simulating density analysis)
      // Round Lat/Lng to 1 decimal place (~11km). Group by that key.
      final grid = <String, List<Map<String, dynamic>>>{};
      
      for (var i in riskyIssues) {
          final lat = (i['latitude'] as double?) ?? 0;
          final lng = (i['longitude'] as double?) ?? 0;
          if (lat == 0 && lng == 0) continue;
          
          final key = "${lat.toStringAsFixed(1)},${lng.toStringAsFixed(1)}";
          grid.putIfAbsent(key, () => []).add(i);
      }

      final markers = <CircleMarker>[];
      grid.forEach((key, group) {
          if (group.isEmpty) return;
          // Centroid
          double sumLat = 0, sumLng = 0;
          for (var i in group) {
              sumLat += (i['latitude'] as double);
              sumLng += (i['longitude'] as double);
          }
          final center = LatLng(sumLat / group.length, sumLng / group.length);
          
          // Density Score based on count & avg priority
          final count = group.length;
          // Visual: Larger/Redder if more critical issues
          final isSevere = count > 3 || group.any((i) => _getDynamicUrgency(i) == 'Critical');

          markers.add(CircleMarker(
              point: center,
              color: isSevere ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.2),
              borderStrokeWidth: 2,
              borderColor: isSevere ? Colors.red.withOpacity(0.6) : Colors.orange.withOpacity(0.5),
              useRadiusInMeter: false, // Use pixels for visual emphasis regardless of zoom
              radius: min(30 + (count * 10).toDouble(), 100), // Cap size
          ));
      });

      return markers;
  }

  // --- Map Markers ---
  Marker _buildMarker(Map<String, dynamic> issue) {
      final urgency = _getDynamicUrgency(issue);
      final pVal = _urgencyToInt(urgency);
      return Marker(
          key: ValueKey(issue['id'] ?? 'unknown_${issue['latitude']}_${issue['longitude']}'),
          point: LatLng((issue['latitude'] as double?) ?? 0, (issue['longitude'] as double?) ?? 0),
          width: 30, height: 30,
          child: GestureDetector(
              onTap: () => _showIssueDetails(issue),
              child: Container(
                  decoration: BoxDecoration(
                      color: _urgencyColor(urgency),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))]
                  ),
              ),
          ),
      );
  }

  Widget _buildClusterMarker(List<Marker> markers) {
      int maxP = 0;
      for (var m in markers) {
          if (m.key is ValueKey<int>) {
              final p = (m.key as ValueKey<int>).value;
              if (p > maxP) maxP = p;
          }
      }
      final color = _priorityIntToColor(maxP);
      return GestureDetector(
          onTap: () {
              // On cluster tap, we could show a list or just zoom in
              // For now, let's just let the cluster handle itself (usually expands)
          },
          child: Container(
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 4))]
          ),
          child: Center(
              child: Text(markers.length.toString(), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
          ),
          ),
      );
  }

  void _showIssueDetails(Map<String, dynamic> issue) {
    final urgency = _getDynamicUrgency(issue);
    final color = _urgencyColor(urgency);
    final textCol = _darkMode ? Colors.white : const Color(0xFF0F172A);
    final cardCol = _darkMode ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardCol,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(issue['issue_type'] ?? 'Issue Details', 
                    style: TextStyle(color: textCol, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textCol.withOpacity(0.5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (issue['image_url'] != null && issue['image_url'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _getImageUrl(issue['image_url']),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: textCol.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.broken_image, color: textCol.withOpacity(0.2), size: 48),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 250,
                        width: double.infinity,
                        color: textCol.withOpacity(0.05),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: textCol.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, color: textCol.withOpacity(0.2), size: 32),
                      const SizedBox(height: 8),
                      Text("No image provided", style: TextStyle(color: textCol.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                ),
                
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(urgency.toUpperCase(), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: textCol.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                    child: Text((issue['status'] ?? 'Reported').toString().toUpperCase(), 
                      style: TextStyle(color: textCol.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              Text("Description", style: TextStyle(color: textCol.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(issue['description'] ?? 'No description provided', 
                style: TextStyle(color: textCol, fontSize: 15, height: 1.5)
              ),
              
              const SizedBox(height: 20),
              Text("Location", style: TextStyle(color: textCol.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(issue['address'] ?? 'Unknown location', style: TextStyle(color: textCol, fontSize: 14))),
                ],
              ),
              
              const SizedBox(height: 20),
              Text("Reported On", style: TextStyle(color: textCol.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(issue['reported_date'] ?? 'Unknown date', style: TextStyle(color: textCol, fontSize: 14)),
              
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Back", style: TextStyle(color: textCol.withOpacity(0.6))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Done"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getImageUrl(String path) {
    if (path.isEmpty) return "";
    if (path.startsWith('http')) return path;
    
    String cleanPath = path;
    if (path.startsWith('gs://')) {
      cleanPath = path.replaceFirst(RegExp(r'gs://[^/]+/'), '');
    }
    
    final encodedPath = Uri.encodeComponent(cleanPath);
    return "https://firebasestorage.googleapis.com/v0/b/civicissue-aae6d.firebasestorage.app/o/$encodedPath?alt=media";
  }



  // --- UI Components ---

  Widget _buildToggleRow(String label, bool value, Function(bool) onChanged, Color textColor, IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
            children: [
                Icon(icon, size: 18, color: textColor.withOpacity(0.6)),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500))),
                Transform.scale(
                    scale: 0.8,
                    child: Switch(
                        value: value, 
                        onChanged: onChanged,
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF4F46E5),
                    ),
                )
            ],
        ),
      );
  }

  Widget _buildIssueCardUI(Map<String, dynamic> issue, Color bg, Color text, Color accent, {bool isChild = false}) {
      final urgency = _getDynamicUrgency(issue);
      final color = _urgencyColor(urgency);
      
      return GestureDetector(
          onTap: () => _showIssueDetails(issue),
          child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isChild ? Colors.transparent : text.withOpacity(0.05)),
                  boxShadow: isChild ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
                children: [
                    Container(
                        width: 4, height: 40,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    children: [
                                        Text(issue['issue_type'] ?? 'Issue', style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(width: 8),
                                        Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                            child: Text(urgency.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                    ],
                                ),
                                const SizedBox(height: 4),
                                Text(issue['description'] ?? '', 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: text.withOpacity(0.6), fontSize: 13)
                                ),
                                const SizedBox(height: 4),
                                Row(
                                    children: [
                                        Icon(Icons.location_on, size: 12, color: text.withOpacity(0.4)),
                                        const SizedBox(width: 4),
                                         Expanded(
                                          child: Text(issue['address'] ?? '', 
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: text.withOpacity(0.4), fontSize: 12)
                                          ),
                                        ),
                                    ],
                                )
                            ],
                        ),
                    ),
                    DropdownButton<String>(
                        value: ['Reported', 'In Progress', 'Resolved'].contains(issue['status']) ? issue['status'] : 'Reported',
                        underline: const SizedBox(),
                        style: TextStyle(color: text, fontSize: 12),
                        items: ['Reported', 'In Progress', 'Resolved'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) {
                            if (v != null) Provider.of<DataService>(context, listen: false).updateIssueStatus(issue['id'], v);
                            setState(() => issue['status'] = v);
                        }
                    )
                ],
            ),
          ),
          ),
      );
  }
  
  Widget _buildClusterCardUI(ListItemModel item, Color bg, Color text) {
      // Find highest urgency in cluster
      String topUrgency = "Low";
      int maxScore = 0;
      for(var i in item.group) {
          int s = _calculatePriorityScore(i).toInt();
          if(s > maxScore) { maxScore = s; topUrgency = _getDynamicUrgency(i); }
      }
      final iconColor = _urgencyColor(topUrgency);
      
      // Determine Cluster Name
      final types = item.group.map((i) => i['issue_type'] ?? 'Issue').toSet();
      final title = types.length == 1 ? "${item.group.length} ${types.first}s" : "${item.group.length} Mixed Issues";

      return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: bg, 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: text.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4)],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
                leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                    child: Center(child: Text('${item.group.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
                title: Text(title, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Highest Priority: $topUrgency", style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.w500)),
                trailing: PopupMenuButton<String>(
                    onSelected: (val) => _updateClusterStatus(context, item.group, val),
                    icon: Icon(Icons.more_vert, color: text.withOpacity(0.5)),
                    tooltip: "Update Status",
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'Reported', child: Text("Mark all Reported")),
                      const PopupMenuItem(value: 'In Progress', child: Text("Mark all In Progress")),
                      const PopupMenuItem(value: 'Resolved', child: Text("Mark all Resolved")),
                    ],
                  ),
                children: item.group.map((i) => Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                    child: _buildIssueCardUI(i, bg, text, Colors.blue, isChild: true),
                )).toList(),
            ),
          ),
      );
  }

  Widget _buildUrgencyRow(String label, int count, Color textCol) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
            children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _urgencyColor(label))),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(color: textCol, fontSize: 13))),
                Text(count.toString(), style: TextStyle(color: textCol.withOpacity(0.6), fontWeight: FontWeight.bold)),
            ],
        ),
      );
  }
  
  Widget _buildStatRow(String label, int count, Color textCol, Color accent) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
              children: [
                  Expanded(child: Text(label, style: TextStyle(color: textCol.withOpacity(0.8), fontSize: 13))),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(count.toString(), style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
              ],
          ),
      );
  }

  Widget _buildSectionHeader(String title, Color color) {
      return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(title, style: TextStyle(color: color.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      );
  }
  
  Widget _buildLeaderboard(List<Map<String, dynamic>> data, Color textCol) {
      final  counts = <String, int>{};
      for(var i in data) {
          if((i['status']??'').toString().toLowerCase() == 'resolved') {
              final d = i['department'] ?? 'General';
              counts[d] = (counts[d] ?? 0) + 1;
          }
      }
      if(counts.isEmpty) return Padding(padding: const EdgeInsets.all(8.0), child: Text("No resolutions yet", style: TextStyle(color: textCol.withOpacity(0.5), fontSize: 12)));

      final sorted = counts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
      return Column(
          children: sorted.take(4).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                  children: [
                      Expanded(child: Text(e.key, style: TextStyle(color: textCol, fontSize: 13))),
                      Text("${e.value} ✔", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))
                  ],
              ),
          )).toList(),
      );
  }
  
  Widget _buildRiskLegend() {
      return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Text("AI Risk Analysis", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Row(children: [Icon(Icons.circle, color: Colors.redAccent, size: 10), SizedBox(width: 4), Text("High Danger Density", style: TextStyle(fontSize: 10))]),
                  Row(children: [Icon(Icons.circle, color: Colors.orangeAccent, size: 10), SizedBox(width: 4), Text("Elevated Risk", style: TextStyle(fontSize: 10))]),
              ],
          ),
      );
  }

  // --- Utility Logic ---
  
  Map<String, int> _calculateUrgencyCounts(List<Map<String, dynamic>> data) {
       final c = <String, int>{};
       for(var i in data) {
           final u = _getDynamicUrgency(i);
           c[u] = (c[u] ?? 0) + 1;
       }
       return c;
  }

  double _calculatePriorityScore(Map<String, dynamic> issue) {
    final baseScores = {'low': 10.0, 'medium': 15.0, 'high': 25.0, 'critical': 40.0};
    final urgency = (issue['urgency'] ?? 'medium').toString().toLowerCase();
    double score = baseScores[urgency] ?? 15.0;

    try {
      final reported = DateTime.tryParse(issue['reported_date'] ?? '');
      if (reported != null) {
        final daysOld = DateTime.now().difference(reported).inDays;
        double ageFactor = (daysOld / 7) * 2.5; 
        if (ageFactor > 30) ageFactor = 30;
        score += ageFactor;
      }
    } catch (_) {}
    if ((issue['status'] ?? '').toString().toLowerCase() == 'reported') score += 10.0;
    return score.clamp(0, 100);
  }

  String _getDynamicUrgency(Map<String, dynamic> issue) {
      double score = _calculatePriorityScore(issue);
      if (score >= 60) return 'Critical';
      if (score >= 40) return 'High';
      if (score >= 25) return 'Medium';
      return 'Low';
  }
  
  int _urgencyToInt(String u) {
      switch(u.toLowerCase()) {
          case 'critical': return 4;
          case 'high': return 3;
          case 'medium': return 2;
          default: return 1;
      }
  }

  Color _priorityIntToColor(int p) {
      switch(p) {
          case 4: return Colors.purple;
          case 3: return Colors.red;
          case 2: return Colors.orange;
          default: return Colors.green; 
      }
  }
   Color _urgencyColor(String? u) {
    switch ((u ?? '').toLowerCase()) {
      case 'critical': return Colors.purple;
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _sortData(DataService ds, String value) {
    if (value == 'Priority') {
        ds.data.sort((a, b) => _calculatePriorityScore(b).compareTo(_calculatePriorityScore(a)));
    } else if (value == 'Latest') {
        ds.data.sort((a, b) {
            final da = DateTime.tryParse(a['reported_date'] ?? '') ?? DateTime.now();
            final db = DateTime.tryParse(b['reported_date'] ?? '') ?? DateTime.now();
            return db.compareTo(da);
        });
    } else if (value == 'Oldest') {
        ds.data.sort((a, b) {
             final da = DateTime.tryParse(a['reported_date'] ?? '') ?? DateTime.now();
            final db = DateTime.tryParse(b['reported_date'] ?? '') ?? DateTime.now();
            return da.compareTo(db);
        });
    }
  }

  // --- Helpers ---
  List<ListItemModel> _groupIssuesForList(List<Map<String, dynamic>> issues) {
      if (issues.isEmpty) return [];
      final List<ListItemModel> result = [];
      final Set<String> processedIds = {};
      const double threshold = 0.0005; 

      for (int i = 0; i < issues.length; i++) {
        final current = issues[i];
        if (processedIds.contains(current['id'])) continue;
        final clusterGroup = [current];
        processedIds.add(current['id']);
        final double lat1 = (current['latitude'] as double?) ?? 0;
        final double lng1 = (current['longitude'] as double?) ?? 0;

        for (int j = i + 1; j < issues.length; j++) {
            final next = issues[j];
            if (processedIds.contains(next['id'])) continue;
             final double lat2 = (next['latitude'] as double?) ?? 0;
             final double lng2 = (next['longitude'] as double?) ?? 0;
             if ((lat1 - lat2).abs() < threshold && (lng1 - lng2).abs() < threshold) {
                 clusterGroup.add(next);
                 processedIds.add(next['id']);
             }
        }
        result.add(clusterGroup.length > 1 ? ListItemModel.cluster(clusterGroup) : ListItemModel.single(current));
    }
    return result;
  }
  
  // Dialog (Functional)
  Future<void> _openFilterDialog(BuildContext context, DataService ds) async {
    final allTypes = ds.allTypes;
    final statuses = ['Reported', 'In Progress', 'Resolved'];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Advanced Filters"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Filter by Category", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: allTypes.map((t) {
                        final isSelected = _selectedCategories.contains(t);
                        return FilterChip(
                          label: Text(t),
                          selected: isSelected,
                          onSelected: (v) {
                            setDialogState(() {
                               if (v) _selectedCategories.add(t);
                               else _selectedCategories.remove(t);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text("Filter by Status", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: statuses.map((s) {
                        final isSelected = _selectedStatuses.contains(s);
                        return FilterChip(
                          label: Text(s),
                          selected: isSelected,
                          onSelected: (v) {
                            setDialogState(() {
                               if (v) _selectedStatuses.add(s);
                               else _selectedStatuses.remove(s);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() { _selectedCategories.clear(); _selectedStatuses.clear(); });
                    Navigator.pop(context);
                  },
                  child: const Text("Reset All", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Trigger refresh in parent
                    Navigator.pop(context);
                  },
                  child: const Text("Apply Filters"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ListItemModel {
    final bool isCluster;
    final Map<String, dynamic>? issue;
    final List<Map<String, dynamic>> group;
    ListItemModel.single(this.issue) : isCluster = false, group = [issue!];
    ListItemModel.cluster(this.group) : isCluster = true, issue = null;
}
