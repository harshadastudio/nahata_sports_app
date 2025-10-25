// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
//
// import 'login_screen.dart';
//
// class PremiumSignUpScreen1 extends StatefulWidget {
//   const PremiumSignUpScreen1({super.key});
//
//   @override
//   _PremiumSignUpScreen1State createState() => _PremiumSignUpScreen1State();
// }
//
// class _PremiumSignUpScreen1State extends State<PremiumSignUpScreen1> {
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
//   final passcodeController = TextEditingController();
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
//
//   // Validate only required steps
//   bool validateSteps() {
//     bool step1Valid = _formKeyStep1.currentState?.validate() ?? false;
//     bool step2Valid = _formKeyStep2.currentState?.validate() ?? false;
//     bool step3Valid = _formKeyStep3.currentState?.validate() ?? false;
//     return step1Valid && step2Valid && step3Valid;
//   }
//
//   Future<void> submitForm() async {
//     if (!validateSteps()) return;
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
// print(body);
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
//
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
//                         : ElevatedButton(
//                       onPressed: () {
//                         if (currentStep < 2) nextStep();
//                         else submitForm();
//                       },
//                       child: Text(currentStep < 2 ? "Next" : "Register"),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   if (currentStep > 0)
//                     ConstrainedBox(
//                       constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
//                       child: ElevatedButton(
//                         onPressed: previousStep,
//                         child: const Text("Back"),
//                         style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
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
//   // ---------- Steps ----------
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
//               validator: (value) => value == null || value.trim().isEmpty ? "Full Name is required" : null,
//             ),
//             buildDropdownField("Gender", ["Male", "Female", "Other"], (val) => genderValue = val),
//           ],
//         ),
//       ),
//     );
//   }
//
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
//             buildInputField(
//               mobileController,
//               "Mobile Number",
//               "Enter 10-digit number",
//               keyboardType: TextInputType.number,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
//               validator: (val) {
//                 if (val == null || val.trim().isEmpty) return "Mobile number is required";
//                 if (val.length != 10) return "Enter exactly 10 digits";
//                 return null;
//               },
//               prefix: const Padding(
//                 padding: EdgeInsets.only(left: 12, right: 6),
//                 child: Text("+91", style: TextStyle(fontSize: 16, color: Colors.black)),
//               ),
//             ),
//             buildInputField(
//               parentController,
//               "Parent / Guardian Contact",
//               "Enter parent number",
//               keyboardType: TextInputType.number,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
//               validator: (val) {
//                 if (val != null && val.trim().isNotEmpty && val.trim().length != 10) {
//                   return "Enter a valid 10-digit parent contact number";
//                 }
//                 return null;
//               },
//               prefix: const Padding(
//                 padding: EdgeInsets.only(left: 12, right: 6),
//                 child: Text("+91", style: TextStyle(fontSize: 16, color: Colors.black)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget step3() {
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.only(bottom: 80),
//         child: Form(
//           key: _formKeyStep3,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text("Account Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//               const SizedBox(height: 20),
//               buildInputField(
//                 emailController,
//                 "Email Address",
//                 "Enter email",
//                 keyboardType: TextInputType.emailAddress,
//                 validator: (val) {
//                   if (val == null || val.trim().isEmpty) return "Email is required";
//                   if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return "Enter a valid email";
//                   return null;
//                 },
//               ),
//               buildInputField(
//                 passwordController,
//                 "Password",
//                 "Enter password",
//                 obscureText: true,
//                 validator: (val) {
//                   if (val == null || val.isEmpty) return "Password is required";
//                   if (val.length < 6) return "Password must be at least 6 characters";
//                   return null;
//                 },
//               ),
//               buildInputField(
//                 confirmController,
//                 "Confirm Password",
//                 "Confirm password",
//                 obscureText: true,
//                 validator: (val) {
//                   if (val == null || val.isEmpty) return "Please confirm your password";
//                   if (val != passwordController.text) return "Passwords do not match";
//                   return null;
//                 },
//               ),
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
//   Widget buildInputField(
//       TextEditingController controller,
//       String label,
//       String hint, {
//         bool obscureText = false,
//         TextInputType keyboardType = TextInputType.text,
//         List<TextInputFormatter>? inputFormatters,
//         String? Function(String?)? validator,
//         Widget? prefix,
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
//             validator: validator,
//             decoration: InputDecoration(
//               labelText: label,
//               hintText: hint,
//               prefix: prefix,
//               suffixIcon: obscureText
//                   ? IconButton(
//                 icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
//                 onPressed: () => obscureNotifier.value = !_obscure,
//               )
//                   : null,
//               border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
//               filled: true,
//               fillColor: Colors.white,
//             ),
//           );
//         },
//       ),
//     );
//   }
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
//         },
//       ),
//     );
//   }
// }
