import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final parentPhoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final referralController = TextEditingController();
  final dobController = TextEditingController();

  String? selectedGender;
  File? selectedFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickFile() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        selectedFile = File(file.path);
      });
    }
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dobController.text =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(

      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    "Register",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Create an account to continue!",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  // Upload Photo
                  const Text("Upload Photo"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Choose File"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedFile != null
                              ? selectedFile!.path.split('/').last
                              : "No file chosen",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Full Name
                  TextFormField(
                    controller: nameController,

                    decoration: _inputDecoration("Full Name"),
                    validator: (value) =>
                    value!.isEmpty ? "Full name is required" : null,
                  ),
                  const SizedBox(height: 15),

                  // Email
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration("Email"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Email is required";
                      }
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(value)) {
                        return "Enter valid email";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Phone
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    decoration: _inputDecoration("Phone Number (+91 XXXXXXXXXX)"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Phone number is required";
                      }
                      final RegExp phoneRegex = RegExp(r'^\d{10}$');
                      if (!phoneRegex.hasMatch(value)) {
                        return "Enter valid phone (e.g. +91 8888888888)";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Parent Phone (Optional)
                  TextFormField(
                    controller: parentPhoneController,


            keyboardType: TextInputType.phone,
                    decoration:
                    _inputDecoration("Parent / Guardian Contact (Optional)"),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10)
                    ],

                  ),
                  const SizedBox(height: 15),

                  // DOB
                  TextFormField(
                    controller: dobController,
                    readOnly: true,
                    decoration: _inputDecoration("Date of Birth"),
                    onTap: pickDate,
                  ),
                  const SizedBox(height: 15),

                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Gender"),
                    value: selectedGender,
                    items: ["Male", "Female", "Other"]
                        .map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedGender = value;
                      });
                    },
                  ),
                  const SizedBox(height: 15),

                  // Password
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: _inputDecoration("Password"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Password is required";
                      }
                      if (value.length < 6) {
                        return "Password must be at least 6 characters";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Confirm Password
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: _inputDecoration("Confirm Password"),
                    validator: (value) {
                      if (value != passwordController.text) {
                        return "Passwords do not match";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),

                  // Referral Code (Optional)
                  TextFormField(
                    controller: referralController,
                    decoration: _inputDecoration("Referral Code (Optional)"),
                  ),
                  const SizedBox(height: 25),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E3192),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator()),
                          );

                          try {
                            String? base64Image;
                            if (selectedFile != null) {
                              List<int> imageBytes = await selectedFile!.readAsBytes();
                              base64Image = base64Encode(imageBytes);
                            }

                            Map<String, dynamic> body = {
                              "name": nameController.text.trim(),
                              "phone": phoneController.text.trim(),
                              "parent_contact": parentPhoneController.text.trim(),
                              "email": emailController.text.trim(),
                              "password": passwordController.text,
                              "confirmPassword": confirmPasswordController.text,
                              "dob": dobController.text.trim(),
                              "gender": selectedGender ?? "",
                              "referral_code": referralController.text.trim(), // optional
                            };

                            if (base64Image != null) {
                              body["student_photo"] = "data:image/jpeg;base64,$base64Image";
                            }

                            var response = await http.post(
                              Uri.parse("https://nahatasports.com/api/register"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode(body),
                            );

                            Navigator.pop(context); // Close loading indicator

                            var responseData = jsonDecode(response.body);

                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   SnackBar(content: Text(responseData["message"] ?? "Registration complete!")),
                            // );

                            if (responseData["status"] == true) {
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              await prefs.setString('userEmail', emailController.text.trim());
                              _showInfoDialog("Registered Successfully");

                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(content: Text(responseData["message"] ?? "Registration complete!")),
                              // );
                              Future.delayed(const Duration(seconds: 2), () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                                );
                              });
                            }
                          } catch (e) {
                            Navigator.pop(context); // Close loading indicator
                            // ScaffoldMessenger.of(context).showSnackBar(
                            //   SnackBar(content: Text("Error: $e")),
                            // );
                            _showInfoDialog("Registration Failed. Please try again.");

                          }
                        }
                      },

                      child: const Text(
                        "Register",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Already have account?
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        },
                        child: const Text(
                          "Login",
                          style: TextStyle(
                              color: Color(0xFF2E3192),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // title: const Text("Hello"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 50, color:  Color(0xFF1A237E)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context); // Close dialog after 2 sec
    });
  }
}
