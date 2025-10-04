import 'package:flutter/material.dart';
import 'package:frontend/navigation/app_router.dart';

Future<void> main() async {
  // 2. Ensure that the Flutter bindings are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MinorProject());
}

class MinorProject extends StatelessWidget {
  const MinorProject({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MINOR-Project',
      routerConfig: router,
    );
  }
}