import 'package:flutter/material.dart';
import 'package:frontend/api/api_client.dart';
import 'package:go_router/go_router.dart';

/// Student attendance dashboard with three tabs:
/// 1) Mark Attendance → opens QR scanner flow
/// 2) Take Leave → opens leave request form
/// 3) Attendance Records → placeholder for stats (awaiting backend support)
class AttendanceDashboard extends StatelessWidget {
  const AttendanceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0f1d3a),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Attendance',
            style: TextStyle(color: Colors.white),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Mark Attendance'),
              Tab(icon: Icon(Icons.event_busy), text: 'Take Leave'),
              Tab(icon: Icon(Icons.list), text: 'Records'),
            ],
          ),
        ),
        body: SafeArea(
          child: const TabBarView(
            children: [
              _MarkAttendanceTab(),
              _TakeLeaveTab(),
              _RecordsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkAttendanceTab extends StatelessWidget {
  const _MarkAttendanceTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan QR to mark attendance',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the professor\'s QR code. Your biometric key will be used to verify.',
            style: TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/student/attendance/scan'),
              label: const Text('Open Scanner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB39DDB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeLeaveTab extends StatelessWidget {
  const _TakeLeaveTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request Leave',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Submit a leave request with a reason for the current session.',
            style: TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/student/attendance/leave'),
              label: const Text('Open Leave Form'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB39DDB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

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
      final res = await ApiClient.I.getAttendanceStats();
      if (!mounted) return;
      setState(() {
        _stats = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load stats', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1f6feb)),
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }

    final stats = _stats ?? {};
    final percent = (stats['attendancePercent'] as num?)?.toDouble() ?? 0.0;
    final attended = (stats['attended'] as num?)?.toInt() ?? 0;
    final missed = (stats['missed'] as num?)?.toInt() ?? 0;
    final leave = (stats['leave'] as num?)?.toInt() ?? 0;
    final total = (stats['totalSessions'] as num?)?.toInt() ?? 0;
    final missedSessions =
        (stats['missedSessions'] as List?)?.cast<Map<String, dynamic>>() ??
            const [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance %',
                      style: TextStyle(color: Colors.white70)),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total: $total',
                      style: const TextStyle(color: Colors.white70)),
                  Text('Attended: $attended',
                      style: const TextStyle(color: Colors.white70)),
                  Text('Leave: $leave',
                      style: const TextStyle(color: Colors.white70)),
                  Text('Missed: $missed',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Missed Sessions',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (missedSessions.isEmpty)
            const Text('No missed sessions 🎉',
                style: TextStyle(color: Colors.white70))
          else
            ...missedSessions.map((m) => _missedTile(m)).toList(),
        ],
      ),
    );
  }

  Widget _missedTile(Map<String, dynamic> m) {
    final title = (m['title'] as String?)?.isNotEmpty == true
        ? m['title'] as String
        : 'Session';
    final sessionId = m['sessionId']?.toString() ?? '';
    final prof = m['professorUid']?.toString() ?? '';
    final expiredAt = m['expiredAt']?.toString();

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session: $sessionId',
                style: const TextStyle(color: Colors.white70)),
            if (prof.isNotEmpty)
              Text('Professor: $prof',
                  style: const TextStyle(color: Colors.white54)),
            if (expiredAt != null)
              Text('Expired: $expiredAt',
                  style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
