import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class CreateSessionQRPage extends StatefulWidget {
  final String sessionId;

  const CreateSessionQRPage({super.key, required this.sessionId});

  @override
  State<CreateSessionQRPage> createState() => _CreateSessionQRPageState();
}

class _CreateSessionQRPageState extends State<CreateSessionQRPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _validFromController =
      TextEditingController(text: DateTime.now().toIso8601String());
  final TextEditingController _validUntilController = TextEditingController();
  final TextEditingController _maxUsesController =
      TextEditingController(text: '0');

  bool _isSubmitting = false;
  String? _error;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final data = {
        "sessionId": widget.sessionId,
        "validFrom": _validFromController.text.isEmpty
            ? null
            : _validFromController.text,
        "validUntil": _validUntilController.text.isEmpty
            ? null
            : _validUntilController.text,
        "maxUses": int.tryParse(_maxUsesController.text) ?? 0,
      };

      const token = "";

      final response = await http.post(
        Uri.parse("http://localhost:4000/professors/generate-session-qr"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];

        // Show QR code popup
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Session QR"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: token,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                    const SizedBox(height: 16),
                    SelectableText("Token: $token"),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      } else {
        setState(() {
          _error = "Failed to create session (status ${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    controller.text = dt.toIso8601String();
  }

  @override
  void dispose() {
    _validFromController.dispose();
    _validUntilController.dispose();
    _maxUsesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generate Session QR")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _validFromController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Valid From (optional)",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _pickDateTime(_validFromController),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _validUntilController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Valid Until (optional)",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _pickDateTime(_validUntilController),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxUsesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Max Uses (0 = unlimited)",
                ),
                validator: (value) {
                  final v = int.tryParse(value ?? '');
                  if (v == null || v < 0)
                    return "Must be 0 or positive integer";
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text("Create Session"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
