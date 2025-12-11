import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:frontend/api/api_client.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:frontend/api/realtime.dart';
import 'package:frontend/utils/error_utils.dart';

class CreatePassPage extends StatefulWidget {
  const CreatePassPage({super.key});

  @override
  State<CreatePassPage> createState() => _CreatePassPageState();
}

class _CreatePassPageState extends State<CreatePassPage> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _sessions = ['CSE 2024', 'DSAI 2024', 'ECE 2024'];
  final List<String> _purposes = ['Lab', 'Theory', 'In', 'Out'];
  String? _selectedSession;
  String? _selectedPurpose;

  int _validityMinutes = 15;
  bool _isSubmitting = false;
  StreamSubscription<QrTick>? _sub;
  // Notifier used so dialog can update independently of parent rebuilds
  final ValueNotifier<String?> _qrNotifier = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _selectedSession = _sessions.first;
    _selectedPurpose = _purposes.first;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _qrNotifier.dispose();
    super.dispose();
  }

  void _pickValidityMinutes() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 250,
          color: const Color(0xFF1E1E1E),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text("Select Validity (Minutes)",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              Expanded(
                child: CupertinoPicker(
                  backgroundColor: const Color(0xFF1E1E1E),
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(
                      initialItem: _validityMinutes - 1),
                  onSelectedItemChanged: (val) {
                    setState(() {
                      _validityMinutes = val + 1;
                    });
                  },
                  children: List.generate(
                    60,
                    (i) => Center(
                      child: Text(
                        "${i + 1} min",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await ApiClient.I.createSession(
        title: _selectedSession,
        durationMinutes: _validityMinutes,
      );
      final sessionId = res['sessionId'] as String?;
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      if (sessionId == null || sessionId.isEmpty)
        throw Exception('No sessionId');

      _sub?.cancel();
      _sub = RealtimeService.I
          .subscribeQrTicks(sessionId, asProfessor: true)
          .listen((tick) {
        final s = tick.toQrString();
        _qrNotifier.value = s;
        // ignore: avoid_print
        print('QR updated: $s');
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Session Token',
                style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF121212),
            content: SizedBox(
              width: double.maxFinite,
              child: ValueListenableBuilder<String?>(
                valueListenable: _qrNotifier,
                builder: (context, value, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value == null)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        )
                      else
                        Container(
                          width: 240,
                          height: 240,
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 220,
                            height: 220,
                            child: CustomPaint(
                              painter: QrPainter(
                                data: value,
                                version: QrVersions.auto,
                                gapless: true,
                                color: Colors.black,
                                emptyColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text('Valid for $_validityMinutes minutes',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
            ],
          );
        },
      );
    } catch (e, st) {
      // Log full error for debugging
      // ignore: avoid_print
      print('createSession error: $e');
      // ignore: avoid_print
      print(st);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      // Attempt to decode server error code for policy popups
      final serverCode = _extractServerCode(e);
      if (serverCode != null) {
        final info = _mapServerCodeToMessage(serverCode);
        _showPolicyDialog(context, info.title, info.message);
        return;
      }

      final message = formatErrorWithContext(
        e,
        action: 'create the session',
        reasons: const [
          'Network dropped while submitting the form',
          'Duration or payload was considered invalid by the server',
          'You already have an active session with the same title',
        ],
        fallback: 'Failed to create session',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text('Create a session',
            style: TextStyle(color: Colors.white)),
      ),
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedSession,
                items: _sessions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSession = v),
                decoration: InputDecoration(
                  labelText: 'Select Session',
                  filled: true,
                  fillColor: const Color(0xFF212022),
                  labelStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                dropdownColor: const Color(0xFF2A2830),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedPurpose,
                items: _purposes
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPurpose = v),
                decoration: InputDecoration(
                  labelText: 'Purpose',
                  filled: true,
                  fillColor: const Color(0xFF212022),
                  labelStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                dropdownColor: const Color(0xFF2A2830),
                style: const TextStyle(color: Colors.white),
                validator: (v) => v == null ? 'Please select a purpose' : null,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickValidityMinutes,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2A282C),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text('$_validityMinutes minutes',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('QR Validity Duration',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDCC8FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30))),
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Generate',
                          style: TextStyle(fontSize: 18, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// QR rendering is handled by `qr_flutter`'s QrImage which accepts a QrCode object.
// We no longer use a local painter.

// --- Helpers to present clear policy messages from backend error codes ---
/// Best-effort extraction of a backend `code` field from common error shapes.
String? _extractServerCode(Object error) {
  try {
    final dynamicErr = error as dynamic;
    final resp = dynamicErr?.response;
    final data = resp?.data ?? dynamicErr?.data;
    if (data is Map && data['code'] is String) return data['code'] as String;
    if (data is Map &&
        data['error'] is Map &&
        (data['error'] as Map)['code'] is String) {
      return (data['error'] as Map)['code'] as String;
    }
    if (dynamicErr?.code is String) return dynamicErr.code as String;
  } catch (_) {
    // swallow
  }
  return null;
}

/// Simple container for dialog info (title + message)
class PolicyInfo {
  final String title;
  final String message;
  PolicyInfo(this.title, this.message);
}

/// Maps server code to a dialog title and body.
PolicyInfo _mapServerCodeToMessage(String code) {
  switch (code) {
    case 'daily_session_limit_exceeded':
      return PolicyInfo(
        'Daily Limit Reached',
        'You can only create two sessions per day: one between 9:00–13:00 and another between 14:00–18:00. Please try again tomorrow or adjust your schedule.',
      );
    case 'outside_allowed_window':
      return PolicyInfo(
        'Outside Allowed Time',
        'Sessions may only be created between 9:00–13:00 or 14:00–18:00. Please create the session during one of these windows.',
      );
    case 'window_already_used':
      return PolicyInfo(
        'Window Already Used',
        'You have already created a session in this window today. You can create at most one session in each window (9:00–13:00 and 14:00–18:00).',
      );
    case 'batch_missing':
    case 'batch_required':
      return PolicyInfo(
        'No Batch Configured',
        'You are not associated with any batch. Please set up your batch in the profile or contact an administrator.',
      );
    default:
      return PolicyInfo(
        'Session Creation Failed',
        'The server rejected the request. Please verify details and try again.',
      );
  }
}

void _showPolicyDialog(BuildContext ctx, String title, String message) {
  showDialog(
    context: ctx,
    builder: (context) {
      return AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF121212),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
