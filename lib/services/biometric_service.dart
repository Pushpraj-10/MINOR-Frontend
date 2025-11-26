import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

class BiometricService {
  static const MethodChannel _channel =
      MethodChannel('com.example.frontend/biometric');

  static Future<String?> getPublicKeyPem() async {
    try {
      final res = await _channel.invokeMethod('getPublicKeyPem');
      return res as String?;
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> generateAndGetPublicKeyPem() async {
    final res = await _channel.invokeMethod('generateAndGetPublicKeyPem');
    return res as String;
  }

  // Attempt to delete local OS-backed keypair. Native side may not implement
  // this method; callers should tolerate failures (returns false on error).
  static Future<bool> deleteLocalKey() async {
    try {
      final res = await _channel.invokeMethod('deleteLocalKey');
      return res as bool? ?? true;
    } catch (e) {
      // If native side doesn't implement, or deletion fails, return false
      return false;
    }
  }

  static Future<String> signChallenge(String challenge) async {
    final res =
        await _channel.invokeMethod('signChallenge', {'challenge': challenge});
    return res as String;
  }

  static Future<String> getFaceStatus() async {
    final res = await _channel.invokeMethod('getFaceStatus');
    return res as String;
  }

  static Future<Map<String, dynamic>?> getFaceDiagnostics() async {
    final res = await _channel.invokeMethod('getFaceDiagnostics');
    return (res as Map?)?.cast<String, dynamic>();
  }

  static Future<bool> isFingerprintEnrolled() async {
    final res = await _channel.invokeMethod('isFingerprintEnrolled');
    return res as bool;
  }

  static Future<bool> openBiometricEnroll() async {
    final res = await _channel.invokeMethod('openBiometricEnroll');
    return res as bool;
  }

  // Compute SHA-256 hex of a normalized PEM (strip whitespace/newlines)
  static String computePublicKeyHash(String publicKeyPem) {
    final normalized = publicKeyPem.replaceAll(RegExp(r"\s+"), '');
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
