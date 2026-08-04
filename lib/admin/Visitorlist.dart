import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
class VisitorPass {
  final String id;
  final String name;
  final String phone;
  final String purpose;
  final DateTime date;
  final DateTime? scannedAt;

  VisitorPass({
    required this.id,
    required this.name,
    required this.phone,
    required this.purpose,
    required this.date,
    this.scannedAt,
  });

  factory VisitorPass.fromJson(Map<String, dynamic> json) {
    final parsed = json['parsed'] ?? {};

    return VisitorPass(
      id: json['id']?.toString() ?? '',
      name: parsed['name']?.toString() ?? '',
      phone: parsed['phone']?.toString() ?? '',
      purpose: parsed['purpose']?.toString() ?? '',
      date: DateTime.tryParse(parsed['date'] ?? '') ?? DateTime.now(),
      scannedAt: DateTime.tryParse(json['scanned_at'] ?? ''),
    );
  }
}

Future<List<VisitorPass>> fetchVisitors({String? date}) async {
  final url = date == null
      ? "https://nahatasports.com/api/Visitor_passes"
      : "https://nahatasports.com/api/Visitor_passes?date=$date";

  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data['status'] == true) {
      return (data['visitors'] as List)
          .map((v) => VisitorPass.fromJson(v))
          .toList();
    }
  }

  return [];
}



class VisitorPassScreen extends StatefulWidget {
  const VisitorPassScreen({Key? key}) : super(key: key);

  @override
  State<VisitorPassScreen> createState() => _VisitorPassScreenState();
}

class _VisitorPassScreenState extends State<VisitorPassScreen> {
  DateTime selectedDate = DateTime.now();
  List<VisitorPass> visitors = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadVisitors();
  }

  Future<void> loadVisitors() async {
    setState(() => loading = true);

    final formatted =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    visitors = await fetchVisitors(date: formatted);

    setState(() => loading = false);
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(2024);
    final lastDate = DateTime(2050, 12, 31); // full year

    final safeInitialDate = selectedDate.isAfter(lastDate)
        ? lastDate
        : selectedDate.isBefore(firstDate)
        ? firstDate
        : selectedDate;

    DateTime? value = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: safeInitialDate,
    );

    if (value != null) {
      setState(() => selectedDate = value);
      loadVisitors();
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = GoogleFonts.poppins();

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text("Visitor Pass List",
            style: txt.copyWith(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // DATE FILTER
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      "${selectedDate.day}-${selectedDate.month}-${selectedDate.year}",
                      style: txt.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: exportToPdf,
                    icon: const Icon(Icons.picture_as_pdf,color: Colors.white,),
                    label: const Text("Export PDF",style: TextStyle(color: Colors.white),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0A198D),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: exportToExcel,
                    icon: const Icon(Icons.file_present,color: Colors.white,),
                    label: const Text("Export Excel",style: TextStyle(color: Colors.white),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0A198D),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : visitors.isEmpty
                ? Center(
              child: Text(
                "No Visitor Pass Found",
                style: txt.copyWith(fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visitors.length,
              itemBuilder: (context, index) {
                final v = visitors[index];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(.07),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // NAME + ARROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            v.name,
                            style: txt.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.qr_code_scanner,
                              color: Colors.blue.shade600)
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(color: Colors.grey.shade300),

                      const SizedBox(height: 10),

                      _infoRow(Icons.phone, "Phone", v.phone),
                      const SizedBox(height: 8),

                      _infoRow(Icons.flag, "Purpose", v.purpose),
                      const SizedBox(height: 8),

                      _infoRow(
                        Icons.date_range,
                        "Pass Date",
                        _formatDate(v.date),
                      ),

                      const SizedBox(height: 8),

                      _infoRow(
                        Icons.access_time,
                        "Scanned At",
                        _formatDate(v.scannedAt),
                      ),

                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final txt = GoogleFonts.poppins();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "$label: $value",
            style: txt.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
  String formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
  Future<void> exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text("Visitor Pass Report",
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),

          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Sr No")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Name")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Phone")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Purpose")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Pass Date")),
                  pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Scanned At")),
                ],
              ),

              ...visitors.asMap().entries.map((entry) {
                final i = entry.key;
                final v = entry.value;

                return pw.TableRow(children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("${i + 1}")),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(v.name)),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(v.phone)),
                  pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(v.purpose)),
                  pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(formatDateTime(v.date))),
                  pw.Padding(padding:  pw.EdgeInsets.all(8), child: pw.Text(formatDateTime(v.scannedAt))),
                ]);
              })
            ],
          ),
        ],
      ),
    );

    final dir = await getExternalStorageDirectory();
    final file = File("${dir!.path}/visitor_pass_${DateTime.now().millisecondsSinceEpoch}.pdf");

    await file.writeAsBytes(await pdf.save());
    OpenFile.open(file.path);
  }
  String excelDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }
  Future<void> exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Visitor Passes'];

    sheetObject.appendRow([
      TextCellValue("Sr No"),
      TextCellValue("Name"),
      TextCellValue("Phone"),
      TextCellValue("Purpose"),
      TextCellValue("Pass Date"),
      TextCellValue("Scanned At")
    ]);

    for (int i = 0; i < visitors.length; i++) {
      final v = visitors[i];

      sheetObject.appendRow([
        TextCellValue((i + 1).toString()),
        TextCellValue(v.name),
        TextCellValue(v.phone),
        TextCellValue(v.purpose),
        TextCellValue(excelDate(v.date)),
        TextCellValue(excelDate(v.scannedAt)),

      ]);
    }

    final dir = await getExternalStorageDirectory();
    final file = File("${dir!.path}/visitor_pass_${DateTime.now().millisecondsSinceEpoch}.xlsx");

    final excelBytes = excel.encode();
    await file.writeAsBytes(excelBytes!);

    OpenFile.open(file.path);
  }

}
