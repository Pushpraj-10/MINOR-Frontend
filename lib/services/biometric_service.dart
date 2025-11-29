import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

/// Native channel (Android MainActivity) handles:
/// - generateAndGetPublicKeyPem
/// - getPublicKeyPem
/// - deleteLocalKey
/// - signChallenge (prompts OS biometric and signs via Keystore)
/// - getFaceStatus / getFaceDiagnostics / openBiometricEnroll (optional)
class BiometricService {
  static const MethodChannel _channel =
      MethodChannel('com.example.frontend/biometric');

  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Returns PEM or null if no key yet.
  static Future<String?> getPublicKeyPem() async {
    final res = await _channel.invokeMethod('getPublicKeyPem');
    return res as String?;
  }

  /// Generates the key if missing and returns PEM (always non-null on success).
  static Future<String> generateAndGetPublicKeyPem() async {
    final res = await _channel.invokeMethod('generateAndGetPublicKeyPem');
    return res as String;
  }

  /// Best-effort deletion of local TEE-backed key (returns false on failure).
  static Future<bool> deleteLocalKey() async {
    try {
      final res = await _channel.invokeMethod('deleteLocalKey');
      return res as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Signs a base64 challenge with the device private key.
  /// Native layer shows BiometricPrompt (face/fingerprint) at signing time.
  static Future<String> signChallenge(String challengeB64) async {
    final res =
        await _channel.invokeMethod('signChallenge', {'challenge': challengeB64});
    return res as String;
  }

  /// Quick availability/enrollment probe to provide UX hints.
  static Future<String> getFaceStatus() async {
    try {
      final res = await _channel.invokeMethod('getFaceStatus');
      return (res as String?) ?? 'not_available';
    } catch (_) {
      return 'not_available';
    }
  }

  static Future<bool> openBiometricEnroll() async {
    try {
      final res = await _channel.invokeMethod('openBiometricEnroll');
      return res as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// SHA-256 over whitespace-stripped PEM (for server-side stable matching).
  static String computePublicKeyHash(String publicKeyPem) {
    final normalized = publicKeyPem.replaceAll(RegExp(r'\s+'), '');
    final digest = sha256.convert(utf8.encode(normalized));
    return digest.toString();
  }
}
