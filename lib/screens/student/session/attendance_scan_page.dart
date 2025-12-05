import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:frontend/services/biometric_service.dart';
import 'package:frontend/repositories/attendance_repository.dart';
import 'package:frontend/utils/error_utils.dart';

/// Flow (Option 2):
/// 1) User scans QR → get `qrToken`
/// 2) Ensure device has local TEE key (generate if missing)
/// 3) Server /biometrics/check → must be {status:'approved', publicKeyHash matches, challenge}
/// 4) Native signChallenge(challenge) → signatureB64
/// 5) POST /attendance/verify-challenge (verify only)
/// 6) If verified → POST /attendance/mark-present
class AttendanceScanPage extends StatefulWidget {
  const AttendanceScanPage({Key? key}) : super(key: key);

  @override
  State<AttendanceScanPage> createState() => _AttendanceScanPageState();
}

class _AttendanceScanPageState extends State<AttendanceScanPage> {
  late final MobileScannerController _scanner;
  bool _processing = false;
  String _status = 'Align the QR code in the frame';

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _handleQR(String raw) async {
    if (_processing) return;

    // accept plain token or JSON with { token }
    String qrToken = raw;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map && parsed['token'] is String) {
        qrToken = parsed['token'] as String;
      }
    } catch (_) {}

    await _process(qrToken);
  }

  Future<void> _process(String qrToken) async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _status = 'Preparing...';
    });

    final repo = AttendanceRepository();

    try {
      // Ensure local device key exists (generate if missing)
      String? pem = await BiometricService.getPublicKeyPem();
      if (pem == null) {
        pem = await BiometricService.generateAndGetPublicKeyPem();
      }

      // Lightweight self-test (ensures key is usable + triggers OS auth UX once)
      try {
        final test =
            base64Encode(List.generate(16, (_) => Random().nextInt(256)));
        await BiometricService.signChallenge(test);
      } on PlatformException catch (e) {
        _fail(
          'Local key unusable: ${e.message ?? e.code}',
          reasons: const [
            'Device biometrics were not verified successfully',
            'Keys were invalidated after changing face or fingerprint data',
          ],
        );
        return;
      } catch (e) {
        _fail(
          'Local key unusable: $e',
          reasons: const [
            'Secure hardware key could not be accessed',
            'OS prevented the biometric prompt from completing',
          ],
        );
        return;
      }

      setState(() => _status = 'Checking device key with server...');

      // Server status + publicKeyHash + optional challenge (must be approved & hash match)
      final check = await repo.checkKey();
      final status = check['status'] as String? ?? 'none';
      final serverHash = check['publicKeyHash'] as String?;
      final clientHash = BiometricService.computePublicKeyHash(pem);

      if (serverHash == null || serverHash != clientHash) {
        // Not registered or mismatch → register and exit; admin must approve
        await repo.registerKey(publicKeyPem: pem);
        _info(
          'Registration Sent',
          'Your device public key has been sent for admin approval. '
              'Please try again after approval.',
        );
        return;
      }

      if (status != 'approved') {
        _info(
          'Awaiting Approval',
          'Your device is registered but not yet approved. Please wait for admin approval.',
        );
        return;
      }

      String? activeChallenge = check['challenge'] as String?;
      if (activeChallenge == null) {
        _fail(
          'No challenge available. Please retry.',
          reasons: const [
            'The QR token expired or was already used',
            'Professor rotated the QR before you finished scanning',
          ],
        );
        return;
      }

      setState(() => _status = 'Authenticating...');

      // This triggers OS biometric prompt and signs via TEE private key
      String activeSignature =
          await BiometricService.signChallenge(activeChallenge);

      setState(() => _status = 'Verifying...');

      // Verify only (no marking here)
      Map<String, dynamic> verifyResp;
      try {
        verifyResp = await repo.verifyChallenge(
          challenge: activeChallenge,
          signature: activeSignature,
          qrToken: qrToken,
        );
      } catch (e) {
        // Retry once on explicit challenge mismatch
        if (e.toString().contains('challenge_mismatch')) {
          final check2 = await repo.checkKey();
          final String? c2 = check2['challenge'] as String?;
          if (c2 != null) {
            final sig2 = await BiometricService.signChallenge(c2);
            activeChallenge = c2;
            activeSignature = sig2;
            verifyResp = await repo.verifyChallenge(
              challenge: activeChallenge,
              signature: activeSignature,
              qrToken: qrToken,
            );
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final verified = verifyResp['verified'] as bool? ?? false;
      if (!verified) {
        if (verifyResp['revoked'] == true) {
          _info(
            'Device Key Revoked',
            withPossibleReasons(
              'Your device key was revoked on the server. Please re-register this device.',
              heading: 'Why this happens:',
              reasons: const [
                'An administrator rejected or revoked the registration',
                'You attempted to use an outdated device key',
              ],
            ),
          );
          return;
        }
        _fail(
          verifyResp['reason']?.toString() ?? 'Verification failed.',
          reasons: const [
            'The QR code was refreshed during verification',
            'Device clock drifted too far from server time',
          ],
        );
        return;
      }
      setState(() => _status = 'Attendance verified');

      final attendanceError = verifyResp['attendanceError']?.toString();
      if (attendanceError != null && attendanceError.isNotEmpty) {
        _fail(
          attendanceError,
          reasons: const [
            'Professor rotated the QR before marking could finish',
            'The biometric proof was already consumed on the server',
          ],
        );
        return;
      }

      final attendancePayload = verifyResp['attendance'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in successful')),
      );
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop(attendancePayload);
    } on PlatformException catch (e) {
      if (e.code == 'key_invalidated') {
        _info(
          'Device Key Invalidated',
          'Your device biometrics changed. Please re-register your device key.',
        );
      } else {
        final message = formatErrorWithContext(
          e,
          action: 'complete biometric auth',
          reasons: const [
            'You dismissed the biometric prompt',
            'Face or fingerprint sensor failed to read',
            'OS blocked the prompt because device is not secured',
          ],
        );
        _fail(message);
      }
    } catch (e) {
      final message = formatErrorWithContext(
        e,
        action: 'process the QR scan',
        reasons: const [
          'QR token is invalid or already consumed',
          'Device lost connectivity while verifying the challenge',
          'Server session expired; ask the professor to refresh',
        ],
      );
      _fail(message);
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _status = 'Align the QR code in the frame';
        });
      }
    }
  }

  void _fail(String msg, {List<String> reasons = const []}) {
    if (!mounted) return;
    final display =
        reasons.isEmpty ? msg : withPossibleReasons(msg, reasons: reasons);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Error'),
        content: Text(display),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
      ),
    );
  }

  void _info(String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
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
          children: const [
            SizedBox(width: 8),
            Text('Attendance - Scan QR', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: (capture) {
              if (_processing) return;
              for (final b in capture.barcodes) {
                final raw = b.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _handleQR(raw);
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
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(12),
        child: Text(
          _processing ? 'Processing…' : _status,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
