import 'package:flutter/material.dart';
import 'package:frontend/repositories/attendance_repository.dart';

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key});

  @override
  State<AttendanceRecordsPage> createState() => _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> {
  final AttendanceRepository _repo = AttendanceRepository();

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];
  String _studentSortBy = 'name'; // name, uid, email
  bool _studentSortAscending = true;

  bool _loading = false;
  bool _loadingStudents = false;
  String? _error;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _records = [];
  String? _selectedUid;
  final Map<String, Map<String, dynamic>> _perStudentStats = {};
  final Set<String> _loadingStatsFor = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loadingStudents = true;
      _error = null;
    });
    try {
      final res = await _repo.studentsByBatch(limit: 300);
      if (!mounted) return;
      setState(() {
        _students = res;
        _filtered = res;
      });
      _applySort();
    } catch (e) {
      if (!mounted) return;
      final err = e.toString();
      // If professor has no batch, show a popup and navigate back to dashboard
      if (err.contains('batch_missing') || err.contains('batch_required')) {
        _showBatchMissingDialog();
        return;
      }
      setState(() => _error = err);
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  void _showBatchMissingDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Batch Not Configured',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'You are not associated with any batch. Please set your batch to view student attendance.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Go to Dashboard',
                  style: TextStyle(color: Color(0xFFB39DDB))),
            ),
          ],
        );
      },
    );
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filtered = _students;
        _applySort(insetState: false);
      });
      return;
    }
    setState(() {
      _filtered = _students
          .where((s) =>
              (s['name']?.toString().toLowerCase().contains(q) ?? false) ||
              (s['uid']?.toString().toLowerCase().contains(q) ?? false) ||
              (s['email']?.toString().toLowerCase().contains(q) ?? false))
          .toList();
      _applySort(insetState: false);
    });
  }

  void _applySort({bool insetState = true}) {
    void sorter() {
      _filtered.sort((a, b) {
        String av, bv;
        switch (_studentSortBy) {
          case 'uid':
            av = (a['uid'] ?? '').toString().toLowerCase();
            bv = (b['uid'] ?? '').toString().toLowerCase();
            break;
          case 'email':
            av = (a['email'] ?? '').toString().toLowerCase();
            bv = (b['email'] ?? '').toString().toLowerCase();
            break;
          case 'name':
          default:
            av = (a['name'] ?? '').toString().toLowerCase();
            bv = (b['name'] ?? '').toString().toLowerCase();
            break;
        }
        return _studentSortAscending ? av.compareTo(bv) : bv.compareTo(av);
      });
    }

    if (insetState) {
      setState(sorter);
    } else {
      sorter();
    }
  }

  Widget _buildSortChip(String sortBy, String label) {
    final isSelected = _studentSortBy == sortBy;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_studentSortBy == sortBy) {
            _studentSortAscending = !_studentSortAscending;
          } else {
            _studentSortBy = sortBy;
            _studentSortAscending = true;
          }
          _applySort(insetState: false);
        });
      },
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
                _studentSortAscending
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 16,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadFor(String uid) async {
    setState(() {
      _loading = true;
      _error = null;
      _records = [];
      _stats = null;
      _selectedUid = uid;
    });
    try {
      final res = await _repo.studentAttendanceRecords(userId: uid, limit: 100);
      if (!mounted) return;
      setState(() {
        final rawRecords = res['records'];
        if (rawRecords is List) {
          _records = rawRecords
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          _records = [];
        }
        final rawStats = res['stats'];
        _stats = rawStats is Map ? Map<String, dynamic>.from(rawStats) : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStatsFor(String uid) async {
    if (_loadingStatsFor.contains(uid)) return;
    setState(() => _loadingStatsFor.add(uid));
    try {
      final res = await _repo.studentAttendanceRecords(userId: uid, limit: 0);
      final rawStats = res['stats'];
      final stats =
          rawStats is Map ? Map<String, dynamic>.from(rawStats) : null;
      if (!mounted) return;
      if (stats != null) {
        setState(() => _perStudentStats[uid] = stats);
      }
    } catch (e) {
      // silently ignore per-item stats failures, could show a toast
    } finally {
      if (mounted) setState(() => _loadingStatsFor.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Attendance',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0f1d3a),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E1E1E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name / uid / email',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white54),
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
                    onChanged: _applySearch,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Sort by:',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      _buildSortChip('name', 'Name'),
                      const SizedBox(width: 8),
                      _buildSortChip('uid', 'UID'),
                      const SizedBox(width: 8),
                      _buildSortChip('email', 'Email'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingStudents) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildStudentList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_error != null) {
      final msg = 'Failed to load students: $_error';
      return _EmptyState(message: msg);
    }
    if (_filtered.isEmpty) {
      return const _EmptyState(message: 'No students found');
    }
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final s = _filtered[index];
        final name = s['name']?.toString() ?? 'Unnamed';
        final uid = s['uid']?.toString() ?? '';
        final email = s['email']?.toString() ?? '';
        final selected = uid == _selectedUid;
        final stats = _perStudentStats[uid];
        final percent = (stats?['attendancePercent'] as num?)?.toDouble() ?? 0;
        final attended = (stats?['attended'] as num?)?.toInt() ?? 0;
        final missed = (stats?['missed'] as num?)?.toInt() ?? 0;
        final leave = (stats?['leave'] as num?)?.toInt() ?? 0;
        return Card(
          color: selected ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _loadFor(uid),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.badge, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(uid, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(email,
                            style: const TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Attended',
                          attended.toString(),
                          Icons.check_circle,
                          Colors.greenAccent,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Missed',
                          missed.toString(),
                          Icons.cancel,
                          Colors.redAccent,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Leave',
                          leave.toString(),
                          Icons.airplane_ticket,
                          Colors.blueAccent,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Percent',
                          '${percent.toStringAsFixed(1)}%',
                          Icons.trending_up,
                          percent >= 75
                              ? Colors.green
                              : percent >= 50
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _loadStatsFor(uid),
                      icon: _loadingStatsFor.contains(uid)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, color: Colors.blue),
                      label: const Text('Refresh Stats',
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    final percent = (_stats?['attendancePercent'] as num?)?.toDouble() ?? 0;
    final attended = (_stats?['attended'] as num?)?.toInt() ?? 0;
    final missed = (_stats?['missed'] as num?)?.toInt() ?? 0;
    final leave = (_stats?['leave'] as num?)?.toInt() ?? 0;
    final total = (_stats?['totalSessions'] as num?)?.toInt() ?? 0;
    final percentColor = percent >= 75
        ? Colors.green
        : percent >= 50
            ? Colors.orange
            : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Attendance',
                  '${percent.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  percentColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Attended',
                  attended.toString(),
                  Icons.check_circle,
                  Colors.greenAccent,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Missed',
                  missed.toString(),
                  Icons.cancel,
                  Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Leave',
                  leave.toString(),
                  Icons.airplane_ticket,
                  Colors.blueAccent,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total',
                  total.toString(),
                  Icons.people,
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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

  Widget _buildRecordsList() {
    // No longer used in single-list layout; return an empty widget
    return const SizedBox.shrink();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFB39DDB).withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFB39DDB)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
