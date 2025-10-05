// face_enrollment_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

import 'face_recognition_service.dart';

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
  List<Face> _faces = [];

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    setState(() => _statusText = 'Loading face model...');
    _faceService = await FaceRecognitionService.create(
      modelAsset: 'assets/models/mobile_face_net.tflite',
    );
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
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
        ResolutionPreset.high,
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
        if (mounted) setState(() => _faces = faces);
        if (faces.isNotEmpty) {
          if (mounted) await _cameraController?.stopImageStream();
          await _processDetectedFaceFromCameraImage(cameraImage, faces.first);
        }
      } catch (e, st) {
        debugPrint('Stream/process error: $e\n$st');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> _processDetectedFaceFromCameraImage(
      CameraImage cameraImage, Face face) async {
    setState(() {
      _faces = [];
      _statusText = 'Face detected. Capturing...';
    });
    try {
      // Convert camera image to oriented RGB image in a background isolate.
      final img.Image? frameImage =
          await _convertCameraImageToImage(cameraImage);
      if (frameImage == null) {
        _retryEnrollment();
        return;
      }

      // Face bounding box coordinates are in the same orientation as the
      // image we produced because we applied rotation/mirroring when converting.
      final rect = face.boundingBox;
      final int left = rect.left.round().clamp(0, frameImage.width - 1);
      final int top = rect.top.round().clamp(0, frameImage.height - 1);
      final int width = rect.width.round().clamp(1, frameImage.width - left);
      final int height = rect.height.round().clamp(1, frameImage.height - top);

      img.Image faceCrop = img.copyCrop(frameImage,
          x: left, y: top, width: width, height: height);

      // If eyes are detected, rotate crop to align eyes horizontally.
      final leftEye = face.landmarks[FaceLandmarkType.leftEye];
      final rightEye = face.landmarks[FaceLandmarkType.rightEye];
      if (leftEye != null && rightEye != null) {
        final dx = rightEye.position.x - leftEye.position.x;
        final dy = rightEye.position.y - leftEye.position.y;
        final angle = math.atan2(dy, dx) * (180 / math.pi);
        faceCrop = img.copyRotate(faceCrop, angle: -angle);
      }

      // Generate embedding (synchronously on UI isolate).
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
    context.go('/student/attendance');
  }

  void _retryEnrollment() {
    setState(() {
      _facePreview = null;
      _capturedEmbedding = null;
      _faces = [];
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ElevatedButton(
              onPressed: _retryEnrollment,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('Retry'),
            ),
            ElevatedButton(
              onPressed: _saveEnrollment,
              child: const Text('Save'),
            ),
          ]),
        ]),
      );
    }
    if (_cameraReady && _cameraController != null) {
      return Stack(fit: StackFit.expand, children: [
        // Mirror preview for front camera so UI looks natural.
        Transform.scale(
          scaleX: -1.0,
          child: CameraPreview(_cameraController!),
        ),
        if (_faces.isNotEmpty && _cameraController!.value.previewSize != null)
          CustomPaint(
            painter: FacePainter(
              faces: _faces,
              imageSize: _cameraController!.value.previewSize!,
              cameraLensDirection: _cameraController!.description.lensDirection,
            ),
          ),
      ]);
    }
    return const Center(child: CircularProgressIndicator());
  }

  // Builds InputImage for ML Kit face detector using bytes+metadata.
  InputImage? _cameraImageToInputImage(CameraImage image) {
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

  // Main conversion function: sends CameraImage data to an isolate and returns an img.Image
  Future<img.Image?> _convertCameraImageToImage(CameraImage image) async {
    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        // pack the minimal data for isolate
        final Map<String, dynamic> params = {
          'format': 'yuv420',
          'width': image.width,
          'height': image.height,
          'y': image.planes[0].bytes,
          'u': image.planes[1].bytes,
          'v': image.planes[2].bytes,
          'uvRowStride': image.planes[1].bytesPerRow,
          'uvPixelStride': image.planes[1].bytesPerPixel,
          // rotation degrees that ML Kit expects (so we create an image aligned to MLKit)
          'sensorOrientation': _cameraController!.description.sensorOrientation,
          'deviceOrientation': _cameraController!.value.deviceOrientation.index,
          'mirrorFront': _cameraController!.description.lensDirection ==
              CameraLensDirection.front,
          // Note: we pass the device orientation index; the isolate will compute rotation similar to _cameraImageToInputImage
        };

        // compute returns Uint8List (JPEG bytes)
        final Uint8List jpeg = await compute(_yuv420ToJpegBytes, params);
        final img.Image? decoded = img.decodeJpg(jpeg);
        return decoded;
      } else if (image.format.group == ImageFormatGroup.bgra8888) {
        final Map<String, dynamic> params = {
          'format': 'bgra8888',
          'width': image.width,
          'height': image.height,
          'bytes': image.planes[0].bytes,
          'bytesPerRow': image.planes[0].bytesPerRow,
          'sensorOrientation': _cameraController!.description.sensorOrientation,
          'deviceOrientation': _cameraController!.value.deviceOrientation.index,
          'mirrorFront': _cameraController!.description.lensDirection ==
              CameraLensDirection.front,
        };
        final Uint8List jpeg = await compute(_bgraToJpegBytes, params);
        final img.Image? decoded = img.decodeJpg(jpeg);
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint("Error converting image: $e");
      return null;
    }
  }
}

