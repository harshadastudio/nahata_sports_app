

import 'dart:convert';
import '../core/utils/app_logger.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nahata_app/auth/registration.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'apple_auth.dart';
import '../core/navigation/role_router.dart';
import '../core/services/app_navigator.dart';
import '../core/services/permission_service.dart';
import '../core/services/session_manager.dart';
import '../core/storage/profile_cache.dart';
import '../core/storage/token_storage.dart';
import '../models/profile_model.dart';
import '../providers/profile_provider.dart';
import '../repositories/auth_repository.dart';

// // 88888888888888888888888888888888888888888888888888888888
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final emailMobileController = TextEditingController();
//   final passwordController = TextEditingController();
//   bool rememberMe = false;
//   bool obscurePassword = true;
//   bool _isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSavedCredentials();
//   }
//
//   Future<void> _loadSavedCredentials() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     final savedEmail = prefs.getString('email') ?? '';
//     final savedPassword = prefs.getString('password') ?? '';
//     final savedRemember = prefs.getBool('rememberMe') ?? false;
//
//     if (savedRemember) {
//       setState(() {
//         emailMobileController.text = savedEmail;
//         passwordController.text = savedPassword;
//         rememberMe = true;
//       });
//     }
//   }
//
//   Future<void> _saveCredentials() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     if (rememberMe) {
//       await prefs.setString('email', emailMobileController.text.trim());
//       await prefs.setString('password', passwordController.text.trim());
//       await prefs.setBool('rememberMe', true);
//     } else {
//       await prefs.remove('email');
//       await prefs.remove('password');
//       await prefs.setBool('rememberMe', false);
//     }
//   }
//
//   bool _isValidEmail(String input) {
//     final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
//     return emailRegex.hasMatch(input);
//   }
//
//   bool _isValidMobile(String input) {
//     final mobileRegex = RegExp(r"^[0-9]{10}$");
//     return mobileRegex.hasMatch(input);
//   }
//
//   void _login() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _isLoading = true);
//
//     final emailOrMobile = emailMobileController.text.trim();
//     final password = passwordController.text.trim();
//
//     bool success = await ApiService.login(emailOrMobile, password);
//
//     setState(() => _isLoading = false);
//
//     if (success) {
//       await _saveCredentials(); // Save credentials if rememberMe is checked
//       _showInfoDialog("Login Successful");
//
//       Future.delayed(const Duration(seconds: 2), () {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const CustomBottomNav()),
//         );
//       });
//     } else {
//       _showInfoDialog("Login failed. Please check your credentials.");
//     }
//   }
//
//   void _forgotPassword() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         title: const Text("Forgot Password"),
//         content: const Text("Please contact support or reset your password."),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Close"),
//           ),
//         ],
//       ),
//     );
//     // Or navigate to a dedicated forgot password screen here
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     const brandBlue = Color(0xFF1A237E);
//
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFFE3F2FD),
//               Colors.white,
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: Center(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     Image.asset("assets/ns.png", height: 100),
//                     const SizedBox(height: 20),
//                     const Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         "Sign in to your\nAccount",
//                         style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//                     TextFormField(
//                       controller: emailMobileController,
//                       decoration: InputDecoration(
//                         hintText: "Email",
//                         filled: true,
//                         fillColor: Colors.white,
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return "Please enter Email or Mobile number";
//                         }
//                         if (!_isValidEmail(value.trim()) &&
//                             !_isValidMobile(value.trim())) {
//                           return "Enter a valid Email or 10-digit Mobile number";
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 20),
//                     TextFormField(
//                       controller: passwordController,
//                       obscureText: obscurePassword,
//                       decoration: InputDecoration(
//                         hintText: "Password",
//                         filled: true,
//                         fillColor: Colors.white,
//                         suffixIcon: IconButton(
//                           icon: Icon(
//                             obscurePassword ? Icons.visibility_off : Icons.visibility,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               obscurePassword = !obscurePassword;
//                             });
//                           },
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return "Password is required";
//                         }
//                         if (value.length < 6) {
//                           return "Password must be at least 6 characters";
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 10),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           children: [
//                             Checkbox(
//                               value: rememberMe,
//                               activeColor: brandBlue,
//                               onChanged: (value) {
//                                 setState(() {
//                                   rememberMe = value ?? false;
//                                 });
//                               },
//                             ),
//                             const Text("Remember me"),
//                           ],
//                         ),
//                         TextButton(
//                           onPressed: _forgotPassword,
//                           child: const Text(
//                             "Forgot Password?",
//                             style: TextStyle(color: brandBlue),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//                     _isLoading
//                         ? const CircularProgressIndicator()
//                         : SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: ElevatedButton(
//                         onPressed: _login,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: brandBlue,
//                           foregroundColor: Colors.black,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         child: const Text(
//                           "Log In",
//                           style: TextStyle(fontSize: 16, color: Colors.white),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     Row(
//                       children: [
//                         const Expanded(child: Divider(thickness: 1)),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 8),
//                           child: Text(
//                             "Or",
//                             style: TextStyle(color: Colors.grey[600]),
//                           ),
//                         ),
//                         const Expanded(child: Divider(thickness: 1)),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Text("Don’t have an account? "),
//                         GestureDetector(
//                           onTap: () {
//                             Navigator.pushReplacement(
//                               context,
//                               MaterialPageRoute(builder: (context) => RegisterScreen()),
//                             );
//                           },
//                           child: const Text(
//                             "Register",
//                             style: TextStyle(
//                               color: brandBlue,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _showInfoDialog(String message) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.info_outline, size: 50, color: Color(0xFF1A237E)),
//             const SizedBox(height: 16),
//             Text(message, textAlign: TextAlign.center),
//           ],
//         ),
//       ),
//     );
//
//     Future.delayed(const Duration(seconds: 2), () {
//       if (mounted) Navigator.pop(context);
//     });
//   }
// }
// //8888888888888888888888888888888888888888888888888888888888

// Role → screen routing now lives in `core/navigation/role_router.dart`, so the
// individual dashboards are no longer imported here.
import 'google_auth.dart';
import 'signup.dart';
// import 'package:google_sign_in/google_sign_in.dart';
//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final emailMobileController = TextEditingController();
//   final passwordController = TextEditingController();
//   bool rememberMe = false;
//   bool obscurePassword = true;
//   bool _isLoading = false;
//
//
//
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSavedCredentials();
//   }
//   Future<void> _loadSavedCredentials() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     final savedEmail = prefs.getString('email') ?? '';
//     final savedPassword = prefs.getString('password') ?? '';
//     final savedRemember = prefs.getBool('rememberMe') ?? false;
//     final savedRole = prefs.getString('role'); // ✅ load role
//
//     if (savedRemember) {
//       setState(() {
//         emailMobileController.text = savedEmail;
//         passwordController.text = savedPassword;
//         rememberMe = true;
//       });
//
//       if (savedRole != null) {
//         // ✅ Auto redirect based on role
//         Future.delayed(Duration.zero, () {
//           Widget screen;
//           switch (savedRole) {
//             case 'admin':
//               screen = AdminDashboardScreen();
//               break;
//             case 'coach':
//               screen = CoachDashboardScreen();
//               break;
//             case 'security':
//               screen = SecurityGateScannerScreen();
//               break;
//             default:
//               screen = CustomBottomNav();
//           }
//
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (context) => screen),
//           );
//         });
//       }
//     }
//   }
//
//   // Future<void> _loadSavedCredentials() async {
//   //   SharedPreferences prefs = await SharedPreferences.getInstance();
//   //   final savedEmail = prefs.getString('email') ?? '';
//   //   final savedPassword = prefs.getString('password') ?? '';
//   //   final savedRemember = prefs.getBool('rememberMe') ?? false;
//   //
//   //   if (savedRemember) {
//   //     setState(() {
//   //       emailMobileController.text = savedEmail;
//   //       passwordController.text = savedPassword;
//   //       rememberMe = true;
//   //     });
//   //   }
//   // }
//
//   Future<void> _saveCredentials() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     if (rememberMe) {
//       await prefs.setString('email', emailMobileController.text.trim());
//       await prefs.setString('password', passwordController.text.trim());
//       await prefs.setBool('rememberMe', true);
//       await prefs.setString('role', role);
//     } else {
//       await prefs.remove('email');
//       await prefs.remove('password');
//       await prefs.setBool('rememberMe', false);
//       await prefs.remove('role');
//     }
//   }
//
//   bool _isValidEmail(String input) {
//     final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
//     return emailRegex.hasMatch(input);
//   }
//
//   bool _isValidMobile(String input) {
//     final mobileRegex = RegExp(r"^[0-9]{10}$");
//     return mobileRegex.hasMatch(input);
//   }
//   void _login() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _isLoading = true);
//
//     final emailOrMobile = emailMobileController.text.trim();
//     final password = passwordController.text.trim();
//
//     bool success = await ApiService.login(emailOrMobile, password);
//
//     setState(() => _isLoading = false);
//
//     if (success && ApiService.currentUser != null) {
//       await _saveCredentials();
//
//       final role = ApiService.currentUser!['role']; // assuming API returns role
//       await _saveCredentials(role);
//       Widget screen;
//
//       switch (role) {
//         case 'admin':
//           screen = AdminDashboardScreen();
//           break;
//         case 'coach':
//           screen = CoachDashboardScreen();
//           break;
//         case 'security':
//           screen = SecurityGateScannerScreen();
//           break;
//         default:
//           screen = CustomBottomNav();
//       }
//
//       _showInfoDialog("Login Successful");
//
//       Future.delayed(const Duration(seconds: 2), () {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => screen),
//         );
//       });
//     } else {
//       _showInfoDialog("Login failed. Please check your credentials.");
//     }
//   }
//
//   // void _login() async {
//   //   if (!_formKey.currentState!.validate()) return;
//   //
//   //   setState(() => _isLoading = true);
//   //
//   //   final emailOrMobile = emailMobileController.text.trim();
//   //   final password = passwordController.text.trim();
//   //
//   //   bool success = await ApiService.login(emailOrMobile, password);
//   //
//   //   setState(() => _isLoading = false);
//   //
//   //   if (success) {
//   //     await _saveCredentials();
//   //     _showInfoDialog("Login Successful");
//   //
//   //     Future.delayed(const Duration(seconds: 2), () {
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(builder: (context) => const CustomBottomNav()),
//   //       );
//   //     });
//   //   } else {
//   //     _showInfoDialog("Login failed. Please check your credentials.");
//   //   }
//   // }
//
//
//   Future<bool> _handleGoogleAuthWithBackend(
//       String email, String? accessToken, String? idToken) async {
//     try {
//       // Example:
//       // return await ApiService.googleLogin(email, accessToken, idToken);
//
//       // Simulated success for demo
//       return true;
//     } catch (e) {
//       print('Google auth backend error: $e');
//       return false;
//     }
//   }
//
//   void _forgotPassword() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         title: const Text("Forgot Password"),
//         content: const Text("Please contact support or reset your password."),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Close"),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     const brandBlue = Color(0xFF1A237E);
//
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFFE3F2FD),
//               Colors.white,
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: Center(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     Image.asset("assets/ns.png", height: 100),
//                     const SizedBox(height: 20),
//                     const Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         "Sign in to your\nAccount",
//                         style: TextStyle(
//                             fontSize: 26, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//                     TextFormField(
//                       controller: emailMobileController,
//                       decoration: InputDecoration(
//                         hintText: "Email",
//                         filled: true,
//                         fillColor: Colors.white,
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return "Please enter Email";
//                         }
//                         if (!_isValidEmail(value.trim()) &&
//                             !_isValidMobile(value.trim())) {
//                           return "Enter a valid Email or 10-digit Mobile number";
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 20),
//                     TextFormField(
//                       controller: passwordController,
//                       obscureText: obscurePassword,
//                       decoration: InputDecoration(
//                         hintText: "Password",
//                         filled: true,
//                         fillColor: Colors.white,
//                         suffixIcon: IconButton(
//                           icon: Icon(
//                             obscurePassword
//                                 ? Icons.visibility_off
//                                 : Icons.visibility,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               obscurePassword = !obscurePassword;
//                             });
//                           },
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return "Password is required";
//                         }
//                         if (value.length < 6) {
//                           return "Password must be at least 6 characters";
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 10),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           children: [
//                             Checkbox(
//                               value: rememberMe,
//                               activeColor: brandBlue,
//                               onChanged: (value) {
//                                 setState(() {
//                                   rememberMe = value ?? false;
//                                 });
//                               },
//                             ),
//                             const Text("Remember me"),
//                           ],
//                         ),
//                         TextButton(
//                           onPressed: _forgotPassword,
//                           child: const Text(
//                             "Forgot Password?",
//                             style: TextStyle(color: brandBlue),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//                     _isLoading
//                         ? const CircularProgressIndicator()
//                         : SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: ElevatedButton(
//                         onPressed: _login,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: brandBlue,
//                           foregroundColor: Colors.black,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         child: const Text(
//                           "Log In",
//                           style: TextStyle(
//                               fontSize: 16, color: Colors.white),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     Row(
//                       children: [
//                         const Expanded(child: Divider(thickness: 1)),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 8),
//                           child: Text(
//                             "Or continue with",
//                             style: TextStyle(color: Colors.grey[600]),
//                           ),
//                         ),
//                         const Expanded(child: Divider(thickness: 1)),
//                       ],
//                     ),
//                     // const SizedBox(height: 20),
//                     // // ✅ Fixed Google Sign-In Button
//                     // SizedBox(
//                     //   width: double.infinity,
//                     //   height: 50,
//                     //   child: OutlinedButton.icon(
//                     //     onPressed: _isLoading ? null : _signInWithGoogle,
//                     //     icon: Image.asset(
//                     //       'assets/g.png',
//                     //       height: 24,
//                     //       width: 24,
//                     //       errorBuilder: (context, error, stackTrace) {
//                     //         return const Icon(Icons.g_mobiledata,
//                     //             size: 24, color: Colors.red);
//                     //       },
//                     //     ),
//                     //     label: const Text(
//                     //       'Sign in with Google',
//                     //       style: TextStyle(
//                     //         fontSize: 16,
//                     //         color: Colors.black87,
//                     //       ),
//                     //     ),
//                     //     style: OutlinedButton.styleFrom(
//                     //       side: const BorderSide(color: Colors.grey),
//                     //       shape: RoundedRectangleBorder(
//                     //         borderRadius: BorderRadius.circular(8),
//                     //       ),
//                     //       backgroundColor: Colors.white,
//                     //     ),
//                     //   ),
//                     // ),
//                     const SizedBox(height: 20),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Text("Don't have an account? "),
//                         GestureDetector(
//                           onTap: () {
//                             Navigator.pushReplacement(
//                               context,
//                               MaterialPageRoute(
//                                   builder: (context) => RegisterScreen()),
//                             );
//                           },
//                           child: const Text(
//                             "Register",
//                             style: TextStyle(
//                               color: brandBlue,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _showInfoDialog(String message) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape:
//         RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.check,
//                 size: 50, color: Color(0xFF1A237E)),
//             const SizedBox(height: 16),
//             Text(message, textAlign: TextAlign.center),
//           ],
//         ),
//       ),
//     );
//
//     Future.delayed(const Duration(seconds: 2), () {
//       if (mounted) Navigator.pop(context);
//     });
//   }
// }




class LoginScreen extends StatefulWidget {
  const  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailMobileController = TextEditingController();
  final passwordController = TextEditingController();
  bool rememberMe = false;
  bool obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email') ?? '';
    final savedPassword = prefs.getString('password') ?? '';
    final savedRemember = prefs.getBool('rememberMe') ?? false;

    if (savedRemember) {
      setState(() {
        emailMobileController.text = savedEmail;
        passwordController.text = savedPassword;
        rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials(String role) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('email', emailMobileController.text.trim());
      await prefs.setString('password', passwordController.text.trim());
      await prefs.setBool('rememberMe', true);
      await prefs.setString('role', role); // save role for splash redirect
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
      await prefs.remove('role');
    }
  }

  bool _isValidEmail(String input) {
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    return emailRegex.hasMatch(input);
  }

  bool _isValidMobile(String input) {
    final mobileRegex = RegExp(r"^[0-9]{10}$");
    return mobileRegex.hasMatch(input);
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final emailOrMobile = emailMobileController.text.trim();
    final password = passwordController.text.trim();

    bool success = await ApiService.login(emailOrMobile, password);

    setState(() => _isLoading = false);
    if (success && ApiService.currentUser != null) {
      final role = ApiService.currentUser!['role'] ?? 'USER';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('role', role);

      Widget screen = _getScreenForRole(role);

      _showMessage("Login successful", tone: AppMessageTone.success);

      // Straight through, no waiting: the snackbar belongs to the app-wide
      // messenger, so it stays on screen over the dashboard. The two-second
      // pause only ever existed to let the old dialog finish.
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } else {
      final msg = ApiService.lastErrorMessage ?? "Login failed. Please check your credentials.";
      _showMessage(msg, tone: AppMessageTone.error);
    }


  }
  /// Where a role lands after a successful sign-in.
  ///
  /// Delegates to [RoleRouter] so the login button, Google, Apple and the
  /// splash-screen session restore all route identically — the fix for
  /// `COMPLEX_ADMIN` opening the student dashboard lives in that one place.
  Widget _getScreenForRole(String role) => RoleRouter.screenFor(role);

// ========================================================
//  FORGOT PASSWORD FLOW (Complete Working Code)
// ========================================================

// ========================================================
//        COMPLETE FORGOT PASSWORD FLOW – NAHATA SPORTS
// ========================================================

// ----------------- 1️⃣ ENTER EMAIL -----------------------
  void _openForgotPassword() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.lock_reset_rounded, color:  Color(0xFF1A237E), size: 28),
              SizedBox(width: 10),
              Text("Forgot Password", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter your registered email address. We will send an OTP to verify your identity.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:  Color(0xFF1A237E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty || !email.contains("@")) {
                  _toast("Enter a valid email");
                  return;
                }
                Navigator.pop(context);
                await _sendOtp(email);
              },
              child: const Text("Send OTP",style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

// ----------------- 2️⃣ SEND OTP API -----------------------
  Future<void> _sendOtp(String email) async {
    final url = Uri.parse("https://nahatasports.com/forgot-password");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email}),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      _showMessage("OTP sent to your email", tone: AppMessageTone.success);
      _openOtpDialog(email);
    } else {
      _toast(data["message"] ?? "Failed to send OTP");
    }
  }

