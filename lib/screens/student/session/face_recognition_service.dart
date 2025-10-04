import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

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