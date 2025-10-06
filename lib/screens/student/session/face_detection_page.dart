// face_detection_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image/image.dart' as img;
import 'package:go_router/go_router.dart';

import 'face_recognition_service.dart';
import 'dashboard_page.dart';

// Init state enum
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

  _InitState _initState = _InitState.checking;
  bool _isProcessing = false;
  String _statusText = 'Initializing...';
  double? _similarity;
  List<Face> _faces = []; // for painter

  // Default threshold — tune it for your app/model.
  static const double similarityThreshold = 0.6;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    setState(() => _statusText = 'Loading model...');
    // Corrected model name for consistency
    _faceService = await FaceRecognitionService.create(
      modelAsset: 'assets/models/mobile_face_net.tflite',
    );

    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
    );
    _faceDetector = FaceDetector(options: options);

    final storedEmbedding = await _faceService.loadEmbedding();
    if (storedEmbedding == null) {
      if (mounted) {
        setState(() => _initState = _InitState.needsEnrollment);
        _showEnrollmentDialog();
      }
    } else {
      await _initCamera();
      if (mounted && _cameraController?.value.isInitialized == true) {
        setState(() {
          _initState = _InitState.ready;
          _statusText = 'Ready to scan face';
        });
        _startStream();
      } else if (mounted) {
        setState(() => _statusText = 'Camera failed to initialize.');
      }
    }
  }

  void _showEnrollmentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registration Required'),
        content: const Text(
            'No face embedding is present. You have to register first.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (c) => const DashboardPage()),
              );
            },
          ),
        ],
      ),
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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
    } catch (e, st) {
      debugPrint('Camera init error: $e\n$st');
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
          if (mounted) setState(() => _faces = faces);

          if (faces.isNotEmpty) {
            // stop stream temporarily, process first face
            await _cameraController?.stopImageStream();
            await _processDetectedFaceFromCameraImage(cameraImage, faces.first);
          } else {
            if (mounted && _similarity == null)
              setState(() => _statusText = 'Look directly at the camera.');
          }
        } catch (e, st) {
          debugPrint('Face detection error: $e\n$st');
        }
      }

      _isProcessing = false;
    });
  }

  Future<void> _processDetectedFaceFromCameraImage(
      CameraImage cameraImage, Face face) async {
    if (!mounted) return;
    bool shouldRestartStream = true;
    try {
      setState(() => _statusText = 'Processing face...');
      final img.Image? fullImage =
          await _convertCameraImageToImage(cameraImage);

      if (fullImage == null) {
        setState(() => _statusText = 'Frame conversion failed. Retrying...');
        return;
      }

      // Crop the face using bounding box
      final rect = face.boundingBox;
      final int left = rect.left.round().clamp(0, fullImage.width - 1);
      final int top = rect.top.round().clamp(0, fullImage.height - 1);
      final int width = rect.width.round().clamp(1, fullImage.width - left);
      final int height = rect.height.round().clamp(1, fullImage.height - top);

      img.Image faceCrop = img.copyCrop(fullImage,
          x: left, y: top, width: width, height: height);

      // Align face using eyes if available
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      if (leftEye != null && rightEye != null) {
        final dx = rightEye.position.x - leftEye.position.x;
        final dy = rightEye.position.y - leftEye.position.y;
        final angle = math.atan2(dy, dx) * (180 / math.pi);
        // Ensure integer angle for copyRotate
        faceCrop = img.copyRotate(faceCrop, angle: -angle.round());
      }

      final probe = _faceService.getEmbeddingFromImage(faceCrop);
      final stored = await _faceService.loadEmbedding();

      String newStatus;
      double? sim;
      bool verified = false;

      if (stored != null) {
        sim = _faceService.cosineSimilarity(probe, stored);
        verified = sim >= similarityThreshold;
        newStatus = verified ? 'Verified' : 'Verification Failed';
      } else {
        newStatus = 'No stored embedding found.';
      }

      if (mounted) {
        setState(() {
          _similarity = sim;
          _statusText = newStatus;
        });
      }

      if (verified && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Verification Successful'),
            content: const Text('Your face has been verified.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        context.go('/student/dashboard');
        shouldRestartStream = false;
        return;
      }
    } catch (e, st) {
      debugPrint('Error processing face: $e\n$st');
      if (mounted)
        setState(() => _statusText = 'Processing error. Retrying...');
    } finally {
      if (shouldRestartStream) {
        await _safeRestartStream();
      }
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
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Verification')),
      body: _buildBody(),
      bottomNavigationBar: Container(
        color: _similarity == null
            ? Colors.black87
            : (_similarity! >= similarityThreshold
                ? Colors.green.shade700
                : Colors.red.shade700),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_statusText,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (_similarity != null)
              Text('Accuracy: ${(_similarity! * 100).toStringAsFixed(2)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initState == _InitState.ready &&
        _cameraController?.value.isInitialized == true) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(scaleX: -1, child: CameraPreview(_cameraController!)),
          if (_faces.isNotEmpty && _cameraController!.value.previewSize != null)
            CustomPaint(
              painter: FacePainter(
                faces: _faces,
                imageSize: _cameraController!.value.previewSize!,
                cameraLensDirection:
                    _cameraController!.description.lensDirection,
              ),
            ),
        ],
      );
    }

    if (_initState == _InitState.needsEnrollment) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
              'Registration is required before face verification can begin.'),
        ),
      );
    }
    
    return const Center(child: CircularProgressIndicator());
  }

  // --- Image Conversion Functions (Used by ML Kit) ---
  InputImage? _cameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      final rotationCompensation =
          orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      final compensatedOrientation =
          (sensorOrientation + rotationCompensation) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensatedOrientation);
    } else if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.format.group == ImageFormatGroup.yuv420) {
      final bytes = _concatenatePlanes(image.planes);
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      final bytes = image.planes[0].bytes;
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
    return null;
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // --- Isolate Image Conversion for Face Recognition Service ---
  Future<img.Image?> _convertCameraImageToImage(CameraImage image) async {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        final Map<String, dynamic> params = {
          'format': 'yuv420',
          'width': image.width,
          'height': image.height,
          'y': image.planes[0].bytes,
          'u': image.planes[1].bytes,
          'v': image.planes[2].bytes,
          'uvRowStride': image.planes[1].bytesPerRow,
          'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
          'sensorOrientation': _cameraController!.description.sensorOrientation,
          'deviceOrientation': _cameraController!.value.deviceOrientation.index,
          'mirrorFront': _cameraController!.description.lensDirection ==
              CameraLensDirection.front,
        };
        final Uint8List jpeg = await compute(_yuv420ToJpegBytes, params);
        return img.decodeJpg(jpeg);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        final Map<String, dynamic> params = {
          'format': 'bgra8888',
          'width': image.width,
          'height': image.height,
          'bytes': image.planes[0].bytes,
          'sensorOrientation': _cameraController!.description.sensorOrientation,
          'deviceOrientation': _cameraController!.value.deviceOrientation.index,
          'mirrorFront': _cameraController!.description.lensDirection ==
              CameraLensDirection.front,
        };
        final Uint8List jpeg = await compute(_bgraToJpegBytes, params);
        return img.decodeJpg(jpeg);
      }
      return null;
    } catch (e, st) {
      debugPrint('Conversion error: $e\n$st');
      return null;
    }
  }
}

