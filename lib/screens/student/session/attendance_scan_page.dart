import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'face_detection_page.dart';
import 'face_enrollment_page.dart';
import 'face_recognition_service.dart';

class AttendanceScanPage extends StatefulWidget {
  const AttendanceScanPage({Key? key}) : super(key: key);

  @override
  State<AttendanceScanPage> createState() => _AttendanceScanPageState();
}

class _AttendanceScanPageState extends State<AttendanceScanPage> {
  CameraController? _cameraController;
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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
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
      // Simulate a short scan delay
      await Future.delayed(const Duration(milliseconds: 700));

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

  @override
  void dispose() {
    _cameraController?.dispose();
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