// ----------------- 3️⃣ OTP VERIFY UI -----------------------
  void _openOtpDialog(String email) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.verified_user_rounded, color:  Color(0xFF1A237E), size: 28),
              SizedBox(width: 10),
              Text("Verify OTP", style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter the 6-digit OTP sent to your email.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                decoration: InputDecoration(
                  labelText: "Enter OTP",
                  prefixIcon: const Icon(Icons.pin_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:  Color(0xFF1A237E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final otp = otpController.text.trim();
                if (otp.isEmpty) {
                  _toast("Enter OTP",);
                  return;
                }
                _verifyOtp(email, otp);
              },
              child: const Text("Verify",style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

// ----------------- 4️⃣ VERIFY OTP API -----------------------
  Future<void> _verifyOtp(String email, String otp) async {
    final url = Uri.parse("https://nahatasports.com/verify-otp");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );

      final data = jsonDecode(response.body);
      AppLogger.debug("VERIFY OTP RESPONSE: $data", name: 'login');

      if (data["status"] == true) {
        // 🔥 IMPORTANT: Close OTP dialog before next dialog
        Navigator.pop(context);

        // 🔥 Now open reset password window
        Future.delayed(Duration(milliseconds: 300), () {
          _openResetPasswordDialog(email);
        });
        _showMessage("OTP verified successfully", tone: AppMessageTone.success);
      } else {
        _showMessage(
          data["message"] ?? "Invalid OTP",
          tone: AppMessageTone.error,
        );
      }
    } catch (e) {
      AppLogger.debug("Error in _verifyOtp: $e", name: 'login');
      _showMessage("Something went wrong", tone: AppMessageTone.error);
    }
  }

// ----------------- 5️⃣ RESET PASSWORD SCREEN -----------------------
  void _openResetPasswordDialog(String email) {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    var obscureNew = true;
    var obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.password_rounded, color:  Color(0xFF1A237E), size: 28),
              SizedBox(width: 10),
              Text("Reset Password", style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Create a new password for your account.",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pass,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: "New Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setDialogState(() => obscureNew = !obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:  Color(0xFF1A237E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (pass.text.trim().length < 6) {
                  _toast("Password must be at least 6 characters");
                  return;
                }

                if (pass.text.trim() != confirm.text.trim()) {
                  _toast("Passwords do not match");
                  return;
                }

                Navigator.pop(context);
                await _resetPassword(email, pass.text.trim());
              },
              child: const Text("Reset",style: TextStyle(color: Colors.white),),
            ),
          ],
          ),
        );
      },
    );
  }

