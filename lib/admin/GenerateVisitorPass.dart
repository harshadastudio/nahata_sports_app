import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Optional packages - add to pubspec.yaml if you want working share/whatsapp/email/print:
// import 'package:share_plus/share_plus.dart';
// import 'package:url_launcher/url_launcher.dart';

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../auth/login.dart';

class VisitorPassListScreen extends StatefulWidget {
  const VisitorPassListScreen({Key? key}) : super(key: key);

  @override
  State<VisitorPassListScreen> createState() => _VisitorPassListScreenState();
}

class _VisitorPassListScreenState extends State<VisitorPassListScreen> {
  bool isLoading = true;
  List<dynamic> visitorList = [];
  String apiBase = 'https://nahatasports.com';

  @override
  void initState() {
    super.initState();
    fetchVisitorPasses();
  }

  Future<void> fetchVisitorPasses() async {
    setState(() => isLoading = true);
    try {
      final resp = await http.get(Uri.parse('$apiBase/api/visitor-pass'));
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded['status'] == true && decoded['data'] is List) {
          visitorList = decoded['data'];
        } else {
          visitorList = [];
        }
      } else {
        visitorList = [];
      }
    } catch (e) {
      visitorList = [];
      debugPrint("Error: $e");
    }
    if (mounted) setState(() => isLoading = false);
  }

  // -------------------------- POPUP --------------------------
  void showVisitorDetailsPopup(BuildContext context, visitor) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Visitor Pass",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),

                const Divider(height: 24),

                _infoText("Name", visitor['visitor_name']),
                _infoText("Phone", visitor['phone']),
                _infoText("Purpose", visitor['purpose']),
                _infoText("Date", visitor['created_at']),

                const SizedBox(height: 16),
                const Text("QR Code",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.grey.shade100,
                    ),
                    child: Image.network(
                      "https://nahatasports.com/${visitor['qr_code']}",
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0A198D),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.share,color: Colors.white,),
                      label: const Text("Share",style: TextStyle(color: Colors.white),),
                      onPressed: () {
                        Share.share("""
Visitor Pass
Name: ${visitor['visitor_name']}
Phone: ${visitor['phone']}
Purpose: ${visitor['purpose']}
Date: ${visitor['created_at']}
QR: https://nahatasports.com/${visitor['qr_code']}
                        """);
                      },
                    ),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0A198D),
                        padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.print,color: Colors.white,),
                      label: const Text("Print",style: TextStyle(color: Colors.white),),
                      onPressed: () async {
                        final pdf = pw.Document();
                        final qrImg = await networkImage(
                          "https://nahatasports.com/${visitor['qr_code']}",
                        );

                        pdf.addPage(
                          pw.Page(
                            build: (context) => pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Visitor Pass",
                                    style: pw.TextStyle(fontSize: 22)),

                                pw.SizedBox(height: 16),
                                pw.Text("Name: ${visitor['visitor_name']}"),
                                pw.Text("Phone: ${visitor['phone']}"),
                                pw.Text("Purpose: ${visitor['purpose']}"),
                                pw.Text("Date: ${visitor['created_at']}"),

                                pw.SizedBox(height: 20),
                                pw.Image(qrImg, width: 200),
                              ],
                            ),
                          ),
                        );

                        final dir = await getTemporaryDirectory();
                        final file = File("${dir.path}/visitor_pass.pdf");
                        await file.writeAsBytes(await pdf.save());

                        Share.shareXFiles([XFile(file.path)],
                            text: "Visitor Pass PDF");
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------- TABLE UI -----------------------
  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 12),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
          MaterialStateProperty.all(Colors.grey.shade200),
          headingTextStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          dataRowHeight: 68,
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Purpose')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('QR')),
            DataColumn(label: Text('Action')),
          ],
          rows: List.generate(visitorList.length, (i) {
            final v = visitorList[i];
            final qrUrl = "$apiBase/${v['qr_code']}";
            return DataRow(
              cells: [
                DataCell(Text("${i + 1}")),
                DataCell(Text(v['visitor_name'] ?? '-')),
                DataCell(Text(v['phone'] ?? '-')),
                DataCell(Text(v['purpose'] ?? '-')),
                DataCell(Text(v['created_at'] ?? '-')),
                DataCell(
                  Image.network(qrUrl, width: 50, height: 50),
                ),
                DataCell(
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0A198D),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => showVisitorDetailsPopup(context, v),
                    child: const Text("View",style: TextStyle(color: Colors.white),),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ---------------- UI ---------------------
  @override
  Widget build(BuildContext context) {
    final txt = GoogleFonts.poppins();

    return Scaffold(
      appBar: AppBar(
        title: Text("Generate Visitor Pass",    style: txt.copyWith(fontWeight: FontWeight.w600)),
        elevation: 1,
        actions: [
          IconButton(
            onPressed: fetchVisitorPasses,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GenerateVisitorPassScreen()),
          );
          if (created == true) fetchVisitorPasses();
        },
        label: const Text("Generate Pass"),
        icon: const Icon(Icons.add),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : visitorList.isEmpty
          ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text("No Visitor Pass Found",
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 18)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: fetchVisitorPasses,
            child: const Text("Retry"),
          )
        ],
      )
          : _buildTable(),
    );
  }
}

