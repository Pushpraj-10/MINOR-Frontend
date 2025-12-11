import 'package:flutter/material.dart';
import 'package:frontend/repositories/attendance_repository.dart';
import 'package:frontend/screens/professor/attendance-record/manage_leave_request.dart';

class LeaveRequestsPage extends StatefulWidget {
  const LeaveRequestsPage({super.key});

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> {
  final AttendanceRepository _repo = AttendanceRepository();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _filtered = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.listLeaves(status: 'pending');
      if (!mounted) return;
      setState(() {
        _leaves = res;
        _filtered = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _searchQuery = q;
      if (query.isEmpty) {
        _filtered = _leaves;
      } else {
        _filtered = _leaves.where((leave) {
          final userId = (leave['userId']?.toString() ?? '').toLowerCase();
          final reason = (leave['reason']?.toString() ?? '').toLowerCase();
          return userId.contains(query) || reason.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Leave Requests', style: TextStyle(color: Colors.white)),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by student id or reason...',
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
                  if (_loading) const LinearProgressIndicator(),
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
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: Colors.redAccent)),
                              )
                            ],
                          )
                        : _filtered.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No pending requests',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                  )
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final leave = _filtered[index];
                                  final userId =
                                      leave['userId']?.toString() ?? '';
                                  final start =
                                      leave['startDate']?.toString() ?? '';
                                  final end =
                                      leave['endDate']?.toString() ?? '';
                                  final reason =
                                      leave['reason']?.toString() ?? '';
                                  return Card(
                                    color: const Color(0xFF1E1E1E),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () async {
                                        final changed =
                                            await Navigator.of(context)
                                                .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ManageLeaveRequestPage(
                                                    leave: leave),
                                          ),
                                        );
                                        if (changed == true) {
                                          _load();
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Student: $userId',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: const Text(
                                                    'Pending',
                                                    style: TextStyle(
                                                      color: Colors.orange,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.event,
                                                    size: 16,
                                                    color: Colors.white70),
                                                const SizedBox(width: 6),
                                                Text('From: $start',
                                                    style: const TextStyle(
                                                        color: Colors.white70)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.event_busy,
                                                    size: 16,
                                                    color: Colors.white70),
                                                const SizedBox(width: 6),
                                                Text('To: $end',
                                                    style: const TextStyle(
                                                        color: Colors.white70)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.messenger,
                                                    size: 16,
                                                    color: Colors.white70),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    'Reason: $reason',
                                                    style: const TextStyle(
                                                        color: Colors.white70),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.chevron_right,
                                                      color: Colors.white54),
                                                  SizedBox(width: 4),
                                                  Text('Manage',
                                                      style: TextStyle(
                                                          color: Colors.blue)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
