import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:nahata_app/core/network/http_logged.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceModel {
  final String id;
  final String name;
  final String date;
  final String? securityScan;
  final String? coachScan;
  final String scanStatus;

  AttendanceModel({
    required this.id,
    required this.name,
    required this.date,
    this.securityScan,
    this.coachScan,
    required this.scanStatus,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      date: json['attendance_date'] ?? '',
      securityScan: json['security_scan_time'],
      coachScan: json['coach_scan_time'],
      scanStatus: json['scan_status'] ?? 'No Scan',
    );
  }
}





class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  DateTime selectedMonth = DateTime.now();
  bool isLoading = false;
  String searchText = '';

  List<AttendanceModel> attendanceList = [];

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  // ================= API =================

  Future<void> fetchAttendance() async {
    setState(() => isLoading = true);

    final month =
        "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}";

    final url =
        "https://nahatasports.com/api/attendance/attendence_list_api?month=$month";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List list = jsonData['data'];
        attendanceList =
            list.map((e) => AttendanceModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }

    setState(() => isLoading = false);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final filteredList = attendanceList.where((item) {
      return item.name.toLowerCase().contains(searchText.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showExportSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _filterCard(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _attendanceList(filteredList),
          ),
        ],
      ),
    );
  }

  // ================= FILTER =================

  Widget _filterCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: pickMonth,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '${selectedMonth.month}-${selectedMonth.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search Student',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => searchText = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= LIST =================

  Widget _attendanceList(List<AttendanceModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No attendance records'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: list.length,
      itemBuilder: (_, index) {
        final item = list[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(item.date,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _scanInfo(Icons.security, 'Security', item.securityScan),
                    const SizedBox(width: 20),
                    _scanInfo(Icons.sports, 'Coach', item.coachScan),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _statusChip(item.scanStatus),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scanInfo(IconData icon, String label, String? time) {
    return Row(
      children: [
        Icon(icon,
            size: 20, color: time != null ? Colors.green : Colors.grey),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(time ?? 'Not scanned',
                style: TextStyle(
                    fontSize: 12,
                    color: time != null ? Colors.black : Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color color;
    IconData icon;

    if (status == 'Security + Coach') {
      color = Colors.green;
      icon = Icons.verified;
    } else if (status == 'Security Only') {
      color = Colors.orange;
      icon = Icons.security;
    } else {
      color = Colors.grey;
      icon = Icons.cancel;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(status, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  // ================= MONTH PICKER =================

  Future<void> pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      selectedMonth = picked;
      fetchAttendance();
    }
  }

  // ================= EXPORT & SHARE =================

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const Text('Export Attendance',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Export Excel'),
            onTap: () async {
              Navigator.pop(context);
              await exportExcel();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Excel'),
            onTap: () async {
              Navigator.pop(context);
              final file = await exportExcel(returnFile: true);
              if (file != null) {
                Share.shareXFiles([XFile(file.path)]);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<File?> exportExcel({bool returnFile = false}) async {
    await Permission.storage.request();

    final excel = xl.Excel.createExcel();
    final sheet = excel['Attendance'];

    sheet.appendRow([
      xl.TextCellValue('Student'),
      xl.TextCellValue('Date'),
      xl.TextCellValue('Security Scan'),
      xl.TextCellValue('Coach Scan'),
      xl.TextCellValue('Status'),
    ]);

    for (var item in attendanceList) {
      sheet.appendRow([
        xl.TextCellValue(item.name),
        xl.TextCellValue(item.date),
        xl.TextCellValue(item.securityScan ?? '-'),
        xl.TextCellValue(item.coachScan ?? '-'),
        xl.TextCellValue(item.scanStatus),
      ]);
    }

    final dir = await getExternalStorageDirectory();
    final path =
        '${dir!.path}/Attendance_${selectedMonth.month}_${selectedMonth.year}.xlsx';

    final file = File(path);
    file.writeAsBytesSync(excel.encode()!);

    if (!returnFile && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel exported successfully')),
      );
    }

    return returnFile ? file : null;
  }
}