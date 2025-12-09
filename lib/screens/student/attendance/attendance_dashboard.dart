import 'package:flutter/material.dart';
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
        body: const TabBarView(
          children: [
            _MarkAttendanceTab(),
            _TakeLeaveTab(),
            _RecordsTab(),
          ],
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

class _RecordsTab extends StatelessWidget {
  const _RecordsTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Attendance Records',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Attendance statistics will appear here. This section will be wired to backend data once available.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
