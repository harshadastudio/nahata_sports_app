import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
    print("--------------- QR SCAN STARTED ---------------");
    print("📥 RAW QR Data: $scannedData");

    try {
      setState(() => isProcessing = true);
      print("🔄 isProcessing = true");

      // Get logged in user
      final userId = await AuthService.getUserId();
      print("👤 Logged-in Coach/User ID: $userId");

      if (userId == null) {
        _showDialog("Error ⚠️", "User not logged in", Colors.red);
        return;
      }

      // ---------- DECODE QR JSON ----------
      Map<String, dynamic> qrData;
      try {
        qrData = jsonDecode(scannedData);
        print("🔍 Decoded QR JSON: $qrData");
      } catch (e) {
        print("❌ Invalid JSON in QR: $e");
        _showDialog("Invalid QR", "QR data is not valid JSON.", Colors.red);
        return;
      }

      final studentId = qrData["student_id"];
      final validUntil = qrData["valid_until"];

      print("🎯 Extracted student_id: $studentId");
      print("📆 Valid Until: $validUntil");

      if (studentId == null) {
        _showDialog("Invalid QR", "Student ID not found in QR.", Colors.red);
        return;
      }

      // ---------- API CALL ----------
      final url = Uri.parse("https://nahatasports.com/api/attendance/scan");
      print("🌐 API URL: $url");

      final body = {
        "student_id": studentId.toString(),
        "coach_id": userId.toString(),
        "qr_code": scannedData,
        "valid_until": validUntil ?? "",
      };

      print("📦 Request Body: $body");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print("📡 Response Status Code: ${response.statusCode}");
      print("📨 Raw Response Body: ${response.body}");

      final data = jsonDecode(response.body);
      print("🔍 Decoded Response: $data");

      if (response.statusCode == 200 && data['success'] == true) {
        print("✅ Attendance Success");
        _showDialog("Success ✅", data['message'], Colors.green);
      } else {
        print("❌ Attendance Failed");
        _showDialog("Failed ❌", data['message'], Colors.red);
      }
    } catch (e) {
      print("🔥 Exception: $e");
      _showDialog("Error ⚠️", "Unexpected error: $e", Colors.orange);
    } finally {
      print("⏳ Resetting scan in 2 seconds...");
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => isProcessing = false);
      }

      print("🔄 isProcessing = false");
      print("--------------- QR SCAN FINISHED ---------------");
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
