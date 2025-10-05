import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'face_detection_page.dart';
import 'face_enrollment_page.dart';
import 'face_recognition_service.dart';
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

      // Decide flow using stored embedding
      final FaceRecognitionService svc = await FaceRecognitionService.create(
        modelAsset: 'assets/models/mobile_face_net.tflite',
      );
      final embedding = await svc.loadEmbedding();
      svc.dispose();

      if (!mounted) return;
      if (embedding == null) {
        // No embedding -> enroll
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FaceEnrollmentPage()),
        );
      } else {
        // Embedding exists -> verify
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FaceDetectionPage()),
        );
      }

      // After returning, try check-in
      final me = await ApiClient.I.me();
      final uid = (me['user']?['uid'] as String?) ?? '';
      final result = await ApiClient.I.checkin(
        qrToken: qrToken,
        studentUid: uid,
        embedding: embedding?.map((e) => e.toDouble()).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['verified'] == true
                ? 'Attendance marked'
                : 'Check-in recorded (unverified)')),
      );

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
                      if (value != null &&
                          value.isNotEmpty &&
                          !completer.isCompleted) {
                        completer.complete(value);
                        Navigator.of(context).pop();
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
      appBar: AppBar(title: const Text('Attendance - Scan QR')),
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
