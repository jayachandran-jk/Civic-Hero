import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class DataService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _rawData = [];   // all individual issues
  List<Map<String, dynamic>> _filteredData = []; // data after applying filters
  bool _isLoading = false;
  String? _error;

  // Filters
  List<String> selectedTypes = [];
  List<String> selectedDepartments = [];
  List<String> selectedUserIds = [];
  List<String> selectedLocations = [];
  List<String> selectedUrgencies = [];
  DateTime? startDate;
  DateTime? endDate;

  // Convenience getters
  List<Map<String, dynamic>> get data => _filteredData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Unique values for dropdowns (from raw data)
  List<String> get allTypes => _unique('issue_type');
  List<String> get allDepartments => _unique('department');
  List<String> get allUsers => _unique('user_id');
  List<String> get allLocations => _unique('address');

  // ------------------- Fetch All Issues -------------------
  Future<void> fetchData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('📥 Admin: Fetching all issues from Firestore...');
      
      // Use collection('issues') instead of collectionGroup('issues')
      final snap = await _firestore
          .collection('issues')
          .orderBy('reported_date', descending: true)
          .get();

      print('✅ Admin: Fetched ${snap.docs.length} issues from Firestore');

      final List<Map<String, dynamic>> allIssues = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id, // Use document ID, not full path
          'complain_id': d['complain_id'] ?? doc.id,
          'issue_type': d['issue_type'] ?? 'Unknown',
          'latitude': (d['latitude'] is double) 
              ? d['latitude'] 
              : double.tryParse(d['latitude']?.toString() ?? '') ?? 0.0,
          'longitude': (d['longitude'] is double)
              ? d['longitude']
              : double.tryParse(d['longitude']?.toString() ?? '') ?? 0.0,
          'address': d['address'] ?? '',
          'description': d['description'] ?? '',
          'status': d['status'] ?? 'Reported',
          'urgency': d['urgency'] ?? 'Medium',
          'reported_date': d['reported_date'] ?? '',
          'user_id': d['user_id'] ?? '',
          'department': d['department'] ?? '',
          'image_url': d['image_url'] ?? '',
        };
      }).toList();

      print('✅ Admin: Processed ${allIssues.length} issues');

      _rawData = allIssues;
      _applyFilters();   // <-- immediately apply current filters
    } catch (e, stackTrace) {
      _error = e.toString();
      print('❌ Admin: Error fetching data: $e');
      print('📚 Stack trace: $stackTrace');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ------------------- Update issue status -------------------
  Future<void> updateIssueStatus(String docId, String newStatus) async {
    try {
      print('🔄 Admin: Updating issue $docId status to $newStatus');
      
      // Find the issue to get user_id, department, and issue_type
      final issue = _rawData.firstWhere(
        (issue) => issue['id'] == docId,
        orElse: () => {},
      );
      
      final userId = issue['user_id'] ?? '';
      final department = issue['department'] ?? '';
      final issueType = issue['issue_type'] ?? '';
      
      // Update Firestore
      await _firestore.collection('issues').doc(docId).update({
        'status': newStatus,
      });
      print('✅ Admin: Status updated successfully');
      
      // Send notification (don't wait for it, fire and forget)
      _sendNotification(
        complaintId: docId,
        userId: userId,
        newStatus: newStatus,
        department: department,
        issueType: issueType,
      );
      
      // Update local data immediately
      final index = _rawData.indexWhere((issue) => issue['id'] == docId);
      if (index != -1) {
        _rawData[index]['status'] = newStatus;
        _applyFilters();
        notifyListeners();
      }
      // Refresh from server to ensure consistency
      await fetchData();
    } catch (e) {
      debugPrint('❌ Admin: Status update failed: $e');
      _error = 'Failed to update status: $e';
      notifyListeners();
    }
  }

  // ------------------- Send Notification -------------------
  Future<void> _sendNotification({
    required String complaintId,
    required String userId,
    required String newStatus,
    required String department,
    required String issueType,
  }) async {
    try {
      // Only send for specific statuses
      final notifyStatuses = ['assigned', 'in progress', 'resolved', 'completed'];
      if (!notifyStatuses.contains(newStatus.toLowerCase())) {
        print('⏭️  Status "$newStatus" not in notification list, skipping...');
        return;
      }

      if (userId.isEmpty) {
        print('⚠️  No userId found, skipping notification...');
        return;
      }

      // Notification server URL (use 127.0.0.1 for Flutter web compatibility)
      const notificationUrl = 'http://127.0.0.1:3000/notify-status-change';
      
      print('📬 Sending notification to user $userId...');
      print('   URL: $notificationUrl');
      print('   Complaint ID: $complaintId');
      print('   Status: $newStatus');
      print('   Department: $department');
      
      final response = await http.post(
        Uri.parse(notificationUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'complaintId': complaintId,
          'userId': userId,
          'newStatus': newStatus,
          'department': department,
          'issueType': issueType,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️  Notification request timeout');
          throw TimeoutException('Notification request timeout');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          print('✅ Notification sent successfully');
          if (result['results'] != null) {
            print('   SMS: ${result['results']['sms']}');
            print('   Email: ${result['results']['email']}');
          }
        } else {
          print('⚠️  Notification sent but with warnings: ${result['error'] ?? 'Unknown'}');
        }
      } else {
        print('⚠️  Notification failed with status ${response.statusCode}');
        print('   Response: ${response.body}');
      }
    } catch (e, stackTrace) {
      // Don't fail the status update if notification fails
      print('⚠️  Notification error (non-critical): $e');
      print('   Stack trace: $stackTrace');
    }
  }

  // ------------------- Filters -------------------
  void updateFilters(
    List<String> types,
    List<String> depts,
    List<String> users,
    List<String> locs,
    DateTime? start,
    DateTime? end,
    List<String> urgencies,
  ) {
    selectedTypes = types;
    selectedDepartments = depts;
    selectedUserIds = users;
    selectedLocations = locs;
    selectedUrgencies = urgencies;
    startDate = start;
    endDate = end;
    _applyFilters();
    notifyListeners();
  }

  void resetFilters() {
    selectedTypes.clear();
    selectedDepartments.clear();
    selectedUserIds.clear();
    selectedLocations.clear();
    selectedUrgencies.clear();
    startDate = null;
    endDate = null;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredData = _rawData.where((issue) {
      final t = selectedTypes.isEmpty || selectedTypes.contains(issue['issue_type']);
      final d = selectedDepartments.isEmpty || selectedDepartments.contains(issue['department']);
      final u = selectedUserIds.isEmpty || selectedUserIds.contains(issue['user_id']);
      final l = selectedLocations.isEmpty ||
          selectedLocations.any((loc) =>
              (issue['address'] as String).toLowerCase().contains(loc.toLowerCase()));
      final urg = selectedUrgencies.isEmpty || selectedUrgencies.contains(issue['urgency']);

      bool dateOK = true;
      if (startDate != null || endDate != null) {
        final issueDate = DateTime.tryParse(issue['reported_date'] ?? '');
        if (issueDate == null) return false;
        if (startDate != null && issueDate.isBefore(startDate!)) dateOK = false;
        if (endDate != null && issueDate.isAfter(endDate!)) dateOK = false;
      }
      return t && d && u && l && urg && dateOK;
    }).toList();
  }

  // ------------------- Sorting -------------------
  void sortData(String type) {
    int compareDate(a, b) {
      final dateA = DateTime.tryParse(a['reported_date'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['reported_date'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA); // Latest first
    }

    if (type == 'Latest') {
      _filteredData.sort(compareDate);
    } else if (type == 'Oldest') {
      _filteredData.sort((a, b) => compareDate(b, a));
    } else if (type == 'Priority' || type == 'Priority Descending') {
      const priorityOrder = {'Low': 1, 'Medium': 2, 'High': 3, 'Critical': 4};
      _filteredData.sort((a, b) {
        final pa = priorityOrder[(a['urgency'] ?? 'Medium').toString()] ?? 2;
        final pb = priorityOrder[(b['urgency'] ?? 'Medium').toString()] ?? 2;
        return pb.compareTo(pa); // Higher priority first
      });
    } else if (type == 'Priority Ascending') {
      const priorityOrder = {'Low': 1, 'Medium': 2, 'High': 3, 'Critical': 4};
      _filteredData.sort((a, b) {
        final pa = priorityOrder[(a['urgency'] ?? 'Medium').toString()] ?? 2;
        final pb = priorityOrder[(b['urgency'] ?? 'Medium').toString()] ?? 2;
        return pa.compareTo(pb); // Lower priority first
      });
    }
    notifyListeners();
  }

  // ------------------- Helpers -------------------
  List<String> _unique(String field) =>
      _rawData.map((e) => e[field]?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
          ..sort();
}
