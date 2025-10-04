import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import 'face_recognition_service.dart';
import 'dashboard_page.dart';

class FaceEnrollmentPage extends StatefulWidget {
  const FaceEnrollmentPage({Key? key}) : super(key: key);

  @override
  State<FaceEnrollmentPage> createState() => _FaceEnrollmentPageState();
}

class _FaceEnrollmentPageState extends State<FaceEnrollmentPage> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  late FaceRecognitionService _faceService;

  bool _cameraReady = false;
  bool _isProcessing = false;
  String _statusText = 'Please look at the camera';

  img.Image? _facePreview;
  Float32List? _capturedEmbedding;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    setState(() => _statusText = 'Loading face model...');
    _faceService = await FaceRecognitionService.create(
      modelAsset: 'assets/models/FaceAntiSpoofing.tflite',
    );

    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
    );
    _faceDetector = FaceDetector(options: options);

    await _startEnrollment();
  }

  Future<void> _startEnrollment() async {
    setState(() => _statusText = 'Initializing camera...');
    await _initCamera();
    if (_cameraReady) {
      _startStream();
    }
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
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      _cameraReady = true;
      setState(() {});
    } catch (e, st) {
      debugPrint('Camera init error: $e\n$st');
      setState(() => _statusText = 'Camera initialization failed.');
    }
  }

  void _startStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isStreamingImages) return;

    _cameraController!.startImageStream((CameraImage cameraImage) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final inputImage = _cameraImageToInputImage(cameraImage);
        if (inputImage == null) {
          _isProcessing = false;
          return;
        }

        final faces = await _faceDetector!.processImage(inputImage);
        if (faces.isNotEmpty) {
          if (mounted) await _cameraController?.stopImageStream();
          await _processDetectedFaceFromCameraImage(cameraImage, faces.first);
        }
      } catch (e, st) {
        debugPrint('Stream/process error: $e\n$st');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    });
  }

  Future<void> _processDetectedFaceFromCameraImage(
      CameraImage cameraImage, Face face) async {
    setState(() => _statusText = 'Face detected. Capturing...');

    try {
      final img.Image? frameImage = _convertCameraImageToImage(cameraImage);
      if (frameImage == null) {
        _retryEnrollment();
        return;
      }

      final rect = face.boundingBox;

      final int left = rect.left.round().clamp(0, frameImage.width - 1);
      final int top = rect.top.round().clamp(0, frameImage.height - 1);
      final int width = rect.width.round().clamp(1, frameImage.width - left);
      final int height = rect.height.round().clamp(1, frameImage.height - top);

      img.Image faceCrop = img.copyCrop(frameImage,
          x: left, y: top, width: width, height: height);

      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      if (leftEye != null && rightEye != null) {
        final dx = rightEye.position.x - leftEye.position.x;
        final dy = rightEye.position.y - leftEye.position.y;
        final angle = math.atan2(dy, dx) * (180 / math.pi);
        faceCrop = img.copyRotate(faceCrop, angle: -angle);
      }

      final Float32List embedding =
          _faceService.getEmbeddingFromImage(faceCrop);

      if (mounted) {
        setState(() {
          _facePreview = faceCrop;
          _capturedEmbedding = embedding;
          _statusText = 'Confirm your enrollment photo.';
        });
      }
    } catch (e, st) {
      debugPrint('Enrollment capture error: $e\n$st');
      _retryEnrollment();
    }
  }

  Future<void> _saveEnrollment() async {
    if (_capturedEmbedding == null || !mounted) return;

    await _faceService.saveEmbedding(_capturedEmbedding!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enrollment Successful!')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DashboardPage()),
      (Route<dynamic> route) => false,
    );
  }

  void _retryEnrollment() {
    setState(() {
      _facePreview = null;
      _capturedEmbedding = null;
      _statusText = 'Please look at the camera again.';
    });
    if (_cameraController != null &&
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
      appBar: AppBar(title: const Text('Register Your Face')),
      body: _buildBody(),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(12),
        child: Text(_statusText,
            style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  Widget _buildBody() {
    if (_facePreview != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Use this photo for registration?',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Image.memory(
              Uint8List.fromList(img.encodeJpg(_facePreview!)),
              width: 250,
              height: 250,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _retryEnrollment,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Retry'),
                ),
                ElevatedButton(
                  onPressed: _saveEnrollment,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_cameraReady && _cameraController != null) {
      return Transform.scale(
        scaleX: -1.0,
        child: CameraPreview(_cameraController!),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
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

  img.Image? _convertCameraImageToImage(CameraImage image) {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420(image);
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        return img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      }
      return null;
    } catch (e) {
      debugPrint("Error converting image: $e");
      return null;
    }
  }

  img.Image _convertYUV420(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;
    final imageResult = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1.402).round().clamp(0, 255);
        int g = (yp - up * 0.344 - vp * 0.714).round().clamp(0, 255);
        int b = (yp + up * 1.772).round().clamp(0, 255);

        imageResult.setPixelRgb(x, y, r, g, b);
      }
    }
    return imageResult;
  }
}
