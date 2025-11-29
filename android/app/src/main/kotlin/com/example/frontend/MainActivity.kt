package com.example.frontend

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.core.hardware.fingerprint.FingerprintManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.example.frontend/biometric"
    private val KEY_ALIAS = "biometric_key_default"
    private val TAG = "BiometricDebug"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "generateAndGetPublicKeyPem" -> {
                        try {
                            val pem = generateAndGetPublicKeyPem()
                            result.success(pem)
                        } catch (e: Exception) {
                            result.error("key_error", e.message, null)
                        }
                    }

                    "getPublicKeyPem" -> {
                        try {
                            result.success(getPublicKeyPemOrNull())
                        } catch (e: Exception) {
                            result.error("key_error", e.message, null)
                        }
                    }

                    "deleteLocalKey" -> {
                        result.success(deleteLocalKey())
                    }

                    "signChallenge" -> {
                        val challenge = call.argument<String>("challenge")
                        if (challenge.isNullOrBlank()) {
                            result.error("invalid_args", "challenge missing", null)
                        } else {
                            signChallengeWithBiometricAsync(challenge, result)
                        }
                    }

                    "isFingerprintEnrolled" -> {
                        try {
                            val fm = FingerprintManagerCompat.from(this)
                            val enrolled = fm.isHardwareDetected && fm.hasEnrolledFingerprints()
                            result.success(enrolled)
                        } catch (e: Exception) {
                            result.error("fp_error", e.message, null)
                        }
                    }

                    "getFaceStatus" -> {
                        try {
                            result.success(getFaceStatusInternal())
                        } catch (e: Exception) {
                            result.error("face_error", e.message, null)
                        }
                    }

                    "getFaceDiagnostics" -> {
                        try {
                            result.success(getFaceDiagnosticsInternal())
                        } catch (e: Exception) {
                            result.error("diag_error", e.message, null)
                        }
                    }

                    "openBiometricEnroll" -> {
                        result.success(openBiometricEnroll())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // -------------------------------------------------------
    // Key Management
    // -------------------------------------------------------

    private fun forceDeleteKeyIfExists() {
        try {
            val ks = KeyStore.getInstance("AndroidKeyStore")
            ks.load(null)
            if (ks.containsAlias(KEY_ALIAS)) {
                ks.deleteEntry(KEY_ALIAS)
                Log.d(TAG, "Force deleted old key alias")
            }
        } catch (e: Exception) {
            Log.e(TAG, "forceDeleteKeyIfExists failed", e)
        }
    }

    private fun getPublicKeyPemOrNull(): String? {
        val ks = KeyStore.getInstance("AndroidKeyStore")
        ks.load(null)
        if (!ks.containsAlias(KEY_ALIAS)) return null

        val cert = ks.getCertificate(KEY_ALIAS)
        val pub = cert.publicKey.encoded
        val b64 = Base64.encodeToString(pub, Base64.NO_WRAP)

        val sb = StringBuilder()
        sb.append("-----BEGIN PUBLIC KEY-----\n")
        var i = 0
        while (i < b64.length) {
            val end = kotlin.math.min(i + 64, b64.length)
            sb.append(b64.substring(i, end)).append('\n')
            i += 64
        }
        sb.append("-----END PUBLIC KEY-----")
        return sb.toString()
    }

    @Throws(Exception::class)
    private fun generateAndGetPublicKeyPem(): String {
        forceDeleteKeyIfExists()

        val kpg = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            "AndroidKeyStore"
        )

        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        ).apply {
            setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)

            setUserAuthenticationRequired(true)
            setUserAuthenticationValidityDurationSeconds(-1)

            @Suppress("DEPRECATION")
            setInvalidatedByBiometricEnrollment(true)
        }.build()

        kpg.initialize(spec)
        kpg.generateKeyPair()

        return getPublicKeyPemOrNull()
            ?: throw IllegalStateException("Public key missing after generation")
    }

    private fun deleteLocalKey(): Boolean {
        return try {
            forceDeleteKeyIfExists()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun signChallengeWithBiometricAsync(
        challengeB64: String,
        result: MethodChannel.Result
    ) {
        val challenge: ByteArray = try {
            Base64.decode(challengeB64, Base64.NO_WRAP)
        } catch (_: Exception) {
            result.error("invalid_args", "challenge base64 invalid", null)
            return
        }

        try {
            val ks = KeyStore.getInstance("AndroidKeyStore")
            ks.load(null)

            val privateKey: PrivateKey = try {
                ks.getKey(KEY_ALIAS, null) as PrivateKey
            } catch (kpie: KeyPermanentlyInvalidatedException) {
                result.error("key_invalidated", kpie.message, null)
                return
            } catch (_: Exception) {
                result.error("key_missing", "signing key not found", null)
                return
            }

            val signature = Signature.getInstance("SHA256withECDSA")
            signature.initSign(privateKey)

            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Authenticate to sign")
                .setSubtitle("Confirm your biometrics")
                .setNegativeButtonText("Cancel")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .build()

            val executor = ContextCompat.getMainExecutor(this)
            val biometricPrompt = BiometricPrompt(
                this,
                executor,
                object : BiometricPrompt.AuthenticationCallback() {

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        result.error("sign_error", errString.toString(), null)
                    }

                    override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                        try {
                            val crypto = authResult.cryptoObject?.signature
                                ?: run {
                                    result.error("sign_error", "crypto_object_missing", null)
                                    return
                                }
                            crypto.update(challenge)
                            val signed = crypto.sign()
                            result.success(Base64.encodeToString(signed, Base64.NO_WRAP))
                        } catch (kpie: KeyPermanentlyInvalidatedException) {
                            result.error("key_invalidated", kpie.message, null)
                        } catch (e: Exception) {
                            result.error("sign_error", e.message, null)
                        }
                    }

                    override fun onAuthenticationFailed() {
                    }
                }
            )

            val cryptoObject = BiometricPrompt.CryptoObject(signature)
            biometricPrompt.authenticate(promptInfo, cryptoObject)

        } catch (e: Exception) {
            result.error("sign_error", e.message, null)
        }
    }

    // -------------------------------------------------------
    // Face status / diagnostics
    // -------------------------------------------------------

    private fun getFaceStatusInternal(): String {
        val faceManagerClass = try {
            Class.forName("android.hardware.face.FaceManager")
        } catch (_: Exception) {
            null
        }

        if (faceManagerClass != null) {
            val fm = getSystemService(faceManagerClass)
            if (fm != null) {
                val hasEnrolled = try {
                    fm.javaClass.getMethod("hasEnrolledFaces").invoke(fm) as Boolean
                } catch (_: Exception) { false }

                val hwDetected = try {
                    fm.javaClass.getMethod("isHardwareDetected").invoke(fm) as Boolean
                } catch (_: Exception) { false }

                if (hwDetected && hasEnrolled) return "available"
            }
        }

        val pm = packageManager
        val hasFaceFeature = try {
            pm.hasSystemFeature("android.hardware.biometrics.face")
                    || pm.hasSystemFeature("android.hardware.face")
        } catch (_: Exception) { false }

        if (hasFaceFeature) {
            val bm = BiometricManager.from(this)
            val can = try {
                bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            } catch (_: Exception) {
                BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE
            }

            return when (can) {
                BiometricManager.BIOMETRIC_SUCCESS -> "available"
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "not_enrolled"
                else -> "not_available"
            }
        }

        val bm2 = BiometricManager.from(this)
        val can2 = try {
            bm2.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        } catch (_: Exception) {
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE
        }

        return when (can2) {
            BiometricManager.BIOMETRIC_SUCCESS -> "available"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "not_enrolled"
            else -> "not_available"
        }
    }

    private fun getFaceDiagnosticsInternal(): Map<String, Any?> {
        val diag = HashMap<String, Any?>()

        val faceManagerClass = try {
            Class.forName("android.hardware.face.FaceManager")
        } catch (_: Exception) {
            null
        }

        var fmPresent = false
        var fmIsDetected = false
        var fmHasEnrolled = false

        if (faceManagerClass != null) {
            fmPresent = true
            val fm = getSystemService(faceManagerClass)
            if (fm != null) {
                fmHasEnrolled = try {
                    fm.javaClass.getMethod("hasEnrolledFaces").invoke(fm) as Boolean
                } catch (_: Exception) { false }

                fmIsDetected = try {
                    fm.javaClass.getMethod("isHardwareDetected").invoke(fm) as Boolean
                } catch (_: Exception) { false }
            }
        }

        val pm = packageManager
        val hasFaceFeature = try {
            pm.hasSystemFeature("android.hardware.biometrics.face")
                    || pm.hasSystemFeature("android.hardware.face")
        } catch (_: Exception) { false }

        val bm = BiometricManager.from(this)
        val can = try {
            bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        } catch (_: Exception) {
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE
        }

        val canStr = when (can) {
            BiometricManager.BIOMETRIC_SUCCESS -> "BIOMETRIC_SUCCESS"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "BIOMETRIC_ERROR_NONE_ENROLLED"
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "BIOMETRIC_ERROR_NO_HARDWARE"
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "BIOMETRIC_ERROR_HW_UNAVAILABLE"
            else -> "UNKNOWN"
        }

        diag["faceManagerPresent"] = fmPresent
        diag["faceManagerIsDetected"] = fmIsDetected
        diag["faceManagerHasEnrolled"] = fmHasEnrolled
        diag["packageHasFaceFeature"] = hasFaceFeature
        diag["biometricCanAuthenticate"] = can
        diag["biometricCanAuthenticateStr"] = canStr

        Log.d(TAG, "Diagnostics: $diag")

        return diag
    }

    // -------------------------------------------------------
    // Open enrollment
    // -------------------------------------------------------

    private fun openBiometricEnroll(): Boolean {
        return try {
            val enrollIntent = Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
                putExtra(
                    Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
                    BiometricManager.Authenticators.BIOMETRIC_STRONG
                )
            }
            startActivity(enrollIntent)
            true
        } catch (e: Exception) {
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                val uri = Uri.fromParts("package", packageName, null)
                intent.data = uri
                startActivity(intent)
                false
            } catch (_: Exception) {
                false
            }
        }
    }
}
