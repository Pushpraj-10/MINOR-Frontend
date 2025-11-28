import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import 'package:frontend/api/api_client.dart';
import 'package:frontend/services/biometric_service.dart';
import 'package:frontend/repositories/attendance_repository.dart';

class AttendanceScanPage extends StatefulWidget {
  const AttendanceScanPage({Key? key}) : super(key: key);

  @override
  State<AttendanceScanPage> createState() => _AttendanceScanPageState();
}

class _AttendanceScanPageState extends State<AttendanceScanPage> {
  late final MobileScannerController _qrController;
  bool _initializing = true;
  bool _processing = false;
  String _status = 'Align the QR code in the frame';

  static const MethodChannel _platform =
      MethodChannel('com.example.frontend/biometric');

  @override
  void initState() {
    super.initState();
    _initScanner();
    // On open, check server for existing biometric public key and auto-register if missing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRegisterOnOpen();
    });
  }

  Future<void> _checkAndRegisterOnOpen() async {
    try {
      debugPrint('Checking server for existing biometric public key on open');
      final attendanceRepo = AttendanceRepository();

      // Check local device PEM (do not create one yet)
      String? localPem = await BiometricService.getPublicKeyPem();
      final clientHash = localPem != null
          ? BiometricService.computePublicKeyHash(localPem)
          : null;

      final Map<String, dynamic> chk = await attendanceRepo.checkKey();
      final String? serverHash = chk['publicKeyHash'] as String?;
      final String status = chk['status'] as String? ?? 'none';
      debugPrint(
          'Biometric public key status on open: $status; serverHash=${serverHash != null} clientHash=${clientHash != null}');

      if (serverHash == null || serverHash != clientHash) {
        // No match — prompt user to register local key so admin can approve it
        final doRegister = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Register Device for Biometric Check-in'),
            content: const Text(
                'This device does not match the registered biometric key. Would you like to register this device so you can use biometric check-in?'),
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
        if (doRegister == true) {
          try {
            // Use the new BiometricService for face authentication
            final authenticated = await BiometricService.authenticateWithFace();
            if (!authenticated) {
              if (mounted)
                _showPopup('Registration Cancelled',
                    'Face authentication is required for registration.');
              return;
            }
          } catch (e) {
            debugPrint('Face authentication failed during registration: $e');
            if (mounted) {
              String message = 'Face authentication failed';
              if (e is PlatformException) {
                switch (e.code) {
                  case 'user_cancelled':
                    message = 'Registration cancelled by user';
                    break;
                  case 'no_biometrics_enrolled':
                    message =
                        'Please set up face lock in device settings first';
                    break;
                  case 'biometric_not_available':
                    message =
                        'Face authentication is not available on this device';
                    break;
                  default:
                    message = 'Face authentication failed: ${e.message}';
                }
              }
              _showPopup('Registration Failed', message);
            }
            return;
          }

          try {
            setState(() => _status = 'Registering device...');
            debugPrint('Generating device public key PEM for registration');
            final String publicKeyPem =
                await _platform.invokeMethod('generateAndGetPublicKeyPem');
            debugPrint(
                'Generated public key PEM length: ${publicKeyPem.length}');
            await attendanceRepo.registerKey(publicKeyPem: publicKeyPem);
            if (!mounted) return;
            await _showResult('Registration Sent',
                'Your device public key has been sent for admin approval.');
          } catch (e) {
            debugPrint('Automatic registration failed: $e');
            if (mounted) _showPopup('Registration Failed', e.toString());
          } finally {
            if (mounted)
              setState(() => _status = 'Align the QR code in the frame');
          }
        }
      } else {
        debugPrint(
            'Device already has a registered public key and matches server (status=$status)');
      }
    } catch (e) {
      debugPrint('Error checking biometric public key on open: $e');
    }
  }

  void _initScanner() {
    _qrController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
    if (!mounted) return;
    setState(() => _initializing = false);
  }

  Future<void> _handleDetectedRaw(String raw) async {
    if (_processing) return;
    String qrToken = raw;
    try {
      final dynamic parsed = jsonDecode(raw);
      if (parsed != null && parsed is Map && parsed['token'] != null) {
        qrToken = parsed['token'] as String;
      }
    } catch (_) {}

    await _processQrToken(qrToken);
  }

  Future<void> _processQrToken(String qrToken) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _status = 'Processing QR...';
    });

    try {
      final LocalAuthentication auth = LocalAuthentication();
      bool canAuth =
          await auth.isDeviceSupported() || await auth.canCheckBiometrics;
      if (!canAuth) {
        if (mounted)
          _showPopup('Biometric Unavailable',
              'Biometric authentication is not available on this device. Contact your administrator to enable biometric check-in or use the QR-only fallback.');
        _resetState();
        return;
      }

      // Check face authentication status
      final faceStatus = await BiometricService.getFaceStatus();
      if (faceStatus == 'not_available') {
        if (mounted)
          _showPopup('Face Authentication Unavailable',
              'Face authentication is not available on this device. Please ensure your device supports biometric authentication.');
        _resetState();
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
            await openAppSettings();
          }
        }
        _resetState();
        return;
      }

      // skip upfront authentication; signing will prompt when needed

      // Use atomic biometricCheck endpoint to get status + challenge in one call
      try {
        debugPrint('Checking biometric status and getting challenge...');
        setState(() => _status = 'Checking device key...');
        final attendanceRepo = AttendanceRepository();

        // Single atomic call to get status + challenge (prevents race conditions)
        final Map<String, dynamic> chk = await attendanceRepo.checkKey();
        final String status = chk['status'] as String? ?? 'none';
        debugPrint('Biometric status from server: $status');

        if (status != 'approved') {
          if (status == 'pending') {
            if (mounted)
              _showPopup('Awaiting Approval',
                  'Your device is registered but not yet approved. Please wait for administrator approval.');
          } else if (status == 'revoked') {
            if (mounted)
              _showPopup('Key Revoked',
                  'Your biometric key was revoked. Please re-register your device.');
          } else {
            if (mounted)
              _showPopup('Not Registered',
                  'Your device is not registered for biometric attendance. Please register first.');
          }
          _resetState();
          return;
        }

        // Status is approved - check if we have a challenge
        final String? challenge = chk['challenge'] as String?;
        if (challenge == null) {
          debugPrint(
              'No challenge returned from server (key may not be fully approved)');
          if (mounted)
            _showPopup('No Challenge',
                'Unable to get authentication challenge. Please try again or contact administrator.');
          _resetState();
          return;
        }

        // Proceed with challenge signing
        try {
          setState(() => _status = 'Authenticating with face...');
          debugPrint(
              'About to sign challenge with face authentication, challenge length=${challenge.length}');

          // Use the new BiometricService which includes face authentication
          final String signature =
              await BiometricService.signChallenge(challenge);
          debugPrint('Signature received length: ${signature.length}');

          // Use attendance endpoints: verify signature first, then mark present
          try {
            final attendanceRepo = AttendanceRepository();

            Map<String, dynamic> verifyResp;
            try {
              verifyResp = await attendanceRepo.verifyChallenge(
                  challenge: challenge, signature: signature, qrToken: qrToken);
              debugPrint('attendance.verifyChallenge returned: $verifyResp');
            } catch (e) {
              // Attempt a single retry if server reports a challenge_mismatch
              try {
                final dynamic dioResp =
                    (e is Exception && e.toString().contains('Dio'))
                        ? (e as dynamic).response
                        : null;
                final errData = dioResp != null ? dioResp.data : null;
                final reason = errData is Map
                    ? (errData['reason'] ?? errData['error'])
                    : null;
                if (reason == 'challenge_mismatch') {
                  debugPrint(
                      'challenge_mismatch detected; fetching fresh challenge and retrying');
                  final Map<String, dynamic> chk2 =
                      await attendanceRepo.checkKey();
                  final String? newChallenge = chk2['challenge'] as String?;
                  if (newChallenge != null) {
                    final String newSig =
                        await BiometricService.signChallenge(newChallenge);
                    verifyResp = await attendanceRepo.verifyChallenge(
                        challenge: newChallenge,
                        signature: newSig,
                        qrToken: qrToken);
                    debugPrint(
                        'attendance.verifyChallenge retry returned: $verifyResp');
                  } else {
                    throw e;
                  }
                } else {
                  throw e;
                }
              } catch (retryErr) {
                debugPrint('attendance.verifyChallenge failed: $retryErr');
                if (mounted)
                  _showPopup('Verification Error', retryErr.toString());
                _resetState();
                return;
              }
            }

            if (verifyResp['verified'] == true) {
              // resolved — mark present
              String studentUid = '';
              try {
                final dynamic me = await ApiClient.I.me();
                if (me != null &&
                    me['user'] != null &&
                    me['user']['uid'] != null) {
                  studentUid = me['user']['uid'] as String;
                }
              } catch (_) {}

              final Map<String, dynamic> markResp = await attendanceRepo
                  .markPresent(studentUid: studentUid, qrToken: qrToken);
              debugPrint('attendance.markPresent returned: $markResp');
              if (!mounted) return;
              await _showResult('Check-in Result', markResp.toString());
              _resetState();
              return;
            } else if (verifyResp['biometricChanged'] == true) {
              // Key mismatch/revoked on server — inform user and offer re-register
              final doReg = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Biometric Key Changed'),
                  content: const Text(
                      'Your biometric key no longer matches the registered key. The server has revoked the stored key. Would you like to re-register this device for biometric check-in?'),
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
              if (doReg == true) {
                try {
                  try {
                    await BiometricService.deleteLocalKey();
                  } catch (_) {}
                  final String newPem =
                      await BiometricService.generateAndGetPublicKeyPem();
                  await attendanceRepo.registerKey(publicKeyPem: newPem);
                  if (!mounted) return;
                  await _showResult('Registration Sent',
                      'Your device public key has been sent for admin approval.');
                } catch (re) {
                  debugPrint('Re-registration failed: $re');
                  if (mounted) _showPopup('Registration Failed', re.toString());
                }
              }
              _resetState();
              return;
            } else {
              final reason =
                  verifyResp['reason']?.toString() ?? 'Verification failed';
              if (mounted) _showPopup('Verification Failed', reason);
              _resetState();
              return;
            }
          } catch (e) {
            debugPrint('attendance verify/mark flow failed: $e');
            if (mounted) _showPopup('Check-in Error', e.toString());
            _resetState();
            return;
          }
        } catch (e, st) {
          debugPrint('Challenge signing/verification failed: $e\n$st');
          String msg = 'Signing failed';
          try {
            if (e is PlatformException) {
              final String code = e.code;
              final String message = e.message ?? '';
              if (code == 'key_invalidated' ||
                  message.contains('Key permanently invalidated')) {
                final doReg = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Device key invalidated'),
                    content: const Text(
                        'Your device biometric key was invalidated (e.g., biometric credentials changed). Re-register this device for biometric check-in now?'),
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
                if (doReg == true) {
                  try {
                    final String newPem = await _platform
                        .invokeMethod('generateAndGetPublicKeyPem');
                    await attendanceRepo.registerKey(publicKeyPem: newPem);
                    if (!mounted) return;
                    await _showResult('Registration Sent',
                        'Your device public key has been sent for admin approval.');
                  } catch (re) {
                    debugPrint('Re-registration failed: $re');
                    if (mounted)
                      _showPopup('Registration Failed', re.toString());
                  }
                  _resetState();
                  return;
                }
              }
            }

            if (e is Exception) {
              final typeName = e.runtimeType.toString();
              if (typeName.contains('Dio') ||
                  typeName.contains('DioException')) {
                final dynamic resp = (e as dynamic).response;
                if (resp != null && resp.data != null) {
                  msg = resp.data.toString();
                } else if (resp != null && resp.statusMessage != null) {
                  msg = resp.statusMessage.toString();
                } else {
                  msg = e.toString();
                }
              } else {
                msg = e.toString();
              }
            } else {
              msg = e.toString();
            }
          } catch (_) {
            msg = e.toString();
          }

          if (mounted) _showPopup('Signing Failed', msg);
          _resetState();
          return;
        }
      } catch (e) {
        debugPrint('Biometric check failed: $e');
        // Only fallback to QR-only if biometric system is completely unavailable
        // For other errors (not approved, etc), we already showed error messages above
        if (mounted) {
          final fallback = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Biometric Check Failed'),
              content: const Text(
                  'Biometric authentication failed. Would you like to use QR-only check-in as fallback?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Use QR Fallback')),
              ],
            ),
          );

          if (fallback == true) {
            final String? fallbackUid = await _askForUid();
            if (fallbackUid != null && fallbackUid.isNotEmpty) {
              try {
                final resp = await ApiClient.I.checkin(
                    sessionId: '',
                    qrToken: qrToken,
                    studentUid: fallbackUid,
                    method: 'qr');
                if (!mounted) return;
                await _showResult('Check-in Result', resp.toString());
              } catch (checkinErr) {
                if (mounted)
                  _showPopup('Check-in Failed', checkinErr.toString());
              }
            }
          }
        }
        _resetState();
        return;
      }
    } catch (e, st) {
      debugPrint('Scan flow error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _processing = false;
        _status = 'Scan failed, try again';
      });
    }
  }

  void _resetState() {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _status = 'Align the QR code in the frame';
    });
  }

  Future<String?> _askForUid() async {
    return showDialog<String?>(
      context: context,
      builder: (ctx) {
        final TextEditingController uidCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Biometric unavailable'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Biometric/secure check-in is not available. To proceed with QR-only check-in, enter your UID below or contact your administrator.'),
                const SizedBox(height: 12),
                TextField(
                    controller: uidCtrl,
                    decoration: const InputDecoration(labelText: 'Your UID')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(uidCtrl.text),
                child: const Text('Submit')),
          ],
        );
      },
    );
  }

  Future<void> _showResult(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  void _showPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))
        ],
      ),
    );
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
            const Text('Attendance - Scan QR',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _qrController,
                  onDetect: (capture) {
                    if (_processing) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final raw = barcode.rawValue;
                      if (raw != null && raw.isNotEmpty) {
                        _handleDetectedRaw(raw);
                        break;
                      }
                    }
                  },
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
                child: Text(_processing ? 'Processing...' : _status,
                    style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
      ),
    );
  }
}