Widget _infoText(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text("$label:")),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class GenerateVisitorPassScreen extends StatefulWidget {
  const GenerateVisitorPassScreen({Key? key}) : super(key: key);

  @override
  State<GenerateVisitorPassScreen> createState() => _GenerateVisitorPassScreenState();
}

class _GenerateVisitorPassScreenState extends State<GenerateVisitorPassScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String? selectedPurpose;
  bool isSubmitting = false;

  final String apiBase = 'https://nahatasports.com';

  final List<String> purposeList = [
    'Nahata Sports',
    'Nahata Lawns',
    'Dreams to Fly',
    'Happywedz',
    'Multipurpose Studio',
    'Lalit Nahata Infrastructure',
    'Labour'
  ];

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // -------------------------------------------------
  // ⭐️⭐️⭐️ FIX: Added createVisitorPass() back ⭐️⭐️⭐️
  // -------------------------------------------------
  Future<void> createVisitorPass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final userId = await AuthService.getUserId();  // ✅ Get logged-in user ID

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not logged in")),
        );
        return;
      }

      final payload = {
        "visitor_name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "purpose": selectedPurpose ?? '',
        "generated_by": userId, // ✅ Dynamically added user_id
      };

      final response = await http.post(
        Uri.parse('$apiBase/api/visitor-pass/create'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded['status'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Visitor pass created')),
            );
            Navigator.pop(context, true);
          }
          return;
        } else {
          final msg = decoded['message'] ?? "Unexpected response";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint("createVisitorPass error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error")),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  // -------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final txt = GoogleFonts.poppins();

    return Scaffold(
      appBar: AppBar(
        title:  Text("Generate Visitor Pass",style: txt.copyWith(fontWeight: FontWeight.w600)),
        elevation: 2,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [

              _input(
                controller: nameController,
                label: "Visitor Name",
                validator: (v) => v!.isEmpty ? "Enter visitor name" : null,
              ),

              const SizedBox(height: 14),

              _input(
                controller: phoneController,
                label: "Phone Number",
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter phone number";
                  if (!RegExp(r'^\d+$').hasMatch(v)) return "Only digits allowed";
                  if (v.length != 10) return "Phone number must be exactly 10 digits";
                  return null;
                },
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: selectedPurpose,
                decoration: _inputDecoration("Select Purpose"),
                items: purposeList
                    .map((p) =>
                    DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => selectedPurpose = v),
                validator: (v) => v == null ? "Select purpose" : null,
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0A198D),

                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),

                    ),
                  ),
                  onPressed: isSubmitting ? null : createVisitorPass,
                  child: isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    "Generate Pass",
                    style: TextStyle(color:Colors.white,fontSize: 16),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ UI Helpers ---------------------
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
  Widget _input({
    required TextEditingController controller,
    required String label,
    required FormFieldValidator validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: _inputDecoration(label),
    );
  }

}
