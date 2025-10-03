import 'package:flutter/material.dart';
import 'package:frontend/navigation/app_router.dart';

void main() {
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