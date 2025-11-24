import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Face-embedding enrollment/verification has been removed. Use the native biometric flow in Settings or contact your administrator to enable biometrics for attendance.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}