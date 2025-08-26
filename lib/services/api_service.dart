// import 'dart:async';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class ApiService {
//   static Future<bool> login(String email, String password) async {
//     await Future.delayed(const Duration(seconds: 2)); // Simulate API delay
//
//     if (email == "test@user.com" && password == "123456") {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isLoggedIn', true);
//       await prefs.setString('userEmail', email);
//       return true;
//     }
//     return false;
//   }
//
//   static Future<void> logout() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//   }
//
//   static Future<bool> isLoggedIn() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getBool('isLoggedIn') ?? false;
//   }
// }
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
//
class ApiService {
  static Future<bool> login(String email, String password) async {
    final url = Uri.parse('https://nahatasports.com/api/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userEmail', email);
          // Save token or user info if returned:
          if (data.containsKey('token')) {
            await prefs.setString('authToken', data['token']);
            print("token");
          }
          return true;
        } else {
          print("❌ Login failed: ${data['message']}");
          return false;
        }
      } else {
        print("❌ Server Error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ Error during login: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}






















//
//
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// class ApiService {
//   /// LOGIN
//   static Future<bool> login(String email, String password) async {
//     final url = Uri.parse('https://nahatasports.com/api/login');
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'email': email, 'password': password}),
//       );
//
//       print("📥 Raw Response: ${response.body}");
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//
//         if (data['status'] == true) {
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           await prefs.setBool('isLoggedIn', true);
//           await prefs.setString('userEmail', email);
//
//           String? token;
//
//           // Extract token
//           if (data.containsKey('token')) {
//             token = data['token'];
//           } else if (data.containsKey('data') && data['data'].containsKey('token')) {
//             token = data['data']['token'];
//           }
//
//           if (token != null) {
//             await prefs.setString('authToken', token);
//             print("✅ Auth Token: $token");
//           } else {
//             print("❌ Token key not found in response");
//           }
//
//           return true;
//         } else {
//           print("❌ Login failed: ${data['message']}");
//           return false;
//         }
//       } else {
//         print("❌ Server Error: ${response.statusCode}");
//         return false;
//       }
//     } catch (e) {
//       print("❌ Error during login: $e");
//       return false;
//     }
//   }
//
//   /// LOGOUT
//   static Future<void> logout() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? token = prefs.getString('authToken');
//     print("🔑 Token before logout: $token"); // Just for debugging
//     await prefs.clear();
//     print("✅ Logged out and local storage cleared");
//   }
//
//   /// CHECK LOGIN STATUS
//   static Future<bool> isLoggedIn() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getBool('isLoggedIn') ?? false;
//   }
// }
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// // class ApiService {
// //   static Future<bool> login(String email, String password) async {
// //     final url = Uri.parse('https://nahatasports.com/api/login');
// //
// //     try {
// //       final response = await http.post(
// //         url,
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({'email': email, 'password': password}),
// //       );
// //
// //       print("📥 Raw Response: ${response.body}"); // DEBUG: print full response
// //
// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //
// //         if (data['status'] == true) {
// //           SharedPreferences prefs = await SharedPreferences.getInstance();
// //           await prefs.setBool('isLoggedIn', true);
// //           await prefs.setString('userEmail', email);
// //
// //           // Check token — adjust path if nested
// //           if (data.containsKey('token')) {
// //             await prefs.setString('authToken', data['token']);
// //             print("✅ Auth Token: ${data['token']}");
// //           } else if (data.containsKey('data') && data['data'].containsKey('token')) {
// //             await prefs.setString('authToken', data['data']['token']);
// //             print("Auth Token: ${data['data']['token']}");
// //           } else {
// //             print("Token key not found in response");
// //             print("Raw Response: ${response.body}");
// //
// //           }
// //
// //           return true;
// //         } else {
// //           print("❌ Login failed: ${data['message']}");
// //           return false;
// //         }
// //       } else {
// //         print("❌ Server Error: ${response.statusCode}");
// //         return false;
// //       }
// //     } catch (e) {
// //       print("❌ Error during login: $e");
// //       return false;
// //     }
// //   }
// //
// //   static Future<void> logout() async {
// //     SharedPreferences prefs = await SharedPreferences.getInstance();
// //     await prefs.clear();
// //   }
// //
// //   static Future<bool> isLoggedIn() async {
// //     SharedPreferences prefs = await SharedPreferences.getInstance();
// //     return prefs.getBool('isLoggedIn') ?? false;
// //   }
// // }
//
