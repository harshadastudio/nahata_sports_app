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

  Future<void> sendQRtoAPI(String qr_code_data) async {
    setState(() => isLoading = true);

    // Use a client to persist cookies/session
    final client = http.Client();

    // try {
    // 1️⃣ Get CSRF token
    // final csrfResponse = await client.get(
    //   Uri.parse("https://nahatasports.com/security-gate/get-csrf-token"),
    // );
    //
    // if (csrfResponse.statusCode != 200) {
    //   throw Exception("Failed to fetch CSRF token");
    // }
    //
    // final csrfToken = jsonDecode(csrfResponse.body)['csrf_token'];

    // 2️⃣ Send QR code with the same client (cookies/session preserved)
    final response = await client.post(
      Uri.parse("https://nahatasports.com/security-gate/scan"),
      headers: {
        "Content-Type": "application/json",
        // "X-CSRF-TOKEN": csrfToken, // include token
      },
      body: jsonEncode({"qr_code_data": qr_code_data}),
    );

    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    // 3️⃣ Decode response safely
    try {
      final data = jsonDecode(response.body);
      setState(() {
        responseData = data;
      });
    } catch (e) {
      setState(() {
        responseData = {
          "status": "ERROR",
          "message": "Invalid JSON response from server",
        };
      });
      print("Error decoding JSON: $e");
      print("Raw response: ${response.body}");
    }


// catch (e) {
//   setState(() {
//     responseData = {
//       "status": "ERROR",
//       "message": e.toString(),
//     };
//   });
//   print("Error sending QR to API: $e");
// }
finally {
      client.close();
      setState(() => isLoading = false);
    }
  }



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
    switch ((status ?? "ERROR").toUpperCase()) {
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      ? Builder(
                    builder: (_) {
                      String status =
                          responseData?['status']?.toString() ?? "ERROR";
                      String message =
                          responseData?['message']?.toString() ?? "Invalid response";

                      print("Parsed response: status=$status, message=$message");

                      return Container(
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
                                color: getStatusColor(status),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    status.toUpperCase() == "VALID"
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            const SizedBox(height: 8),

                            // Raw API response (debug)
                            Text(
                              jsonEncode(responseData),
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                            ),
                          ],
                        ),
                      );
                    },
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