// --------------------
// ISOLATE FUNCTIONS (TOP-LEVEL)
// --------------------

Future<Uint8List> _yuv420ToJpegBytes(Map<String, dynamic> params) async {
  final int width = params['width'] as int;
  final int height = params['height'] as int;
  final Uint8List y = params['y'] as Uint8List;
  final Uint8List u = params['u'] as Uint8List;
  final Uint8List v = params['v'] as Uint8List;
  final int uvRowStride = params['uvRowStride'] as int;
  final int uvPixelStride =
      params['uvPixelStride'] is int ? params['uvPixelStride'] as int : 1;

  final img.Image image = img.Image(width: width, height: height);

  for (int row = 0; row < height; row++) {
    final int uvRow = (row / 2).floor();
    for (int col = 0; col < width; col++) {
      final int yIndex = row * width + col;
      final int uvCol = (col / 2).floor();
      final int uvIndex = uvCol * uvPixelStride + uvRow * uvRowStride;

      final int yp = y[yIndex] & 0xff;
      int up = u[uvIndex] & 0xff;
      int vp = v[uvIndex] & 0xff;

      final double yD = yp.toDouble();
      final double uD = (up - 128).toDouble();
      final double vD = (vp - 128).toDouble();

      int r = (yD + 1.403 * vD).round().clamp(0, 255);
      int g = (yD - 0.344 * uD - 0.714 * vD).round().clamp(0, 255);
      int b = (yD + 1.770 * uD).round().clamp(0, 255);

      image.setPixelRgba(col, row, r, g, b, 255);
    }
  }

  final int sensorOrientation = params['sensorOrientation'] as int;
  final int deviceOrientationIndex = params['deviceOrientation'] as int;
  final bool mirrorFront = params['mirrorFront'] as bool;
  const List<int> deviceIndexToDegrees = [0, 90, 180, 270];
  final int deviceDegrees = deviceIndexToDegrees[
      deviceOrientationIndex % deviceIndexToDegrees.length];
  final int rotationDegrees = (sensorOrientation + deviceDegrees) % 360;

  img.Image oriented = image;

  if (rotationDegrees == 90) {
    oriented = img.copyRotate(oriented, angle: 90);
  } else if (rotationDegrees == 180) {
    oriented = img.copyRotate(oriented, angle: 180);
  } else if (rotationDegrees == 270) {
    oriented = img.copyRotate(oriented, angle: 270);
  }

  if (mirrorFront) oriented = img.flipHorizontal(oriented);

  final List<int> jpg = img.encodeJpg(oriented, quality: 85);
  return Uint8List.fromList(jpg);
}

