import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/api/api_client.dart';
import 'dart:math';
import 'dart:convert';
import 'package:frontend/services/biometric_service.dart';
import 'package:flutter/services.dart';

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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      backgroundColor: const Color(0xFF121212), // Dark mode background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white, // Set the color for all icons in the AppBar
        ),
        title: Row(
          children: [
            // App logo
            Image.asset(
              "assets/images/IIITNR_Logo.png",
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _loading ? 'Loading...' : 'Welcome, ${_name ?? 'Student'}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
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
            // Grid Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDashboardTile(context, Icons.warning, "Complaint"),
                  _buildDashboardTile(
                      context, Icons.directions_walk, "Gatepass"),
                  _buildDashboardTile(context, Icons.shopping_cart, "Buy/Sell"),
                  _buildDashboardTile(context, Icons.contacts, "Contacts"),
                  _buildDashboardTile(context, Icons.search, "Found/Lost"),
                  _buildDashboardTile(
                      context, Icons.help_outline, "Contact\nDevelopers"),
                  _buildDashboardTile(
                      context, Icons.calendar_today, "Attendance"),
                ],
              ),
            ),

            // Announcement Card
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
                    "Can you believe it's been a year since the IIIT NR app launched? Still crashes less than our GPA but "
                    "more than our will to live. Cheers to 365 days of “please try again later”!!",
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

  Widget _buildDashboardTile(
      BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        if (label == 'Attendance') {
          _handleAttendanceTap(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFB39DDB), // Lavender tile color
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

  Future<void> _handleAttendanceTap(BuildContext context) async {
    try {
      // Show loading
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()));

      // Step 1: Check biometric status using new combined endpoint
      final result = await ApiClient.I.biometricCheck();
      Navigator.of(context).pop(); // Hide loading

      final String status = result['status'] as String? ?? 'none';
      debugPrint('dashboard: biometric status = $status');

      // Step 2: Handle different status cases
      switch (status) {
        case 'none':
          // No key registered - prompt to register
          await _showRegistrationDialog(context);
          break;

        case 'pending':
          // Key registered but awaiting approval
          await _showAwaitingApprovalDialog(context);
          break;

        case 'approved':
          // Key approved - navigate to QR scanner
          if (!mounted) return;
          context.push('/student/attendance');
          break;

        case 'revoked':
          // Key was revoked - prompt to re-register
          await _showReRegistrationDialog(context);
          break;

        default:
          await _showErrorDialog(context, 'Unknown biometric status: $status');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Hide loading if still showing
      await _showErrorDialog(context, 'Failed to check biometric status: $e');
    }
  }

  Future<void> _showRegistrationDialog(BuildContext context) async {
    final register = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register Device'),
        content: const Text(
            'No biometric key is registered for this device. Would you like to register it for biometric attendance?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Later')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Register')),
        ],
      ),
    );

    if (register == true) {
      await _performRegistration(context);
    }
  }

  Future<void> _performRegistration(BuildContext context) async {
    try {
      // First check if face authentication is available
      final faceStatus = await BiometricService.getFaceStatus();
      if (faceStatus == 'not_available') {
        await _showErrorDialog(context,
            'Face authentication is not available on this device. Please ensure your device supports biometric authentication.');
        return;
      } else if (faceStatus == 'not_enrolled') {
        final setup = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Setup Face Authentication'),
            content: const Text(
                'Face authentication is not set up on this device. Would you like to open settings to enable it?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Open Settings')),
            ],
          ),
        );

        if (setup == true) {
          final opened = await BiometricService.openBiometricEnroll();
          if (!opened) {
            // Fallback to system settings - you may need to import permission_handler
            // await Permission.manageExternalStorage.request();
          }
        }
        return;
      }

      // Authenticate with face before registration
      final authenticated = await BiometricService.authenticateWithFace();
      if (!authenticated) {
        await _showErrorDialog(
            context, 'Face authentication is required for registration.');
        return;
      }

      // Generate and test device key
      final publicKeyPem = await BiometricService.generateAndGetPublicKeyPem();

      // Test key with local challenge (this will prompt for face auth again)
      final testChallenge =
          base64Encode(List.generate(32, (_) => Random().nextInt(256)));
      await BiometricService.signChallenge(testChallenge);

      // Register with server
      await ApiClient.I.registerBiometricKey(publicKeyPem: publicKeyPem);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Registration Sent'),
          content: const Text(
              'Your device has been registered for biometric attendance using face authentication. Please wait for admin approval.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'))
          ],
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      String message = 'Registration failed';

      switch (e.code) {
        case 'user_cancelled':
          message = 'Registration cancelled by user';
          break;
        case 'authentication_failed':
          message = 'Face authentication failed. Please try again.';
          break;
        case 'no_biometrics_enrolled':
          message =
              'No biometric credentials are enrolled. Please set up face lock in device settings.';
          break;
        case 'biometric_not_available':
          message = 'Biometric authentication is not available on this device.';
          break;
        default:
          message = 'Registration failed: ${e.message}';
      }

      await _showErrorDialog(context, message);
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(context, 'Registration failed: $e');
    }
  }

  Future<void> _showAwaitingApprovalDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Awaiting Approval'),
        content: const Text(
            'Your device is registered but not yet approved for biometric attendance. Please wait for administrator approval.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _showReRegistrationDialog(BuildContext context) async {
    final reRegister = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-register Device'),
        content: const Text(
            'Your biometric key was revoked. Would you like to register this device again?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Later')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Re-register')),
        ],
      ),
    );

    if (reRegister == true) {
      await _performRegistration(context);
    }
  }

  Future<void> _showErrorDialog(BuildContext context, String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))
        ],
      ),
    );
  }
}