// ----------------- 6️⃣ RESET PASSWORD API -----------------------
  Future<void> _resetPassword(String email, String newPass) async {
    final url = Uri.parse("https://nahatasports.com/reset-password");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "new_password": newPass,
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data["success"] == true) {
      _showMessage(
        "Password reset successfully",
        tone: AppMessageTone.success,
      );

      // 📌 Backend already sends email with new password

      // 🔄 Move to Login Screen
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
    } else {
      _toast(data["message"] ?? "Failed to reset password");
    }
  }

// ----------------- Helper -----------------------

  /// Every message this screen shows — a snackbar along the bottom, not a
  /// dialog in the middle of the page.
  ///
  /// It goes through [AppNavigator]'s messenger, which sits above the
  /// navigator, so the bar outlives this screen: "Login successful" stays
  /// readable while the dashboard replaces the login page underneath it.
  ///
  /// What this replaced was a blocking `AlertDialog` that closed itself on a
  /// two-second timer. Besides looking wrong, that timer raced the navigation
  /// timer beside it — whichever fired second decided whether the pop closed
  /// the dialog or the screen the user had just landed on.
  void _showMessage(
    String message, {
    AppMessageTone tone = AppMessageTone.info,
  }) {
    AppNavigator.showMessage(message, tone: tone, context: context);
  }

  /// Validation and failure lines from the forgot-password flow.
  void _toast(String msg) => _showMessage(msg, tone: AppMessageTone.error);
  /// `POST /auth/google-login` — stores the tokens, caches the profile, syncs
  /// permissions and registers the FCM token, exactly like a password login.
  ///
  /// Old API (commented out below): `POST /google_login` with `{idToken}`,
  /// which was the wrong path (the route is `/auth/google-login`), the wrong
  /// body key (`credential`, plus a `portal`) and was checked against
  /// `status` instead of `success` — so it could never have succeeded.
  Future<bool> _googleLoginToBackend(String idToken) =>
      ApiService.googleLogin(idToken);

  /// Sign in with Apple — the whole flow, from the Apple sheet to the routed
  /// screen.
  ///
  /// Old API (commented out at the Apple button below): a raw `http.post` to
  /// `/api/apple_login` with `{idToken: ...}`, checked against `data["status"]`.
  /// Three things were wrong with it: the route is `/auth/apple-login`, the
  /// body key is `identityToken`, and the response flag is `success`. It also
  /// threw away `credential.givenName` / `familyName`, which Apple hands over
  /// on the first authorization and never again — so every Apple account was
  /// created named after its email prefix.
  Future<void> _handleAppleSignIn() async {
    final appleUser = await AppleAuthService.signInWithApple();

    // Null covers cancel as well as failure; nothing to shout about, and the
    // service has already logged which it was.
    if (appleUser == null) {
      _showMessage(
        "Apple sign-in cancelled or failed.",
        tone: AppMessageTone.error,
      );
      return;
    }

    _showMessage("Verifying your Apple account…");

    // Straight to the backend: the identity token dies ~10 minutes after Apple
    // issues it, and an expired one is rejected exactly like a forged one.
    final success = await ApiService.appleLogin(
      appleUser["identityToken"]!,
      firstName: appleUser["firstName"],
      lastName: appleUser["lastName"],
    );

    if (!success) {
      _showMessage(
        ApiService.lastErrorMessage ?? "Apple login failed. Try again.",
        tone: AppMessageTone.error,
      );
      return;
    }

    final profile = ApiService.currentProfile;
    final role = (profile?.roleLabel.isNotEmpty ?? false)
        ? profile!.roleLabel
        : (ApiService.currentUser?['role']?.toString() ?? 'user');
    final screen = _getScreenForRole(role);

    // Apple never provides a phone number, so a fresh Apple account arrives
    // with `needsPhone`. Booking confirmations and passes go to that WhatsApp
    // number, so say so — the profile screen is where it gets saved
    // (`PUT /auth/profile`).
    _showMessage(
      profile?.needsPhone == true
          ? "Login successful. Add your WhatsApp number in your profile to receive booking confirmations."
          : "Login successful",
      tone: AppMessageTone.success,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // ---------------------- OLD API (commented out) ----------------------
  // Future<bool> _googleLoginToBackend(String idToken) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse("https://api.nahatasports.com/api/google_login"),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({"idToken": idToken}),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //
  //       if (data["status"] == true && data["data"] != null) {
  //         final payload = Map<String, dynamic>.from(data["data"]);
  //
  //         // Stores tokens, caches the profile and syncs every screen.
  //         final profile = await ApiService.adoptSession(payload);
  //
  //         final userId = profile.id;
  //         if (userId != null) await ApiService._saveFcmTokenToServer(userId);
  //
  //         return true;
  //       }
  //     }
  //
  //     return false;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1A237E);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset("assets/ns.png", height: 100),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Sign in to your\nAccount",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: emailMobileController,
                      decoration: InputDecoration(
                        hintText: "Email",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Please enter Email";
                        }
                        if (!_isValidEmail(value.trim()) &&
                            !_isValidMobile(value.trim())) {
                          return "Enter a valid Email or 10-digit Mobile number";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: "Password",
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Password is required";
                        }
                        if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: rememberMe,
                              activeColor: brandBlue,
                              onChanged: (value) {
                                setState(() {
                                  rememberMe = value ?? false;
                                });
                              },
                            ),
                            const Text("Remember me"),
                          ],
                        ),
                        TextButton(
                          onPressed: _openForgotPassword,
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: brandBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandBlue,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Log In",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),


                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        icon: Image.asset('assets/g.png', height: 24),
                        label: const Text("Sign in with Google"),
                        onPressed: () async {
                          final googleUser = await GoogleAuthService.signInWithGoogle();

                          if (googleUser == null) {
                            _showMessage(
                              "Google sign-in failed",
                              tone: AppMessageTone.error,
                            );
                            return;
                          }

                          _showMessage("Verifying your Google account…");

                          final success = await _googleLoginToBackend(googleUser["idToken"]);

                          if (!success) {
                            _showMessage(
                              "Google login failed. Try again.",
                              tone: AppMessageTone.error,
                            );
                            return;
                          }

                          final role = ApiService.currentUser?['role'] ?? 'user';
                          final screen = _getScreenForRole(role);

                          _showMessage(
                            "Login successful",
                            tone: AppMessageTone.success,
                          );

                          if (!mounted) return;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => screen),
                          );
                        },
                      ),
                    ),
