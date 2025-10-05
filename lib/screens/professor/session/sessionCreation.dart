import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:frontend/api/api_client.dart';

class CreatePassPage extends StatefulWidget {
  const CreatePassPage({super.key});

  @override
  State<CreatePassPage> createState() => _CreatePassPageState();
}

class _CreatePassPageState extends State<CreatePassPage> {
  final _formKey = GlobalKey<FormState>();

  // State for 'Session' dropdown
  final List<String> _sessions = ['CSE 2024', 'DSAI 2024', 'ECE 2024'];
  String? _selectedSession;

  // --- CHANGES START HERE ---

  // 1. Define the list for the 'Purpose' dropdown
  final List<String> _purposes = ['Lab', 'Theory', 'In', 'Out'];
  // 2. Add a state variable to hold the selected purpose
  String? _selectedPurpose;
  // 3. The TextEditingController is no longer needed for 'purpose'
  // final TextEditingController _purposeController = TextEditingController();

  // --- CHANGES END HERE ---

  int _validityMinutes = 15; // default 15 min
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedSession = _sessions.first;
    _selectedPurpose = _purposes.first; // Initialize the selected purpose
  }

  // The dispose for the controller is no longer needed
  // @override
  // void dispose() {
  //   _purposeController.dispose();
  //   super.dispose();
  // }

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
                      initialItem: _validityMinutes),
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
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title:
                const Text("Session QR", style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF121212),

            // --- FIX START ---
            // Wrap the Column in a SizedBox to give it a finite width,
            // which resolves the LayoutBuilder issue with QrImageView.
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min, // This is still important
                children: [
                  QrImageView(
                    data: (res['qrToken'] as String?) ?? '',
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  SelectableText("Token: ${res['qrToken']}",
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  Text("Valid for $_validityMinutes minutes",
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            // --- FIX END ---

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create session')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        title: const Text("Create a session",
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
                // --- FIX ---
                isExpanded: true,
                // -----------
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
                // --- FIX ---
                isExpanded: true,
                // -----------
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "$_validityMinutes minutes",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "QR Validity Duration",
                        style: TextStyle(color: Colors.white70),
                      ),
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
                        borderRadius: BorderRadius.circular(30)),
                  ),
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
