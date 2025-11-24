import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Legacy face-embedding pages removed. Biometric-first flow only.
import 'package:frontend/api/api_client.dart';

class AttendanceScanPage extends StatefulWidget {
  const AttendanceScanPage({Key? key}) : super(key: key);

  @override
  State<AttendanceScanPage> createState() => _AttendanceScanPageState();
}

class _AttendanceScanPageState extends State<AttendanceScanPage> {
  CameraController? _cameraController;
  MobileScannerController? _qrController;
  bool _initializing = true;
  bool _scanning = false;
  String _status = 'Align the QR code in the frame';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
      _qrController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        formats: const [BarcodeFormat.qrCode],
      );
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e, st) {
      debugPrint('QR camera init error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _status = 'Camera failed to initialize';
      });
    }
  }

  Future<void> _onScanPressed() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _status = 'Scanning QR...';
    });

    try {
      final qrToken = await _scanSingleQrToken();

      // Prefer biometrics when enabled on the server
      try {
        final status = await ApiClient.I.getBiometricsStatus();
        if (status['status'] == 'approved') {
          // Request a challenge
          final challengeResp = await ApiClient.I.getBiometricChallenge();
          final challenge = challengeResp['challenge'] as String?;
          if (challenge == null) throw Exception('no_challenge');

          // Ask user to paste a signature (manual/dev flow) and their UID
          final Map<String, String?> result = await showDialog(
            context: context,
            builder: (ctx) {
              final TextEditingController uidCtrl = TextEditingController();
              final TextEditingController sigCtrl = TextEditingController();
              return AlertDialog(
                title: const Text('Biometric Check-in'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Challenge (copy to OS signing tool):'),
                      SelectableText(challenge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: uidCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Your UID'),
                      ),
                      TextField(
                        controller: sigCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Signature (base64)'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop({'uid': null, 'sig': null}),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.of(ctx)
                          .pop({'uid': uidCtrl.text, 'sig': sigCtrl.text}),
                      child: const Text('Submit')),
                ],
              );
            },
          ) as Map<String, String?>;

          final studentUid = result['uid'];
          final signature = result['sig'];
          if (studentUid != null &&
              studentUid.isNotEmpty &&
              signature != null &&
              signature.isNotEmpty) {
            // Send biometric checkin (session lookup allowed by server using qrToken)
            final resp = await ApiClient.I.checkin(
                sessionId: '',
                qrToken: qrToken,
                studentUid: studentUid,
                method: 'biometric',
                challenge: challenge,
                signature: signature);
            // A simple success popup
            await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                        title: const Text('Check-in Result'),
                        content: Text(resp.toString()),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('OK'))
                        ]));
            if (!mounted) return;
            setState(() {
              _scanning = false;
              _status = 'Align the QR code in the frame';
            });
            return;
          }
        }
      } catch (e) {
        // If biometrics flow fails/disabled, fall back to embedding flow below
        debugPrint('Biometrics flow skipped: $e');
      }

      // Embedding-based fallback removed. Offer a QR-only check-in via UID entry.
      final String? fallbackUid = await showDialog<String?>(
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
                      'Biometric/face-embedding verification is not available. To proceed with QR-only check-in, enter your UID below or contact your administrator.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: uidCtrl,
                    decoration: const InputDecoration(labelText: 'Your UID'),
                  ),
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

      if (fallbackUid != null && fallbackUid.isNotEmpty) {
        final resp = await ApiClient.I.checkin(
            sessionId: '',
            qrToken: qrToken,
            studentUid: fallbackUid,
            method: 'qr');
        await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Check-in Result'),
                    content: Text(resp.toString()),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'))
                    ]));
        if (!mounted) return;
        setState(() {
          _scanning = false;
          _status = 'Align the QR code in the frame';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _scanning = false;
        _status = 'Align the QR code in the frame';
      });
    } catch (e, st) {
      debugPrint('Scan flow error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _status = 'Scan failed, try again';
      });
    }
  }

  Future<String> _scanSingleQrToken() async {
    final completer = Completer<String>();
    final controller = _qrController ??
        MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          formats: const [BarcodeFormat.qrCode],
        );

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.width * 0.85,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final value = barcodes.first.rawValue;
                      if (value != null && value.isNotEmpty) {
                        // Expecting rotating payload: "{sessionId}:{token}".
                        // Keep as is; FaceDetectionPage will parse it.
                        if (!completer.isCompleted) {
                          completer.complete(value);
                          Navigator.of(context).pop();
                        }
                      }
                    }
                  },
                ),
                Align(
                  alignment: Alignment.center,
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!completer.isCompleted) {
                  completer.completeError('cancelled');
                }
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    return completer.future;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _qrController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark mode background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Image.asset(
              "assets/images/IIITNR_Logo.png",
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Attendance - Scan QR',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                if (_cameraController != null)
                  CameraPreview(_cameraController!),
                // Simple overlay
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
              child: Text(
                _status,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: _scanning ? null : _onScanPressed,
              child: Text(_scanning ? 'Scanning...' : 'Scan'),
            ),
          ],
        ),
      ),
    );
  }
}
