import 'package:flutter/material.dart';
import 'package:frontend/repositories/attendance_repository.dart';

class ManageLeaveRequestPage extends StatefulWidget {
  final Map<String, dynamic> leave;
  const ManageLeaveRequestPage({super.key, required this.leave});

  @override
  State<ManageLeaveRequestPage> createState() => _ManageLeaveRequestPageState();
}

class _ManageLeaveRequestPageState extends State<ManageLeaveRequestPage> {
  final AttendanceRepository _repo = AttendanceRepository();
  bool _submitting = false;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    setState(() => _submitting = true);
    try {
      await _repo.reviewLeave(
        leaveId: widget.leave['_id'].toString(),
        decision: decision,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Leave ${decision == 'approved' ? 'approved' : 'rejected'}')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final userId = leave['userId']?.toString() ?? '';
    final start = leave['startDate']?.toString() ?? '';
    final end = leave['endDate']?.toString() ?? '';
    final reason = leave['reason']?.toString() ?? '';
    final status = leave['status']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Manage Leave', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0f1d3a),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: $userId',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('From: $start',
                  style: const TextStyle(color: Colors.white70)),
              Text('To: $end', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              const Text('Reason', style: TextStyle(color: Colors.white70)),
              Text(reason, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              const Text('Note (optional)',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add a note for the student',
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
              if (status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _submitting ? null : () => _decide('rejected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _submitting ? null : () => _decide('approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Approve'),
                      ),
                    ),
                  ],
                )
              else
                Text('Status: $status',
                    style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