// --------------------
// ISOLATE FUNCTIONS
// --------------------
//
// These top-level functions are executed inside an isolate via compute()
// to avoid blocking the UI thread. They convert YUV420 / BGRA frames
// into an oriented RGB image and return JPEG bytes for transfer.

// YUV420 -> img.Image -> JPEG bytes
Future<Uint8List> _yuv420ToJpegBytes(Map<String, dynamic> params) async {
  final int width = params['width'] as int;
  final int height = params['height'] as int;
  final Uint8List y = params['y'] as Uint8List;
  final Uint8List u = params['u'] as Uint8List;
  final Uint8List v = params['v'] as Uint8List;
  final int uvRowStride = params['uvRowStride'] as int;
  final int? uvPixelStrideDynamic = params['uvPixelStride'];
  final int uvPixelStride =
      uvPixelStrideDynamic is int ? uvPixelStrideDynamic : 1;

  // Create image buffer
  final img.Image image = img.Image(width: width, height: height);

  // YUV -> RGB conversion (NV21/NV12 style, using U/V planes)
  for (int row = 0; row < height; row++) {
    final int uvRow = (row / 2).floor();
    for (int col = 0; col < width; col++) {
      final int yIndex = row * width + col;
      final int uvCol = (col / 2).floor();
      final int uvIndex = uvCol * uvPixelStride + uvRow * uvRowStride;

      final int yp = y[yIndex] & 0xff;
      int up = u[uvIndex] & 0xff;
      int vp = v[uvIndex] & 0xff;

      // Center chroma and convert using float math
      final double yD = yp.toDouble();
      final double uD = (up - 128).toDouble();
      final double vD = (vp - 128).toDouble();

      int r = (yD + 1.403 * vD).round().clamp(0, 255);
      int g = (yD - 0.344 * uD - 0.714 * vD).round().clamp(0, 255);
      int b = (yD + 1.770 * uD).round().clamp(0, 255);

      image.setPixelRgba(col, row, r, g, b, 255);
    }
  }

  // Apply rotation/mirroring if needed to produce same orientation as ML Kit's bounding boxes.
  // We attempt to compute rotation using passed sensorOrientation + deviceOrientation index.
  // deviceOrientation index mapping: 0=portraitUp,1=landscapeLeft,2=portraitDown,3=landscapeRight
  // This mirrors the mapping used on the UI isolate.
  final int sensorOrientation = params['sensorOrientation'] as int;
  final int deviceOrientationIndex = params['deviceOrientation'] as int;
  final bool mirrorFront = params['mirrorFront'] as bool;

  // convert deviceOrientationIndex back to degrees (same mapping used earlier)
  const List<int> deviceIndexToDegrees = [0, 90, 180, 270];
  final int deviceDegrees = deviceIndexToDegrees[
      deviceOrientationIndex % deviceIndexToDegrees.length];
  final int rotationDegrees = (sensorOrientation + deviceDegrees) % 360;

  img.Image oriented = image;

  // rotate the image so it matches the "natural" orientation ML Kit uses when you pass rotation metadata
  if (rotationDegrees != 0) {
    if (rotationDegrees == 90) {
      oriented = img.copyRotate(oriented, angle: 90);
    } else if (rotationDegrees == 180) {
      oriented = img.copyRotate(oriented, angle: 180);
    } else if (rotationDegrees == 270) {
      oriented = img.copyRotate(oriented, angle: 270);
    }
  }

  // mirror for front camera so coordinates match the preview & ML Kit bounding boxes expectation
  if (mirrorFront) {
    oriented = img.flipHorizontal(oriented);
  }

  final List<int> jpg = img.encodeJpg(oriented, quality: 85);
  return Uint8List.fromList(jpg);
}

