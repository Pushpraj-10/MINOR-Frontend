import 'package:flutter/material.dart';
import 'face_enrollment_page.dart';
import 'face_detection_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const FaceEnrollmentPage()),
                );
              },
              child: const Text('Register Face'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const FaceDetectionPage()),
                );
              },
              child: const Text('Verify Face'),
            ),
          ],
        ),
      ),
    );
  }
}