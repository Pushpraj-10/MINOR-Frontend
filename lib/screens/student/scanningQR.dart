import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerQRScreen extends StatefulWidget {
  const ScannerQRScreen({super.key});

  @override
  State<ScannerQRScreen> createState() => _ScannerQRScreenState();
}

class _ScannerQRScreenState extends State<ScannerQRScreen> {
  bool _isProcessing = false;

  Future<void> _sendTokenRequest(String token) async {
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse("http://localhost:4000/iiitnr/studentapi/attendance/mark"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showPopup("Success", "Attendance marked successfully!");
      } else {
        _showPopup("Failed", "Error: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        _showPopup("Error", "Something went wrong: $e");
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null) {
        try {
          final data = jsonDecode(rawValue);
          final token = data["token"];
          if (token != null) {
            _sendTokenRequest(token);
          } else {
            _showPopup("Invalid QR", "No token found in QR code");
          }
        } catch (_) {
          _showPopup("Invalid QR", "QR code does not contain valid JSON");
        }
        break; // stop after first valid QR
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
