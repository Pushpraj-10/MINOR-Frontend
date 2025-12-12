import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/api/api_client.dart';
import 'package:frontend/utils/error_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // State variables for UI logic
  bool _isGoogleLoading = false;

  /// Google Sign-In using Firebase Auth, then backend login with ID token
  Future<void> _loginWithGoogle() async {
    if (_isGoogleLoading) return;
    setState(() {
      _isGoogleLoading = true;
    });
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Sign-in cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();

      final res = await ApiClient.I
          .post('/auth/login/google', data: {'idToken': idToken});
      final role = (res['user']?['role'] as String?) ?? 'student';
      if (!mounted) return;
      switch (role) {
        case 'admin':
          context.go('/admin/dashboard');
          break;
        case 'professor':
          context.go('/professor/dashboard');
          break;
        default:
          context.go('/student/dashboard');
      }
    } catch (e) {
      // Log authentication failure to console for debugging
      debugPrint('[Auth] Google sign-in failed: ' + e.toString());
      if (!mounted) return;
      final message = formatErrorWithContext(
        e,
        action: 'sign in with Google',
        reasons: const [
          'Google sign-in was cancelled or failed',
          'Device is offline or the server is unreachable',
          'Your account may not be allowed for this app',
        ],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    setState(() {
      _isGoogleLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark mode background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Sign In',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Logo
                Image.asset(
                  'assets/images/IIITNR_Logo.png',
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 32.0),
                const Text(
                  'Welcome',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8.0),
                const Text(
                  'Sign in with your Google account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32.0),
                // Google Button
                ElevatedButton.icon(
                  onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black87,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.login, color: Colors.black87),
                  label: Text(
                    _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
