import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:frontend/api/api_client.dart';

class ProfessorSessionsListPage extends StatefulWidget {
  const ProfessorSessionsListPage({Key? key}) : super(key: key);

  @override
  State<ProfessorSessionsListPage> createState() =>
      _ProfessorSessionsListPageState();
}

class _ProfessorSessionsListPageState extends State<ProfessorSessionsListPage> {
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _filteredSessions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'start_time'; // start_time, title, attended_students
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() => _isLoading = true);
      final response = await ApiClient.I.getProfessorSessions();
      final sessions = (response['sessions'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _filteredSessions = sessions;
          _isLoading = false;
        });
        _applySorting();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sessions: $e')),
        );
      }
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredSessions = List.from(_sessions);
    } else {
      _filteredSessions = _sessions.where((session) {
        final title = (session['title'] as String? ?? '').toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    _applySorting();
  }

  void _applySorting() {
    _filteredSessions.sort((a, b) {
      dynamic aValue, bValue;

      switch (_sortBy) {
        case 'title':
          aValue = a['title'] as String? ?? '';
          bValue = b['title'] as String? ?? '';
          break;
        case 'start_time':
          aValue = DateTime.parse(a['start_time'] as String);
          bValue = DateTime.parse(b['start_time'] as String);
          break;
        case 'attended_students':
          aValue = a['attended_students'] as int? ?? 0;
          bValue = b['attended_students'] as int? ?? 0;
          break;
        default:
          aValue = a['start_time'] as String;
          bValue = b['start_time'] as String;
      }

      if (aValue is String && bValue is String) {
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      } else if (aValue is DateTime && bValue is DateTime) {
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      } else if (aValue is int && bValue is int) {
        return _sortAscending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }
      return 0;
    });
  }

  void _onSortChanged(String sortBy) {
    if (_sortBy == sortBy) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      _sortAscending = false;
    }
    _applySorting();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        title: const Text(
          'My Sessions',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search sessions...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white54),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _applySearch();
                  },
                ),
                const SizedBox(height: 12),
                // Sort Options
                Row(
                  children: [
                    const Text('Sort by:',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    _buildSortChip('start_time', 'Date'),
                    const SizedBox(width: 8),
                    _buildSortChip('title', 'Title'),
                    const SizedBox(width: 8),
                    _buildSortChip('attended_students', 'Attendance'),
                  ],
                ),
              ],
            ),
          ),
          // Sessions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSessions.isEmpty
                    ? const Center(
                        child: Text(
                          'No sessions found',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredSessions.length,
                        itemBuilder: (context, index) {
                          final session = _filteredSessions[index];
                          return _buildSessionCard(session);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String sortBy, String label) {
    final isSelected = _sortBy == sortBy;
    return GestureDetector(
      onTap: () => _onSortChanged(sortBy),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final sessionId = session['session_id'] as String;
    final title = session['title'] as String? ?? 'Untitled Session';
    final startTime = DateTime.parse(session['start_time'] as String);
    final endTime = DateTime.parse(session['end_time'] as String);
    final totalStudents = session['total_students'] as int? ?? 0;
    final attendedStudents = session['attended_students'] as int? ?? 0;

    final attendanceRate =
        totalStudents > 0 ? (attendedStudents / totalStudents) : 0.0;
    final isExpired = endTime.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E1E1E),
      child: InkWell(
        onTap: () => context.push('/professor/sessions/$sessionId/students'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red[800] : Colors.green[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isExpired ? 'Expired' : 'Active',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Time Information
              Row(
                children: [
                  const Icon(Icons.access_time,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('MMM dd, yyyy').format(startTime)} at ${DateFormat('HH:mm').format(startTime)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${endTime.difference(startTime).inMinutes} minutes',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Attendance Statistics
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total Students',
                      totalStudents.toString(),
                      Icons.people,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Attended',
                      attendedStudents.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Rate',
                      '${(attendanceRate * 100).toStringAsFixed(1)}%',
                      Icons.trending_up,
                      attendanceRate > 0.7
                          ? Colors.green
                          : attendanceRate > 0.4
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/professor/sessions/$sessionId/students'),
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    label: const Text(
                      'View Students',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 16,
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
    );
  }
}
