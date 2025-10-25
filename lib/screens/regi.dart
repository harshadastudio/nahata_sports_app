// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show TextInputFormatter, FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
//
// import 'login_screen.dart';
//
// class PremiumSignUpScreen extends StatefulWidget {
//   const PremiumSignUpScreen({super.key});
//
//   @override
//   State<PremiumSignUpScreen> createState() => _PremiumSignUpScreenState();
// }
//
// // class _PremiumSignUpScreenState extends State<PremiumSignUpScreen> {
// //   final _formKeyStep1 = GlobalKey<FormState>();
// //   final _formKeyStep2 = GlobalKey<FormState>();
// //   final _formKeyStep3 = GlobalKey<FormState>();
// //
// //   final ImagePicker _picker = ImagePicker();
// //   File? studentPhoto;
// //
// //   int currentStep = 0;
// //   PageController pageController = PageController();
// //
// //   // Controllers
// //   final fullNameController = TextEditingController();
// //   final emailController = TextEditingController();
// //   final mobileController = TextEditingController(text: "+91");
// //   final parentController = TextEditingController(text: "+91");
// //   final passwordController = TextEditingController();
// //   final confirmController = TextEditingController();
// //   final dobController = TextEditingController();
// //
// //   String? genderValue;
// //   String? bloodGroupValue;
// //
// //   bool isLoading = false;
// //
// //   double getProgress() => (currentStep + 1) / 3;
// //
// //   @override
// //   void dispose() {
// //     pageController.dispose();
// //     fullNameController.dispose();
// //     emailController.dispose();
// //     mobileController.dispose();
// //     parentController.dispose();
// //     passwordController.dispose();
// //     confirmController.dispose();
// //     dobController.dispose();
// //     super.dispose();
// //   }
// //
// //   Future<void> pickImage(ImageSource source) async {
// //     try {
// //       final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
// //       if (image != null) {
// //         final bytes = await image.readAsBytes();
// //         if (bytes.lengthInBytes > 1024 * 1024) {
// //           ScaffoldMessenger.of(context).showSnackBar(
// //             const SnackBar(content: Text("Image must be less than 1 MB")),
// //           );
// //           return;
// //         }
// //         setState(() => studentPhoto = File(image.path));
// //       }
// //     } catch (e) {
// //       print("Image pick failed: $e");
// //     }
// //   }
// //
// //   void nextStep() {
// //     if (currentStep == 0) {
// //       if (!_formKeyStep1.currentState!.validate()) return;
// //     } else if (currentStep == 1) {
// //       if (!_formKeyStep2.currentState!.validate()) return;
// //     }
// //
// //     if (currentStep < 2) {
// //       setState(() => currentStep += 1);
// //       pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
// //     }
// //   }
// //
// //   void previousStep() {
// //     if (currentStep > 0) {
// //       setState(() => currentStep -= 1);
// //       pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
// //     }
// //   }
// //
// //   Future<void> submitForm() async {
// //     if (!_formKeyStep3.currentState!.validate()) return;
// //     if (studentPhoto == null) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Please select a student photo")),
// //       );
// //       return;
// //     }
// //
// //     setState(() => isLoading = true);
// //
// //     try {
// //       var uri = Uri.parse("https://nahatasports.com/api/register");
// //       List<int> imageBytes = await studentPhoto!.readAsBytes();
// //       String base64Image = base64Encode(imageBytes);
// //
// //       var body = {
// //         "name": fullNameController.text.trim(),
// //         "dob": dobController.text.trim(),
// //         "blood_group": bloodGroupValue,
// //         "gender": genderValue,
// //         "phone": mobileController.text.trim(),
// //         "parent_contact": parentController.text.trim(),
// //         "email": emailController.text.trim(),
// //         "password": passwordController.text,
// //         "confirmPassword": confirmController.text,
// //         "student_photo": base64Image,
// //       };
// //
// //       var response = await http.post(
// //         uri,
// //         headers: {"Content-Type": "application/json"},
// //         body: jsonEncode(body),
// //       );
// //
// //       setState(() => isLoading = false);
// //
// //       if (response.statusCode == 200) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text("Registration successful!")),
// //         );
// //         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
// //         print(response.body);
// //       } else {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text("Registration failed: ${response.body}")),
// //         );
// //       }
// //     } catch (e) {
// //       setState(() => isLoading = false);
// //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     double padding = MediaQuery.of(context).size.width < 600 ? 16 : 40;
// //     return Scaffold(
// //       body: SafeArea(
// //         child: Padding(
// //           padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.stretch,
// //             children: [
// //               LinearProgressIndicator(
// //                 value: getProgress(),
// //                 minHeight: 6,
// //                 backgroundColor: Colors.grey[300],
// //                 color: Colors.blue,
// //               ),
// //               const SizedBox(height: 20),
// //               Expanded(
// //                 child: PageView(
// //                   controller: pageController,
// //                   physics: const NeverScrollableScrollPhysics(),
// //                   children: [step1(), step2(), step3()],
// //                 ),
// //               ),
// //               const SizedBox(height: 20),
// //               isLoading
// //                   ? const Center(child: CircularProgressIndicator())
// //                   : ElevatedButton(
// //                 onPressed: currentStep < 2 ? nextStep : submitForm,
// //                 style: ElevatedButton.styleFrom(
// //                   padding: const EdgeInsets.symmetric(vertical: 16),
// //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
// //                   backgroundColor: Colors.blue,
// //                 ),
// //                 child: Text(
// //                   currentStep < 2 ? "Next" : "Register",
// //                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
// //                 ),
// //               ),
// //               if (currentStep > 0)
// //                 TextButton(
// //                   onPressed: previousStep,
// //                   child: const Text("Back", style: TextStyle(color: Colors.black54)),
// //                 ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget step1() {
// //     return SingleChildScrollView(
// //       child: Form(
// //         key: _formKeyStep1,
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             const SizedBox(height: 20),
// //             const Text("Hi 👋", style: TextStyle(fontSize: 22)),
// //             const SizedBox(height: 6),
// //             const Text("Welcome to Nahata Sports", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 20),
// //             // GestureDetector(
// //             //   onTap: () => pickImage(ImageSource.gallery),
// //             //   child: CircleAvatar(
// //             //     radius: 60,
// //             //     backgroundColor: Colors.grey[200],
// //             //     backgroundImage: studentPhoto != null ? FileImage(studentPhoto!) : null,
// //             //     child: studentPhoto == null ? Icon(Icons.person, size: 60, color: Colors.grey[600]) : null,
// //             //   ),
// //             // ),
// //             GestureDetector(
// //               onTap: () async {
// //                 try {
// //                   final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
// //                   if (image != null) {
// //                     final bytes = await image.readAsBytes();
// //                     if (bytes.lengthInBytes > 1024 * 1024) { // 1 MB
// //                       ScaffoldMessenger.of(context).showSnackBar(
// //                         const SnackBar(content: Text("Image must be less than 1 MB")),
// //                       );
// //                       return;
// //                     }
// //                     setState(() => studentPhoto = File(image.path));
// //                   }
// //                 } catch (e) {
// //                   ScaffoldMessenger.of(context).showSnackBar(
// //                     SnackBar(content: Text("Error picking image: $e")),
// //                   );
// //                 }
// //               },
// //               child: CircleAvatar(
// //                 radius: 60,
// //                 backgroundColor: Colors.grey[200],
// //                 backgroundImage: studentPhoto != null ? FileImage(studentPhoto!) : null,
// //                 child: studentPhoto == null ? Icon(Icons.person, size: 60, color: Colors.grey[600]) : null,
// //               ),
// //             ),
// //
// //             const SizedBox(height: 20),
// //             // buildInputField(fullNameController, "Full Name", "Enter full name", icon: Icons.person),
// //             buildInputField(
// //               fullNameController,
// //               "Full Name",
// //               "Enter full name",
// //               icon: Icons.person,
// //               validatorOverride: (val) {
// //                 if (val == null || val.trim().isEmpty) return "Full Name is required";
// //                 if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(val.trim())) return "Only letters and spaces allowed";
// //                 if (val.trim().length < 4) return "Full Name too short";
// //                 if (val.trim().length > 30) return "Full Name too long";
// //                 return null;
// //               },
// //             ),
// //
// //             buildDropdownField("Gender", ["Male", "Female", "Other"], (val) => genderValue = val),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget step2() {
// //     return SingleChildScrollView(
// //       child: Form(
// //         key: _formKeyStep2,
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             const Text("Personal Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 20),
// //             buildDatePickerField("Date of Birth", dobController, context),
// //             buildDropdownField("Blood Group", ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"], (val) => bloodGroupValue = val),
// //             buildInputField(
// //               mobileController,
// //               "Mobile Number",
// //               "Enter mobile number",
// //               keyboardType: TextInputType.number,
// //               inputFormatters: [
// //                 FilteringTextInputFormatter.digitsOnly,
// //                 LengthLimitingTextInputFormatter(10), // only 10 digits after +91
// //               ],
// //               onChanged: (val) {
// //                 if (!mobileController.text.startsWith("+91")) {
// //                   mobileController.text = "+91";
// //                   mobileController.selection = TextSelection.fromPosition(TextPosition(offset: mobileController.text.length));
// //                 }
// //               },
// //               validatorOverride: (val) {
// //                 if (val == null || val.trim().isEmpty) return "Mobile number is required";
// //                 if (!val.startsWith("+91")) return "Mobile number must start with +91";
// //                 String digits = val.replaceAll("+91", "").trim();
// //                 if (digits.length != 10) return "Enter 10 digits after +91";
// //                 return null;
// //               },
// //             ),
// //
// //             buildInputField(
// //               parentController,
// //               "Parent / Guardian Contact",
// //               "Enter parent number",
// //               keyboardType: TextInputType.number,
// //               inputFormatters: [
// //                 FilteringTextInputFormatter.digitsOnly,
// //                 LengthLimitingTextInputFormatter(10),
// //               ],
// //               onChanged: (val) {
// //                 if (!parentController.text.startsWith("+91")) {
// //                   parentController.text = "+91";
// //                   parentController.selection = TextSelection.fromPosition(TextPosition(offset: parentController.text.length));
// //                 }
// //               },
// //               validatorOverride: (val) {
// //                 if (val == null || val.trim().isEmpty) return "Parent number is required";
// //                 if (!val.startsWith("+91")) return "Number must start with +91";
// //                 String digits = val.replaceAll("+91", "").trim();
// //                 if (digits.length != 10) return "Enter 10 digits after +91";
// //                 return null;
// //               },
// //             ),
// //
// //
// //             // buildInputField(mobileController, "Mobile Number", "Enter mobile number", keyboardType: TextInputType.phone),
// //             // buildInputField(parentController, "Parent / Guardian Contact", "Enter parent number", keyboardType: TextInputType.phone),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget step3() {
// //     return SingleChildScrollView(
// //       child: Form(
// //         key: _formKeyStep3,
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             const Text("Account Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 20),
// //             buildInputField(emailController, "Email Address", "Enter email", keyboardType: TextInputType.emailAddress, isEmail: true),
// //             // buildInputField(passwordController, "Password", "Enter password", obscureText: true),
// //             buildInputField(
// //               passwordController,
// //               "Password",
// //               "Enter password",
// //               obscureText: true,
// //               validatorOverride: (val) {
// //                 if (val == null || val.isEmpty) return "Password is required";
// //                 if (val.length < 10) return "Password must be at least 10 characters";
// //                 if (!RegExp(r'[A-Z]').hasMatch(val)) return "Password must have at least one uppercase letter";
// //                 if (!RegExp(r'[a-z]').hasMatch(val)) return "Password must have at least one lowercase letter";
// //                 if (!RegExp(r'[0-9]').hasMatch(val)) return "Password must have at least one number";
// //                 if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(val)) return "Password must have at least one special character";
// //                 if (val.contains(' ')) return "Password cannot contain spaces";
// //                 return null;
// //               },
// //             ),
// //
// //             // buildInputField(confirmController, "Confirm Password", "Confirm password", obscureText: true),
// //             buildInputField(
// //               confirmController,
// //               "Confirm Password",
// //               "Confirm password",
// //               obscureText: true,
// //               validatorOverride: (val) {
// //                 if (val == null || val.isEmpty) return "Confirm your password";
// //                 if (val != passwordController.text) return "Passwords do not match";
// //                 return null;
// //               },
// //             ),
// //
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget buildInputField(TextEditingController controller,
// //       String label,
// //       String hint,
// //       {bool obscureText = false,
// //         TextInputType keyboardType = TextInputType.text,
// //         IconData? icon,
// //         bool isEmail = false,
// //       String? Function(String?)? validatorOverride,
// //         // optional custom validator
// //         List<TextInputFormatter>? inputFormatters,  void Function(String)? onChanged, // optional input formatters
// //       }
// //       ) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 8),
// //       child: TextFormField(
// //         controller: controller,
// //         obscureText: obscureText,
// //         keyboardType: keyboardType,
// //         validator: (val) {
// //           if (val == null || val.isEmpty) return "Required";
// //           if (isEmail && !RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$").hasMatch(val)) {
// //             return "Invalid email";
// //           }
// //           return null;
// //         },
// //         decoration: InputDecoration(
// //           labelText: label,
// //           hintText: hint,
// //           prefixIcon: icon != null ? Icon(icon) : null,
// //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
// //           filled: true,
// //           fillColor: Colors.white,
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget buildDropdownField(String label, List<String> items, Function(String?) onChanged) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 8),
// //       child: DropdownButtonFormField<String>(
// //         validator: (val) => val == null || val.isEmpty ? "Required" : null,
// //         decoration: InputDecoration(
// //           labelText: label,
// //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
// //           filled: true,
// //           fillColor: Colors.white,
// //         ),
// //         items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
// //         onChanged: onChanged,
// //       ),
// //     );
// //   }
// //
// //   Widget buildDatePickerField(String label, TextEditingController controller, BuildContext context) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 8),
// //       child: TextFormField(
// //         controller: controller,
// //         readOnly: true,
// //         validator: (val) => val == null || val.isEmpty ? "Required" : null,
// //         decoration: InputDecoration(
// //           labelText: label,
// //           hintText: "yyyy/mm/dd",
// //           suffixIcon: const Icon(Icons.calendar_today),
// //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
// //           filled: true,
// //           fillColor: Colors.white,
// //         ),
// //         onTap: () async {
// //           DateTime? pickedDate = await showDatePicker(
// //             context: context,
// //             initialDate: DateTime(2005),
// //             firstDate: DateTime(1990),
// //             lastDate: DateTime.now(),
// //           );
// //           if (pickedDate != null) {
// //             String formattedDate = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
// //             controller.text = formattedDate;
// //           }
// //         },
// //       ),
// //     );
// //   }
// // }
//
// class _PremiumSignUpScreenState extends State<PremiumSignUpScreen> {
//   final _formKeyStep1 = GlobalKey<FormState>();
//   final _formKeyStep2 = GlobalKey<FormState>();
//   final _formKeyStep3 = GlobalKey<FormState>();
//
//   final ImagePicker _picker = ImagePicker();
//   File? studentPhoto;
//
//   int currentStep = 0;
//   PageController pageController = PageController();
//
//   // Controllers
//   final fullNameController = TextEditingController();
//   final emailController = TextEditingController();
//   final mobileController = TextEditingController();
//   final parentController = TextEditingController();
//   final passwordController = TextEditingController();
//   final confirmController = TextEditingController();
//   final dobController = TextEditingController();
//   final referralController = TextEditingController();
//   final passcodeController = TextEditingController(); // ✅ NEW FIELD
//
//   String? genderValue;
//   String? bloodGroupValue;
//
//   bool isLoading = false;
//
//   double getProgress() => (currentStep + 1) / 3;
//
//   @override
//   void dispose() {
//     pageController.dispose();
//     fullNameController.dispose();
//     emailController.dispose();
//     mobileController.dispose();
//     parentController.dispose();
//     passwordController.dispose();
//     confirmController.dispose();
//     dobController.dispose();
//     referralController.dispose();
//     passcodeController.dispose();
//     super.dispose();
//   }
//   // Future<void> submitForm() async {
//   //   setState(() => isLoading = true);
//   //   if (!_formKeyStep3.currentState!.validate()) return; // ✅ Final validation
//   //
//   //   try {
//   //     var uri = Uri.parse("https://nahatasports.com/api/register");
//   //     String? base64Image;
//   //     if (studentPhoto != null) {
//   //       List<int> imageBytes = await studentPhoto!.readAsBytes();
//   //       base64Image = base64Encode(imageBytes);
//   //     }
//   //
//   //     Map<String, dynamic> body = {};
//   //
//   //     if (base64Image != null) body["student_photo"] = "data:image/jpeg;base64,$base64Image";
//   //     if (fullNameController.text.trim().isNotEmpty) body["name"] = fullNameController.text.trim();
//   //     if (dobController.text.trim().isNotEmpty) body["dob"] = dobController.text.trim();
//   //     if (bloodGroupValue != null && bloodGroupValue!.isNotEmpty) body["blood_group"] = bloodGroupValue;
//   //     if (genderValue != null && genderValue!.isNotEmpty) body["gender"] = genderValue;
//   //     if (mobileController.text.trim().isNotEmpty) body["phone"] = mobileController.text.trim();
//   //     if (parentController.text.trim().isNotEmpty) body["parent_contact"] = parentController.text.trim();
//   //     if (emailController.text.trim().isNotEmpty) body["email"] = emailController.text.trim();
//   //     if (passwordController.text.isNotEmpty) body["password"] = passwordController.text;
//   //     if (confirmController.text.isNotEmpty) body["confirmPassword"] = confirmController.text;
//   //
//   //     // ✅ Add referral code only if not empty
//   //     body["referral_code"] = referralController.text.trim().isNotEmpty
//   //         ? referralController.text.trim()
//   //         : "";
//   //
//   //
//   //     // ✅ Add passcode only if not empty
//   //     // ✅ Always include passcode (even if blank)
//   //     body["passcode"] = passcodeController.text.trim().isNotEmpty
//   //         ? passcodeController.text.trim()
//   //         : "";
//   //
//   //
//   //     var response = await http.post(
//   //       uri,
//   //       headers: {"Content-Type": "application/json"},
//   //       body: jsonEncode(body),
//   //     );
//   //
//   //     setState(() => isLoading = false);
//   //
//   //     print("📤 Registration Body: $body");
//   //     print("📥 Response: ${response.body}");
//   //
//   //     if (response.statusCode == 200) {
//   //       var responseData = jsonDecode(response.body);
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         SnackBar(content: Text(responseData["message"] ?? "Registration complete!")),
//   //       );
//   //
//   //       if (responseData["status"] == true) {
//   //         Navigator.pushReplacement(
//   //           context,
//   //           MaterialPageRoute(builder: (_) => const LoginScreen()),
//   //         );
//   //       }
//   //     } else {
//   //       ScaffoldMessenger.of(context).showSnackBar(
//   //         SnackBar(content: Text("Registration failed: ${response.body}")),
//   //       );
//   //     }
//   //   } catch (e) {
//   //     setState(() => isLoading = false);
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(content: Text("Error: $e")),
//   //     );
//   //   }
//   // }
//   bool validateSteps() {
//     bool step1Valid = _formKeyStep1.currentState?.validate() ?? false;
//     bool step2Valid = _formKeyStep2.currentState?.validate() ?? false;
//     bool step3Valid = _formKeyStep3.currentState?.validate() ?? false;
//
//     return step1Valid && step2Valid && step3Valid;
//   }
//
//   Future<void> submitForm() async {
//     if (!validateSteps()) return; // only required fields block submission
//
//     setState(() => isLoading = true);
//
//     try {
//       var uri = Uri.parse("https://nahatasports.com/api/register");
//
//       String? base64Image;
//       if (studentPhoto != null) {
//         List<int> imageBytes = await studentPhoto!.readAsBytes();
//         base64Image = base64Encode(imageBytes);
//       }
//
//       Map<String, dynamic> body = {
//         "name": fullNameController.text.trim(),
//         "phone": mobileController.text.trim(),
//         "parent_contact": parentController.text.trim(),
//         "email": emailController.text.trim(),
//         "password": passwordController.text,
//         "confirmPassword": confirmController.text,
//         "dob": dobController.text.trim(),
//         "blood_group": bloodGroupValue ?? "",
//         "gender": genderValue ?? "",
//         "referral_code": referralController.text.trim(), // optional
//         "passcode": passcodeController.text.trim(),     // optional
//       };
//
//       if (base64Image != null) {
//         body["student_photo"] = "data:image/jpeg;base64,$base64Image";
//       }
//
//       var response = await http.post(
//         uri,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(body),
//       );
//
//       if (!mounted) return;
//       setState(() => isLoading = false);
//
//       var responseData = jsonDecode(response.body);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(responseData["message"] ?? "Registration complete!")),
//       );
//
//       if (responseData["status"] == true) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const LoginScreen()),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: $e")),
//       );
//     }
//   }
//
//
// //   Future<void> submitForm() async {
// //     setState(() => isLoading = true);
// //
// //     try {
// //       var uri = Uri.parse("https://nahatasports.com/api/register");
// //       String? base64Image;
// //       if (studentPhoto != null) {
// //         List<int> imageBytes = await studentPhoto!.readAsBytes();
// //         base64Image = base64Encode(imageBytes);
// //       }
// //
// //       Map<String, dynamic> body = {};
// //
// //       if (base64Image != null) body["student_photo"] = "data:image/jpeg;base64,$base64Image";
// //       if (fullNameController.text.trim().isNotEmpty) body["name"] = fullNameController.text.trim();
// //       if (dobController.text.trim().isNotEmpty) body["dob"] = dobController.text.trim();
// //       if (bloodGroupValue != null && bloodGroupValue!.isNotEmpty) body["blood_group"] = bloodGroupValue;
// //       if (genderValue != null && genderValue!.isNotEmpty) body["gender"] = genderValue;
// //       if (mobileController.text.trim().isNotEmpty) body["phone"] = mobileController.text.trim();
// //       if (parentController.text.trim().isNotEmpty) body["parent_contact"] = parentController.text.trim();
// //       if (emailController.text.trim().isNotEmpty) body["email"] = emailController.text.trim();
// //       if (passwordController.text.isNotEmpty) body["password"] = passwordController.text;
// //       if (confirmController.text.isNotEmpty) body["confirmPassword"] = confirmController.text;
// //       if (referralController.text.trim().isNotEmpty) body["referral_code"] = referralController.text.trim();
// //
// //       // ✅ Optional Passcode added
// //       if (passcodeController.text.trim().isNotEmpty) {
// //         body["passcode"] = passcodeController.text.trim();
// //       }
// //
// //       var response = await http.post(
// //         uri,
// //         headers: {"Content-Type": "application/json"},
// //         body: jsonEncode(body),
// //       );
// //
// //       setState(() => isLoading = false);
// // print(body);
// //       if (response.statusCode == 200) {
// //         var responseData = jsonDecode(response.body);
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text(responseData["message"] ?? "Registration complete!")),
// //         );
// //
// //         if (responseData["status"] == true) {
// //           Navigator.pushReplacement(
// //             context,
// //             MaterialPageRoute(builder: (_) => const LoginScreen()),
// //           );
// //         }
// //       } else {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text("Registration failed: ${response.body}")),
// //         );
// //       }
// //     } catch (e) {
// //       setState(() => isLoading = false);
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text("Error: $e")),
// //       );
// //     }
// //   }
//
//   Future<void> pickImage(ImageSource source) async {
//     try {
//       final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
//       if (image != null) {
//         setState(() => studentPhoto = File(image.path));
//       }
//     } catch (e) {
//       print("Image pick failed: $e");
//     }
//   }
//   void nextStep() {
//     GlobalKey<FormState> currentForm;
//     if (currentStep == 0) currentForm = _formKeyStep1;
//     else if (currentStep == 1) currentForm = _formKeyStep2;
//     else currentForm = _formKeyStep3;
//
//     if (currentForm.currentState!.validate()) {
//       if (currentStep < 2) {
//         setState(() => currentStep += 1);
//         pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
//       }
//     }
//   }
//   // void nextStep() {
//   //   if (currentStep < 2) {
//   //     setState(() => currentStep += 1);
//   //     pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
//   //   }
//   // }
//
//   void previousStep() {
//     if (currentStep > 0) {
//       setState(() => currentStep -= 1);
//       pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     double padding = MediaQuery.of(context).size.width < 600 ? 16 : 40;
//     return Scaffold(
//       body: SafeArea(
//         child: Padding(
//           padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               LinearProgressIndicator(
//                 value: getProgress(),
//                 minHeight: 6,
//                 backgroundColor: Colors.grey[300],
//                 color: const Color(0xFF0A198D),
//               ),
//               const SizedBox(height: 20),
//               Expanded(
//                 child: PageView(
//                   controller: pageController,
//                   physics: const NeverScrollableScrollPhysics(),
//                   children: [step1(), step2(), step3()],
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   ConstrainedBox(
//                     constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
//                     child: isLoading
//                         ? const Center(child: CircularProgressIndicator())
//                         :  AnimatedButton(
//                       onPressed: () {
//                         if (currentStep < 2) nextStep();
//                         else submitForm();
//                       },
//                       text: currentStep < 2 ? "Next" : "Register",
//                     ),
//       ),
//
//                   const SizedBox(height: 12),
//                   if (currentStep > 0)
//                     ConstrainedBox(
//                       constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
//                       child: AnimatedButton(
//                         onPressed: previousStep,
//                         text: "Back",
//                         isPrimary: false,
//                       ),
//                     ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Step 1
//   Widget step1() {
//     return SingleChildScrollView(
//       child: Form(
//         key: _formKeyStep1,
//         child: Column(
//           children: [
//             const SizedBox(height: 20),
//             const Text("Hi 👋", style: TextStyle(fontSize: 22)),
//             const SizedBox(height: 6),
//             const Text("Welcome to Nahata Sports", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 20),
//             GestureDetector(
//               onTap: () => pickImage(ImageSource.gallery),
//               child: Stack(
//                 children: [
//                   CircleAvatar(
//                     radius: 60,
//                     backgroundColor: Colors.grey[200],
//                     backgroundImage: studentPhoto != null ? FileImage(studentPhoto!) : null,
//                     child: studentPhoto == null
//                         ? Icon(Icons.person, size: 60, color: Colors.grey[600])
//                         : null,
//                   ),
//                   Positioned(
//                     bottom: 0,
//                     right: 0,
//                     child: Container(
//                       padding: const EdgeInsets.all(2),
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.white,
//                         border: Border.all(color: Colors.grey[400]!, width: 2),
//                       ),
//                       child: Icon(Icons.add, size: 24, color: Colors.grey[600]),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 20),
//             buildInputField(
//               fullNameController,
//               "Full Name",
//               "Enter full name",
//               validator: (value) {
//                 if (value == null || value.trim().isEmpty) {
//                   return "Full Name is required";
//                 }
//                 return null;
//               },
//             ),
//             buildDropdownField("Gender", ["Male", "Female", "Other"], (val) => genderValue = val),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Step 2
//   Widget step2() {
//     return SingleChildScrollView(
//       child: Form(
//         key: _formKeyStep2,
//         child: Column(
//           children: [
//             const Text("Personal Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 20),
//             buildDatePickerField("Date of Birth", dobController, context),
//             buildDropdownField("Blood Group", ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"], (val) => bloodGroupValue = val),
//
//             buildInputField(
//               mobileController,
//               "Mobile Number",
//               "Enter 10-digit number",
//               keyboardType: TextInputType.number,
//               inputFormatters: [
//                 FilteringTextInputFormatter.digitsOnly,
//                 LengthLimitingTextInputFormatter(10),
//               ],
//               validator: (val) {
//                 if (val == null || val.trim().isEmpty) {
//                   return "Mobile number is required";
//                 }
//                 if (val.length != 10) {
//                   return "Enter exactly 10 digits";
//                 }
//                 return null;
//               },
//               prefix: Padding(
//                 padding: const EdgeInsets.only(left: 12, right: 6),
//                 child: Text(
//                   "+91",
//                   style: TextStyle(fontSize: 16, color: Colors.black),
//                 ),
//               ),
//             ),
//
//
//             buildInputField(
//               parentController,
//               "Parent / Guardian Contact",
//               "Enter parent number",
//               keyboardType: TextInputType.number,
//               inputFormatters: [
//                 FilteringTextInputFormatter.digitsOnly,
//                 LengthLimitingTextInputFormatter(10),
//               ],
//               validator: (value) {
//                 if (value != null && value.trim().isNotEmpty && value.trim().length != 10) {
//                   return "Enter a valid 10-digit parent contact number";
//                 }
//                 return null;
//               },
//               prefix: Padding(
//                 padding: const EdgeInsets.only(left: 12, right: 6),
//                 child: Text(
//                   "+91",
//                   style: TextStyle(fontSize: 16, color: Colors.black),
//                 ),
//               ),
//             ),
//
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Step 3
//   Widget step3() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.only(bottom: 80), // ✅ ensures no overlap with button
//         child: Form(
//           key: _formKeyStep3,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 "Account Details",
//                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 20),
//
//               // ✅ Email
//               buildInputField(
//                 emailController,
//                 "Email Address",
//                 "Enter email",
//                 keyboardType: TextInputType.emailAddress,
//                 validator: (value) {
//                   if (value == null || value.trim().isEmpty) {
//                     return "Email is required";
//                   }
//                   if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
//                     return "Enter a valid email";
//                   }
//                   return null;
//                 },
//               ),
//
//               // ✅ Password
//               buildInputField(
//                 passwordController,
//                 "Password",
//                 "Enter password",
//                 obscureText: true,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Password is required";
//                   }
//                   if (value.length < 6) {
//                     return "Password must be at least 6 characters";
//                   }
//                   return null;
//                 },
//               ),
//
//               // ✅ Confirm Password with validation
//               buildInputField(
//                 confirmController,
//                 "Confirm Password",
//                 "Confirm password",
//                 obscureText: true,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Please confirm your password";
//                   }
//                   if (value != passwordController.text) {
//                     return "Passwords do not match";
//                   }
//                   return null;
//                 },
//               ),
//
//               const SizedBox(height: 20),
//
//               // ✅ Optional Fields
//               // buildInputField(
//               //   referralController,
//               //   "Referral Code (Optional)",
//               //   "Enter referral code",
//               // ),
//               buildInputField(
//                 passcodeController,
//                 "Passcode (Optional)",
//                 "Enter passcode",
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   Widget buildInputField(
//       TextEditingController controller,
//       String label,
//       String hint, {
//         bool obscureText = false,
//         TextInputType keyboardType = TextInputType.text,
//         IconData? icon,
//         List<TextInputFormatter>? inputFormatters,
//         void Function(String)? onChanged,
//         String? Function(String?)? validator,
//         Widget? prefix, // 👈 Add this for "+91"
//       }) {
//     final obscureNotifier = ValueNotifier<bool>(obscureText);
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: ValueListenableBuilder<bool>(
//         valueListenable: obscureNotifier,
//         builder: (context, _obscure, child) {
//           return TextFormField(
//             controller: controller,
//             obscureText: _obscure,
//             keyboardType: keyboardType,
//             inputFormatters: inputFormatters,
//             onChanged: onChanged,
//             validator: validator,
//             decoration: InputDecoration(
//               labelText: label,
//               hintText: hint,
//               prefixIcon: icon != null ? Icon(icon) : null,
//               prefix: prefix, // 👈 Support for prefix text
//               suffixIcon: obscureText
//                   ? IconButton(
//                 icon: Icon(
//                   _obscure ? Icons.visibility : Icons.visibility_off,
//                 ),
//                 onPressed: () => obscureNotifier.value = !_obscure,
//               )
//                   : null,
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(16),
//                 borderSide: BorderSide.none,
//               ),
//               filled: true,
//               fillColor: Colors.white,
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//
//
//   Widget buildDropdownField(String label, List<String> items, Function(String?) onChanged) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: DropdownButtonFormField<String>(
//         validator: (_) => null,
//         decoration: InputDecoration(
//           labelText: label,
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
//           filled: true,
//           fillColor: Colors.white,
//         ),
//         items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
//         onChanged: onChanged,
//       ),
//     );
//   }
//
//   Widget buildDatePickerField(String label, TextEditingController controller, BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: TextFormField(
//         controller: controller,
//         readOnly: true,
//         validator: (_) => null,
//         decoration: InputDecoration(
//           labelText: label,
//           hintText: "yyyy/mm/dd",
//           suffixIcon: const Icon(Icons.calendar_today),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
//           filled: true,
//           fillColor: Colors.white,
//         ),
//         onTap: () async {
//           DateTime? pickedDate = await showDatePicker(
//             context: context,
//             initialDate: DateTime.now(),
//             firstDate: DateTime(1970),
//             lastDate: DateTime.now(),
//           );
//           if (pickedDate != null) {
//             controller.text = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
//           }
//
//         },
//       ),
//     );
//   }
// }
// // Dummy AnimatedButton & LoginScreen for completeness
// // class AnimatedButton extends StatelessWidget {
// //   final void Function() onPressed;
// //   final String text;
// //   final bool isPrimary;
// //   const AnimatedButton({super.key, required this.onPressed, required this.text, this.isPrimary = true});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return ElevatedButton(
// //       onPressed: onPressed,
// //       style: ElevatedButton.styleFrom(
// //         backgroundColor: isPrimary ? Color(0xFF0A198D) : Colors.grey,
// //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
// //         padding: const EdgeInsets.symmetric(vertical: 16),
// //       ),
// //       child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //     );
// //   }
// // }
//
//
//
//
//
//
// // class _PremiumSignUpScreenState extends State<PremiumSignUpScreen> {
// //   final _formKeyStep1 = GlobalKey<FormState>();
// //   final _formKeyStep2 = GlobalKey<FormState>();
// //   final _formKeyStep3 = GlobalKey<FormState>();
// //
// //   final ImagePicker _picker = ImagePicker();
// //   File? studentPhoto;
// //
// //   int currentStep = 0;
// //   PageController pageController = PageController();
// //
// //   // Controllers
// //   final fullNameController = TextEditingController();
// //   final emailController = TextEditingController();
// //   final mobileController = TextEditingController(text: "+91");
// //   final parentController = TextEditingController(text: "+91");
// //   final passwordController = TextEditingController();
// //   final confirmController = TextEditingController();
// //   final dobController = TextEditingController();
// //   final referralController = TextEditingController();
// //
// //   String? genderValue;
// //   String? bloodGroupValue;
// //
// //   bool isLoading = false;
// //
// //   double getProgress() => (currentStep + 1) / 3;
// //
// //   @override
// //   void dispose() {
// //     pageController.dispose();
// //     fullNameController.dispose();
// //     emailController.dispose();
// //     mobileController.dispose();
// //     parentController.dispose();
// //     passwordController.dispose();
// //     confirmController.dispose();
// //     dobController.dispose();
// //     referralController.dispose();
// //
// //     super.dispose();
// //   }
// //
// //   Future<void> submitForm() async {
// //     setState(() => isLoading = true);
// //     if (!_formKeyStep3.currentState!.validate()) return; // ✅ Final validation
// //
// //     try {
// //       var uri = Uri.parse("https://nahatasports.com/api/register");
// //       String? base64Image;
// //       if (studentPhoto != null) {
// //         List<int> imageBytes = await studentPhoto!.readAsBytes();
// //         base64Image = base64Encode(imageBytes);
// //       }
// //
// //       Map<String, dynamic> body = {};
// //
// //       if (base64Image != null) body["student_photo"] = "data:image/jpeg;base64,$base64Image";
// //       if (fullNameController.text.trim().isNotEmpty) body["name"] = fullNameController.text.trim();
// //       if (dobController.text.trim().isNotEmpty) body["dob"] = dobController.text.trim();
// //       if (bloodGroupValue != null && bloodGroupValue!.isNotEmpty) body["blood_group"] = bloodGroupValue;
// //       if (genderValue != null && genderValue!.isNotEmpty) body["gender"] = genderValue;
// //       if (mobileController.text.trim().isNotEmpty) body["phone"] = mobileController.text.trim();
// //       if (parentController.text.trim().isNotEmpty) body["parent_contact"] = parentController.text.trim();
// //       if (emailController.text.trim().isNotEmpty) body["email"] = emailController.text.trim();
// //       if (passwordController.text.isNotEmpty) body["password"] = passwordController.text;
// //       if (confirmController.text.isNotEmpty) body["confirmPassword"] = confirmController.text;
// //       if (referralController.text.trim().isNotEmpty) body["referral_code"] = referralController.text.trim();
// //
// //       var response = await http.post(
// //         uri,
// //         headers: {"Content-Type": "application/json"},
// //         body: jsonEncode(body),
// //       );
// //
// //       setState(() => isLoading = false);
// //
// //       if (response.statusCode == 200) {
// //         var responseData = jsonDecode(response.body);
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text(responseData["message"] ?? "Registration complete!")),
// //         );
// //
// //         if (responseData["status"] == true) {
// //           Navigator.pushReplacement(
// //             context,
// //             MaterialPageRoute(builder: (_) => const LoginScreen()),
// //           );
// //         }
// //       } else {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(content: Text("Registration failed: ${response.body}")),
// //         );
// //       }
// //     } catch (e) {
// //       setState(() => isLoading = false);
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text("Error: $e")),
// //       );
// //     }
// //   }
// //
// //   Future<void> pickImage(ImageSource source) async {
// //     try {
// //       final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
// //       if (image != null) {
// //         setState(() => studentPhoto = File(image.path));
// //       }
// //     } catch (e) {
// //       print("Image pick failed: $e");
// //     }
// //   }
// //
// //   void nextStep() {
// //     GlobalKey<FormState> currentForm;
// //     if (currentStep == 0) currentForm = _formKeyStep1;
// //     else if (currentStep == 1) currentForm = _formKeyStep2;
// //     else currentForm = _formKeyStep3;
// //
// //     if (currentForm.currentState!.validate()) {
// //       if (currentStep < 2) {
// //         setState(() => currentStep += 1);
// //         pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
// //       }
// //     }
// //   }
// //   // void nextStep() {
// //   //   if (currentStep < 2) {
// //   //     setState(() => currentStep += 1);
// //   //     pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
// //   //   }
// //   // }
// //
// //   void previousStep() {
// //     if (currentStep > 0) {
// //       setState(() => currentStep -= 1);
// //       pageController.previousPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     double padding = MediaQuery.of(context).size.width < 600 ? 16 : 40;
// //     return Scaffold(
// //       body: SafeArea(
// //         child: Padding(
// //           padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.stretch,
// //             children: [
// //               LinearProgressIndicator(
// //                 value: getProgress(),
// //                 minHeight: 6,
// //                 backgroundColor: Colors.grey[300],
// //                 color: Color(0xFF0A198D),
// //               ),
// //               const SizedBox(height: 20),
// //               Expanded(
// //                 child: PageView(
// //                   controller: pageController,
// //                   physics: const NeverScrollableScrollPhysics(),
// //                   children: [step1(), step2(), step3()],
// //                 ),
// //               ),
// //               const SizedBox(height: 20),
// //               Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   ConstrainedBox(
// //                     constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
// //                     child: isLoading
// //                         ? const Center(child: CircularProgressIndicator())
// //                         : AnimatedButton(
// //                       onPressed: currentStep < 2 ? nextStep : submitForm,
// //                       text: currentStep < 2 ? "Next" : "Register",
// //                     ),
// //                   ),
// //                   const SizedBox(height: 12),
// //                   if (currentStep > 0)
// //                     ConstrainedBox(
// //                       constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
// //                       child: AnimatedButton(
// //                         onPressed: previousStep,
// //                         text: "Back",
// //                         isPrimary: false,
// //                       ),
// //                     ),
// //                 ],
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // Step 1
// //   Widget step1() {
// //     return SingleChildScrollView(
// //       child: Form(
// //         key: _formKeyStep1,
// //         child: Column(
// //           children: [
// //             const SizedBox(height: 20),
// //             const Text("Hi 👋", style: TextStyle(fontSize: 22)),
// //             const SizedBox(height: 6),
// //             const Text("Welcome to Nahata Sports", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 20),
// //             GestureDetector(
// //               onTap: () => pickImage(ImageSource.gallery),
// //               child: Stack(
// //                 children: [
// //                   CircleAvatar(
// //                     radius: 60,
// //                     backgroundColor: Colors.grey[200],
// //                     backgroundImage: studentPhoto != null ? FileImage(studentPhoto!) : null,
// //                     child: studentPhoto == null
// //                         ? Icon(Icons.person, size: 60, color: Colors.grey[600])
// //                         : null,
// //                   ),
// //                   Positioned(
// //                     bottom: 0,
// //                     right: 0,
// //                     child: Container(
// //                       padding: EdgeInsets.all(2),
// //                       decoration: BoxDecoration(
// //                         shape: BoxShape.circle,
// //                         color: Colors.white,
// //                         border: Border.all(color: Colors.grey[400]!, width: 2),
// //                       ),
// //                       child: Icon(Icons.add, size: 24, color: Colors.grey[600]),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //             const SizedBox(height: 20),
// //             buildInputField(
// //               fullNameController,
// //               "Full Name",
// //               "Enter full name",
// //               validator: (value) {
// //                 if (value == null || value.trim().isEmpty) {
// //                   return "Full Name is required";
// //                 }
// //                 return null;
// //               },
// //             ),
// //             buildDropdownField("Gender", ["Male", "Female", "Other"], (val) => genderValue = val),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // Step 2
// //   Widget step2() {
// //     return SingleChildScrollView(
// //       child: Form(
// //         key: _formKeyStep2,
// //         child: Column(
// //           children: [
// //             const Text("Personal Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 20),
// //             buildDatePickerField("Date of Birth", dobController, context),
// //             buildDropdownField("Blood Group", ["A+", "A-", "B+", "B-", "O+", "O-", "AB+", "AB-"], (val) => bloodGroupValue = val),
// //             buildInputField(
// //               mobileController,
// //               "Mobile Number",
// //               "Enter mobile number",
// //               keyboardType: TextInputType.phone,
// //               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
// //               validator: (value) {
// //                 if (value == null || value.trim().isEmpty) {
// //                   return "Mobile number is required";
// //                 }
// //                 if (value.length != 10) {
// //                   return "Enter a valid 10-digit mobile number";
// //                 }
// //                 return null;
// //               },
// //             ),
// //             buildInputField(
// //               parentController,
// //               "Parent / Guardian Contact",
// //               "Enter parent number",
// //               keyboardType: TextInputType.phone,
// //               validator: (value) {
// //                 if (value != null && value.length != 10) {
// //                   return "Enter a valid 10-digit parent contact number";
// //                 }
// //                 return null;
// //               },
// //             ),
// //
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // Step 3
// //   Widget step3() {
// //     return SingleChildScrollView(
// //       child: Form(
// //         key: _formKeyStep3,
// //         child: Column(
// //           children: [
// //             const Text("Account Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 20),
// //             buildInputField(emailController, "Email Address", "Enter email", keyboardType: TextInputType.emailAddress),
// //             buildInputField(
// //               passwordController,
// //               "Password",
// //               "Enter password",
// //               obscureText: true,
// //               validator: (value) {
// //                 if (value == null || value.isEmpty) {
// //                   return "Password is required";
// //                 }
// //                 if (value.length < 6) {
// //                   return "Password must be at least 6 characters";
// //                 }
// //                 return null;
// //               },
// //             ),
// //             buildInputField(confirmController, "Confirm Password", "Confirm password", obscureText: true),
// //             const SizedBox(height: 20),
// //             buildInputField(referralController, "Referral Code (Optional)", "Enter referral code"),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget buildInputField(
// //       TextEditingController controller,
// //       String label,
// //       String hint, {
// //         bool obscureText = false,
// //         TextInputType keyboardType = TextInputType.text,
// //         IconData? icon,
// //         List<TextInputFormatter>? inputFormatters,
// //         void Function(String)? onChanged,
// //         String? Function(String?)? validator,
// //
// //       }) {
// //     final obscureNotifier = ValueNotifier<bool>(obscureText);
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 8),
// //       child: ValueListenableBuilder<bool>(
// //         valueListenable: obscureNotifier,
// //         builder: (context, _obscure, child) {
// //           return TextFormField(
// //             controller: controller,
// //             obscureText: _obscure,
// //             keyboardType: keyboardType,
// //             inputFormatters: inputFormatters,
// //             onChanged: onChanged,
// //             validator: validator,
// //             decoration: InputDecoration(
// //               labelText: label,
// //               hintText: hint,
// //               prefixIcon: icon != null ? Icon(icon) : null,
// //               suffixIcon: obscureText
// //                   ? IconButton(
// //                 icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
// //                 onPressed: () => obscureNotifier.value = !_obscure,
// //               )
// //                   : null,
// //               border: OutlineInputBorder(
// //                 borderRadius: BorderRadius.circular(16),
// //                 borderSide: BorderSide.none,
// //               ),
// //               filled: true,
// //               fillColor: Colors.white,
// //             ),
// //           );
// //         },
// //       ),
// //     );
// //   }
// //
// //   Widget buildDropdownField(String label, List<String> items, Function(String?) onChanged) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 8),
// //       child: DropdownButtonFormField<String>(
// //         validator: (_) => null,
// //         decoration: InputDecoration(
// //           labelText: label,
// //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
// //           filled: true,
// //           fillColor: Colors.white,
// //         ),
// //         items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
// //         onChanged: onChanged,
// //       ),
// //     );
// //   }
// //
// //   Widget buildDatePickerField(String label, TextEditingController controller, BuildContext context) {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(vertical: 8),
// //       child: TextFormField(
// //         controller: controller,
// //         readOnly: true,
// //         validator: (_) => null,
// //         decoration: InputDecoration(
// //           labelText: label,
// //           hintText: "yyyy/mm/dd",
// //           suffixIcon: const Icon(Icons.calendar_today),
// //           border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
// //           filled: true,
// //           fillColor: Colors.white,
// //         ),
// //         onTap: () async {
// //           DateTime? pickedDate = await showDatePicker(
// //             context: context,
// //             initialDate: DateTime.now(),
// //             firstDate: DateTime(1970),
// //             lastDate: DateTime.now(),
// //           );
// //           if (pickedDate != null) {
// //             controller.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
// //           }
// //         },
// //       ),
// //     );
// //   }
// // }
//
// // Dummy AnimatedButton & LoginScreen for completeness
// // class AnimatedButton extends StatelessWidget {
// //   final void Function() onPressed;
// //   final String text;
// //   final bool isPrimary;
// //   const AnimatedButton({super.key, required this.onPressed, required this.text, this.isPrimary = true});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return ElevatedButton(
// //       onPressed: onPressed,
// //       style: ElevatedButton.styleFrom(
// //         backgroundColor: isPrimary ? Color(0xFF0A198D) : Colors.grey,
// //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
// //         padding: const EdgeInsets.symmetric(vertical: 16),
// //       ),
// //       child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
// //     );
// //   }
// // }
//
//
//
//
//
//
//
// class AnimatedButton extends StatefulWidget {
//   final VoidCallback onPressed;
//   final String text;
//   final bool isPrimary;
//   final bool isLoading;
//
//   const AnimatedButton({
//     super.key,
//     required this.onPressed,
//     required this.text,
//     this.isPrimary = true,
//     this.isLoading = false,
//   });
//
//   @override
//   State<AnimatedButton> createState() => _AnimatedButtonState();
// }
//
// class _AnimatedButtonState extends State<AnimatedButton> {
//   double _scale = 1.0;
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTapDown: (_) => setState(() => _scale = 0.95),
//       onTapUp: (_) {
//         setState(() => _scale = 1.0);
//         if (!widget.isLoading) widget.onPressed();
//       },
//       onTapCancel: () => setState(() => _scale = 1.0),
//       child: AnimatedScale(
//         scale: _scale,
//         duration: const Duration(milliseconds: 100),
//         curve: Curves.easeOut,
//         child: ElevatedButton(
//           onPressed: widget.isLoading ? null : widget.onPressed,
//           style: ElevatedButton.styleFrom(
//             padding: const EdgeInsets.symmetric(vertical: 16),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//             backgroundColor: widget.isPrimary ? Color(0xFF0A198D) : Colors.grey[300],
//             minimumSize: const Size(double.infinity, 48),
//           ),
//           child: widget.isLoading
//               ? const SizedBox(
//             height: 24,
//             width: 24,
//             child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
//           )
//               : Text(
//             widget.text,
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: widget.isPrimary ? Colors.white : Colors.black54,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
