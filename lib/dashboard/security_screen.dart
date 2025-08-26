import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SecurityGateScanner extends StatefulWidget {
  const SecurityGateScanner({super.key});

  @override
  State<SecurityGateScanner> createState() => _SecurityGateScannerState();
}

class _SecurityGateScannerState extends State<SecurityGateScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool scanCompleted = false;
  String? scanResult;
  Map<String, dynamic>? responseData;
  bool isLoading = false;

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      if (Platform.isAndroid) controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  // Send scanned QR to API
  Future<void> sendQRtoAPI(String qrCode) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("https://nahatasports.com/security-gate/scan"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({"code": qrCode}), // <-- send QR code as "code"
      );

      if (response.statusCode == 200) {
        setState(() {
          responseData = jsonDecode(response.body);
        });
      } else {
        setState(() {
          responseData = {
            "status": "ERROR",
            "message": "HTTP ${response.statusCode}: ${response.body}"
          };
        });
      }
    } catch (e) {
      setState(() {
        responseData = {"status": "ERROR", "message": e.toString()};
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (!scanCompleted && scanData.code != null) {
        setState(() {
          scanCompleted = true;
          scanResult = scanData.code!;
        });

        // Send QR code to API
        sendQRtoAPI(scanResult!);
        controller.pauseCamera();
      }
    });
  }

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "VALID":
        return Colors.green;
      case "CHECK":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.black87),
                    SizedBox(width: 8),
                    Text(
                      "Security Gate Scanner",
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // QR Scanner
              if (!scanCompleted)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 250,
                        width: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black38, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QRView(
                          key: qrKey,
                          onQRViewCreated: _onQRViewCreated,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Point camera at QR code",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),

              // Show API Response
              if (scanCompleted)
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : responseData != null
                      ? Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: getStatusColor(
                                responseData!['status'] ?? "ERROR"),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                responseData!['status'] == "VALID"
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  responseData!['message'] ??
                                      "Unknown status",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              scanCompleted = false;
                              scanResult = null;
                              responseData = null;
                              controller?.resumeCamera();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                          child: const Text("Scan Next Person"),
                        )
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

