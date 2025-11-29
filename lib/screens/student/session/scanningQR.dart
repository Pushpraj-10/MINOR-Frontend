import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:frontend/api/api_client.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/biometric_service.dart';
import 'package:frontend/repositories/attendance_repository.dart';

class ScannerQRScreen extends StatefulWidget {
  const ScannerQRScreen({super.key});

  @override
  State<ScannerQRScreen> createState() => _ScannerQRScreenState();
}

class _ScannerQRScreenState extends State<ScannerQRScreen> {
  bool _isProcessing = false;

  Future<void> _sendTokenRequest(String token) async {
    if (_isProcessing) return;
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      // Require OS biometric authentication before proceeding with check-in
      final LocalAuthentication auth = LocalAuthentication();
      bool canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuth) {
        if (mounted)
          _showPopup('Biometric Unavailable',
              'Biometric authentication is not available on this device. Contact your administrator to enable biometric check-in or use the QR-only fallback.');
        return;
      }

      // Do not pre-authenticate here; defer to native signing prompt later.
      try {
        // no-op
      } on PlatformException catch (e) {
        final code = e.code.toString().toLowerCase();
        if (code.contains('notenrolled') ||
            code.contains('no_biometrics') ||
            code.contains('no_biometric')) {
          final setup = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Enable Biometric Authentication'),
              content: const Text(
                  'No biometric credential is set up on this device. Would you like to open settings to enable it?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Open Settings')),
              ],
            ),
          );
          if (setup == true) {
            await openAppSettings();
            return;
          } else {
            if (mounted)
              _showPopup('Biometric Unavailable',
                  'No biometric credential is set up. Contact your administrator to enable biometric check-in or retry after enabling biometrics.');
            return;
          }
        }
        if (mounted)
          _showPopup(
              'Authentication Error', e.message ?? 'Authentication failed');
        return;
      } catch (_) {
        if (mounted)
          _showPopup('Authentication Failed',
              'Biometric authentication failed or was cancelled.');
        return;
      }

      // skip upfront authenticate; native signing will prompt when needed
      // After successful OS biometric auth, attempt to register/get public key
      // and, if approved, sign the server challenge and verify.
      try {
        final attendanceRepo = AttendanceRepository();


        // Ensure device has a public key; try to read it, otherwise generate one.
        String? publicKeyPem = await BiometricService.getPublicKeyPem();
        if (publicKeyPem == null) {
          debugPrint('No public key on device — generating new key');
          publicKeyPem = await BiometricService.generateAndGetPublicKeyPem();
          debugPrint('Generated public key PEM length=${publicKeyPem.length}');
        }

        // Self-test: sign a local challenge to ensure the device key is usable
        try {
          final List<int> rnd = List.generate(32, (_) => Random().nextInt(256));
          final String testChallenge = base64Encode(rnd);
          debugPrint('Performing local sign-test to validate key');
          final String sig =
              await BiometricService.signChallenge(testChallenge);
          debugPrint('Local sign-test succeeded sigLen=${sig.length}');
        } on PlatformException catch (pe) {
          debugPrint('Local sign-test failed: $pe');
          if (mounted)
            _showPopup(
                'Registration Failed', 'Device key unusable: ${pe.message}');
          return;
        } catch (e) {
          debugPrint('Local sign-test failed: $e');
          if (mounted)
            _showPopup('Registration Failed', 'Device key unusable: $e');
          return;
        }

        final clientHash = BiometricService.computePublicKeyHash(publicKeyPem);
        debugPrint('Computed client publicKeyHash=$clientHash');

        // Ask server about registered key state and possible challenge
        final Map<String, dynamic> chk = await attendanceRepo.checkKey();
        debugPrint('attendance.checkKey response: $chk');

        final String? serverHash = chk['publicKeyHash'] as String?;
        final String? status = chk['status'] as String?;

        // If server has no key or hashes differ, register and exit (await admin approval)
        if (serverHash == null || serverHash != clientHash) {
          debugPrint(
              'Public key mismatch or not registered on server; registering');
          await attendanceRepo.registerKey(publicKeyPem: publicKeyPem);
          if (mounted)
            _showPopup('Registration Sent',
                'Your device public key has been sent for admin approval. Please wait for approval.');
          return;
        }

        // At this point serverHash == clientHash. Only proceed if approved and challenge is present.
        if (status != 'approved' || chk['challenge'] == null) {
          debugPrint(
              'Server key not yet approved or no challenge available (status=$status)');
          if (mounted)
            _showPopup('Awaiting Approval',
                'Your device is registered but not yet approved. Please wait for administrator approval.');
          return;
        }

        final String challenge = chk['challenge'] as String;
        debugPrint('Signing server challenge (len=${challenge.length})');
        final String signature =
            await BiometricService.signChallenge(challenge);
        debugPrint('Signature length=${signature.length}');

        Map<String, dynamic> verifyResp;
        try {
          verifyResp = await attendanceRepo.verifyChallenge(
              challenge: challenge, signature: signature, qrToken: token);
          debugPrint('verifyChallenge response: $verifyResp');
        } catch (e) {
          // Handle challenge mismatch by requesting a fresh challenge and retrying once
          try {
            final dynamic dioResp =
                (e is Exception && e.toString().contains('Dio'))
                    ? (e as dynamic).response
                    : null;
            final errData = dioResp != null ? dioResp.data : null;
            final reason =
                errData is Map ? (errData['reason'] ?? errData['error']) : null;
            if (reason == 'challenge_mismatch') {
              debugPrint(
                  'challenge_mismatch detected; fetching fresh challenge and retrying');
              final Map<String, dynamic> chk2 = await attendanceRepo.checkKey();
              final String? newChallenge = chk2['challenge'] as String?;
              if (newChallenge != null) {
                final String newSig =
                    await BiometricService.signChallenge(newChallenge);
                verifyResp = await attendanceRepo.verifyChallenge(
                    challenge: newChallenge, signature: newSig, qrToken: token);
                debugPrint('verifyChallenge retry response: $verifyResp');
              } else {
                throw e;
              }
            } else {
              throw e;
            }
          } catch (retryErr) {
            debugPrint('verifyChallenge failed: $retryErr');
            if (mounted) _showPopup('Verification Error', retryErr.toString());
            return;
          }
        }

        final bool verified = verifyResp['verified'] as bool? ?? false;
        if (verified) {
          // Server may have atomically marked attendance and returned attendance info.
          final attendance = verifyResp['attendance'];
          final attendanceError = verifyResp['attendanceError'];
          if (attendance != null) {
            debugPrint('Attendance recorded via verifyChallenge: $attendance');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Check-in successful')));
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) Navigator.of(context).pop(true);
            return;
          }
          if (attendanceError != null) {
            debugPrint('Attendance marking returned error: $attendanceError');
            if (mounted)
              _showPopup('Attendance Error', attendanceError.toString());
            return;
          }

          // No attendance info returned but verification succeeded — treat as success.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification successful')));
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.of(context).pop(true);
          return;
        } else if (verifyResp['biometricChanged'] == true) {
          // Server revoked stored key — offer re-register
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
              _showPopup('Registration Sent',
                  'Your device public key has been sent for admin approval.');
            } catch (re) {
              debugPrint('Re-registration failed: $re');
              if (mounted) _showPopup('Registration Failed', re.toString());
            }
          }
          return;
        } else {
          if (mounted)
            _showPopup('Verification Failed', 'Biometric verification failed.');
          return;
        }
      } catch (e) {
        debugPrint('Key registration/verification flow failed: $e');
      }
      // Enforce face enrollment: check native face status before sending biometric checkin
      try {
        final dynamic faceStatus =
            await const MethodChannel('com.example.frontend/biometric')
                .invokeMethod('getFaceStatus');
        final String fs = faceStatus as String? ?? 'not_available';
        if (fs == 'not_enrolled') {
          final enroll = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Face not enrolled'),
              content: const Text(
                  'Face recognition is not enrolled on this device. To use face-only biometric check-in, please enroll your face in system settings.'),
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
          if (enroll == true) {
            try {
              await const MethodChannel('com.example.frontend/biometric')
                  .invokeMethod('openBiometricEnroll');
            } catch (e) {
              await openAppSettings();
            }
          }
          if (mounted) setState(() => _isProcessing = false);
          return;
        } else if (fs == 'not_available') {
          // Face hardware not available — gather diagnostics and show to user
          String diagText = '';
          try {
            final dynamic diag =
                await const MethodChannel('com.example.frontend/biometric')
                    .invokeMethod('getFaceDiagnostics');
            if (diag != null && diag is Map) {
              final entries =
                  diag.entries.map((e) => '${e.key}: ${e.value}').join('\n');
              diagText = '\n\nDiagnostics:\n$entries';
            }
          } catch (e) {
            diagText = '\n\nDiagnostics: unavailable ($e)';
          }
          if (mounted)
            _showPopup(
                'Face biometric not available',
                'Face biometric hardware is not available on this device. Please contact your administrator in person to arrange an alternative check-in.' +
                    diagText);
          if (mounted) setState(() => _isProcessing = false);
          return;
        }
      } catch (e) {
        debugPrint('Face status check failed: $e');
      }
      String studentUid = '';
      try {
        final dynamic me = await ApiClient.I.me();
        if (me != null && me['user'] != null && me['user']['uid'] != null) {
          studentUid = me['user']['uid'] as String;
        }
      } catch (_) {
        // ignore - server may accept qrToken-only
      }

      // Send check-in request to backend (some backends accept only qrToken)
      try {
        debugPrint(
            'Calling ApiClient.checkin (scanner): qrToken=${token.length > 32 ? token.substring(0, 32) : token} studentUid=$studentUid');
        final resp = await ApiClient.I
            .checkin(sessionId: '', qrToken: token, studentUid: studentUid);
        debugPrint('ApiClient.checkin (scanner) response: $resp');
      } catch (e) {
        debugPrint('Checkin failed: $e');
        String msg = 'Check-in failed';
        try {
          final typeName = e.runtimeType.toString();
          if (typeName.contains('Dio') || typeName.contains('DioException')) {
            final dynamic resp = (e as dynamic).response;
            if (resp != null && resp.data != null) {
              msg = resp.data.toString();
            } else if (resp != null && resp.statusMessage != null) {
              msg = resp.statusMessage.toString();
            }
          } else {
            msg = e.toString();
          }
        } catch (_) {
          msg = e.toString();
        }
        if (mounted) _showPopup('Check-in Failed', msg);
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Check-in successful')));
      // short delay so user sees feedback, then close scanner and return success
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showPopup('Check-in Error', e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null) {
        try {
          final data = jsonDecode(rawValue);
          final token = data["token"];
          if (token != null) {
            _sendTokenRequest(token);
          } else {
            _showPopup("Invalid QR", "No token found in QR code");
          }
        } catch (_) {
          _showPopup("Invalid QR", "QR code does not contain valid JSON");
        }
        break; // stop after first valid QR
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
