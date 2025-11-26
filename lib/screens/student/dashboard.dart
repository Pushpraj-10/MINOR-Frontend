import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/api/api_client.dart';
import 'dart:math';
import 'dart:convert';
import 'package:frontend/services/biometric_service.dart';
import 'package:frontend/repositories/attendance_repository.dart';
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
    final repo = AttendanceRepository();
    try {
      // Indicate busy
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()));

      final me = await ApiClient.I.me();
      final String myUid = me['user']?['uid'] as String? ?? '';

      // New flow: compute local publicKeyHash, compare with server before attempting sign.
      final status = await repo.checkKey();
      Navigator.of(context).pop(); // hide progress

      // Get or create device public key PEM
      String? publicKeyPem = await BiometricService.getPublicKeyPem();
      if (publicKeyPem == null) {
        // No key present on device — create and register
        try {
          publicKeyPem = await BiometricService.generateAndGetPublicKeyPem();
          // self-test sign to ensure key is usable
          try {
            final List<int> rnd =
                List.generate(32, (_) => Random().nextInt(256));
            final String testChallenge = base64Encode(rnd);
            await BiometricService.signChallenge(testChallenge);
          } catch (e) {
            await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text('Registration Failed'),
                      content: Text('Device key unusable: $e'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('OK'))
                      ],
                    ));
            return;
          }
          await repo.registerKey(publicKeyPem: publicKeyPem);
          await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Registration Sent'),
                    content: const Text(
                        'Your device public key has been sent for admin approval. Please wait and retry.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ],
                  ));
          return;
        } catch (e) {
          await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Registration Failed'),
                    content: Text(e.toString()),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ],
                  ));
          return;
        }
      }

      final clientHash = BiometricService.computePublicKeyHash(publicKeyPem);
      final String? serverHash = status['publicKeyHash'] as String?;
      final String? sStatus = status['status'] as String?;
      debugPrint(
          'dashboard: clientHash=$clientHash serverHash=$serverHash status=$sStatus');

      if (serverHash == null || serverHash != clientHash) {
        // Hash mismatch — register current device key and ask for approval
        await repo.registerKey(publicKeyPem: publicKeyPem);
        await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Registration Sent'),
                  content: const Text(
                      'Your device public key (local) does not match the server record. The local key has been submitted for admin approval.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'))
                  ],
                ));
        return;
      }

      // serverHash == clientHash. Only proceed if approved and a challenge is present
      if (sStatus != 'approved' || status['challenge'] == null) {
        await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Awaiting Approval'),
                  content: const Text(
                      'Your device is registered but not yet approved. Please wait for administrator approval.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'))
                  ],
                ));
        return;
      }

      final String challenge = status['challenge'] as String;

      // Attempt to sign
      String signature;
      try {
        signature = await BiometricService.signChallenge(challenge);
      } on PlatformException catch (pe) {
        final code = pe.code;
        final msg = pe.message;
        if (code == 'key_invalidated' ||
            (msg != null && msg.contains('Key permanently invalidated'))) {
          await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Biometrics Changed'),
                    content: const Text(
                        'Your biometrics have changed or the device key was invalidated. Ask admin for approval.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ],
                  ));
          return;
        }
        if (code == 'sign_error' &&
            msg != null &&
            msg.toLowerCase().contains('cancel')) {
          // user cancelled
          return;
        }
        await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Signing Failed'),
                  content: Text(pe.toString()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'))
                  ],
                ));
        return;
      } catch (e) {
        await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Signing Failed'),
                  content: Text(e.toString()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'))
                  ],
                ));
        return;
      }

      // Send signature to server for verification
      try {
        final verifyResp = await repo.verifyChallenge(
            challenge: challenge, signature: signature);
        if (verifyResp['biometricChanged'] == true) {
          await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Biometrics Changed'),
                    content: const Text(
                        'Your biometrics have changed. Ask admin for approval.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ],
                  ));
          return;
        }

        if (verifyResp['verified'] == true) {
          // Mark present
          await repo.markPresent(studentUid: myUid);
          await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('Attendance Marked'),
                    content: const Text('You have been marked present.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ],
                  ));
          return;
        }

        // fallback
        await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Verification Failed'),
                  content: Text(verifyResp.toString()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'))
                  ],
                ));
      } catch (e) {
        await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Verification Error'),
                  content: Text(e.toString()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK'))
                  ],
                ));
      }
    } catch (e) {
      Navigator.of(context).pop();
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Error'),
                content: Text(e.toString()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'))
                ],
              ));
    }
  }
}
