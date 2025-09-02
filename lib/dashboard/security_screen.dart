import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class SecurityGateScannerScreen extends StatefulWidget {
  const SecurityGateScannerScreen({super.key});

  @override
  State<SecurityGateScannerScreen> createState() =>
      _SecurityGateScannerScreenState();
}

class _SecurityGateScannerScreenState extends State<SecurityGateScannerScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool scanCompleted = false;
  String? scanResult;
  Map<String, dynamic>? responseData;
  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _animationController, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
  }

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      if (Platform.isAndroid) controller!.pauseCamera();
      controller!.resumeCamera();
    }
  }

  Future<void> sendQRtoAPI(String qrCodeData) async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("https://nahatasports.com/api/scan"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"qr_code_data": qrCodeData}),
      );

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = {
          "status": "ERROR",
          "message": "Invalid JSON response from server",
        };
      }

      setState(() {
        responseData = data;
      });

      // Start animation after getting response
      _animationController.forward(from: 0);
    } catch (e) {
      setState(() {
        responseData = {
          "status": "ERROR",
          "message": e.toString(),
        };
      });
      _animationController.forward(from: 0);
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

        sendQRtoAPI(scanResult!);
        controller.pauseCamera();
      }
    });
  }

  Color getStatusColor(String? status) {
    switch ((status ?? "ERROR").toLowerCase()) {
      case "valid":
      case "green":
        return Colors.green;
      case "warning":
      case "yellow":
        return Colors.orange;
      case "invalid":
      case "red":
      case "error":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(String? status) {
    switch ((status ?? "ERROR").toLowerCase()) {
      case "valid":
      case "green":
        return Icons.check_circle;
      case "warning":
      case "yellow":
        return Icons.warning;
      case "invalid":
      case "red":
      case "error":
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.security, size: 50, color: Colors.white),
                    SizedBox(height: 10),
                    Text(
                      "Security Gate Scanner",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Scan QR codes to verify entry",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // QR Scanner or Result
              Expanded(
                child: scanCompleted
                    ? isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : responseData != null
                    ? Center(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Pulsing icon
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 1, end: 1.2),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeInOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: Icon(
                                      getStatusIcon(responseData?['status']),
                                      color: getStatusColor(responseData?['status']),
                                      size: 60,
                                    ),
                                  );
                                },
                                onEnd: () => _animationController.forward(from: 0),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                responseData?['message'] ?? "No message",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: getStatusColor(responseData?['status']),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    scanCompleted = false;
                                    scanResult = null;
                                    responseData = null;
                                    controller?.resumeCamera();
                                  });
                                },
                                icon: const Icon(Icons.qr_code),
                                label: const Text("Scan Next Person"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                    : const Center(child: Text("No data available"))
                    : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 250,
                        width: 300,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blueGrey.shade200, width: 2),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                        ),
                        child: QRView(
                          key: qrKey,
                          onQRViewCreated: _onQRViewCreated,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Point your camera at the QR code",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          controller?.resumeCamera();
                          setState(() {
                            scanCompleted = false;
                            scanResult = null;
                            responseData = null;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Restart Scanner"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class SecurityGateScanner extends StatefulWidget {
//   const SecurityGateScanner({super.key});
//
//   @override
//   State<SecurityGateScanner> createState() => _SecurityGateScannerState();
// }
//
// class _SecurityGateScannerState extends State<SecurityGateScanner> {
//   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
//   QRViewController? controller;
//   bool scanCompleted = false;
//   String? scanResult;
//   Map<String, dynamic>? responseData;
//   bool isLoading = false;
//
//   @override
//   void reassemble() {
//     super.reassemble();
//     if (controller != null) {
//       if (Platform.isAndroid) controller!.pauseCamera();
//       controller!.resumeCamera();
//     }
//   }
//   Future<void> sendQRtoAPI(String qr_code_data) async {
//     setState(() => isLoading = true);
//
//     try {
//       final response = await http.post(
//         Uri.parse("https://nahatasports.com/api/scan"), // ✅ Correct endpoint
//         headers: {
//           "Content-Type": "application/json",
//         },
//         body: jsonEncode({"qr_code_data": qr_code_data}),
//       );
//
//       print("Status: ${response.statusCode}");
//       print("Body: ${response.body}");
//
//       Map<String, dynamic> data;
//       try {
//         data = jsonDecode(response.body);
//       } catch (e) {
//         data = {
//           "status": "ERROR",
//           "message": "Invalid JSON response from server",
//         };
//         print("JSON decode error: $e");
//         print("Response body: ${response.body}");
//       }
//
//       setState(() {
//         responseData = data;
//       });
//     } catch (e) {
//       setState(() {
//         responseData = {
//           "status": "ERROR",
//           "message": e.toString(),
//         };
//       });
//       print("Error sending QR to API: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//
//
//   void _onQRViewCreated(QRViewController controller) {
//     this.controller = controller;
//     controller.scannedDataStream.listen((scanData) {
//       if (!scanCompleted && scanData.code != null) {
//         setState(() {
//           scanCompleted = true;
//           scanResult = scanData.code!;
//         });
//
//         sendQRtoAPI(scanResult!);
//         controller.pauseCamera();
//       }
//     });
//   }
//
//   Color getStatusColor(String? status) {
//     switch ((status ?? "ERROR").toLowerCase()) {
//       case "green":
//         return Colors.green;
//       case "yellow":
//         return Colors.orange;
//       case "red":
//       case "error":
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }
//
//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // Title
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: const Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.camera_alt, color: Colors.black87),
//                     SizedBox(width: 8),
//                     Text(
//                       "Security Gate Scanner",
//                       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
//
//               // QR Scanner
//               if (!scanCompleted)
//                 Expanded(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         height: 250,
//                         width: 300,
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.black38, width: 2),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: QRView(
//                           key: qrKey,
//                           onQRViewCreated: _onQRViewCreated,
//                         ),
//                       ),
//                       const SizedBox(height: 15),
//                       const Text(
//                         "Point camera at QR code",
//                         style: TextStyle(color: Colors.black87),
//                       ),
//                     ],
//                   ),
//                 ),
//
//               // Show API Response
//               if (scanCompleted)
//                 Expanded(
//                   child: isLoading
//                       ? const Center(child: CircularProgressIndicator())
//                       : responseData != null
//                       ? Builder(
//                     builder: (_) {
//                       String status =
//                           responseData?['status']?.toString() ?? "ERROR";
//                       String message =
//                           responseData?['message']?.toString() ?? "Invalid response";
//
//                       print("Parsed response: status=$status, message=$message");
//
//                       return Container(
//                         margin: const EdgeInsets.all(16),
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Status Banner
//                             Container(
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: getStatusColor(status),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Icon(
//                                     status.toUpperCase() == "VALID"
//                                         ? Icons.check_circle
//                                         : Icons.cancel,
//                                     color: Colors.white,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Expanded(
//                                     child: Text(
//                                       message,
//                                       style: const TextStyle(
//                                           color: Colors.white, fontSize: 16),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//
//                             const SizedBox(height: 8),
//
//                             // // Raw API response (debug)
//                             // Text(
//                             //   // jsonEncode(responseData),
//                             //   style: TextStyle(fontSize: 12, color: Colors.grey[700]),
//                             // ),
//
//                             const SizedBox(height: 20),
//                             ElevatedButton(
//                               onPressed: () {
//                                 setState(() {
//                                   scanCompleted = false;
//                                   scanResult = null;
//                                   responseData = null;
//                                   controller?.resumeCamera();
//                                 });
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.blue[700],
//                                 foregroundColor: Colors.black,
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 20, vertical: 14),
//                               ),
//                               child: const Text("Scan Next Person"),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   )
//                       : const SizedBox.shrink(),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




















//   Future<void> sendQRtoAPI(String qr_code_data) async {
//     setState(() => isLoading = true);
//
//     // Use a client to persist cookies/session
//     final client = http.Client();
//
//     // try {
//     // 1️⃣ Get CSRF token
//     // final csrfResponse = await client.get(
//     //   Uri.parse("https://nahatasports.com/security-gate/get-csrf-token"),
//     // );
//     //
//     // if (csrfResponse.statusCode != 200) {
//     //   throw Exception("Failed to fetch CSRF token");
//     // }
//     //
//     // final csrfToken = jsonDecode(csrfResponse.body)['csrf_token'];
//
//     // 2️⃣ Send QR code with the same client (cookies/session preserved)
//     final response = await client.post(
//       Uri.parse("https://nahatasports.com/security-gate/scan"),
//       headers: {
//         "Content-Type": "application/json",
//         // "X-CSRF-TOKEN": csrfToken, // include token
//       },
//       body: jsonEncode({"qr_code_data": qr_code_data}),
//     );
//
//     print("Status: ${response.statusCode}");
//     print("Body: ${response.body}");
//
//     // 3️⃣ Decode response safely
//     try {
//       final data = jsonDecode(response.body);
//       setState(() {
//         responseData = data;
//       });
//     } catch (e) {
//       setState(() {
//         responseData = {
//           "status": "ERROR",
//           "message": "Invalid JSON response from server",
//         };
//       });
//       print("Error decoding JSON: $e");
//       print("Raw response: ${response.body}");
//     }
//
//
// // catch (e) {
// //   setState(() {
// //     responseData = {
// //       "status": "ERROR",
// //       "message": e.toString(),
// //     };
// //   });
// //   print("Error sending QR to API: $e");
// // }
// finally {
//       client.close();
//       setState(() => isLoading = false);
//     }
//   }



// Future<void> sendQRtoAPI(String qr_code_data) async {
//   setState(() => isLoading = true);
//
//   try {
//     // Get CSRF token
//     final csrfResponse = await http.get(
//       Uri.parse("https://nahatasports.com/security-gate/get-csrf-token"),
//     );
//
//     String csrfToken = "";
//     try {
//       csrfToken = jsonDecode(csrfResponse.body)['csrf_token'].toString();
//     } catch (_) {
//       csrfToken = "";
//       print("Failed to get CSRF token: ${csrfResponse.body}");
//     }
//
//     // Send QR code
//     final response = await http.post(
//       Uri.parse("https://nahatasports.com/security-gate/scan"),
//       headers: {
//         "Content-Type": "application/json",
//         "X-CSRF-TOKEN": csrfToken,
//       },
//       body: jsonEncode({"qr_code_data": qr_code_data}),
//     );
//
//     Map<String, dynamic> data;
//     try {
//       data = jsonDecode(response.body);
//     } catch (e) {
//       data = {
//         "status": "ERROR",
//         "message": "Invalid response from server",
//       };
//       print("JSON decode error: $e");
//       print("Response body: ${response.body}");
//     }
//
//     setState(() {
//       responseData = data;
//     });
//
//     print("API Response: $responseData");
//
//   } catch (e) {
//     setState(() {
//       responseData = {
//         "status": "ERROR",
//         "message": e?.toString() ?? "Unknown error",
//       };
//     });
//     print("Error sending QR to API: ${responseData!['message']}");
//   } finally {
//     setState(() => isLoading = false);
//   }
// }



// class _SecurityGateScannerState extends State<SecurityGateScanner> {
//   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
//   QRViewController? controller;
//   bool scanCompleted = false;
//   String? scanResult;
//   Map<String, dynamic>? responseData;
//   bool isLoading = false;
//
//   @override
//   void reassemble() {
//     super.reassemble();
//     if (controller != null) {
//       if (Platform.isAndroid) controller!.pauseCamera();
//       controller!.resumeCamera();
//     }
//   }
//
//   // Send scanned QR to API
//
//   Future<void> sendQRtoAPI(String qr_code_data) async {
//     setState(() => isLoading = true);
//
//     try {
//       // Get CSRF token
//       final csrfResponse = await http.get(Uri.parse("https://nahatasports.com/security-gate/get-csrf-token"));
//       final csrfToken = jsonDecode(csrfResponse.body)['csrf_token'];
//
//       // Send QR code
//       final response = await http.post(
//         Uri.parse("https://nahatasports.com/security-gate/scan"),
//         headers: {
//           "Content-Type": "application/json",
//           "X-CSRF-TOKEN": csrfToken,
//         },
//         body: jsonEncode({"qr_code_data": qr_code_data}),
//       );
//
//       print("Status: ${response.statusCode}");
//       print("Body: ${response.body}");
//
//       // Decode response safely
//       try {
//         final data = jsonDecode(response.body);
//         setState(() {
//           responseData = data;
//         });
//       } catch (e) {
//         final errorMsg = "Invalid JSON response from server";
//         setState(() {
//           responseData = {
//             "status": "ERROR",
//             "message": errorMsg,
//           };
//         });
//         print("Error decoding JSON: $e");
//         print("Raw response: ${response.body}");
//       }
//     } catch (e) {
//       final errorMsg = e?.toString() ?? "Unknown error";
//       setState(() {
//         responseData = {
//           "status": "ERROR",
//           "message": errorMsg,
//         };
//       });
//       print("Error sending QR to API: $errorMsg");
//       print("ResponseData: $responseData");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   void _onQRViewCreated(QRViewController controller) {
//     this.controller = controller;
//     controller.scannedDataStream.listen((scanData) {
//       if (!scanCompleted && scanData.code != null) {
//         setState(() {
//           scanCompleted = true;
//           scanResult = scanData.code!;
//         });
//
//         // Send QR code to API
//         sendQRtoAPI(scanResult!);
//         controller.pauseCamera();
//       }
//     });
//   }
//
//   Color getStatusColor(String? status) {
//     switch ((status ?? "ERROR").toUpperCase()) {
//       case "VALID":
//         return Colors.green;
//       case "CHECK":
//         return Colors.orange;
//       default:
//         return Colors.red;
//     }
//   }
//
//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//
//       body: SafeArea(
//         child: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // Title
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: const Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(Icons.camera_alt, color: Colors.black87),
//                     SizedBox(width: 8),
//                     Text(
//                       "Security Gate Scanner",
//                       style:
//                       TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
//
//               // QR Scanner
//               if (!scanCompleted)
//                 Expanded(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         height: 250,
//                         width: 300,
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.black38, width: 2),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: QRView(
//                           key: qrKey,
//                           onQRViewCreated: _onQRViewCreated,
//                         ),
//                       ),
//                       const SizedBox(height: 15),
//                       const Text(
//                         "Point camera at QR code",
//                         style: TextStyle(color: Colors.black87),
//                       ),
//                     ],
//                   ),
//                 ),
//
//               // Show API Response
//               if (scanCompleted)
//                 Expanded(
//                   child: isLoading
//                       ? const Center(child: CircularProgressIndicator())
//                       : responseData != null
//                       ? Builder(
//                     builder: (_) {
//                       // SAFELY EXTRACT STATUS AND MESSAGE
//
//                       String status = responseData?['status']?.toString() ?? "ERROR";
//                       String message = responseData?['message']?.toString() ?? "Invalid response";
//
//
//                       // Print for debugging
//                       print("Parsed response: status=$status, message=$message");
//
//                       return Container(
//                         margin: const EdgeInsets.all(16),
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Status Banner
//                             Container(
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: getStatusColor(status),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Row(
//                                 children: [
//                                   Icon(
//                                     status.toUpperCase() == "VALID"
//                                         ? Icons.check_circle
//                                         : Icons.cancel,
//                                     color: Colors.white,
//                                   ),
//                                   const SizedBox(width: 8),
//                                   Expanded(
//                                     child: Text(
//                                       message,
//                                       style: const TextStyle(
//                                           color: Colors.white, fontSize: 16),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//                             ElevatedButton(
//                               onPressed: () {
//                                 setState(() {
//                                   scanCompleted = false;
//                                   scanResult = null;
//                                   responseData = null;
//                                   controller?.resumeCamera();
//                                 });
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.blue[700],
//                                 foregroundColor: Colors.black,
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 20, vertical: 14),
//                               ),
//                               child: const Text("Scan Next Person"),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   )
//                       : const SizedBox.shrink(),
//                 )
//
//               // Expanded(
//                 //   child: isLoading
//                 //       ? const Center(child: CircularProgressIndicator())
//                 //       : responseData != null
//                 //       ? Builder(
//                 //     builder: (_) {
//                 //       // SAFELY EXTRACT STATUS AND MESSAGE
//                 //       String status = (responseData?['status']?.toString() ?? "ERROR");
//                 //       String message = (responseData?['message']?.toString() ?? "Unknown status");
//                 //
//                 //
//                 //       try {
//                 //         final s = responseData?['status'];
//                 //         final m = responseData?['message'];
//                 //
//                 //         status = (s is String ? s : s?.toString() ?? "ERROR");
//                 //         message = (m is String ? m : m?.toString() ?? "Unknown status");
//                 //       } catch (e) {
//                 //         // fallback if parsing fails
//                 //         status = "ERROR";
//                 //         message = "Invalid response from server";
//                 //         print("Error parsing response: $e");
//                 //         print("Response: $responseData");
//                 //         print("Status: $status");
//                 //         print("Message: $message");
//                 //       }
//                 //
//                 //       return Container(
//                 //         margin: const EdgeInsets.all(16),
//                 //         padding: const EdgeInsets.all(16),
//                 //         decoration: BoxDecoration(
//                 //           color: Colors.white,
//                 //           borderRadius: BorderRadius.circular(12),
//                 //         ),
//                 //         child: Column(
//                 //           crossAxisAlignment: CrossAxisAlignment.start,
//                 //           children: [
//                 //             // Status Banner
//                 //             Container(
//                 //               padding: const EdgeInsets.all(12),
//                 //               decoration: BoxDecoration(
//                 //                 color: getStatusColor(status),
//                 //                 borderRadius: BorderRadius.circular(8),
//                 //               ),
//                 //               child: Row(
//                 //                 children: [
//                 //                   Icon(
//                 //                     status.toUpperCase() == "VALID"
//                 //                         ? Icons.check_circle
//                 //                         : Icons.cancel,
//                 //                     color: Colors.white,
//                 //                   ),
//                 //                   const SizedBox(width: 8),
//                 //                   Expanded(
//                 //                     child: Text(
//                 //                       message,
//                 //                       style: const TextStyle(
//                 //                           color: Colors.white, fontSize: 16),
//                 //                     ),
//                 //                   ),
//                 //                 ],
//                 //               ),
//                 //             ),
//                 //             const SizedBox(height: 20),
//                 //             ElevatedButton(
//                 //               onPressed: () {
//                 //                 setState(() {
//                 //                   scanCompleted = false;
//                 //                   scanResult = null;
//                 //                   responseData = null;
//                 //                   controller?.resumeCamera();
//                 //                 });
//                 //               },
//                 //               style: ElevatedButton.styleFrom(
//                 //                 backgroundColor: Colors.blue[700],
//                 //                 foregroundColor: Colors.black,
//                 //                 padding: const EdgeInsets.symmetric(
//                 //                     horizontal: 20, vertical: 14),
//                 //               ),
//                 //               child: const Text("Scan Next Person"),
//                 //             )
//                 //           ],
//                 //         ),
//                 //       );
//                 //     },
//                 //   )
//                 //       : const SizedBox.shrink(),
//                 // )
//
//
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }




