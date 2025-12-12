import 'package:flutter/material.dart';
import 'package:frontend/navigation/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase ONCE before building the app; guard for duplicates
  try {
    if (Firebase.apps.isEmpty) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 8));
      }
    }
  } catch (e) {
    // Log and proceed so the UI loads even if Firebase init stalls
    debugPrint('[Firebase Init] Failed or timed out: ' + e.toString());
  }
  runApp(const MinorProject());
}

class MinorProject extends StatelessWidget {
  const MinorProject({super.key});

  @override
  Widget build(BuildContext context) {
    // Single MaterialApp.router; Firebase already initialized in main()
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MINOR-Project',
      routerConfig: router,
    );
  }
}
