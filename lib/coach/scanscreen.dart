import 'dart:convert';
import '../core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../auth/login.dart';


class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  // ---------------- QR VIEW CREATED ----------------
  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;

    ctrl.scannedDataStream.listen((scanData) async {
      if (!isProcessing) {
        setState(() => isProcessing = true);
        await _handleScan(scanData.code ?? '');
      }
    });
  }

  // --------------- HANDLE QR SCAN ----------------
  Future<void> _handleScan(String scannedData) async {
    AppLogger.debug("--------------- QR SCAN STARTED ---------------", name: 'scanscreen');
    AppLogger.debug("📥 RAW QR Data:\n$scannedData", name: 'scanscreen');

    try {
      setState(() => isProcessing = true);

      final userId = await AuthService.getUserId();
      AppLogger.debug("👤 Logged-in Coach/User ID: $userId", name: 'scanscreen');

      if (userId == null) {
        _showDialog("Error ⚠️", "User not logged in", Colors.red);
        return;
      }

      final trimmed = scannedData.trim();

      // =====================================================
      // 🟢 CASE 1: BOOKING CONFIRMATION (TEXT QR)
      // =====================================================
      if (!trimmed.startsWith('{')) {
        AppLogger.debug("📄 Detected BOOKING CONFIRMATION QR", name: 'scanscreen');

        final lines = trimmed.split('\n');
        final Map<String, String> bookingData = {};

        for (final line in lines) {
          if (line.contains(':')) {
            final parts = line.split(':');
            final key = parts.first.trim();
            final value = parts.sublist(1).join(':').trim();
            bookingData[key] = value;
          }
        }

        AppLogger.debug("📋 Parsed Booking Data: $bookingData", name: 'scanscreen');

        _showDialog(
          "Booking Details 📄",
          """
Booking ID: ${bookingData['Booking ID'] ?? '-'}
Name: ${bookingData['Name'] ?? '-'}
Email: ${bookingData['Email'] ?? '-'}
Date: ${bookingData['Date'] ?? '-'}
Amount: ${bookingData['Amount'] ?? '-'}
""",
          Colors.blue,
        );

        return;
      }

      // =====================================================
      // 🟢 CASE 2: ATTENDANCE QR (JSON)
      // =====================================================
      late Map<String, dynamic> qrData;

      try {
        qrData = jsonDecode(trimmed);
        AppLogger.debug("✅ Attendance QR JSON decoded: $qrData", name: 'scanscreen');
      } catch (e) {
        _showDialog(
          "Invalid QR ❌",
          "Unsupported QR format.",
          Colors.red,
        );
        return;
      }

      final studentId = qrData['student_id'];

      if (studentId == null) {
        _showDialog(
          "Invalid QR ❌",
          "Student ID missing in QR.",
          Colors.red,
        );
        return;
      }

      final url = Uri.parse("https://nahatasports.com/api/attendance/scan");

      final body = {
        "student_id": studentId,
        "coach_id": userId,
      };

      AppLogger.debug("📤 Sending Attendance Data: $body", name: 'scanscreen');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      AppLogger.debug("📥 API Response: $data", name: 'scanscreen');

      if (response.statusCode == 200 && data['success'] == true) {
        final studentName = data['student']?['name'] ?? '';

        _showDialog(
          "Success ✅",
          "Attendance marked for $studentName",
          Colors.green,
        );
      } else {
        _showDialog(
          "Failed ❌",
          data['message'] ?? "Attendance failed",
          Colors.red,
        );
      }
    } catch (e, stack) {
      AppLogger.debug("🔥 Exception: $e", name: 'scanscreen');
      AppLogger.debug('${stack}', name: 'scanscreen');

      _showDialog(
        "Error ⚠️",
        "Unexpected error occurred",
        Colors.orange,
      );
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => isProcessing = false);
      AppLogger.debug("--------------- QR SCAN FINISHED ---------------", name: 'scanscreen');
    }
  }
  // ---------------- Result dialog ----------------
  void _showDialog(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          message ?? "",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller?.resumeCamera();
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // ---------------- UI BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A198D),
        title: const Text("Scan Attendance", style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
          ),

          // Dark overlay during processing
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // text hint
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Align the QR code within the frame",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
