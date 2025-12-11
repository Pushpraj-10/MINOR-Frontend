import 'package:flutter/material.dart';
import 'package:frontend/api/api_client.dart';
import 'package:frontend/utils/error_utils.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final _reasonController = TextEditingController();
  bool _submitting = false;
  bool _loading = true;
  String? _error;
  DateTimeRange? _range;
  Map<String, dynamic>? _pendingLeave;

  @override
  void initState() {
    super.initState();
    _loadPendingLeave();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final maxEnd = firstDate.add(const Duration(days: 30));

    final previous = _range;
    final fallback = DateTimeRange(start: firstDate, end: firstDate);

    final initialRange =
        previous == null ? fallback : _clampRange(previous, firstDate, maxEnd);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: maxEnd,
      initialDateRange: initialRange,
      builder: _datePickerBuilder,
    );

    if (picked == null) return; // cancelled

    // Normalize selected dates (strip time)
    final start = _truncateToDate(picked.start);
    final end = _truncateToDate(picked.end);

    // ⭐ If user did NOT pick a second date -> use start = end
    final isSingleSelection = picked.start == picked.end;

    final finalRange = isSingleSelection
        ? DateTimeRange(start: start, end: start)
        : DateTimeRange(start: start, end: end);

    // Validate range
    final days = finalRange.end.difference(finalRange.start).inDays + 1;
    if (days > 30) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum leave is 30 days")),
      );
      return;
    }

    setState(() => _range = finalRange);
  }

  Future<void> _submit() async {
    if (_range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range')),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for leave')),
      );
      return;
    }

    final daysSelected = _range!.end.difference(_range!.start).inDays + 1;
    if (daysSelected > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum leave is 30 days')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final resp = await ApiClient.I.requestLeaveRange(
        startDate: _range!.start,
        endDate: _range!.end,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted')),
      );
      setState(() {
        _pendingLeave = resp['leave'] as Map<String, dynamic>? ?? resp;
      });
      await _loadPendingLeave();
    } catch (err) {
      if (!mounted) return;
      final msg = formatError(err, fallback: 'Failed to submit leave');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _datePickerBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB39DDB),
          onPrimary: Colors.white,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
          secondary: Color(0xFFB39DDB),
        ),
        textTheme: Theme.of(context)
            .textTheme
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
        dialogBackgroundColor: const Color(0xFF121212),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Color(0x338C6BC3),
          selectionHandleColor: Color(0xFFB39DDB),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          hintStyle: const TextStyle(color: Colors.white70),
          labelStyle: const TextStyle(color: Colors.white70),
          floatingLabelStyle: const TextStyle(color: Colors.white),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFB39DDB), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFB39DDB), width: 1.5),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: const Color(0xFF121212),
          surfaceTintColor: const Color.fromARGB(0, 0, 0, 0),
          headerBackgroundColor: const Color(0xFF0f1d3a),
          headerForegroundColor: Colors.white,
          dayForegroundColor:
              WidgetStateProperty.resolveWith((states) => Colors.white),
          dayStyle: const TextStyle(color: Colors.white),
          yearForegroundColor: const WidgetStatePropertyAll(Colors.white),
          weekdayStyle: const TextStyle(color: Colors.white70),
          dayOverlayColor: const WidgetStatePropertyAll(Color(0x338C6BC3)),
        ),
        textButtonTheme: TextButtonThemeData(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFB39DDB))),
      ),
      child: child!,
    );
  }

  DateTime _truncateToDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _fmtDate(DateTime date) => date.toLocal().toString().split(' ').first;

  Future<void> _loadPendingLeave() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final leaves = await ApiClient.I.listMyLeaves();
      if (!mounted) return;

      Map<String, dynamic>? pending;
      if (leaves.isNotEmpty) {
        pending = leaves.firstWhere(
          (l) => (l['status'] as String?) == 'pending',
          orElse: () => {},
        );
        if (pending.isEmpty) pending = null;
      }

      setState(() {
        _pendingLeave = pending;
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

  DateTimeRange _clampRange(DateTimeRange range, DateTime min, DateTime max) {
    var start = range.start.isBefore(min) ? min : range.start;
    var end = range.end.isAfter(max) ? max : range.end;
    if (end.isBefore(start)) {
      end = start;
    }
    return DateTimeRange(
        start: _truncateToDate(start), end: _truncateToDate(end));
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load leave status',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPendingLeave,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB39DDB)),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_pendingLeave != null) {
      final pending = _pendingLeave!;
      final start = pending['startDate'] != null
          ? DateTime.tryParse(pending['startDate'].toString())
          : null;
      final end = pending['endDate'] != null
          ? DateTime.tryParse(pending['endDate'].toString())
          : null;
      final status = (pending['status'] ?? 'pending').toString();
      final isSingleDay = start != null && end != null && start == end;
      final dateText = start != null && end != null
          ? (isSingleDay
              ? _fmtDate(start)
              : '${_fmtDate(start)}  →  ${_fmtDate(end)}')
          : '—';

      Color statusColor;
      switch (status) {
        case 'approved':
          statusColor = const Color(0xFF4CAF50);
          break;
        case 'rejected':
          statusColor = const Color(0xFFE53935);
          break;
        default:
          statusColor = const Color(0xFFB39DDB);
      }

      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your leave request',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Material(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'approved'
                              ? Icons.check_circle
                              : status == 'rejected'
                                  ? Icons.cancel
                                  : Icons.pending,
                          color: statusColor,
                        ),
                        const SizedBox(width: 8),
                        const Text('Status',
                            style: TextStyle(color: Colors.white70)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status.toUpperCase(),
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Dates',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(dateText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    if (pending['reason'] != null) ...[
                      const SizedBox(height: 12),
                      const Text('Reason',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(pending['reason'].toString(),
                          style: const TextStyle(color: Colors.white)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadPendingLeave,
              icon: const Icon(Icons.refresh, color: Color(0xFFB39DDB)),
              label: const Text('Refresh status',
                  style: TextStyle(color: Color(0xFFB39DDB))),
            ),
          ],
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave dates',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickRange,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _range == null
                    ? 'Select date range'
                    : (_range!.start == _range!.end
                        ? '${_range!.start.toLocal().toString().split(' ').first}'
                        : '${_range!.start.toLocal().toString().split(' ').first}  to  ${_range!.end.toLocal().toString().split(' ').first}'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe why you are taking leave',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB39DDB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Leave',
                        style: TextStyle(color: Colors.black),
                      ),
              ),
            )
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Request Leave',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0f1d3a),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(child: body),
    );
  }
}
