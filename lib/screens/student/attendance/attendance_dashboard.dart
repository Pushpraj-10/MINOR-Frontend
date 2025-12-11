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

class _MarkAttendanceTab extends StatefulWidget {
  const _MarkAttendanceTab();

  @override
  State<_MarkAttendanceTab> createState() => _MarkAttendanceTabState();
}

class _MarkAttendanceTabState extends State<_MarkAttendanceTab> {
  bool _checking = false;

  Future<void> _handleScanPressed(BuildContext context) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // Block scanning when student has any pending request
      final leaves = await ApiClient.I.listMyLeaves();
      final hasPending =
          leaves.any((l) => (l['status'] as String?) == 'pending');
      if (hasPending) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'You have a pending leave request. Scanning is disabled.')),
        );
        return;
      }
      // Block scanning when student has an approved active leave for today
      final hasActiveApproved = await ApiClient.I.hasActiveApprovedLeave();
      if (hasActiveApproved) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'You are currently on approved leave. Scanning is disabled.')),
        );
        return;
      }
      if (!mounted) return;
      context.push('/student/attendance/scan');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check leave status: $e')),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

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
              onPressed: _checking ? null : () => _handleScanPressed(context),
              label: _checking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Open Scanner'),
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
            const Text('Failed to load stats',
                style: TextStyle(color: Colors.white)),
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
          _SummaryGrid(
            percent: percent,
            total: total,
            attended: attended,
            leave: leave,
            missed: missed,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Missed Sessions',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Color(0xFFB39DDB)),
                label: const Text('Refresh',
                    style: TextStyle(color: Color(0xFFB39DDB))),
              )
            ],
          ),
          const SizedBox(height: 8),
          if (missedSessions.isEmpty)
            const Text('No missed sessions 🎉',
                style: TextStyle(color: Colors.white70))
          else
            ...missedSessions.map((m) => _missedTile(m)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB39DDB).withOpacity(0.18)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: ListTile(
        leading:
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB39DDB)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
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

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.percent,
    required this.total,
    required this.attended,
    required this.leave,
    required this.missed,
  });

  final double percent;
  final int total;
  final int attended;
  final int leave;
  final int missed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final cardWidth =
            isNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _GaugeCard(
              title: 'Attendance',
              percent: percent.clamp(0, 100),
              width: cardWidth,
              accent: const Color(0xFFB39DDB),
              subtitle: 'Target ≥ 75% to stay eligible',
            ),
            _StatCard(
                title: 'Total Sessions',
                value: '$total',
                width: cardWidth,
                icon: Icons.event_note),
            _StatCard(
                title: 'Attended',
                value: '$attended',
                width: cardWidth,
                icon: Icons.check_circle_outline),
            _StatCard(
                title: 'Leave',
                value: '$leave',
                width: cardWidth,
                icon: Icons.beach_access_outlined),
            _StatCard(
                title: 'Missed',
                value: '$missed',
                width: cardWidth,
                icon: Icons.close_rounded),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    this.accent,
    this.width,
    this.icon,
  });

  final String title;
  final String value;
  final Color? accent;
  final double? width;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFFB39DDB);
    return Container(
      width: width ?? 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(icon, color: color, size: 22),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.title,
    required this.percent,
    required this.width,
    this.subtitle,
    this.accent,
  });

  final String title;
  final double percent; // 0..100
  final double width;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? const Color(0xFFB39DDB);
    final progress = (percent.clamp(0, 100)) / 100.0;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  color: Colors.white12,
                  backgroundColor: Colors.transparent,
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  color: color,
                  backgroundColor: Colors.transparent,
                ),
                Text('${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }
}