// BGRA -> JPEG bytes
Future<Uint8List> _bgraToJpegBytes(Map<String, dynamic> params) async {
  final int width = params['width'] as int;
  final int height = params['height'] as int;
  final dynamic bytesParam = params['bytes'];

  // Normalize incoming bytes -> ByteBuffer (image.fromBytes may expect ByteBuffer)
  ByteBuffer byteBuffer;
  if (bytesParam is ByteBuffer) {
    byteBuffer = bytesParam;
  } else if (bytesParam is Uint8List) {
    byteBuffer = bytesParam.buffer;
  } else if (bytesParam is List<int>) {
    // If for some reason it's a plain List<int>, create a Uint8List copy.
    final Uint8List copy = Uint8List.fromList(bytesParam.cast<int>());
    byteBuffer = copy.buffer;
  } else {
    throw ArgumentError(
        'Unsupported bytes type for BGRA image conversion: ${bytesParam.runtimeType}');
  }

  // image.Image.fromBytes sometimes expects a ByteBuffer for the `bytes` param
  final img.Image image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: byteBuffer,
    order: img.ChannelOrder.bgra,
  );

  // Rotation & mirroring (same as before)
  final int sensorOrientation = params['sensorOrientation'] as int;
  final int deviceOrientationIndex = params['deviceOrientation'] as int;
  final bool mirrorFront = params['mirrorFront'] as bool;

  const List<int> deviceIndexToDegrees = [0, 90, 180, 270];
  final int deviceDegrees = deviceIndexToDegrees[
      deviceOrientationIndex % deviceIndexToDegrees.length];
  final int rotationDegrees = (sensorOrientation + deviceDegrees) % 360;

  img.Image oriented = image;

  if (rotationDegrees != 0) {
    if (rotationDegrees == 90) {
      oriented = img.copyRotate(oriented, angle: 90);
    } else if (rotationDegrees == 180) {
      oriented = img.copyRotate(oriented, angle: 180);
    } else if (rotationDegrees == 270) {
      oriented = img.copyRotate(oriented, angle: 270);
    }
  }

  if (mirrorFront) {
    oriented = img.flipHorizontal(oriented);
  }

  final List<int> jpg = img.encodeJpg(oriented, quality: 85);
  return Uint8List.fromList(jpg);
}

// --------------------
// FacePainter unchanged besides a bugfix in shouldRepaint
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
    for (final face in faces) {
      // imageSize may be rotated relative to UI; make scaling consistent.
      final double scaleX = size.width / imageSize.height;
      final double scaleY = size.height / imageSize.width;
      double left, top, right, bottom;
      if (cameraLensDirection == CameraLensDirection.front) {
        left = size.width - (face.boundingBox.left * scaleX);
        top = face.boundingBox.top * scaleY;
        right = size.width - (face.boundingBox.right * scaleX);
        bottom = face.boundingBox.bottom * scaleY;
      } else {
        left = face.boundingBox.left * scaleX;
        top = face.boundingBox.top * scaleY;
        right = face.boundingBox.right * scaleX;
        bottom = face.boundingBox.bottom * scaleY;
      }
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
