import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static const MethodChannel _channel =
      MethodChannel('com.example.frontend/biometric');

  static final LocalAuthentication _localAuth = LocalAuthentication();

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
    // First authenticate with OS face lock
    final bool authenticated = await authenticateWithFace();
    if (!authenticated) {
      throw PlatformException(
        code: 'authentication_failed',
        message: 'Face authentication was cancelled or failed',
      );
    }

    // Then sign the challenge with the device key
    final res =
        await _channel.invokeMethod('signChallenge', {'challenge': challenge});
    return res as String;
  }

  /// Authenticate using OS-provided face lock
  static Future<bool> authenticateWithFace() async {
    try {
      // Check if biometric authentication is available
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) {
        throw PlatformException(
          code: 'biometric_not_available',
          message: 'Biometric authentication is not available on this device',
        );
      }

      // Get available biometric types
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      // Check if face authentication is available
      final bool hasFace = availableBiometrics.contains(BiometricType.face);

      if (!hasFace) {
        // Fallback to any available biometric
        if (availableBiometrics.isEmpty) {
          throw PlatformException(
            code: 'no_biometrics_enrolled',
            message: 'No biometric credentials are enrolled on this device',
          );
        }
      }

      // Perform authentication with preference for face
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to mark attendance',
        options: AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      return authenticated;
    } on PlatformException catch (e) {
      // Handle specific authentication errors
      switch (e.code) {
        case 'NotEnrolled':
        case 'BiometricNotEnrolled':
          throw PlatformException(
            code: 'no_biometrics_enrolled',
            message:
                'No biometric credentials are enrolled. Please set up face lock or fingerprint in device settings.',
          );
        case 'NotAvailable':
        case 'BiometricNotAvailable':
          throw PlatformException(
            code: 'biometric_not_available',
            message: 'Biometric authentication is not available on this device',
          );
        case 'UserCancel':
        case 'BiometricUserCancel':
          throw PlatformException(
            code: 'user_cancelled',
            message: 'Authentication was cancelled by user',
          );
        case 'AuthenticationFailed':
        case 'BiometricAuthenticationFailed':
          throw PlatformException(
            code: 'authentication_failed',
            message: 'Authentication failed. Please try again.',
          );
        default:
          rethrow;
      }
    } catch (e) {
      throw PlatformException(
        code: 'unknown_error',
        message: 'An unknown error occurred during authentication: $e',
      );
    }
  }

  /// Check the status of face authentication on the device
  static Future<String> getFaceStatus() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) {
        return 'not_available';
      }

      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.contains(BiometricType.face)) {
        return 'enrolled';
      } else if (availableBiometrics.isNotEmpty) {
        return 'other_biometrics_available';
      } else {
        return 'not_enrolled';
      }
    } catch (e) {
      return 'not_available';
    }
  }

  /// Get diagnostics information about biometric capabilities
  static Future<Map<String, dynamic>?> getFaceDiagnostics() async {
    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      return {
        'canCheckBiometrics': isAvailable,
        'isDeviceSupported': isDeviceSupported,
        'availableBiometrics': availableBiometrics.map((e) => e.name).toList(),
        'hasFace': availableBiometrics.contains(BiometricType.face),
        'hasFingerprint':
            availableBiometrics.contains(BiometricType.fingerprint),
        'hasIris': availableBiometrics.contains(BiometricType.iris),
        'hasWeak': availableBiometrics.contains(BiometricType.weak),
        'hasStrong': availableBiometrics.contains(BiometricType.strong),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'canCheckBiometrics': false,
        'isDeviceSupported': false,
        'availableBiometrics': <String>[],
      };
    }
  }

  /// Check if fingerprint is enrolled (legacy method)
  static Future<bool> isFingerprintEnrolled() async {
    try {
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.fingerprint);
    } catch (e) {
      return false;
    }
  }

  /// Open system biometric enrollment settings
  static Future<bool> openBiometricEnroll() async {
    try {
      // Try to use the native method first (if implemented)
      final res = await _channel.invokeMethod('openBiometricEnroll');
      return res as bool? ?? false;
    } catch (e) {
      // Fallback: return false to indicate caller should use openAppSettings
      return false;
    }
  }

  // Compute SHA-256 hex of a normalized PEM (strip whitespace/newlines)
  static String computePublicKeyHash(String publicKeyPem) {
    final normalized = publicKeyPem.replaceAll(RegExp(r"\s+"), '');
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
