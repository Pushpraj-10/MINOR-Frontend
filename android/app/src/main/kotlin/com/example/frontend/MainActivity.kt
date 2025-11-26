package com.example.frontend

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricPrompt
import androidx.biometric.BiometricManager
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.hardware.fingerprint.FingerprintManagerCompat
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.PrivateKey
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import android.security.keystore.KeyPermanentlyInvalidatedException

class MainActivity: FlutterFragmentActivity() {
	private val CHANNEL = "com.example.frontend/biometric"
	private val KEY_ALIAS = "biometric_key_default"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"isFingerprintEnrolled" -> {
					try {
						val fm = FingerprintManagerCompat.from(this)
						val enrolled = fm.isHardwareDetected && fm.hasEnrolledFingerprints()
						result.success(enrolled)
					} catch (e: Exception) {
						result.error("fp_error", e.message, null)
					}
				}

					"getFaceDiagnostics" -> {
						try {
							val diagnostics = HashMap<String, Any?>()
							var fmPresent = false
							var fmIsDetected = false
							var fmHasEnrolled = false
							val faceManagerClass2 = try { Class.forName("android.hardware.face.FaceManager") } catch (e: Exception) { null }
							if (faceManagerClass2 != null) {
								fmPresent = true
								val fm2 = getSystemService(faceManagerClass2)
								if (fm2 != null) {
									fmHasEnrolled = try { fm2.javaClass.getMethod("hasEnrolledFaces").invoke(fm2) as Boolean } catch (e: Exception) { false }
									fmIsDetected = try { fm2.javaClass.getMethod("isHardwareDetected").invoke(fm2) as Boolean } catch (e: Exception) { false }
								}
							}
							val pm2 = this.packageManager
							val hasFaceFeature2 = try { pm2.hasSystemFeature("android.hardware.biometrics.face") || pm2.hasSystemFeature("android.hardware.face") } catch (e: Exception) { false }
							val bmDiag = BiometricManager.from(this)
							val canDiag = try { bmDiag.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) } catch (e: Exception) { BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE }
							diagnostics["faceManagerPresent"] = fmPresent
							diagnostics["faceManagerIsDetected"] = fmIsDetected
							diagnostics["faceManagerHasEnrolled"] = fmHasEnrolled
							diagnostics["packageHasFaceFeature"] = hasFaceFeature2
							diagnostics["biometricCanAuthenticate"] = canDiag
							var canStr = when (canDiag) {
								BiometricManager.BIOMETRIC_SUCCESS -> "BIOMETRIC_SUCCESS"
								BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "BIOMETRIC_ERROR_NONE_ENROLLED"
								BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "BIOMETRIC_ERROR_NO_HARDWARE"
								BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "BIOMETRIC_ERROR_HW_UNAVAILABLE"
								else -> "UNKNOWN"
							}
							diagnostics["biometricCanAuthenticateStr"] = canStr
							Log.d("BiometricDebug", "Diagnostics: $diagnostics")
							result.success(diagnostics)
						} catch (e: Exception) {
							result.error("diag_error", e.message, null)
						}
					}
				"isFaceEnrolled" -> {
					try {
						// Use reflection to access FaceManager to remain compatible across API levels
						val faceManagerClass = try {
							Class.forName("android.hardware.face.FaceManager")
						} catch (e: Exception) {
							null
						}
						if (faceManagerClass != null) {
							val fm = getSystemService(faceManagerClass)
							if (fm != null) {
								val hasEnrolled = try {
									val m = fm.javaClass.getMethod("hasEnrolledFaces")
									m.invoke(fm) as Boolean
								} catch (e: Exception) { false }
								val isDetected = try {
									val m2 = fm.javaClass.getMethod("isHardwareDetected")
									m2.invoke(fm) as Boolean
								} catch (e: Exception) { false }
								result.success(hasEnrolled && isDetected)
							} else {
								result.success(false)
							}
						} else {
							// FaceManager class not available
							result.success(false)
						}
					} catch (e: Exception) {
						result.error("face_error", e.message, null)
					}
				}
				"getFaceStatus" -> {
					try {
						// First try the direct FaceManager (some OEMs expose this)
						val faceManagerClass = try { Class.forName("android.hardware.face.FaceManager") } catch (e: Exception) { null }
						if (faceManagerClass != null) {
							val fm = getSystemService(faceManagerClass)
							if (fm != null) {
								val hasEnrolled = try { fm.javaClass.getMethod("hasEnrolledFaces").invoke(fm) as Boolean } catch (e: Exception) { false }
								val isDetected = try { fm.javaClass.getMethod("isHardwareDetected").invoke(fm) as Boolean } catch (e: Exception) { false }
								Log.d("BiometricDebug", "FaceManager present: isDetected=$isDetected hasEnrolled=$hasEnrolled")
								// If FaceManager explicitly reports both hardware and enrollment, return available immediately.
								if (isDetected && hasEnrolled) {
									result.success("available")
									return@setMethodCallHandler
								}
								// Otherwise, do not treat FaceManager's negative as final — fall back to broader checks below.
							} // else continue to fallback
						}
						// Fallback: check package features and BiometricManager which is more widely supported
						val pm = this.packageManager
						val hasFaceFeature = try {
							pm.hasSystemFeature("android.hardware.biometrics.face") || pm.hasSystemFeature("android.hardware.face")
						} catch (e: Exception) { false }
						Log.d("BiometricDebug", "PackageManager hasFaceFeature=$hasFaceFeature")
						if (hasFaceFeature) {
							// If feature present, use BiometricManager to see if credentials exist
							val bm = BiometricManager.from(this)
							val can = try { bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) } catch (e: Exception) { BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE }
							Log.d("BiometricDebug", "BiometricManager.canAuthenticate (faceFeature) => $can")
							when (can) {
								BiometricManager.BIOMETRIC_SUCCESS -> result.success("available")
								BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> result.success("not_enrolled")
								else -> result.success("not_available")
							}
							return@setMethodCallHandler
						}
						// As a last resort, use BiometricManager generally (may be fingerprint or face)
						val bm2 = BiometricManager.from(this)
						val can2 = try { bm2.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) } catch (e: Exception) { BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE }
						Log.d("BiometricDebug", "BiometricManager.canAuthenticate (fallback) => $can2")
						when (can2) {
							BiometricManager.BIOMETRIC_SUCCESS -> result.success("available")
							BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> result.success("not_enrolled")
							else -> result.success("not_available")
						}
					} catch (e: Exception) {
						result.error("face_error", e.message, null)
					}
				}
				"getPublicKeyPem" -> {
					try {
						val keyStore = KeyStore.getInstance("AndroidKeyStore")
						keyStore.load(null)
						if (!keyStore.containsAlias(KEY_ALIAS)) {
							result.success(null)
						} else {
							val entry = keyStore.getCertificate(KEY_ALIAS)
							val pub = entry.publicKey.encoded
							val b64 = Base64.encodeToString(pub, Base64.NO_WRAP)
							val pem = StringBuilder()
							pem.append("-----BEGIN PUBLIC KEY-----\n")
							var i = 0
							while (i < b64.length) {
								val end = Math.min(i + 64, b64.length)
								pem.append(b64.substring(i, end))
								pem.append('\n')
								i += 64
							}
							pem.append("-----END PUBLIC KEY-----")
							result.success(pem.toString())
						}
					} catch (e: Exception) {
						result.error("key_error", e.message, null)
					}
				}

				"openBiometricEnroll" -> {
					try {
						val enrollIntent = Intent(Settings.ACTION_BIOMETRIC_ENROLL).apply {
							// Use string literal for the extra key to avoid AndroidX version mismatch
							putExtra("androidx.biometric.BIOMETRIC_AUTHENTICATORS", BiometricManager.Authenticators.BIOMETRIC_STRONG)
						}
						startActivity(enrollIntent)
						result.success(true)
					} catch (e: Exception) {
						// Fallback: open app settings
						try {
							val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
							val uri = android.net.Uri.fromParts("package", this.packageName, null)
							intent.data = uri
							startActivity(intent)
							result.success(false)
						} catch (ex: Exception) {
							result.error("open_enroll_failed", ex.message, null)
						}
					}
				}

				"generateAndGetPublicKeyPem" -> {
					try {
						val pem = generateAndGetPublicKeyPem()
						result.success(pem)
					} catch (e: Exception) {
						result.error("key_error", e.message, null)
					}
				}
				"deleteLocalKey" -> {
					try {
						val keyStore = KeyStore.getInstance("AndroidKeyStore")
						keyStore.load(null)
						if (keyStore.containsAlias(KEY_ALIAS)) {
							keyStore.deleteEntry(KEY_ALIAS)
						}
						result.success(true)
					} catch (e: Exception) {
						// return false on failure but do not crash
						result.success(false)
					}
				}
				"signChallenge" -> {
						val challenge = call.argument<String>("challenge")
						if (challenge == null) {
							result.error("invalid_args", "challenge missing", null)
						} else {
							// Perform biometric signing asynchronously to avoid blocking the main thread
							signChallengeWithBiometricAsync(challenge, result)
						}
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun generateAndGetPublicKeyPem(): String {
		val keyStore = KeyStore.getInstance("AndroidKeyStore")
		keyStore.load(null)

		if (!keyStore.containsAlias(KEY_ALIAS)) {
			val kpg = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
			val parameterSpec = KeyGenParameterSpec.Builder(
				KEY_ALIAS,
				KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
			).apply {
				setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
				setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
				// require biometric auth for key use
				setUserAuthenticationRequired(true)
				setUserAuthenticationValidityDurationSeconds(-1)
			}.build()
			kpg.initialize(parameterSpec)
			kpg.generateKeyPair()
		}

		val entry = keyStore.getCertificate(KEY_ALIAS)
		val pub = entry.publicKey.encoded
		val b64 = Base64.encodeToString(pub, Base64.NO_WRAP)
		val pem = StringBuilder()
		pem.append("-----BEGIN PUBLIC KEY-----\n")
		var i = 0
		while (i < b64.length) {
			val end = Math.min(i + 64, b64.length)
			pem.append(b64.substring(i, end))
			pem.append('\n')
			i += 64
		}
		pem.append("-----END PUBLIC KEY-----")

		return pem.toString()
	}

	private fun signChallengeWithBiometricAsync(challengeB64: String, result: MethodChannel.Result) {
		val challenge = try {
			Base64.decode(challengeB64, Base64.NO_WRAP)
		} catch (e: Exception) {
			result.error("invalid_args", "challenge base64 invalid", null)
			return
		}

		try {
				val keyStore = KeyStore.getInstance("AndroidKeyStore")
				keyStore.load(null)
				val privateKey = try {
					keyStore.getKey(KEY_ALIAS, null) as PrivateKey
				} catch (kpie: KeyPermanentlyInvalidatedException) {
					// Key invalidated (biometric changed or unenrolled). Signal to Flutter so it can re-register.
					result.error("key_invalidated", kpie.message ?: "Key permanently invalidated", null)
					return
				}

			val signature = Signature.getInstance("SHA256withECDSA")
			signature.initSign(privateKey)

			val executor = ContextCompat.getMainExecutor(this)
			val promptInfo = BiometricPrompt.PromptInfo.Builder()
				.setTitle("Authenticate to sign")
				.setSubtitle("Confirm biometric to complete check-in")
				.setNegativeButtonText("Cancel")
				.build()

			val biometricPrompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
				override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
					result.error("sign_error", errString.toString(), null)
				}

				override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
					try {
								val crypto = authResult.cryptoObject?.signature
								if (crypto != null) {
									try {
										crypto.update(challenge)
										val signedBytes = crypto.sign()
										val sigB64 = Base64.encodeToString(signedBytes, Base64.NO_WRAP)
										result.success(sigB64)
									} catch (kpie: KeyPermanentlyInvalidatedException) {
										// Key invalidated after auth — tell Flutter to re-register
										result.error("key_invalidated", kpie.message ?: "Key permanently invalidated", null)
									} catch (ex: Exception) {
										result.error("sign_error", ex.message, null)
									}
								} else {
									// Crypto object missing — cannot sign securely
									result.error("sign_error", "crypto_object_missing", null)
								}
					} catch (ex: Exception) {
						result.error("sign_error", ex.message, null)
					}
				}

				override fun onAuthenticationFailed() {
					// let user retry; do not close the channel yet
				}
			})

			try {
				val cryptoObject = BiometricPrompt.CryptoObject(signature)
				biometricPrompt.authenticate(promptInfo, cryptoObject)
			} catch (e: Exception) {
				// If wrapping as CryptoObject failed, return error
				result.error("sign_error", e.message, null)
			}
		} catch (e: Exception) {
			result.error("sign_error", e.message, null)
		}
	}
}