// ----------------------------
//   SIGN IN WITH APPLE BUTTON
// ----------------------------
                    // Apple only offers the native sheet on iOS/macOS, and
                    // App Store review requires this button wherever another
                    // social sign-in is offered — which Google is, above.
                    if (AppleAuthService.isAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: SignInWithAppleButton(
                            borderRadius: BorderRadius.circular(15),
                            style: SignInWithAppleButtonStyle.black,
                            onPressed: _handleAppleSignIn,
                          ),
                        ),
                      ),
//
//
//
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            "Or",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                        const Expanded(child: Divider(thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Two ways in, because they are for two different people:
                    // Register is the full enrolment (sports complex, DOB,
                    // photo) that a coaching student needs, while Sign Up is
                    // the four-field `POST /auth/register` for somebody who
                    // just wants an account to book a court.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don’t have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => RegisterScreen()),
                            );
                          },
                          child: const Text(
                            "Student Register",
                            style: TextStyle(
                              color: brandBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Just want to book a court? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: brandBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


//
// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final emailMobileController = TextEditingController();
//   final passwordController = TextEditingController();
//   bool rememberMe = false;
//   bool obscurePassword = true;
//
//   bool _isLoading = false;
//
//   bool _isValidEmail(String input) {
//     final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
//     return emailRegex.hasMatch(input);
//   }
//
//   bool _isValidMobile(String input) {
//     final mobileRegex = RegExp(r"^[0-9]{10}$");
//     return mobileRegex.hasMatch(input);
//   }
//   void _login() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _isLoading = true);
//
//     final emailOrMobile = emailMobileController.text.trim();
//     final password = passwordController.text.trim();
//
//     bool success = await ApiService.login(emailOrMobile, password);
//
//     setState(() => _isLoading = false);
//
//     if (success) {
//       _showInfoDialog("Login Successful");
//
//       Future.delayed(const Duration(seconds: 2), () {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => const CustomBottomNav()),
//         );
//       });
//     } else {
//       _showInfoDialog("Login failed. Please check your credentials.");
//     }
//   }
//
//   // void _login() async {
//   //   if (!_formKey.currentState!.validate()) return;
//   //
//   //   setState(() {
//   //     _isLoading = true;
//   //   });
//   //
//   //   final emailOrMobile = emailMobileController.text.trim();
//   //   final password = passwordController.text.trim();
//   //
//   //   // You can send email or mobile as 'email' param (assuming your backend handles that)
//   //   bool success = await ApiService.login(emailOrMobile, password);
//   //
//   //   setState(() {
//   //     _isLoading = false;
//   //   });
//   //
//   //   if (success) {
//   //     Navigator.pushReplacement(
//   //       context,
//   //       MaterialPageRoute(builder: (context) => CustomBottomNav()),
//   //     );
//   //   } else {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       const SnackBar(content: Text("Login failed. Please check your credentials.")),
//   //     );
//   //   }
//   // }
//
//   @override
//   Widget build(BuildContext context) {
//     const brandBlue = Color(0xFF1A237E);
//     const brandYellow = Color(0xFFF9A825);
//
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFFE3F2FD),
//               Colors.white,
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: Center(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     Image.asset("asset/ns.png", height: 100),
//                     const SizedBox(height: 20),
//                     const Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         "Sign in to your\nAccount",
//                         style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//
//                     TextFormField(
//                       controller: emailMobileController,
//                       decoration: InputDecoration(
//                         hintText: "Email",
//                         filled: true,
//                         fillColor: Colors.white,
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return "Please enter Email or Mobile number";
//                         }
//                         if (!_isValidEmail(value.trim()) &&
//                             !_isValidMobile(value.trim())) {
//                           return "Enter a valid Email or 10-digit Mobile number";
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 20),
//
//                     TextFormField(
//                       controller: passwordController,
//                       obscureText: obscurePassword,
//                       decoration: InputDecoration(
//                         hintText: "Password",
//                         filled: true,
//                         fillColor: Colors.white,
//                         suffixIcon: IconButton(
//                           icon: Icon(
//                             obscurePassword ? Icons.visibility_off : Icons.visibility,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               obscurePassword = !obscurePassword;
//                             });
//                           },
//                         ),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(8),
//                           borderSide: BorderSide.none,
//                         ),
//                       ),
//                       validator: (value) {
//                         if (value == null || value.trim().isEmpty) {
//                           return "Password is required";
//                         }
//                         if (value.length < 6) {
//                           return "Password must be at least 6 characters";
//                         }
//                         return null;
//                       },
//                     ),
//                     const SizedBox(height: 10),
//
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           children: [
//                             Checkbox(
//                               value: rememberMe,
//                               activeColor: brandBlue,
//                               onChanged: (value) {
//                                 setState(() {
//                                   rememberMe = value ?? false;
//                                 });
//                               },
//                             ),
//                             const Text("Remember me"),
//                           ],
//                         ),
//                         TextButton(
//                           onPressed: () {},
//                           child: const Text(
//                             "Forgot Password ?",
//                             style: TextStyle(color: brandBlue),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//
//                     _isLoading
//                         ? const CircularProgressIndicator()
//                         : SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: ElevatedButton(
//                         onPressed: _login,
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: brandBlue,
//                           foregroundColor: Colors.black,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         child: const Text(
//                           "Log In",
//                           style: TextStyle(fontSize: 16, color: Colors.white),
//                         ),
//                       ),
//                     ),
//
//                     const SizedBox(height: 20),
//                     Row(
//                       children: [
//                         const Expanded(child: Divider(thickness: 1)),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 8),
//                           child: Text(
//                             "Or",
//                             style: TextStyle(color: Colors.grey[600]),
//                           ),
//                         ),
//                         const Expanded(child: Divider(thickness: 1)),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Text("Don’t have an account? "),
//                         GestureDetector(
//                           onTap: () {
//                             Navigator.pushReplacement(
//                               context,
//                               MaterialPageRoute(builder: (context) => RegisterScreen()),
//                             );
//                           },
//                           child: const Text(
//                             "Register",
//                             style: TextStyle(
//                               color: brandBlue,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _showInfoDialog(String message) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         // title: const Text("Hello"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.info_outline, size: 50, color:  Color(0xFF1A237E)),
//             const SizedBox(height: 16),
//             Text(message, textAlign: TextAlign.center),
//           ],
//         ),
//       ),
//     );
//
//     Future.delayed(const Duration(seconds: 2), () {
//       if (mounted) Navigator.pop(context); // Close dialog after 2 sec
//     });
//   }
// }


/// Thin facade over [AuthRepository] kept at its original name and shape so
/// every existing screen keeps compiling. All networking, token handling and
/// caching now happen in the core layer.
class ApiService {
  /// Raw user map, for screens that have not moved to [ProfileModel] yet.
  static Map<String, dynamic>? currentUser;

  static String? lastErrorMessage; // populated when login fails for UI to show

  /// Strongly typed view of the same user.
  static ProfileModel? currentProfile;

  /// Load user from local (cached) storage
  static Future<void> loadUserFromPrefs() async {
    final profile = await AuthRepository.instance.cachedProfile();

    if (profile == null || !await AuthRepository.instance.hasSession) {
      currentProfile = null;
      currentUser = null;
      return;
    }

    currentProfile = profile;
    currentUser = profile.toLegacyUserMap();
    PermissionService.instance.sync(profile);
  }

  /// Get role (default = user)
  static String getRole() {
    return currentUser?['role']?.toString().toLowerCase() ?? 'user';
  }

  /// Permission check backed by `/auth/profile`.
  static bool hasPermission(String permission) =>
      PermissionService.instance.hasPermission(permission);

  /// Login API — `POST /auth/login`.
  ///
  /// Tokens go straight into encrypted storage; the profile is cached and
  /// broadcast to every listening screen.
  static Future<bool> login(String email, String password) async {
    final result = await AuthRepository.instance.login(
      email: email,
      password: password,
    );

    if (!result.success || result.profile == null) {
      lastErrorMessage =
          result.message ?? 'Login failed. Please check your credentials.';
      currentUser = null;
      currentProfile = null;
      return false;
    }

    final profile = result.profile!;
    currentProfile = profile;
    currentUser = profile.toLegacyUserMap();

    // Fan the new profile out to Home / More / Profile / Dashboard at once.
    ProfileProvider.maybeInstance?.adopt(profile);

    final userId = profile.id;
    if (userId != null) await _saveFcmTokenToServer(userId);

    lastErrorMessage = null;
    return true;
  }

  /// Google sign-in — `POST /auth/google-login`.
  ///
  /// [credential] is the Google ID token. Everything after the network call is
  /// identical to [login]: tokens stored, profile cached and broadcast, FCM
  /// token registered.
  static Future<bool> googleLogin(String credential) async {
    final result =
        await AuthRepository.instance.googleLogin(credential: credential);

    if (!result.success || result.profile == null) {
      lastErrorMessage =
          result.message ?? 'Google login failed. Please try again.';
      currentUser = null;
      currentProfile = null;
      return false;
    }

    final profile = result.profile!;
    currentProfile = profile;
    currentUser = profile.toLegacyUserMap();

    ProfileProvider.maybeInstance?.adopt(profile);

    final userId = profile.id;
    if (userId != null) await _saveFcmTokenToServer(userId);

    lastErrorMessage = null;
    return true;
  }

  /// Apple sign-in — `POST /auth/apple-login`.
  ///
  /// [identityToken] is the JWT from the Apple sheet. [firstName] / [lastName]
  /// are non-null only on the user's first ever authorization — Apple never
  /// sends the name again — and are simply dropped after that.
  ///
  /// Everything after the network call is identical to [login] and
  /// [googleLogin]: tokens stored, profile cached and broadcast, FCM token
  /// registered.
  static Future<bool> appleLogin(
    String identityToken, {
    String? firstName,
    String? lastName,
  }) async {
    final result = await AuthRepository.instance.appleLogin(
      identityToken: identityToken,
      firstName: firstName,
      lastName: lastName,
    );

    if (!result.success || result.profile == null) {
      lastErrorMessage =
          result.message ?? 'Apple login failed. Please try again.';
      currentUser = null;
      currentProfile = null;
      return false;
    }

    final profile = result.profile!;
    currentProfile = profile;
    currentUser = profile.toLegacyUserMap();

    ProfileProvider.maybeInstance?.adopt(profile);

    final userId = profile.id;
    if (userId != null) await _saveFcmTokenToServer(userId);

    lastErrorMessage = null;
    return true;
  }

  static Future<void> _saveFcmTokenToServer(int userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await AuthRepository.instance.registerFcmToken(
        userId: userId,
        fcmToken: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint("FCM Save Error: $e");
    }
  }

  /// Check login state.
  static Future<bool> isLoggedIn() async {
    if (await AuthRepository.instance.hasSession) return true;
    // Social sign-ins that predate JWT still mark the flag directly.
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Adopts a session established by a social provider (Google / Apple).
  ///
  /// Stores any tokens the backend returned, caches the profile and pushes it
  /// to every screen — the same path a password login takes.
  static Future<ProfileModel> adoptSession(Map<String, dynamic> payload) async {
    await TokenStorage.instance.saveTokens(
      accessToken:
          (payload['accessToken'] ?? payload['token'])?.toString(),
      refreshToken: payload['refreshToken']?.toString(),
    );

    final rawUser = payload['user'] is Map
        ? Map<String, dynamic>.from(payload['user'] as Map)
        : payload;

    final profile = ProfileModel.fromJson(rawUser);

    await ProfileCache.instance.save(profile);
    PermissionService.instance.sync(profile);

    currentProfile = profile;
    currentUser = profile.toLegacyUserMap();
    ProfileProvider.maybeInstance?.adopt(profile);

    return profile;
  }
  static Future<void> _removeFcmTokenFromServer(int userId) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      await AuthRepository.instance.unregisterFcmToken(
        userId: userId,
        fcmToken: fcmToken,
      );
    } catch (e) {
      debugPrint("FCM Delete Error: $e");
    }
  }

  /// Full sign-out: de-registers push, then wipes tokens, cached profile and
  /// permissions.
  static Future<void> logout() async {
    try {
      final userId = currentProfile?.id ??
          int.tryParse(currentUser?['id']?.toString() ?? '') ??
          int.tryParse(await AuthService.getUserId() ?? '');

      if (userId != null) {
        await _removeFcmTokenFromServer(userId);
      }

      await FirebaseMessaging.instance.deleteToken(); // invalidate on device too
    } catch (e) {
      debugPrint("Error during FCM cleanup: $e");
    }

    currentUser = null;
    currentProfile = null;
    lastErrorMessage = null;

    // Clears tokens + cached profile + permissions and notifies every screen
    // bound to the profile. Navigation stays with the calling screen.
    await SessionManager.instance.signOut(navigateToLogin: false);
  }

}
class AuthService {
  static Future<Map<String, dynamic>?> getUser() async {
    final profile = await AuthRepository.instance.cachedProfile();
    if (profile != null) return profile.toLegacyUserMap();

    // Fallback for sessions written before the profile cache existed.
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson == null) return null;
    try {
      final decoded = jsonDecode(userJson);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getUserId() async {
    final user = await getUser();
    return user?['id']?.toString();
  }

  static Future<String?> getUserEmail() async {
    final user = await getUser();
    return user?['email']?.toString();
  }
  static Future<String?> getUserName() async {
    final user = await getUser();
    return user?['name']?.toString();

  }

  static Future<String?> getUserRole() async {
    final profile = await AuthRepository.instance.cachedProfile();
    if (profile?.role != null) return profile!.role;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  /// Access token, read from encrypted storage.
  static Future<String?> getAuthToken() => TokenStorage.instance.accessToken;

  /// Sign out. Delegates to [ApiService.logout] so there is exactly one
  /// implementation of "end the session".
  static Future<void> logout() => ApiService.logout();

  /// Permissions granted by `/auth/profile`.
  static Future<List<String>> getPermissions() async {
    final profile = await AuthRepository.instance.cachedProfile();
    return profile?.permissions ?? const <String>[];
  }

  static Future<bool> hasPermission(String permission) async {
    if (PermissionService.instance.isLoaded) {
      return PermissionService.instance.hasPermission(permission);
    }
    return (await getPermissions()).contains(permission);
  }
}
























// // ✅ Updated Google Sign-In method

// Future<void> _signInWithGoogle() async {
//   try {
//     // Trigger Google Sign-In flow
//     final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//
//     if (googleUser != null) {
//       // Obtain the authentication details
//       final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
//
//       // Print out the whole googleAuth object and its tokens for debugging
//       print('--- Google Auth Debug ---');
//       print('googleAuth: $googleAuth');
//       print('idToken: ${googleAuth.idToken}');
//       print('accessToken: ${googleAuth.accessToken}');
//
//       // If idToken is null, it might indicate a configuration issue
//       if (googleAuth.idToken == null) {
//         print('idToken is null');
//         return;
//       }
//
//       // Create a new credential for Firebase Authentication
//       final OAuthCredential credential = GoogleAuthProvider.credential(
//         idToken: googleAuth.idToken,
//         accessToken: googleAuth.accessToken,
//       );
//
//       // Sign in with Firebase using the credential
//       final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
//
//       // You now have the user signed in
//       print('User signed in: ${userCredential.user?.displayName}');
//     }
//   } catch (e) {
//     print('Google Sign-In error: $e');
//   }
// }

// Future<void> _signInWithGoogle() async {
//   setState(() => _isLoading = true);
//
//   try {
//
//     // Always sign out first to force account picker
//     await _googleSignIn.signOut();
//
//     final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//
//     if (googleUser != null) {
//       final GoogleSignInAuthentication googleAuth =
//       await googleUser.authentication;
//
//       final String? accessToken = googleAuth.accessToken;
//       final String? idToken = googleAuth.idToken;
//
//       print('--- Google Sign-In Debug ---');
//       print('Email: ${googleUser.email}');
//       print('AccessToken: $accessToken');
//       print('idToken: $idToken');
//
//       // If idToken is still null, likely SHA1 mismatch
//       if (idToken == null) {
//         _showInfoDialog('null');
//       } else {
//         // Send tokens to your backend
//         bool success = await _handleGoogleAuthWithBackend(
//           googleUser.email,
//           accessToken,
//           idToken,
//         );
//
//         if (success) {
//           _showInfoDialog("Google Sign-In Successful");
//           Future.delayed(const Duration(seconds: 2), () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => const CustomBottomNav()),
//             );
//           });
//         } else {
//           _showInfoDialog("Google Sign-In failed. Please try again.");
//         }
//       }
//     }
//   } catch (error) {
//     _showInfoDialog("Google Sign-In failed: $error");
//     print('Google Sign-In error: $error');
//   } finally {
//     setState(() => _isLoading = false);
//   }
// }

// Handle Google authentication with your backend