import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nahata_app/screens/regi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard/admin_screen.dart';
import '../dashboard/coach_screen.dart';
import '../dashboard/dashboard1.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/security_screen.dart';
import '../services/api_service.dart';
import 'location_screen.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});
//
//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();
//
//   bool _obscurePassword = true;
//
//   late AnimationController _controller;
//   late Animation<double> _fadeAnimation;
//
//
//
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }
//   void showCustomSnackbar(BuildContext context, String message, {bool isSuccess = true,bool isError = false} ) {
//     final snackBar = SnackBar(
//       behavior: SnackBarBehavior.floating,
//       margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       backgroundColor: isError ? Colors.grey: Colors.grey,
//       elevation: 6,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       content: Row(
//         children: [
//           Icon(
//             isSuccess ? Icons.check_circle : Icons.error,
//             color: Colors.white,
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ),
//         ],
//       ),
//       duration: const Duration(seconds: 3),
//     );
//
//     ScaffoldMessenger.of(context).showSnackBar(snackBar);
//   }
//   // Future<void> loginUser() async {
//   //   final url = Uri.parse('https://nahatasports.com/api/login');
//   //
//   //
//   //
//   //   showDialog(
//   //     context: context,
//   //     barrierDismissible: false,
//   //     builder: (_) => const Center(child: CircularProgressIndicator()),
//   //   );
//   //
//   //   try {
//   //     final response = await http.post(
//   //       url,
//   //       headers: {'Content-Type': 'application/json'},
//   //       body: jsonEncode({'email': _emailC, 'password': _pwdC}),
//   //     );
//   //
//   //     if (Navigator.canPop(context)) Navigator.pop(context); // Dismiss loader
//   //
//   //     final res = jsonDecode(response.body);
//   //     print("📥 Login Response: $res");
//   //
//   //     if (res['success'] == true) {
//   //       showCustomSnackbar(context, '✅ Login successful!');
//   //
//   //       // ✅ Navigate to Location Screen
//   //       Navigator.pushReplacement(
//   //         context,
//   //         MaterialPageRoute(builder: (_) => const LocationScreen()),
//   //       );
//   //     } else {
//   //       // ❌ Login failed: Show alert
//   //       showDialog(
//   //         context: context,
//   //         builder: (ctx) => AlertDialog(
//   //           title: const Text("Login Failed"),
//   //           content: const Text("You are not registered."),
//   //           actions: [
//   //             TextButton(
//   //               onPressed: () => Navigator.of(ctx).pop(),
//   //               child: const Text("OK"),
//   //             ),
//   //           ],
//   //         ),
//   //       );
//   //     }
//   //   } catch (e) {
//   //     if (Navigator.canPop(context)) Navigator.pop(context);
//   //     showCustomSnackbar(context, '❌ Error: $e', isError: true);
//   //   }
//   // }
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _fadeAnimation = CurvedAnimation(
//       parent: _controller,
//       curve: Curves.easeIn,
//     );
//     _controller.forward();
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // 🔵 Gradient background
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           ),
//
//           // 🧊 Glass card UI
//           Center(
//             child: FadeTransition(
//               opacity: _fadeAnimation,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(24),
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(horizontal: 24),
//                     padding: const EdgeInsets.all(24),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.9),
//                       borderRadius: BorderRadius.circular(24),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.grey.withOpacity(0.3),
//                           blurRadius: 20,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: SingleChildScrollView(
//                       child: Form(
//                         key: _formKey,
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Image.asset(
//                               'assets/images/nahata_a.webp',
//                               height: 80,
//                             ),
//                             const SizedBox(height: 16),
//                             const Text(
//                               "Welcome Back",
//                               style: TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey,
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//
//                             _buildField("Email", _emailController, keyboardType: TextInputType.emailAddress, icon: Icons.email, validator: (value) {
//                               if (value == null || value.isEmpty) return "Email is required";
//                               if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$").hasMatch(value)) return "Enter valid email";
//                               return null;
//                             }),
//
//                             const SizedBox(height: 20),
//
//                             _buildField("Password", _passwordController, isPassword: true, icon: Icons.lock, validator: (value) {
//                               if (value == null || value.isEmpty) return "Password is required";
//                               if (value.length < 4 || value.length > 10) return "Password must be 4–10 characters";
//                               return null;
//                             }),
//
//                             const SizedBox(height: 24),
//                             SizedBox(
//                               width: double.infinity,
//                               child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: const Color(0xFF0A198D), // Same as Register button
//                                   padding: const EdgeInsets.symmetric(vertical: 16),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(30),
//                                   ),
//                                 ),
//                                 onPressed: () async {
//                                   final email = _emailController.text.trim();
//                                   final password = _passwordController.text.trim();
//
//                                   if (email.isEmpty || password.isEmpty) {
//                                     showCustomSnackbar(context, 'Please fill all fields', isError: true);
//                                     return;
//                                   }
//
//
//
//
//                                   showDialog(
//                                     context: context,
//                                     barrierDismissible: false,
//                                     builder: (_) => const Center(child: CircularProgressIndicator()),
//                                   );
//
//                                   bool isSuccess = await ApiService.login(email, password);
//
//                                   if (Navigator.canPop(context)) Navigator.pop(context); // dismiss loader
//
//                                   // if (isSuccess) {
//                                   //   showCustomSnackbar(context, 'Login Successful');
//                                   //   Navigator.pushReplacement(
//                                   //     context,
//                                   //     MaterialPageRoute(builder: (_) => const DashboardScreen1()),
//                                   //   );
//                                   // }
//
//                                   if (isSuccess) {
//                                     final role = ApiService.currentUser?['role'];
//
//                                     if (role == 'admin') {
//                                       Navigator.pushReplacement(
//                                         context,
//                                         MaterialPageRoute(builder: (_) => AdminDashboardScreen()),
//                                       );
//                                     } else if (role == 'coach') {
//                                       Navigator.pushReplacement(
//                                         context,
//                                         MaterialPageRoute(builder: (_) => CoachDashboardScreen()),
//                                       );
//                                     } else if (role == 'user') {
//                                       Navigator.pushReplacement(
//                                         context,
//                                         MaterialPageRoute(builder: (_) => DashboardScreen()),
//                                       );
//                                     } else if (role == 'security') {
//                                       Navigator.pushReplacement(
//                                         context,
//                                         MaterialPageRoute(builder: (_) => SecurityGateScanner()),
//                                       );
//                                     }
//                                   }
//
//
//
//                                   else {
//                                     // Show dialog or error message
//                                     showDialog(
//                                       context: context,
//                                       builder: (ctx) => AlertDialog(
//                                         title: const Text("Login Failed"),
//                                         content: const Text("You are not registered."),
//                                         actions: [
//                                           TextButton(
//                                             onPressed: () => Navigator.of(ctx).pop(),
//                                             child: const Text("OK"),
//                                           ),
//                                         ],
//                                       ),
//                                     );
//                                   }
//                                 },
//                                 child: const Text("Login",style: TextStyle(
//                                   fontSize: 18,
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                 ),),
//                               )
//
//                             ),
//
//                             const SizedBox(height: 10),
//
//                             GestureDetector(
//                               onTap: () {
//                                 // Navigator.pushReplacementNamed(context, '/signup');
//
//                                 Navigator.push(
//                                   context,
//                                   MaterialPageRoute(builder: (context) => const PremiumSignUpScreen()),
//                                 );
//                               },
//                               child: Text.rich(
//                                 TextSpan(
//                                   text: "Don't have an account? ",
//                                   style: const TextStyle(color: Colors.grey),
//                                   children: [
//                                     TextSpan(
//                                       text: "Register",
//                                       style: const TextStyle(
//                                         color: Color(0xFF0A198D),
//                                         fontWeight: FontWeight.bold,
//                                         decoration: TextDecoration.underline,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildField(
//       String label,
//       TextEditingController controller, {
//         TextInputType keyboardType = TextInputType.text,
//         bool isPassword = false,
//         IconData? icon,
//         String? Function(String?)? validator,
//       }) {
//     return TextFormField(
//       controller: controller,
//       keyboardType: keyboardType,
//       obscureText: isPassword ? _obscurePassword : false,
//       validator: validator,
//       decoration: InputDecoration(
//         prefixIcon: icon != null ? Icon(icon) : null,
//         suffixIcon: isPassword
//             ? IconButton(
//           icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
//           onPressed: () {
//             setState(() {
//               _obscurePassword = !_obscurePassword;
//             });
//           },
//         )
//             : null,
//         labelText: label,
//         labelStyle: TextStyle(color: Colors.grey[700]),
//         filled: true,
//         fillColor: Colors.grey[200],
//         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(30),
//           borderSide: BorderSide.none,
//         ),
//       ),
//     );
//   }
// }





