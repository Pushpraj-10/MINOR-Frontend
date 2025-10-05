// face_recognition_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static const String _storageKey = 'face_embedding_v1';

  // Fields are now final and initialized in the private constructor
  final Interpreter _interpreter;
  final int _inputSize;
  final int _outputSize; // Dynamically determined embedding size

  // Private constructor to enforce proper initialization
  FaceRecognitionService._(this._interpreter, this._inputSize, this._outputSize);

  static Future<FaceRecognitionService> create({
    required String modelAsset,
    int inputSize = 112,
    InterpreterOptions? interpreterOptions,
  }) async {
    try {
      debugPrint('[SERVICE-CREATE] Loading model from asset: $modelAsset');
      final Interpreter interpreter = interpreterOptions == null
          ? await Interpreter.fromAsset(modelAsset)
          : await Interpreter.fromAsset(modelAsset, options: interpreterOptions);
      
      // Determine output size from the model interpreter's first output tensor
      final int outputSize = interpreter.getOutputTensor(0).shape.last;
      debugPrint('[SERVICE-CREATE] Model loaded successfully. Output vector size: $outputSize');
      
      return FaceRecognitionService._(interpreter, inputSize, outputSize);
    } catch (e, st) {
      debugPrint('[SERVICE-CREATE] Failed to load model: $e\n$st');
      rethrow;
    }
  }

  /// Generate an embedding from a face-cropped [img.Image].
  /// The image is resized to [_inputSize] and normalized to [-1, 1].
  Float32List getEmbeddingFromImage(img.Image faceImage) {
    try {
      debugPrint('[SERVICE-EMBED] Starting embedding generation...');
      debugPrint('[SERVICE-EMBED] Input image size: ${faceImage.width}x${faceImage.height}');

      if (faceImage.length == 0) {
        throw StateError('Input image has no pixels.');
      }

      // Resize to model expected input
      final img.Image resized =
          img.copyResize(faceImage, width: _inputSize, height: _inputSize);
      debugPrint('[SERVICE-EMBED] Resized image to: ${_inputSize}x$_inputSize');

      // Build input tensor as List (shape: [1, H, W, 3]) with values normalized to [-1, 1].
      final List<List<List<List<double>>>> input = [
        List.generate(_inputSize, (y) {
          return List.generate(_inputSize, (x) {
            // Use the modern way to get pixel channels from the 'image' package
            final pixel = resized.getPixel(x, y); 
            
            // Extract channels as integers
            final num r = pixel.r.toInt();
            final num g = pixel.g.toInt();
            final num b = pixel.b.toInt();

            // Normalize from [0, 255] to [-1, 1]
            final double rn = (r - 127.5) / 127.5;
            final double gn = (g - 127.5) / 127.5;
            final double bn = (b - 127.5) / 127.5;
            return [rn, gn, bn];
          });
        })
      ];

      // Prepare output buffer using the dynamically determined _outputSize
      final List<List<double>> output = List.generate(1, (_) => List.filled(_outputSize, 0.0));

      debugPrint('[SERVICE-EMBED] Running TFLite interpreter...');
      _interpreter.run(input, output);
      debugPrint('[SERVICE-EMBED] Interpreter run complete.');

      // Convert output[0] into Float32List
      final List rawOut = output[0];
      final Float32List embedding = Float32List.fromList(
          rawOut.map((e) => (e as num).toDouble()).toList());

      // L2 normalize result
      final Float32List normalized = _l2Normalize(embedding);
      debugPrint('[SERVICE-EMBED] Embedding normalized. Length: ${normalized.length}');
      return normalized;
    } catch (e, st) {
      debugPrint('[SERVICE-EMBED] Error generating embedding: $e\n$st');
      rethrow;
    }
  }

  Float32List _l2Normalize(Float32List v) {
    double sum = 0.0;
    for (int i = 0; i < v.length; i++) {
      sum += v[i] * v[i];
    }
    final double norm = math.sqrt(sum);
    if (norm == 0.0) return v;
    final Float32List out = Float32List(v.length);
    for (int i = 0; i < v.length; i++) {
      out[i] = v[i] / norm;
    }
    return out;
  }

  Future<void> saveEmbedding(Float32List embedding) async {
    try {
      debugPrint('[SERVICE-SAVE] Attempting to save embedding of length ${embedding.length}');
      final Uint8List bytes = embedding.buffer.asUint8List(
        embedding.offsetInBytes,
        embedding.lengthInBytes,
      );
      final String encoded = base64Encode(bytes);
      await _secure.write(key: _storageKey, value: encoded);
      debugPrint('[SERVICE-SAVE] Embedding successfully written to secure storage.');
    } catch (e, st) {
      debugPrint('[SERVICE-SAVE] Failed to save embedding: $e\n$st');
      rethrow;
    }
  }

  Future<Float32List?> loadEmbedding() async {
    try {
      debugPrint('[SERVICE-LOAD] Attempting to load embedding from secure storage.');
      final String? encoded = await _secure.read(key: _storageKey);
      if (encoded == null) {
        debugPrint('[SERVICE-LOAD] No embedding found in storage.');
        return null;
      }
      final Uint8List bytes = base64Decode(encoded);
      final int floatCount = bytes.lengthInBytes ~/ Float32List.bytesPerElement;
      final Float32List embedding = bytes.buffer.asFloat32List(
        bytes.offsetInBytes,
        floatCount,
      );
      debugPrint('[SERVICE-LOAD] Decoding complete. Embedding length: ${embedding.length}');
      return embedding;
    } catch (e, st) {
      debugPrint('[SERVICE-LOAD] Failed to load or decode embedding: $e\n$st');
      return null;
    }
  }

  Future<void> deleteEmbedding() async {
    await _secure.delete(key: _storageKey);
    debugPrint('[SERVICE-DELETE] Deleted embedding from storage.');
  }

  double cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) return -2.0;
    double dot = 0.0;
    for (int i = 0; i < a.length; i++) dot += a[i] * b[i];
    // Since the embeddings are L2 normalized, the dot product is the cosine similarity.
    return dot; 
  }

  Future<Map<String, dynamic>> verifyAgainstSavedEmbedding(
      Float32List currentEmbedding, {
      double threshold = 0.6,
    }) async {
    final Float32List? stored = await loadEmbedding();
    if (stored == null) return {'match': false, 'score': 0.0, 'reason': 'no_saved_embedding'};
    // Use the stored embedding length as the canonical length for comparison
    if (stored.length != currentEmbedding.length) return {'match': false, 'score': 0.0, 'reason': 'length_mismatch'};
    final double score = cosineSimilarity(stored, currentEmbedding);
    final bool match = score >= threshold;
    return {'match': match, 'score': score};
  }

  void dispose() {
    try {
      _interpreter.close();
      debugPrint('[SERVICE-DISPOSE] TFLite interpreter closed.');
    } catch (e, st) {
      debugPrint('[SERVICE-DISPOSE] Error closing interpreter: $e\n$st');
    }
  }
}