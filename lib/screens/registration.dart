// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// class SignUp extends StatefulWidget {
//   const SignUp({super.key});
//
//   @override
//   State<SignUp> createState() => _SignUpState();
// }
//
// class _SignUpState extends State<SignUp> {
//   final _formKey = GlobalKey<FormState>();
//   bool _isLoading = false;
//
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//
//   Future<void> _registerUser() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() => _isLoading = true);
//
//     final url = Uri.parse("https://nahatasports.com/api/register");
//     final body = {
//       "name": _nameController.text.trim(),
//       "phone": _phoneController.text.trim(),
//       "email": _emailController.text.trim(),
//       "password": _passwordController.text,
//     };
//
//     try {
//       final response = await http.post(
//         url,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(body),
//       );
//
//       final data = jsonDecode(response.body);
//       debugPrint("📥 API Response: $data");
//
//       if (response.statusCode == 200 && (data["success"] == true || data["status"] == true)) {
//         _showDialog("✅ Registered", "Account created successfully.");
//       } else {
//         _showDialog("❌ Failed", data["message"] ?? "Something went wrong");
//       }
//     } catch (e) {
//       _showDialog("❌ Error", "Network or server error: $e");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _showDialog(String title, String message) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(title),
//         content: Text(message),
//         actions: [
//           TextButton(
//             child: const Text("OK"),
//             onPressed: () => Navigator.pop(context),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF5F5F5),
//         body: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Form(
//             key: _formKey,
//             child: ListView(
//               children: [
//                 const SizedBox(height: 30),
//                 const Text(
//                   "Register",
//                   style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
//                 ),
//                 const SizedBox(height: 30),
//
//                 TextFormField(
//                   controller: _nameController,
//                   decoration: const InputDecoration(labelText: "Name"),
//                   validator: (value) => value!.isEmpty ? "Enter your name" : null,
//                 ),
//                 const SizedBox(height: 15),
//
//                 TextFormField(
//                   controller: _phoneController,
//                   keyboardType: TextInputType.phone,
//                   decoration: const InputDecoration(labelText: "Phone"),
//                   validator: (value) => value!.isEmpty ? "Enter phone number" : null,
//                 ),
//                 const SizedBox(height: 15),
//
//                 TextFormField(
//                   controller: _emailController,
//                   keyboardType: TextInputType.emailAddress,
//                   decoration: const InputDecoration(labelText: "Email"),
//                   validator: (value) => value!.isEmpty ? "Enter email" : null,
//                 ),
//                 const SizedBox(height: 15),
//
//                 TextFormField(
//                   controller: _passwordController,
//                   obscureText: true,
//                   decoration: const InputDecoration(labelText: "Password"),
//                   validator: (value) =>
//                   value!.length < 6 ? "Password must be at least 6 characters" : null,
//                 ),
//                 const SizedBox(height: 30),
//
//                 ElevatedButton(
//                   onPressed: _isLoading ? null : _registerUser,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.indigo,
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                   child: _isLoading
//                       ? const CircularProgressIndicator(color: Colors.white)
//                       : const Text("Register", style: TextStyle(fontSize: 16)),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';

import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _pwdC = TextEditingController();
  final _roleC = TextEditingController();

  List<String> roles = ["Student", "Admin", "Coach", "Security"];
  String? _selectedRole;

  bool _obscurePassword = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  void showCustomSnackbar(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    bool isError = false,
  }) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: isError ? Colors.grey : Colors.grey,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    final url = Uri.parse('https://nahatasports.com/api/register');

    final Map<String, String> body = {
      'name': _nameC.text.trim(),
      'phone': _phoneC.text.trim(),
      'email': _emailC.text.trim(),
      'password': _pwdC.text.trim(),
      'role': _roleC.text.trim(),
    };

    // ✅ Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // ✅ Close the loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      final res = jsonDecode(response.body);
      print("📥 API Response: $res");

      if (res['status'] == true) {
        print("loginScreen");
        showCustomSnackbar(
          context,
          '✅ Registered successfully!',
          isError: false,
        );

        _nameC.clear();
        _phoneC.clear();
        _emailC.clear();
        _pwdC.clear();
        _roleC.clear();

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        print("Registration failed: ${res['message']}");
        showCustomSnackbar(
          context,
          res['message'] ?? "Registration failed",
          isSuccess: false,
          isError: true,
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      showCustomSnackbar(context, "Error: $e", isSuccess: false, isError: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1D2B64), Color(0xFFf8cdda)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
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
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/nahata_a.webp',
                              height: 80,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              "Full Name",
                              _nameC,
                              icon: Icons.person,
                              maxLength: 20,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Name is required";
                                }
                                if (value.length > 20) {
                                  return "Name must be under 20 characters";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              "Phone",
                              _phoneC,
                              keyboardType: TextInputType.phone,
                              icon: Icons.phone,
                              maxLength: 10,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Phone number is required";
                                }
                                if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                                  return "Enter a valid 10-digit phone number";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              "Email",
                              _emailC,
                              keyboardType: TextInputType.emailAddress,
                              icon: Icons.email,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Email is required";
                                }
                                if (!RegExp(
                                  r"^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$",
                                ).hasMatch(value)) {
                                  return "Enter a valid email";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              "Password",
                              _pwdC,
                              isPassword: true,
                              icon: Icons.lock,
                              maxLength: 10,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Password is required";
                                }
                                if (value.length < 4 || value.length > 10) {
                                  return "Password must be 4-10 characters";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              decoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.people,
                                  color: Colors.grey[700],
                                ), // same as password field
                                labelText: "Role",
                                labelStyle: TextStyle(color: Colors.grey[700]),
                                filled: true,
                                fillColor: Colors.grey[200],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              dropdownColor: Colors.white.withOpacity(0.95),
                              elevation: 4,
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey[700],
                              ), // same as password icon
                              items: roles.map((role) {
                                return DropdownMenuItem<String>(
                                  value: role,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      role,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value;
                                  _roleC.text = value ?? "";
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Role is required";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _registerUser();
                                    // ✅ All validations passed — proceed with registration
                                    print("All fields are valid");
                                    // Future.delayed(const Duration(seconds: 1));

                                    // // ✅ Navigate to LoginScreen
                                    // Navigator.pushReplacement(
                                    //     context,
                                    //     MaterialPageRoute(builder: (_) => const LoginScreen())
                                    // );
                                  } else {
                                    // ❌ Validation failed — show errors
                                    print("Validation failed. Check the form.");
                                  }
                                },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF0A198D),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  "Register",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                                print("Navigate to login screen");
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: "Already have an account? ",
                                  style: TextStyle(color: Colors.grey),
                                  children: [
                                    TextSpan(
                                      text: "Login",
                                      style: TextStyle(
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
    );
  }

  Widget _buildField(
    String label,
    TextEditingController c, {
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    int? maxLength,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      maxLength: maxLength,

      buildCounter:
          (
            context, {
            required currentLength,
            required isFocused,
            required maxLength,
          }) => null,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (label == 'Phone' && value.length != 10) return 'Enter 10 digits';
        if (label == 'Email' && !value.contains('@'))
          return 'Enter valid email';
        return null;
      },
      decoration: InputDecoration(
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
