import 'package:flutter/material.dart';
import 'package:frontend/api/api_client.dart';
import 'package:frontend/utils/error_utils.dart';

class SessionAttendancePage extends StatefulWidget {
  final String sessionId;

  const SessionAttendancePage({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<SessionAttendancePage> createState() => _SessionAttendancePageState();
}

class _SessionAttendancePageState extends State<SessionAttendancePage> {
  Map<String, dynamic>? _sessionData;
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, attended, absent

  @override
  void initState() {
    super.initState();
    _loadSessionAttendance();
  }

  Future<void> _loadSessionAttendance() async {
    try {
      setState(() => _isLoading = true);
      final response = await ApiClient.I.getSessionAttendance(widget.sessionId);

      if (mounted) {
        setState(() {
          _sessionData = response;
          _students = (response['students'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final message = formatErrorWithContext(
          e,
          action: 'load session attendance',
          reasons: const [
            'Session ID is invalid or expired',
            'Server rejected the request due to missing permissions',
            'Network connection timed out while fetching data',
          ],
          fallback: 'Failed to load attendance',
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_filterStatus == 'all') return _students;
    if (_filterStatus == 'attended') {
      return _students.where((s) => s['attendance_status'] == true).toList();
    }
    if (_filterStatus == 'absent') {
      return _students.where((s) => s['attendance_status'] == false).toList();
    }
    return _students;
  }

  int get _attendedCount =>
      _students.where((s) => s['attendance_status'] == true).length;
  int get _absentCount =>
      _students.where((s) => s['attendance_status'] == false).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        title: Text(
          _sessionData?['session_title'] ?? 'Session Attendance',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSessionAttendance,
          ),
        ],
      ),
      body: Column(
        children: [
          // Session Info Header
          if (_sessionData != null) _buildSessionHeader(),

          // Filter Tabs
          _buildFilterTabs(),

          // Students List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _filterStatus == 'all'
                                  ? Icons.people_outline
                                  : _filterStatus == 'attended'
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filterStatus == 'all'
                                  ? 'No students found'
                                  : _filterStatus == 'attended'
                                      ? 'No students attended'
                                      : 'No students absent',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          return _buildStudentCard(student);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sessionData!['session_title'] ?? 'Untitled Session',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Students',
                  _students.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Attended',
                  _attendedCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Absent',
                  _absentCount.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildFilterTab('all', 'All', _students.length),
          _buildFilterTab('attended', 'Attended', _attendedCount),
          _buildFilterTab('absent', 'Absent', _absentCount),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String status, String label, int count) {
    final isSelected = _filterStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = student['name'] as String? ?? 'Unknown Student';
    final email = student['email'] as String? ?? 'unknown@email.com';
    final isAttended = student['attendance_status'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1E1E1E),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAttended ? Colors.green : Colors.red,
          child: Icon(
            isAttended ? Icons.check : Icons.close,
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          email,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isAttended
                ? Colors.green.withOpacity(0.2)
                : Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAttended ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Text(
            isAttended ? 'Attended' : 'Absent',
            style: TextStyle(
              color: isAttended ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
