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
