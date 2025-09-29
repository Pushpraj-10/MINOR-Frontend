// In your main.dart
import 'package:flutter/material.dart';
import 'package:frontend/screens/professor/dashboard.dart';
import 'package:frontend/screens/student/dashboard.dart';
import 'package:frontend/screens/student/scanningQR.dart';
import 'package:frontend/screens/professor/sessionCreation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard UI',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Roboto', // Or any font you prefer
      ),
      debugShowCheckedModeBanner: false,
      home: const StudentDashboard(),// Set the dashboard as the home screen.
    );
  }
}
