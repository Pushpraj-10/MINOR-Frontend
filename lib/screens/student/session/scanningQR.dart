import 'dart:async';
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
      final auth = LocalAuthentication();
      bool canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();

      if (!canAuth) {
        if (mounted) {
          _showPopup('Biometric Unavailable',
              'Biometric authentication is not available on this device.');
        }
        return;
      }

      final attendanceRepo = AttendanceRepository();

      String? publicKeyPem = await BiometricService.getPublicKeyPem();
      if (publicKeyPem == null) {
        publicKeyPem = await BiometricService.generateAndGetPublicKeyPem();
      }

      try {
        final rnd = List.generate(32, (_) => Random().nextInt(256));
        final testChallenge = base64Encode(rnd);
        await BiometricService.signChallenge(testChallenge);
      } catch (e) {
        if (mounted) {
          _showPopup('Registration Failed', 'Local key unusable');
        }
        return;
      }

      final clientHash = BiometricService.computePublicKeyHash(publicKeyPem);

      final chk = await attendanceRepo.checkKey();

      final String? serverHash = chk['publicKeyHash'];
      final String? status = chk['status'];

      if (serverHash == null || serverHash != clientHash) {
        await attendanceRepo.registerKey(publicKeyPem: publicKeyPem);
        if (mounted) {
          _showPopup('Registration Sent',
              'Your key was submitted for admin approval.');
        }
        return;
      }

      if (status != 'approved' || chk['challenge'] == null) {
        if (mounted) {
          _showPopup('Awaiting Approval',
              'Your device key is waiting for admin approval.');
        }
        return;
      }

      final String challenge = chk['challenge'];

      final String signature = await BiometricService.signChallenge(challenge);

      String studentUid = '';
      try {
        final me = await ApiClient.I.me();
        studentUid = me['user']['uid'] ?? '';
      } catch (_) {}

      Map<String, dynamic> verifyResp;

      try {
        verifyResp = await attendanceRepo.verifyChallenge(
          challenge: challenge,
          signature: signature,
          qrToken: token,
          studentUid: studentUid,
          sessionId: '',
        );
      } catch (err) {
        try {
          final errData = (err as dynamic)?.response?.data ?? null;
          final reason = errData is Map ? errData['reason'] : null;

          if (reason == 'challenge_mismatch') {
            final chk2 = await attendanceRepo.checkKey();
            final newChallenge = chk2['challenge'];
            if (newChallenge != null) {
              final newSig = await BiometricService.signChallenge(newChallenge);
              verifyResp = await attendanceRepo.verifyChallenge(
                challenge: newChallenge,
                signature: newSig,
                qrToken: token,
                studentUid: studentUid,
                sessionId: '',
              );
            } else {
              throw err;
            }
          } else {
            throw err;
          }
        } catch (err2) {
          if (mounted) {
            _showPopup('Verification Error', err2.toString());
          }
          return;
        }
      }

      final bool verified = verifyResp['verified'] ?? false;

      if (!verified) {
        if (verifyResp['revoked'] == true) {
          final doit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Device Key Revoked'),
              content: const Text('Your device key was revoked. Re-register?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Later')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Re-register')),
              ],
            ),
          );

          if (doit == true) {
            await BiometricService.deleteLocalKey();
            final newPem = await BiometricService.generateAndGetPublicKeyPem();
            await attendanceRepo.registerKey(publicKeyPem: newPem);
            if (mounted) {
              _showPopup('Registration Sent',
                  'Your new key is pending admin approval.');
            }
          }
          return;
        }

        if (mounted)
          _showPopup(
              'Verification Failed',
              verifyResp['reason']?.toString() ??
                  'Biometric verification failed');
        return;
      }

      // If verified, mark attendance via separate endpoint
      final markResp = await attendanceRepo.markPresent(
        qrToken: token,
        studentUid: studentUid,
        method: 'biometric',
      );

      if (markResp['ok'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance marked')),
          );
          await Future.delayed(const Duration(milliseconds: 800));
          Navigator.pop(context, true);
        }
        return;
      }

      if (mounted)
        _showPopup('Attendance Error',
            markResp['reason']?.toString() ?? 'Failed to mark attendance');
    } catch (e) {
      if (mounted) _showPopup('Error', e.toString());
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) {
        try {
          final data = jsonDecode(raw);
          final token = data['token'];
          if (token != null) {
            _sendTokenRequest(token);
          } else {
            _showPopup('Invalid QR', 'Token missing');
          }
        } catch (_) {
          _showPopup('Invalid QR', 'QR does not contain valid JSON');
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          if (_isProcessing) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
