// import 'dart:convert';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:nahata_app/dashboard/dashboard_screen.dart';
// import 'package:nahata_app/screens/regi.dart';
//
// import 'login_screen.dart';
//
//
//
//
// class PremiumSignUpScreen2 extends StatefulWidget {
//   const PremiumSignUpScreen2({super.key});
//
//   @override
//   State<PremiumSignUpScreen2> createState() => _PremiumSignUpScreen2State();
// }
//
// class _PremiumSignUpScreen2State extends State<PremiumSignUpScreen2> {
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
//   final mobileController = TextEditingController(text: "+91");
//   final parentController = TextEditingController(text: "+91");
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
//   Future<void> submitForm() async {
//     setState(() => isLoading = true);
//
//     try {
//       var uri = Uri.parse("https://nahatasports.com/api/register");
//       String? base64Image;
//       if (studentPhoto != null) {
//         List<int> imageBytes = await studentPhoto!.readAsBytes();
//         base64Image = base64Encode(imageBytes);
//       }
//
//       // Map<String, dynamic> body = {};
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
//       print(body);
//
//       if (base64Image != null) body["student_photo"] = "data:image/jpeg;base64,$base64Image";
//       if (fullNameController.text.trim().isNotEmpty) body["name"] = fullNameController.text.trim();
//       if (dobController.text.trim().isNotEmpty) body["dob"] = dobController.text.trim();
//       if (bloodGroupValue != null && bloodGroupValue!.isNotEmpty) body["blood_group"] = bloodGroupValue;
//       if (genderValue != null && genderValue!.isNotEmpty) body["gender"] = genderValue;
//       if (mobileController.text.trim().isNotEmpty) body["phone"] = mobileController.text.trim();
//       if (parentController.text.trim().isNotEmpty) body["parent_contact"] = parentController.text.trim();
//       if (emailController.text.trim().isNotEmpty) body["email"] = emailController.text.trim();
//       if (passwordController.text.isNotEmpty) body["password"] = passwordController.text;
//       if (confirmController.text.isNotEmpty) body["confirmPassword"] = confirmController.text;
//       if (referralController.text.trim().isNotEmpty) body["passcode"] = referralController.text.trim();
//
//       var response = await http.post(
//         uri,
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode(body),
//       );
//
//       setState(() => isLoading = false);
//
//       if (response.statusCode == 200) {
//         var responseData = jsonDecode(response.body);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(responseData["message"] ?? "Registration complete!")),
//         );
//
//         if (responseData["status"] == true) {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const LoginScreen()),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Registration failed: ${response.body}")),
//         );
//       }
//     } catch (e) {
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
//     if (currentStep < 2) {
//       setState(() => currentStep += 1);
//       pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.ease);
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
//                 color: Color(0xFF0A198D),
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
//                         : AnimatedButton(
//                       onPressed: currentStep < 2 ? nextStep : submitForm,
//                       text: currentStep < 2 ? "Next" : "Register",
//                     ),
//                   ),
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
//                       padding: EdgeInsets.all(2),
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
//             buildInputField(fullNameController, "Full Name", "Enter full name"),
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
//             buildInputField(mobileController, "Mobile Number", "Enter mobile number", keyboardType: TextInputType.number,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],),
//
//             buildInputField(parentController, "Parent / Guardian Contact", "Enter parent number", keyboardType: TextInputType.number ,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Step 3
//   Widget step3() {
//     return SingleChildScrollView(
//       child: Form(
//         key: _formKeyStep3,
//         child: Column(
//           children: [
//             const Text("Account Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 20),
//             buildInputField(emailController, "Email Address", "Enter email", keyboardType: TextInputType.emailAddress),
//             buildInputField(passwordController, "Password", "Enter password", obscureText: true),
//             buildInputField(confirmController, "Confirm Password", "Confirm password", obscureText: true),
//             const SizedBox(height: 20),
//             buildInputField(referralController, "Referral Code (Optional)", "Enter referral code"),
//           ],
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
//         IconData? icon,
//         List<TextInputFormatter>? inputFormatters,
//         void Function(String)? onChanged,
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
//             validator: (_) => null,
//             decoration: InputDecoration(
//               labelText: label,
//               hintText: hint,
//               prefixIcon: icon != null ? Icon(icon) : null,
//               suffixIcon: obscureText
//                   ? IconButton(
//                 icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
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
//             controller.text = "${pickedDate.month}/${pickedDate.day}/${pickedDate.year}";
//           }
//         },
//       ),
//     );
//   }
// }