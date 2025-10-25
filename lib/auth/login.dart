

import 'dart:convert';

// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nahata_app/auth/registration.dart';

import '../bottombar/Custombottombar.dart';


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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



import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard/admin_screen.dart';
import '../dashboard/coach_screen.dart';
import '../dashboard/security_screen.dart';
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
  const LoginScreen({super.key});

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
      final role = ApiService.currentUser!['role'] ?? 'user';

      Widget screen;
      switch (role) {
        case 'admin':
          screen = AdminDashboardScreen();
          break;
        case 'coach':
          screen = CoachDashboardScreen();
          break;
        case 'security':
          screen = SecurityGateScannerScreen();
          break;
        default:
          screen = CustomBottomNav();
      }

      _showInfoDialog("Login Successful");

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        }
      });
    }

    // if (success && ApiService.currentUser != null) {
    //   final role = ApiService.currentUser!['role'] ?? 'user'; // get role
    //   await _saveCredentials(role);
    //
    //   Widget screen;
    //   switch (role) {
    //     case 'admin':
    //       screen = AdminDashboardScreen();
    //       break;
    //     case 'coach':
    //       screen = CoachDashboardScreen();
    //       break;
    //     case 'security':
    //       screen = SecurityGateScannerScreen();
    //       break;
    //     default:
    //       screen = CustomBottomNav();
    //   }
    //
    //   _showInfoDialog("Login Successful");
    //
    //   Future.delayed(const Duration(seconds: 2), () {
    //     if (mounted) {
    //       Navigator.pushReplacement(
    //         context,
    //         MaterialPageRoute(builder: (_) => screen),
    //       );
    //     }
    //   });
    // } else {
    //   _showInfoDialog("Login failed. Please check your credentials.");
    // }
  }

  void _forgotPassword() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Forgot Password"),
        content: const Text("Please contact support or reset your password."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 50, color: Color(0xFF1A237E)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

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
                          onPressed: _forgotPassword,
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
                            "Register",
                            style: TextStyle(
                              color: brandBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
          ),
//
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








class ApiService {
  static Map<String, dynamic>? currentUser;

  static Future<void> loadUserFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isLoggedIn') ?? false) {
      final userJson = prefs.getString('user');
      if (userJson != null) {
        try {
          currentUser = jsonDecode(userJson);
        } catch (e) {
          print("❌ Failed to decode stored user: $e");
          currentUser = null;
          await prefs.remove('isLoggedIn');
          await prefs.remove('user');
        }
      }
    }
  }

  static String? getRole() {
    return currentUser?['role'];
  }

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
          currentUser = data['data'];

          if (currentUser!['role'] == 'user' && currentUser!['student_id'] == null) {
            currentUser!['student_id'] = currentUser!['id'];
          }

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('user', jsonEncode(currentUser));

          if (data.containsKey('token')) {
            await prefs.setString('authToken', data['token']);
          }

          print("✅ Login successful");
          print("📥 User Data: $currentUser");

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

  static Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}

class AuthService {
  static Future<Map<String, dynamic>?> getUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString('user');
    return userJson != null ? jsonDecode(userJson) : null;
  }

  static Future<String?> getUserEmail() async {
    final user = await getUser();
    return user?['email'];
  }

  static Future<String?> getUserId() async {
    final user = await getUser();
    return user?['id']?.toString();
  }

  static Future<String?> getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  /// ✅ Add this method
  static Future<String?> getUserRole() async {
    final user = await getUser();
    return user?['role'];
  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('user');
    await prefs.remove('authToken');
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