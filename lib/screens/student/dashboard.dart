import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/api/api_client.dart';
import 'dart:math';
import 'dart:convert';
import 'package:frontend/services/biometric_service.dart';
import 'package:flutter/services.dart';
import 'package:frontend/utils/error_utils.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final me = await ApiClient.I.me();
      if (!mounted) return;
      setState(() {
        _name = (me['user']?['name'] as String?) ?? 'Student';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final message = formatErrorWithContext(
        e,
        action: 'load your profile',
        reasons: const [
          'Session expired, please log in again',
          'Poor or no internet connectivity',
          'Server is temporarily unavailable',
        ],
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _logout() async {
    try {
      await ApiClient.I.logout();
    } finally {
      if (!mounted) return;
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Image.asset("assets/images/IIITNR_Logo.png", height: 24, width: 24),
            const SizedBox(width: 8),
            Text(
              _loading ? 'Loading...' : 'Welcome, ${_name ?? 'Student'}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'logout') _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildTile(context, Icons.warning, "Complaint"),
                  _buildTile(context, Icons.directions_walk, "Gatepass"),
                  _buildTile(context, Icons.shopping_cart, "Buy/Sell"),
                  _buildTile(context, Icons.contacts, "Contacts"),
                  _buildTile(context, Icons.search, "Found/Lost"),
                  _buildTile(
                      context, Icons.help_outline, "Contact\nDevelopers"),
                  _buildTile(context, Icons.calendar_today, "Attendance"),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Happy b'day gatepass",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "One year since the IIIT NR app launched. "
                    "Still crashes less than our GPA.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: Image.asset(
                        "assets/images/Anniversary.png",
                        height: 300,
                        width: 300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        if (label == "Attendance") {
          _handleAttendance(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFB39DDB),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // NEW BIOMETRIC LOGIC (matching final MainActivity.kt)
  // ======================================================
  Future<void> _handleAttendance(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final result = await ApiClient.I.biometricCheck();
      Navigator.of(context).pop();

      final String status = result['status'] ?? 'none';

      switch (status) {
        case 'none':
          await _showRegisterDialog(context);
          break;

        case 'pending':
          await _showAwaitingApproval(context);
          break;

        case 'approved':
          context.push('/student/attendance');
          break;

        case 'revoked':
          await _showReRegisterDialog(context);
          break;

        default:
          await _error(
            context,
            withPossibleReasons(
              'Unknown biometric status: $status',
              reasons: const [
                'App is outdated and does not recognize the new status',
                'Server returned malformed data',
              ],
            ),
          );
      }
    } catch (e) {
      Navigator.of(context).pop();
      await _error(context, "Failed: $e");
    }
  }

  Future<void> _showRegisterDialog(BuildContext context) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Register Device'),
        content: const Text(
            'No biometric key registered. Do you want to register this device?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Register')),
        ],
      ),
    );

    if (choice == true) {
      await _performRegistration(context);
    }
  }

  Future<void> _performRegistration(BuildContext context) async {
    try {
      // Ask native for face availability
      final status = await BiometricService.getFaceStatus();

      if (status == 'not_available') {
        await _error(context, "Biometrics not available on this device");
        return;
      }

      if (status == 'not_enrolled') {
        final open = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Setup Biometrics"),
            content: const Text("No biometrics enrolled. Open settings?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings')),
            ],
          ),
        );

        if (open == true) {
          await BiometricService.openBiometricEnroll();
        }
        return;
      }

      // Generate keypair
      final pem = await BiometricService.generateAndGetPublicKeyPem();

      // Test signing process (this will prompt biometric)
      final challenge =
          base64Encode(List.generate(32, (_) => Random().nextInt(256)));

      await BiometricService.signChallenge(challenge);

      // Register with backend
      await ApiClient.I.registerBiometricKey(publicKeyPem: pem);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registration Complete'),
          content: const Text(
              'Your device key has been registered. Wait for admin approval.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    } on PlatformException catch (e) {
      await _error(context, e.message ?? "Biometric error");
    } catch (e) {
      await _error(context, "Registration failed: $e");
    }
  }

  Future<void> _showAwaitingApproval(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Awaiting Approval'),
        content: const Text(
            'Your key is registered but not approved yet. Please wait.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _showReRegisterDialog(BuildContext context) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Re-register Device'),
        content: const Text('Your biometric key was revoked. Register again?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Re-register')),
        ],
      ),
    );

    if (choice == true) {
      await _performRegistration(context);
    }
  }

  Future<void> _error(BuildContext context, String msg) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }
}
