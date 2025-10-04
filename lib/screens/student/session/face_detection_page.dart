import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import 'face_recognition_service.dart';
import 'dashboard_page.dart';

// New enum to manage initialization state
enum _InitState { checking, needsEnrollment, ready }

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({Key? key}) : super(key: key);

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  late FaceRecognitionService _faceService;

  // Use the new enum for state management
  _InitState _initState = _InitState.checking;

  bool _isProcessing = false;
  String _statusText = 'Initializing...';
  double? _similarity;

  static const double similarityThreshold = 0.52;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  // --- REVISED INITIALIZATION LOGIC ---
  Future<void> _initializeAll() async {
    setState(() => _statusText = 'Loading model...');
    _faceService = await FaceRecognitionService.create(
        modelAsset: 'assets/models/FaceAntiSpoofing.tflite');

    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
    );
    _faceDetector = FaceDetector(options: options);

    final storedEmbedding = await _faceService.loadEmbedding();

    if (storedEmbedding == null) {
      // If no embedding, update state to show dialog and wait.
      // Do NOT initialize the camera here.
      if (mounted) {
        setState(() => _initState = _InitState.needsEnrollment);
        _showEnrollmentDialog();
      }
    } else {
      // If embedding exists, update state to ready and proceed.
      await _initCamera();
      if (mounted) {
        setState(() => _initState = _InitState.ready);
        _startStream();
      }
    }
  }

  void _showEnrollmentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Registration Required'),
          content: const Text(
              'No face embedding is present. You have to register first.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) => const DashboardPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await _cameraController!.initialize();
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _startStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isStreamingImages) return;

    _cameraController!.startImageStream((CameraImage cameraImage) async {
      if (_isProcessing) return;
      _isProcessing = true;

      final inputImage = _cameraImageToInputImage(cameraImage);
      if (inputImage != null) {
        try {
          final faces = await _faceDetector!.processImage(inputImage);
          if (faces.isNotEmpty) {
            if (mounted) await _cameraController?.stopImageStream();
            await _processDetectedFace(faces.first);
            await _safeRestartStream();
          }
        } catch (e) {
          debugPrint('Face detection error: $e');
        }
      }
      _isProcessing = false;
    });
  }

  Future<void> _processDetectedFace(Face face) async {
    if (!mounted) return;
    try {
      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      img.Image? baseImage = img.decodeImage(bytes);
      if (baseImage == null) return;

      final rect = face.boundingBox;
      img.Image faceCrop = img.copyCrop(baseImage,
          x: rect.left.toInt(),
          y: rect.top.toInt(),
          width: rect.width.toInt(),
          height: rect.height.toInt());

      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      if (leftEye != null && rightEye != null) {
        final dx = rightEye.position.x - leftEye.position.x;
        final dy = rightEye.position.y - leftEye.position.y;
        final angle = math.atan2(dy, dx) * (180 / math.pi);
        faceCrop = img.copyRotate(faceCrop, angle: -angle);
      }

      final probe = _faceService.getEmbeddingFromImage(faceCrop);
      final stored = await _faceService.loadEmbedding();

      if (stored != null) {
        final sim = _faceService.cosineSimilarity(probe, stored);
        if (mounted) {
          setState(() {
            _similarity = sim;
            _statusText =
                sim >= similarityThreshold ? 'Verified' : 'Not Verified';
          });
        }
      }
    } catch (e) {
      debugPrint("Error processing face: $e");
    }
  }

  Future<void> _safeRestartStream() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted &&
        _cameraController != null &&
        !_cameraController!.value.isStreamingImages) {
      _startStream();
    }
  }

  @override
  void dispose() {
    if (_cameraController?.value.isStreamingImages == true) {
      _cameraController?.stopImageStream();
    }
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Verification')),
      body: _buildBody(),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_statusText,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (_similarity != null)
              Text(
                'Accuracy: ${(_similarity! * 100).toStringAsFixed(2)}%',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Only show camera preview if the state is 'ready'
    if (_initState == _InitState.ready &&
        _cameraController?.value.isInitialized == true) {
      return Transform.scale(
          scaleX: -1, child: CameraPreview(_cameraController!));
    }
    // Otherwise, show an indicator
    return const Center(child: CircularProgressIndicator());
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
    // ... (This function remains exactly the same as the last version)
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          (camera.lensDirection == CameraLensDirection.front) ? 0 : 90;
      rotation = InputImageRotationValue.fromRawValue(
          (sensorOrientation + rotationCompensation) % 360);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
