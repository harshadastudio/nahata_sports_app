//
//
// import 'dart:async';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
//
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../../dashboard/admin_screen.dart';
// import '../../dashboard/coach_screen.dart';
// import '../../dashboard/dashboard_screen.dart';
// import '../../dashboard/security_screen.dart';
// import '../../services/api_service.dart';
//
// // import your ApiService & Screens
// // import 'api_service.dart';
// // import 'admin_dashboard.dart';
// // import 'coach_dashboard.dart';
// // import 'security_gate_scanner.dart';
// // import 'book_play_screen.dart';
// // import 'register_screen.dart';
//
// class NLoginScreen extends StatefulWidget {
//   const NLoginScreen({super.key});
//
//   @override
//   State<NLoginScreen> createState() => _NLoginScreenState();
// }
//
// class _NLoginScreenState extends State<NLoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//
//   final emailMobileController = TextEditingController();
//   final passwordController = TextEditingController();
//
//   bool rememberMe = false;
//   bool obscurePassword = true;
//   bool _isLoading = false;
//   bool _autoLoginTried = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadRememberedLogin();
//   }
//
//   Future<void> _loadRememberedLogin() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     final savedRemember = prefs.getBool('rememberMe') ?? false;
//     final savedEmail = prefs.getString('savedEmail') ?? '';
//     final savedPassword = prefs.getString('savedPassword') ?? '';
//
//     if (savedRemember && savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
//       setState(() {
//         rememberMe = true;
//         emailMobileController.text = savedEmail;
//         passwordController.text = savedPassword;
//       });
//
//       // 🔑 Silent auto login
//       if (!_autoLoginTried) {
//         _autoLoginTried = true;
//         _handleLogin(silent: true);
//       }
//     }
//   }
//
//   void showCustomSnackbar(String message,
//       {bool isSuccess = true, bool isError = false}) {
//     final snackBar = SnackBar(
//       behavior: SnackBarBehavior.floating,
//       margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//       backgroundColor: isError ? Colors.red : Colors.green,
//       elevation: 6,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       content: Row(
//         children: [
//           Icon(
//             isError ? Icons.error : Icons.check_circle,
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
//
//   Future<void> _handleLogin({bool silent = false}) async {
//     if (!_formKey.currentState!.validate() && !silent) return;
//
//     final emailOrMobile = emailMobileController.text.trim();
//     final password = passwordController.text.trim();
//
//     if (!silent) setState(() => _isLoading = true);
//
//     bool isSuccess = await ApiService.login(emailOrMobile, password);
//
//     if (!silent) setState(() => _isLoading = false);
//
//     if (isSuccess && ApiService.currentUser != null) {
//       final role = ApiService.currentUser?['role'];
//
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.setBool('isLoggedIn', true);
//       await prefs.setString('user', jsonEncode(ApiService.currentUser));
//
//       // 🔑 Save or clear rememberMe
//       if (rememberMe) {
//         await prefs.setBool('rememberMe', true);
//         await prefs.setString('savedEmail', emailOrMobile);
//         await prefs.setString('savedPassword', password);
//       } else {
//         await prefs.remove('rememberMe');
//         await prefs.remove('savedEmail');
//         await prefs.remove('savedPassword');
//       }
//
//       Widget screen;
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
//           screen = BookPlayScreen();
//       }
//
//       if (mounted) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => screen),
//         );
//       }
//     } else {
//       if (!silent) {
//         showCustomSnackbar("Login Failed", isError: true);
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     emailMobileController.dispose();
//     passwordController.dispose();
//     super.dispose();
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
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Image.asset("assets/icons/nahata (2).webp", height: 100),
//                     const SizedBox(height: 20),
//                     const Align(
//                       alignment: Alignment.centerLeft,
//                       child: Text(
//                         "Sign in to your\nAccount",
//                         style: TextStyle(
//                           fontSize: 26,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//
//                     // Email / Mobile
//                     TextFormField(
//                       controller: emailMobileController,
//                       decoration: InputDecoration(
//                         hintText: "Email or Mobile Number",
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
//                     // Password
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
//
//                     // Remember Me + Forgot
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
//                     // Login Button
//                     SizedBox(
//                       width: double.infinity,
//                       height: 50,
//                       child: ElevatedButton(
//                         onPressed: _isLoading ? null : () => _handleLogin(),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: brandBlue,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                         ),
//                         child: _isLoading
//                             ? const CircularProgressIndicator(
//                           color: Colors.white,
//                         )
//                             : const Text(
//                           "Log In",
//                           style: TextStyle(
//                               fontSize: 16, color: Colors.white),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//
//                     // Divider
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
//                     // Register
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Text("Don’t have an account? "),
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
//   bool _isValidEmail(String input) {
//     final emailRegex =
//     RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
//     return emailRegex.hasMatch(input);
//   }
//
//   bool _isValidMobile(String input) {
//     final mobileRegex = RegExp(r"^[0-9]{10}$");
//     return mobileRegex.hasMatch(input);
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
// class RegisterScreen extends StatefulWidget {
//   const RegisterScreen({super.key});
//
//   @override
//   _RegisterScreenState createState() => _RegisterScreenState();
// }
//
// class _RegisterScreenState extends State<RegisterScreen> {
//   final _formKey = GlobalKey<FormState>();
//
//   final nameController = TextEditingController();
//   final emailController = TextEditingController();
//   final phoneController = TextEditingController();
//   final parentPhoneController = TextEditingController();
//   final passwordController = TextEditingController();
//   final confirmPasswordController = TextEditingController();
//   final referralController = TextEditingController();
//   final dobController = TextEditingController();
//
//   String? selectedGender;
//   File? selectedFile;
//   final ImagePicker _picker = ImagePicker();
//
//   Future<void> pickFile() async {
//     final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
//     if (file != null) {
//       setState(() {
//         selectedFile = File(file.path);
//       });
//     }
//   }
//
//   Future<void> pickDate() async {
//     DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime(2005, 1, 1),
//       firstDate: DateTime(1900),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() {
//         dobController.text =
//         "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
//       });
//     }
//   }
//
//   InputDecoration _inputDecoration(String label) {
//     return InputDecoration(
//       labelText: label,
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(8),
//         borderSide: BorderSide.none,
//       ),
//       filled: true,
//       fillColor: Colors.white,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFFE3F2FD), Colors.white],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Back button
//                   IconButton(
//                     icon: const Icon(Icons.arrow_back),
//                     onPressed: (){
//                       Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(builder: (context) => NLoginScreen()),
//                       );
//                     },
//                   ),
//                   const SizedBox(height: 10),
//
//                   const Text(
//                     "Register",
//                     style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 5),
//                   const Text(
//                     "Create an account to continue!",
//                     style: TextStyle(color: Colors.black54),
//                   ),
//                   const SizedBox(height: 20),
//
//                   // Upload Photo
//                   const Text("Upload Photo"),
//                   const SizedBox(height: 8),
//                   Row(
//                     children: [
//                       ElevatedButton.icon(
//                         onPressed: pickFile,
//                         icon: const Icon(Icons.upload_file),
//                         label: const Text("Choose File"),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.grey[200],
//                           foregroundColor: Colors.black,
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Expanded(
//                         child: Text(
//                           selectedFile != null
//                               ? selectedFile!.path.split('/').last
//                               : "No file chosen",
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 20),
//
//                   // Full Name
//                   TextFormField(
//                     controller: nameController,
//
//                     decoration: _inputDecoration("Full Name"),
//                     validator: (value) =>
//                     value!.isEmpty ? "Full name is required" : null,
//                   ),
//                   const SizedBox(height: 15),
//
//                   // Email
//                   TextFormField(
//                     controller: emailController,
//                     keyboardType: TextInputType.emailAddress,
//                     decoration: _inputDecoration("Email"),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return "Email is required";
//                       }
//                       final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
//                       if (!emailRegex.hasMatch(value)) {
//                         return "Enter valid email";
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),
//
//                   // Phone
//                   TextFormField(
//                     controller: phoneController,
//                     keyboardType: TextInputType.phone,
//                     decoration: _inputDecoration("Phone Number (+91 XXXXXXXXXX)"),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return "Phone number is required";
//                       }
//                       final phoneRegex = RegExp(r'^\+91[0-9]{10}$');
//                       if (!phoneRegex.hasMatch(value)) {
//                         return "Enter valid phone (e.g. +91 8888888888)";
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),
//
//                   // Parent Phone (Optional)
//                   TextFormField(
//                     controller: parentPhoneController,
//                     keyboardType: TextInputType.phone,
//                     decoration:
//                     _inputDecoration("Parent / Guardian Contact (Optional)"),
//                   ),
//                   const SizedBox(height: 15),
//
//                   // DOB
//                   TextFormField(
//                     controller: dobController,
//                     readOnly: true,
//                     decoration: _inputDecoration("Date of Birth"),
//                     onTap: pickDate,
//                   ),
//                   const SizedBox(height: 15),
//
//                   // Gender Dropdown
//                   DropdownButtonFormField<String>(
//                     decoration: _inputDecoration("Gender"),
//                     value: selectedGender,
//                     items: ["Male", "Female", "Other"]
//                         .map((g) => DropdownMenuItem(
//                       value: g,
//                       child: Text(g),
//                     ))
//                         .toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         selectedGender = value;
//                       });
//                     },
//                   ),
//                   const SizedBox(height: 15),
//
//                   // Password
//                   TextFormField(
//                     controller: passwordController,
//                     obscureText: true,
//                     decoration: _inputDecoration("Password"),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return "Password is required";
//                       }
//                       if (value.length < 6) {
//                         return "Password must be at least 6 characters";
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),
//
//                   // Confirm Password
//                   TextFormField(
//                     controller: confirmPasswordController,
//                     obscureText: true,
//                     decoration: _inputDecoration("Confirm Password"),
//                     validator: (value) {
//                       if (value != passwordController.text) {
//                         return "Passwords do not match";
//                       }
//                       return null;
//                     },
//                   ),
//                   const SizedBox(height: 15),
//
//                   // Referral Code (Optional)
//                   TextFormField(
//                     controller: referralController,
//                     decoration: _inputDecoration("Referral Code (Optional)"),
//                   ),
//                   const SizedBox(height: 25),
//
//                   // Register Button
//                   SizedBox(
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF2E3192),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                       ),
//                       onPressed: () {
//                         if (_formKey.currentState!.validate()) {
//                           // ✅ Handle Registration
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(content: Text("Form Submitted")),
//                           );
//                         }
//                       },
//                       child: const Text(
//                         "Register",
//                         style: TextStyle(fontSize: 18, color: Colors.white),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//
//                   // Already have account?
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Text("Already have an account? "),
//                       GestureDetector(
//                         onTap: () {
//                           Navigator.pushReplacement(
//                             context,
//                             MaterialPageRoute(builder: (context) => NLoginScreen()),
//                           );
//                         },
//                         child: const Text(
//                           "Login",
//                           style: TextStyle(
//                               color: Color(0xFF2E3192),
//                               fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
//
//
// /// This widget controls the 3-step splash animation
// class SplashController extends StatefulWidget {
//   @override
//   State<SplashController> createState() => _SplashControllerState();
// }
//
// class _SplashControllerState extends State<SplashController> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     // Auto animate between screens every 2 seconds
//     Timer.periodic(const Duration(seconds: 2), (timer) {
//       if (_currentPage < 2) {
//         _currentPage++;
//         _pageController.animateToPage(
//           _currentPage,
//           duration: const Duration(milliseconds: 600),
//           curve: Curves.easeInOut,
//         );
//       } else {
//         timer.cancel();
//         // Navigate to Login after splash
//         Future.delayed(const Duration(seconds: 1), () {
//           Navigator.pushReplacement(
//               context, MaterialPageRoute(builder: (_) => const NLoginScreen()));
//         });
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: PageView(
//         controller: _pageController,
//         physics: const NeverScrollableScrollPhysics(), // disable swipe
//         children: const [
//           SplashStep1(),
//           SplashStep2(),
//           SplashStep3(),
//         ],
//       ),
//     );
//   }
// }
//
// /// Step 1 → Only Logo
// class SplashStep1 extends StatelessWidget {
//   const SplashStep1({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Image.asset(
//         "assets/ns.png", // Your NahataSports logo
//         height: 120,
//       ),
//     );
//   }
// }
//
// /// Step 2 → Logo with images around
// class SplashStep2 extends StatelessWidget {
//   const SplashStep2({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         Positioned(top: 80, left: 40, child: _splashImage("assets/ns1.jpg")),
//         Positioned(top: 80, right: 40, child: _splashImage("assets/ns2.jpg")),
//         Positioned(bottom: 100, left: 30, child: _splashImage("assets/ns3.jpg")),
//         Positioned(bottom: 100, right: 30, child: _splashImage("assets/ns4.jpg")),
//         Image.asset("assets/ns.png", height: 120),
//       ],
//     );
//   }
//
//   Widget _splashImage(String path) => ClipRRect(
//     borderRadius: BorderRadius.circular(12),
//     child: Image.asset(path, height: 90, width: 90, fit: BoxFit.cover),
//   );
// }
//
// /// Step 3 → Logo + tagline + images
//
// class SplashStep3 extends StatefulWidget {
//   const SplashStep3({super.key});
//
//   @override
//   State<SplashStep3> createState() => _SplashStep3State();
// }
//
// class _SplashStep3State extends State<SplashStep3> {
//   double logoOpacity = 0.0;
//   double imagesOpacity = 0.0;
//   double text1Opacity = 0.0;
//   double text2Opacity = 0.0;
//   double text3Opacity = 0.0;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Animation sequence
//     Timer(const Duration(milliseconds: 500), () {
//       setState(() => logoOpacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 1500), () {
//       setState(() => imagesOpacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 2500), () {
//       setState(() => text1Opacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 3500), () {
//       setState(() => text2Opacity = 1.0);
//     });
//     Timer(const Duration(milliseconds: 4500), () {
//       setState(() => text3Opacity = 1.0);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         alignment: Alignment.center,
//         children: [
//           // Sports images
//           AnimatedOpacity(
//             opacity: imagesOpacity,
//             duration: const Duration(seconds: 1),
//             child: Stack(
//               children: [
//                 Positioned(top: 80, left: 40, child: _splashImage("assets/ns1.jpg")),
//                 Positioned(top: 80, right: 40, child: _splashImage("assets/ns2.jpg")),
//                 Positioned(bottom: 100, left: 30, child: _splashImage("assets/ns3.jpg")),
//                 Positioned(bottom: 100, right: 30, child: _splashImage("assets/ns4.jpg")),
//               ],
//             ),
//           ),
//
//           // Main content
//           Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // Logo
//               AnimatedOpacity(
//                 opacity: logoOpacity,
//                 duration: const Duration(seconds: 1),
//                 child: Image.asset("assets/ns.png", height: 100),
//               ),
//               const SizedBox(height: 16),
//
//               // Texts fade-in sequentially
//               AnimatedOpacity(
//                 opacity: text1Opacity,
//                 duration: const Duration(seconds: 1),
//                 child: const Text(
//                   "Unleash Potential",
//                   style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               AnimatedOpacity(
//                 opacity: text2Opacity,
//                 duration: const Duration(seconds: 1),
//                 child: const Text(
//                   "Elevate Every Game.",
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF2E3192),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 6),
//               AnimatedOpacity(
//                 opacity: text3Opacity,
//                 duration: const Duration(seconds: 1),
//                 child: const Text(
//                   "Sport. Spirit. Strength. Success. Nahata.",
//                   style: TextStyle(fontSize: 14, color: Colors.black54),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _splashImage(String path) => ClipRRect(
//     borderRadius: BorderRadius.circular(12),
//     child: Image.asset(path, height: 120, width: 80, fit: BoxFit.cover),
//   );
// }
//
//
