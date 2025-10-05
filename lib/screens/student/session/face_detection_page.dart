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
  static const double similarityThreshold = 0.52;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    setState(() => _statusText = 'Loading model...');
    _faceService = await FaceRecognitionService.create(
      modelAsset: 'assets/models/mobile_facenet.tflite',
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
      builder: (context) => AlertDialog(
        title: const Text('Registration Required'),
        content: const Text('No face embedding is present. You have to register first.'),
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
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
          if (faces.isNotEmpty) {
            if (mounted) await _cameraController?.stopImageStream();
            await _processDetectedFaceFromCameraImage(cameraImage, faces.first);
            await _safeRestartStream();
          }
        } catch (e, st) {
          debugPrint('Face detection error: $e\n$st');
        }
      }

      _isProcessing = false;
    });
  }

  Future<void> _processDetectedFaceFromCameraImage(CameraImage cameraImage, Face face) async {
    if (!mounted) return;
    try {
      setState(() => _statusText = 'Processing face...');
      final img.Image? fullImage = await _convertCameraImageToImage(cameraImage);
      if (fullImage == null) {
        setState(() => _statusText = 'Frame conversion failed');
        return;
      }

      // bounding box is in the same orientation because conversion applied rotation/mirror
      final rect = face.boundingBox;
      final int left = rect.left.round().clamp(0, fullImage.width - 1);
      final int top = rect.top.round().clamp(0, fullImage.height - 1);
      final int width = rect.width.round().clamp(1, fullImage.width - left);
      final int height = rect.height.round().clamp(1, fullImage.height - top);

      img.Image faceCrop = img.copyCrop(fullImage, x: left, y: top, width: width, height: height);

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
            _statusText = sim >= similarityThreshold ? 'Verified' : 'Not Verified';
          });
        }
      } else {
        setState(() => _statusText = 'No stored embedding');
      }
    } catch (e, st) {
      debugPrint('Error processing face: $e\n$st');
      setState(() => _statusText = 'Processing error');
    }
  }

  Future<void> _safeRestartStream() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted && _cameraController != null && !_cameraController!.value.isStreamingImages) {
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
            Text(_statusText, style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (_similarity != null)
              Text('Accuracy: ${(_similarity! * 100).toStringAsFixed(2)}%', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initState == _InitState.ready && _cameraController?.value.isInitialized == true) {
      return Transform.scale(scaleX: -1, child: CameraPreview(_cameraController!));
    }
    return const Center(child: CircularProgressIndicator());
  }

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
      final rotationCompensation = orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      final compensatedOrientation = (sensorOrientation + rotationCompensation) % 360;
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

  // Convert CameraImage to img.Image using an isolate to avoid UI jank.
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
          'mirrorFront': _cameraController!.description.lensDirection == CameraLensDirection.front,
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
          'mirrorFront': _cameraController!.description.lensDirection == CameraLensDirection.front,
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
// Isolate helpers (top-level)
// --------------------
Future<Uint8List> _yuv420ToJpegBytes(Map<String, dynamic> params) async {
  final int width = params['width'] as int;
  final int height = params['height'] as int;
  final Uint8List y = params['y'] as Uint8List;
  final Uint8List u = params['u'] as Uint8List;
  final Uint8List v = params['v'] as Uint8List;
  final int uvRowStride = params['uvRowStride'] as int;
  final int uvPixelStride = params['uvPixelStride'] as int;

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
  final int deviceDegrees = deviceIndexToDegrees[deviceOrientationIndex % deviceIndexToDegrees.length];
  final int rotationDegrees = (sensorOrientation + deviceDegrees) % 360;

  img.Image oriented = image;
  if (rotationDegrees != 0) oriented = img.copyRotate(oriented, angle: rotationDegrees);
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

  final img.Image image = img.Image.fromBytes(width: width, height: height, bytes: byteBuffer, order: img.ChannelOrder.bgra);

  final int sensorOrientation = params['sensorOrientation'] as int;
  final int deviceOrientationIndex = params['deviceOrientation'] as int;
  final bool mirrorFront = params['mirrorFront'] as bool;
  const List<int> deviceIndexToDegrees = [0, 90, 180, 270];
  final int deviceDegrees = deviceIndexToDegrees[deviceOrientationIndex % deviceIndexToDegrees.length];
  final int rotationDegrees = (sensorOrientation + deviceDegrees) % 360;

  img.Image oriented = image;
  if (rotationDegrees != 0) oriented = img.copyRotate(oriented, angle: rotationDegrees);
  if (mirrorFront) oriented = img.flipHorizontal(oriented);

  final List<int> jpg = img.encodeJpg(oriented, quality: 85);
  return Uint8List.fromList(jpg);
}