// Future<void> sendQRtoAPI(String qr_code_data) async {
//   setState(() => isLoading = true);
//
//   try {
//     // final response = await http.post(
//     //   Uri.parse("https://nahatasports.com/security-gate/scan"),
//     //   headers: {
//     //     "Content-Type": "application/json",
//     //   },
//     //   body: jsonEncode({"qr_code_data": qr_code_data}), // <-- send QR code as "code"
//     // );
//     final csrfResponse = await http.get(Uri.parse("https://nahatasports.com/security-gate/get-csrf-token"));
//     final csrfToken = jsonDecode(csrfResponse.body)['csrf_token'];
//
//     final response = await http.post(
//       Uri.parse("https://nahatasports.com/security-gate/scan"),
//       headers: {
//         "Content-Type": "application/json",
//         "X-CSRF-TOKEN": csrfToken, // include token
//       },
//       body: jsonEncode({"qr_code_data": qr_code_data}),
//     );
//
//     print("Status: ${response.statusCode}");
//     print("Body: ${response.body}");
//
//     if (response.statusCode == 200) {
//       setState(() {
//         responseData = jsonDecode(response.body);
//       });
//     } else {
//       setState(() {
//
//         responseData = {
//           "status": "ERROR",
//           "message": "HTTP ${response.statusCode}: ${response.body}"
//         };
//       });
//     }
//     responseData = jsonDecode(response.body);
//   }
//   // catch (e) {
//   //   setState(() {
//   //     responseData = {"status": "ERROR", "message": e.toString()};
//   //   });
//   //   print("Error sending QR to API: $e");
//   //   print("ResponseData: $responseData");
//   // }
//
//   catch (e) {
//     final errorMsg =  "Invalid response from server";
//     responseData = {
//       "status": "ERROR",
//       "message": errorMsg,
//     };
//     // setState(() {
//     //   responseData = {
//     //     "status": "ERROR",
//     //     "message": errorMsg,
//     //   };
//     // });
//     // print("Error sending QR to API: $errorMsg");
//     // print("ResponseData: $responseData");
//
//     print("Error decoding JSON: $e");
//     print("Response body: ${response.body}");
//   }
//   finally {
//     setState(() => isLoading = false);
//   }
// }







// email-security@gmail.com
// pass-admin@gmail.com