Future<Uint8List> _bgraToJpegBytes(Map<String, dynamic> params) async {
  final int width = params['width'] as int;
  final int height = params['height'] as int;
  final dynamic bytesParam = params['bytes'];
  ByteBuffer byteBuffer;
  if (bytesParam is ByteBuffer) {
    byteBuffer = bytesParam;
  } else if (bytesParam is Uint8List) {
    byteBuffer = bytesParam.buffer;
  } else if (bytesParam is List<int>) {
    final Uint8List copy = Uint8List.fromList(bytesParam.cast<int>());
    byteBuffer = copy.buffer;
  } else {
    throw ArgumentError('Unsupported bytes type: ${bytesParam.runtimeType}');
  }

  // Pass ByteBuffer directly as required by image.fromBytes signature
  final img.Image image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: byteBuffer,
      order: img.ChannelOrder.bgra);

  final int sensorOrientation = params['sensorOrientation'] as int;
  final int deviceOrientationIndex = params['deviceOrientation'] as int;
  final bool mirrorFront = params['mirrorFront'] as bool;
  const List<int> deviceIndexToDegrees = [0, 90, 180, 270];
  final int deviceDegrees = deviceIndexToDegrees[
      deviceOrientationIndex % deviceIndexToDegrees.length];
  final int rotationDegrees = (sensorOrientation + deviceDegrees) % 360;

  img.Image oriented = image;

  if (rotationDegrees == 90) {
    oriented = img.copyRotate(oriented, angle: 90);
  } else if (rotationDegrees == 180) {
    oriented = img.copyRotate(oriented, angle: 180);
  } else if (rotationDegrees == 270) {
    oriented = img.copyRotate(oriented, angle: 270);
  }

  if (mirrorFront) oriented = img.flipHorizontal(oriented);

  final List<int> jpg = img.encodeJpg(oriented, quality: 85);
  return Uint8List.fromList(jpg);
}

// --------------------
// FacePainter Class for Bounding Box Visualization
// --------------------
class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    // Scaling logic accounts for camera frame (imageSize) being potentially rotated relative to the UI (size).
    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    for (final face in faces) {
      double left, top, right, bottom;

      if (cameraLensDirection == CameraLensDirection.front) {
        // Front camera requires mirroring coordinates
        left = size.width - (face.boundingBox.left * scaleX);
        top = face.boundingBox.top * scaleY;
        right = size.width - (face.boundingBox.right * scaleX);
        bottom = face.boundingBox.bottom * scaleY;
      } else {
        // Back camera
        left = face.boundingBox.left * scaleX;
        top = face.boundingBox.top * scaleY;
        right = face.boundingBox.right * scaleX;
        bottom = face.boundingBox.bottom * scaleY;
      }

      // Draw stable rect even if coordinates inverted
      final double l = math.min(left, right);
      final double r = math.max(left, right);
      final double t = math.min(top, bottom);
      final double b = math.max(top, bottom);
      canvas.drawRect(Rect.fromLTRB(l, t, r, b), paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
