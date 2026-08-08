import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/navigation/role_router.dart';
import '../core/services/app_navigator.dart';
import '../models/sports_complex_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sports_complex_repository.dart';
// The per-role dashboards are reached through `RoleRouter`, not imported here.
import 'google_auth.dart';
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

  /// Show/hide state for the two password fields.
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  /// Sports complex the student registers at — mandatory.
  List<SportsComplex> _complexes = const [];
  SportsComplex? _selectedComplex;
  bool _loadingComplexes = true;

  @override
  void initState() {
    super.initState();
    _loadComplexes();
  }

  Future<void> _loadComplexes() async {
    final complexes = await SportsComplexRepository.instance.fetchComplexes();
    if (!mounted) return;
    setState(() {
      _complexes = complexes;
      _loadingComplexes = false;
    });
  }

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

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(

      labelText: label,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
  /// `POST /auth/google-login` — the same call the login screen makes; signing
  /// up with Google and signing in with Google are one endpoint.
  ///
  /// Old API (commented out below): `POST nahatasports.com/api/google_login`,
  /// which hit the legacy host, used the wrong body key and — worse — only
  /// wrote SharedPreferences flags. No access token was ever stored, so every
  /// authenticated call made after a Google sign-up would have failed with 401.
  Future<bool> _googleLoginToBackend(String idToken) =>
      ApiService.googleLogin(idToken);

  // ---------------------- OLD API (commented out) ----------------------
  // Future<bool> _googleLoginToBackend(String idToken) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse("https://nahatasports.com/api/google_login"),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({"idToken": idToken}),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //
  //       if (data["status"] == true && data["data"] != null) {
  //         final user = Map<String, dynamic>.from(data["data"]);
  //
  //         final prefs = await SharedPreferences.getInstance();
  //         await prefs.setBool('isLoggedIn', true);
  //
  //         // role may NOT come from API → avoid crash
  //         final role = user["role"]?.toString() ?? "user";
  //         await prefs.setString('role', role);
  //
  //         // save full user object
  //         await prefs.setString('user', jsonEncode(user));
  //
  //         ApiService.currentUser = user;
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
  /// Same role → screen table as the login screen, so a Google sign-up that
  /// returns an existing staff account lands on that account's own console.
  Widget _getScreenForRole(String role) => RoleRouter.screenFor(role);
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
// Google Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2E3192), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Colors.white,
                      ),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset("assets/g.png", height: 24), // Add google.png in assets
                          const SizedBox(width: 12),
                          const Text(
                            "Sign Up with Google",
                            style: TextStyle(
                              color: Color(0xFF2E3192),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
            //       const SizedBox(height: 15),
            //
            //       // Parent Phone (Optional)
            //       TextFormField(
            //         controller: parentPhoneController,
            //
            //
            // keyboardType: TextInputType.phone,
            //         decoration:
            //         _inputDecoration("Parent / Guardian Contact (Optional)"),
            //         inputFormatters: [
            //           FilteringTextInputFormatter.digitsOnly,
            //           LengthLimitingTextInputFormatter(10)
            //         ],
            //
            //       ),
                  const SizedBox(height: 15),

                  // Sports Complex (mandatory)
                  _loadingComplexes
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : DropdownButtonFormField<SportsComplex>(
                          key: const Key('sports_complex_field'),
                          decoration: _inputDecoration("Sports Complex"),
                          value: _selectedComplex,
                          isExpanded: true,
                          items: _complexes
                              .map((complex) => DropdownMenuItem(
                                    value: complex,
                                    child: Text(complex.label,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedComplex = value);
                          },
                          validator: (value) =>
                              value == null ? "Sports complex is required" : null,
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
                    obscureText: _obscurePassword,
                    decoration: _inputDecoration(
                      "Password",
                      suffixIcon: IconButton(
                        key: const Key('password_visibility'),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey,
                        ),
                        tooltip:
                            _obscurePassword ? 'Show password' : 'Hide password',
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
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
                    obscureText: _obscureConfirmPassword,
                    decoration: _inputDecoration(
                      "Confirm Password",
                      suffixIcon: IconButton(
                        key: const Key('confirm_password_visibility'),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey,
                        ),
                        tooltip: _obscureConfirmPassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Confirm your password";
                      }
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
                      onPressed: _register,

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

  /// `POST /students/register`
  ///
  /// Old API (commented out below): `POST nahatasports.com/api/register`,
  /// which used `phone`/`student_photo` and reported `status: true`.
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final complex = _selectedComplex;
    if (complex == null) {
      _showMessage(
        "Please select a sports complex",
        tone: AppMessageTone.error,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await AuthRepository.instance.register(
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      email: emailController.text.trim(),
      sportComplexId: complex.id,
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
      dob: dobController.text.trim(),
      gender: selectedGender,
      referralCode: referralController.text.trim(),
      avatarPath: selectedFile?.path,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading indicator

    if (!result.success) {
      _showMessage(
        result.firstFieldError ??
            result.message ??
            "Registration failed. Please try again.",
        tone: AppMessageTone.error,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userEmail', emailController.text.trim());

    if (!mounted) return;
    _showMessage(
      result.message ?? "Registered successfully",
      tone: AppMessageTone.success,
    );

    // Straight to the sign-in screen; the snackbar rides over it rather than
    // being popped by a timer that raced this one.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  /// The same bottom snackbar the sign-in screen uses, for the same reasons —
  /// see `_showMessage` in `login.dart`.
  void _showMessage(
    String message, {
    AppMessageTone tone = AppMessageTone.info,
  }) {
    AppNavigator.showMessage(message, tone: tone, context: context);
  }
}
