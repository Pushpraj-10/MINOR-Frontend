import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

enum _AppMode { checking, enrollment, verification }

class FaceDetectionPage extends StatefulWidget {
  const FaceDetectionPage({Key? key}) : super(key: key);

  @override
  State<FaceDetectionPage> createState() => _FaceDetectionPageState();
}

class _FaceDetectionPageState extends State<FaceDetectionPage> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  late FaceRecognitionService _faceService;

  bool _cameraReady = false;
  bool _isProcessing = false;
  String _statusText = 'Initializing...';
  _AppMode _mode = _AppMode.checking;

  static const double similarityThreshold = 0.52;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    setState(() => _statusText = 'Loading model and services...');
    // 1) Load recognition model
    _faceService =
        await FaceRecognitionService.create(modelAsset: 'assets/models/mobile_face_net.tflite');

    // 2) Create ML Kit face detector
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
    );
    _faceDetector = FaceDetector(options: options);

    // 3) Check if embedding exists
    final stored = await _faceService.loadEmbedding();
    if (stored == null) {
      _mode = _AppMode.enrollment;
      _statusText = 'Mode: Enrollment (no stored embedding)';
    } else {
      _mode = _AppMode.verification;
      _statusText = 'Mode: Verification (stored embedding found)';
    }

    // 4) Initialize camera (front)
    await _initCamera();
    if (_cameraReady) {
      _startStream();
    }
    if (mounted) setState(() {});
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
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      if (!mounted) return;
      _cameraReady = true;
      setState(() => _statusText = 'Camera initialized. $_statusText');
    } catch (e) {
      setState(() => _statusText = 'Camera init error: $e');
      debugPrint('Camera init error: $e');
    }
  }

  void _startStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isStreamingImages) return;

    _cameraController!.startImageStream((CameraImage cameraImage) async {
      if (_isProcessing) return;
      _isProcessing = true;

      final inputImage = _cameraImageToInputImage(cameraImage);
      if (inputImage != null) {
        try {
          final faces = await _faceDetector!.processImage(inputImage);
          if (faces.isNotEmpty) {
            if (_cameraController!.value.isStreamingImages) {
              await _cameraController!.stopImageStream();
            }
            await _processDetectedFace(faces.first);

            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) _startStream();
          }
        } catch (e) {
          debugPrint('Face detection error: $e');
        }
      }

      _isProcessing = false;
    });
  }

  Future<void> _processDetectedFace(Face face) async {
    setState(() => _statusText = 'Face detected - capturing photo...');
    try {
      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      img.Image? baseImage = img.decodeImage(bytes);
      if (baseImage == null) {
        setState(() => _statusText = 'Failed to decode captured image');
        await _safeRestartStream();
        return;
      }

      final rect = face.boundingBox;
      img.Image faceCrop = img.copyCrop(
        baseImage,
        x: rect.left.toInt(),
        y: rect.top.toInt(),
        width: rect.width.toInt(),
        height: rect.height.toInt(),
      );

      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      if (leftEye != null && rightEye != null) {
        final dx = rightEye.position.x - leftEye.position.x;
        final dy = rightEye.position.y - leftEye.position.y;
        final angle = math.atan2(dy, dx) * (180 / math.pi);
        faceCrop = img.copyRotate(faceCrop, angle: -angle);
      }

      setState(() => _statusText = 'Extracting embedding...');
      final probe = _faceService.getEmbeddingFromImage(faceCrop);

      final stored = await _faceService.loadEmbedding();

      if (_mode == _AppMode.enrollment) {
        await _faceService.saveEmbedding(probe);
        setState(() {
          _statusText = 'Enrollment complete. Embedding saved.';
          _mode = _AppMode.verification;
        });
      } else {
        if (stored == null) {
          await _faceService.saveEmbedding(probe);
          setState(() {
            _statusText = 'No stored embedding found. Saved new embedding.';
            _mode = _AppMode.verification;
          });
        } else {
          final sim = _faceService.cosineSimilarity(probe, stored);
          if (sim >= similarityThreshold) {
            setState(
                () => _statusText = 'Verified (sim=${sim.toStringAsFixed(3)})');
          } else {
            setState(() =>
                _statusText = 'Not verified (sim=${sim.toStringAsFixed(3)})');
          }
        }
      }

      try {
        await File(file.path).delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('Error processing detected face: $e');
      setState(() => _statusText = 'Error: $e');
    } finally {
      await _safeRestartStream();
    }
  }

  Future<void> _safeRestartStream() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    if (_cameraController != null &&
        !_cameraController!.value.isStreamingImages) {
      try {
        _startStream();
      } catch (e) {
        debugPrint('Failed to restart stream: $e');
      }
    }
  }

  // ** THIS IS THE DEFINITIVE, CORRECTED FUNCTION **
  InputImage? _cameraImageToInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    final orientation = Platform.isIOS
        ? InputImageRotationValue.fromRawValue(sensorOrientation)
        : InputImageRotation.rotation0deg; // Will be handled by rotationCompensation

    if (orientation == null) return null;

    InputImageFormat? format;
    if (image.format.group == ImageFormatGroup.yuv420) {
      format = InputImageFormat.nv21;
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      format = InputImageFormat.bgra8888;
    } else {
      return null;
    }

    // Concatenate plane bytes into a single buffer
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // The metadata for each platform is different.
    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: orientation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  Future<void> _clearEnrollment() async {
    await _faceService.deleteEmbedding();
    setState(() {
      _mode = _AppMode.enrollment;
      _statusText = 'Cleared stored embedding. Mode: Enrollment';
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Detection'),
        actions: [
          IconButton(
            tooltip: 'Clear enrollment',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearEnrollment,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cameraReady && _cameraController != null
                ? Transform.scale(
                    scaleX: -1,
                    child: CameraPreview(_cameraController!),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                    child: Text(_statusText,
                        style: const TextStyle(color: Colors.white))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaceRecognitionService {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static const String _storageKey = 'face_embedding_v1';

  late final Interpreter _interpreter;
  late final int _inputSize;

  FaceRecognitionService._(this._interpreter, this._inputSize);

  static Future<FaceRecognitionService> create(
      {required String modelAsset, int inputSize = 112}) async {
    final interpreter = await Interpreter.fromAsset(modelAsset);
    return FaceRecognitionService._(interpreter, inputSize);
  }

  Float32List getEmbeddingFromImage(img.Image faceImage) {
    final resized =
        img.copyResize(faceImage, width: _inputSize, height: _inputSize);

    final imageMatrix = List.generate(
      _inputSize,
      (y) => List.generate(
        _inputSize,
        (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (pixel.r - 127.5) / 127.5,
            (pixel.g - 127.5) / 127.5,
            (pixel.b - 127.5) / 127.5,
          ];
        },
      ),
    );

    final input = [imageMatrix];
    final output = List.filled(1 * 192, 0.0).reshape([1, 192]);
    _interpreter.run(input, output);
    return _l2Normalize(
        Float32List.fromList((output[0] as List).cast<double>()));
  }

  Float32List _l2Normalize(Float32List v) {
    double sum = v.fold(0, (prev, elem) => prev + elem * elem);
    final norm = math.sqrt(sum);
    if (norm == 0) return v;
    return Float32List.fromList(v.map((e) => e / norm).toList());
  }

  Future<void> saveEmbedding(Float32List embedding) async {
    final bytes = embedding.buffer.asUint8List();
    final encoded = base64Encode(bytes);
    await _secure.write(key: _storageKey, value: encoded);
  }

  Future<Float32List?> loadEmbedding() async {
    final encoded = await _secure.read(key: _storageKey);
    if (encoded == null) return null;
    try {
      final bytes = base64Decode(encoded);
      return bytes.buffer.asFloat32List();
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteEmbedding() async {
    await _secure.delete(key: _storageKey);
  }

  double cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) return -2.0;
    double dot = 0;
    for (int i = 0; i < a.length; i++) dot += a[i] * b[i];
    return dot;
  }

  void dispose() {
    _interpreter.close();
  }
}