class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
    // _checkLoginOnce();

  }

  bool _redirected = false;

  void _checkLoginOnce() async {
    if (_redirected) return; // prevent multiple calls
    _redirected = true;

    bool loggedIn = await ApiService.isLoggedIn();
    if (loggedIn && ApiService.currentUser != null) {
      final role = ApiService.currentUser!['role'];
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
          screen = BookPlayScreen();
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      }
    }
  }




  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void showCustomSnackbar(BuildContext context, String message, {bool isSuccess = true, bool isError = false}) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: isError ? Colors.red : Colors.green,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      content: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // 🔵 Gradient background
            // Container(
            //   decoration: const BoxDecoration(
            //     gradient: LinearGradient(
            //       colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
            //       begin: Alignment.topCenter,
            //       end: Alignment.bottomCenter,
            //     ),
            //   ),
            // ),
            // 🧊 Glass card
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      // decoration: BoxDecoration(
                      //   color: Colors.white.withOpacity(0.9),
                      //   borderRadius: BorderRadius.circular(24),
                      //   boxShadow: [
                      //     BoxShadow(
                      //       color: Colors.grey.withOpacity(0.3),
                      //       blurRadius: 20,
                      //       offset: const Offset(0, 10),
                      //     ),
                      //   ],
                      // ),
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/icons/nahata (2).webp', height: 100),
                              const SizedBox(height: 16),
                              const Text(
                                "Welcome Back",
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const SizedBox(height: 20),

                              // Email field
                              _buildField(
                                "Email",
                                _emailController,
                                keyboardType: TextInputType.emailAddress,
                                icon: Icons.email,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return "Email is required";
                                  if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$").hasMatch(val)) return "Enter valid email";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Password field
                              _buildField(
                                "Password",
                                _passwordController,
                                isPassword: true,
                                icon: Icons.lock,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return "Password is required";
                                  // if (val.length < 4 || val.length > 10) return "Password must be 4–10 characters";
                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Forgot Password link
                              // Align(
                              //   alignment: Alignment.centerRight,
                              //   child: TextButton(
                              //     onPressed: () {
                              //       Navigator.push(
                              //         context,
                              //         MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              //       );
                              //     },
                              //     child: const Text(
                              //       "Forgot Password?",
                              //       style: TextStyle(color: Color(0xFF0A198D)),
                              //     ),
                              //   ),
                              // ),

                              const SizedBox(height: 24),

                              // Login Button
                              SizedBox(
                                width: 150,
                                // width: double.infinity,
                                child: AnimatedButton(
                                  text: "Login",
                                  isPrimary: true, // uses your Color(0xFF0A198D) blue
                                  onPressed: () async {
                                    if (!_formKey.currentState!.validate()) return;

                                    final email = _emailController.text.trim();
                                    final password = _passwordController.text.trim();

                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => const Center(child: CircularProgressIndicator()),
                                    );

                                    bool isSuccess = await ApiService.login(email, password);

                                    if (Navigator.canPop(context)) Navigator.pop(context); // dismiss loader

                                    if (isSuccess) {

                                      SharedPreferences prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('isLoggedIn', true);
                                      await prefs.setString('user', jsonEncode(ApiService.currentUser));
                                      final role = ApiService.currentUser?['role'];

                                      if (role == 'admin') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (_) => AdminDashboardScreen()),
                                        );
                                      } else if (role == 'coach') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (_) => CoachDashboardScreen()),
                                        );
                                      } else if (role == 'user') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (_) => BookPlayScreen()),
                                              // DashboardScreen()),
                                        );
                                      } else if (role == 'security') {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(builder: (_) => SecurityGateScannerScreen()),
                                        );
                                      }
                                    } else {
                                      showCustomSnackbar(context, "Login Failed", isError: true);
                                    }
                                  },
                                ),
                              ),

                              // SizedBox(
                              //   width: double.infinity,
                              //   child: ElevatedButton(
                              //     style: ElevatedButton.styleFrom(
                              //       backgroundColor: const Color(0xFF0A198D),
                              //       padding: const EdgeInsets.symmetric(vertical: 16),
                              //       shape: RoundedRectangleBorder(
                              //         borderRadius: BorderRadius.circular(30),
                              //       ),
                              //     ),
                              //     onPressed: () async {
                              //       if (!_formKey.currentState!.validate()) return;
                              //
                              //       final email = _emailController.text.trim();
                              //       final password = _passwordController.text.trim();
                              //
                              //       showDialog(
                              //         context: context,
                              //         barrierDismissible: false,
                              //         builder: (_) => const Center(child: CircularProgressIndicator()),
                              //       );
                              //
                              //       bool isSuccess = await ApiService.login(email, password);
                              //
                              //       if (Navigator.canPop(context)) Navigator.pop(context); // dismiss loader
                              //
                              //       if (isSuccess) {
                              //         final role = ApiService.currentUser?['role'];
                              //
                              //         if (role == 'admin') {
                              //           Navigator.pushReplacement(
                              //             context,
                              //             MaterialPageRoute(builder: (_) => AdminDashboardScreen()),
                              //           );
                              //         } else if (role == 'coach') {
                              //           Navigator.pushReplacement(
                              //             context,
                              //             MaterialPageRoute(builder: (_) => CoachDashboardScreen()),
                              //           );
                              //         } else if (role == 'user') {
                              //           Navigator.pushReplacement(
                              //             context,
                              //             MaterialPageRoute(builder: (_) => DashboardScreen()),
                              //           );
                              //         } else if (role == 'security') {
                              //           Navigator.pushReplacement(
                              //             context,
                              //             MaterialPageRoute(builder: (_) => SecurityGateScanner()),
                              //           );
                              //         }
                              //       } else {
                              //         showCustomSnackbar(context, "Login Failed", isError: true);
                              //       }
                              //     },
                              //     child: const Text(
                              //       "Login",
                              //       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              //     ),
                              //   ),
                              // ),

                              const SizedBox(height: 10),

                              // Register Link
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PremiumSignUpScreen()),
                                  );
                                },
                                child: Text.rich(
                                  TextSpan(
                                    text: "Don't have an account? ",
                                    style: const TextStyle(color: Colors.grey),
                                    children: [
                                      TextSpan(
                                        text: "Register",
                                        style: const TextStyle(
                                          color: Color(0xFF0A198D),
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label,
      TextEditingController controller, {
        TextInputType keyboardType = TextInputType.text,
        bool isPassword = false,
        IconData? icon,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
