import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'notifications/admin_notification.dart';

class BookedSlotsScreen extends StatefulWidget {
  const BookedSlotsScreen({super.key});

  @override
  State<BookedSlotsScreen> createState() => _BookedSlotsScreenState();
}

class _BookedSlotsScreenState extends State<BookedSlotsScreen> {
  final List<CourtResponse> _slots = [];
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DateTime _selectedMonth = DateTime.now();

  int _page = 1;
  final int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchSlots();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !_loadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  Future<void> _showMonthPicker() async {
    DateTime tempDate = _selectedMonth;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Month"),
          content: SizedBox(
            height: 250,
            child: Column(
              children: [
                Expanded(
                  child: CalendarDatePicker(
                    initialDate: tempDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    onDateChanged: (date) {
                      tempDate = date;
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _selectedMonth = tempDate;

                // 🔥 EXPORT AFTER MONTH SELECTION
                _exportMonthWiseExcel(
                  year: _selectedMonth.year,
                  month: _selectedMonth.month,
                );
              },
              child: const Text("Export"),
            ),
          ],
        );
      },
    );
  }
  bool _isSameMonth(String date, int year, int month) {
    try {
      final d = DateTime.parse(date);
      return d.year == year && d.month == month;
    } catch (_) {
      return false;
    }
  }

  Future<void> _exportMonthWiseExcel({
    required int year,
    required int month,
  }) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Preparing month-wise Excel...")),
    );

    await Permission.storage.request();

    // 🔥 FETCH FULL DATA
    final allSlots = await _fetchAllSlotsForExport();

    // 🔥 FILTER MONTH
    final monthSlots = allSlots.where(
          (e) => _isSameMonth(e.selectedDate, year, month),
    ).toList();

    if (monthSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data for selected month")),
      );
      return;
    }

    final excel = Excel.createExcel();
    final Sheet sheet = excel['$year-$month'];

    // HEADER
    sheet.appendRow([
      TextCellValue('Booking ID'),
      TextCellValue('Court Name'),
      TextCellValue('Date'),
      TextCellValue('Slot Time'),
      TextCellValue('Amount'),
      TextCellValue('Status'),
    ]);

    // ONE ROW PER SLOT
    for (final booking in monthSlots) {
      if (booking.slots.isEmpty) {
        sheet.appendRow([
          TextCellValue(booking.id),
          TextCellValue(booking.courtName),
          TextCellValue(booking.selectedDate),
          TextCellValue('No Slot'),
          DoubleCellValue(booking.amount),
          TextCellValue(booking.status),
        ]);
      } else {
        for (final slot in booking.slots) {
          sheet.appendRow([
            TextCellValue(booking.id),
            TextCellValue(booking.courtName),
            TextCellValue(booking.selectedDate),
            TextCellValue(slot.time),
            DoubleCellValue(booking.amount),
            TextCellValue(booking.status),
          ]);
        }
      }
    }

    final directory = await getExternalStorageDirectory();
    final filePath =
        '${directory!.path}/Booked_Slots_${year}_$month.xlsx';

    final bytes = excel.save();
    if (bytes == null) return;

    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Booked Slots ($year-$month)',
    );
  }

  Future<void> _fetchSlots() async {
    final list = await CourtResponseService.fetchCourtResponses(
      page: _page,
      perPage: _perPage,
    );

    setState(() {
      _slots.addAll(list);
      _loading = false;
      _hasMore = list.length == _perPage;
    });
  }

  Future<void> _loadMore() async {
    _loadingMore = true;
    _page++;

    final list = await CourtResponseService.fetchCourtResponses(
      page: _page,
      perPage: _perPage,
    );

    setState(() {
      _slots.addAll(list);
      _loadingMore = false;
      if (list.length < _perPage) _hasMore = false;
    });
  }

  Future<List<CourtResponse>> _fetchAllSlotsForExport() async {
    List<CourtResponse> allSlots = [];
    int page = 1;
    const int perPage = 50; // bigger = faster

    while (true) {
      final list = await CourtResponseService.fetchCourtResponses(
        page: page,
        perPage: perPage,
      );

      if (list.isEmpty) break;

      allSlots.addAll(list);

      if (list.length < perPage) break;

      page++;
    }

    return allSlots;
  }

  Future<void> _exportToExcelAndShare() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Preparing full export...")),
    );

    await Permission.storage.request();

    // 🔥 FETCH FULL DATA (NOT PAGINATED)
    final allSlots = await _fetchAllSlotsForExport();

    if (allSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data found")),
      );
      return;
    }

    final excel = Excel.createExcel();
    final Sheet sheet = excel['Booked Slots'];

    // HEADER
    sheet.appendRow([
      TextCellValue('Booking ID'),
      TextCellValue('Court Name'),
      TextCellValue('Date'),
      TextCellValue('Slot Time'),
      TextCellValue('Amount'),
      TextCellValue('Status'),
    ]);

    // ONE ROW PER SLOT TIME
    for (final booking in allSlots) {
      if (booking.slots.isEmpty) {
        sheet.appendRow([
          TextCellValue(booking.id),
          TextCellValue(booking.courtName),
          TextCellValue(booking.selectedDate),
          TextCellValue('No Slot'),
          DoubleCellValue(booking.amount),
          TextCellValue(booking.status),
        ]);
      } else {
        for (final slot in booking.slots) {
          sheet.appendRow([
            TextCellValue(booking.id),
            TextCellValue(booking.courtName),
            TextCellValue(booking.selectedDate),
            TextCellValue(slot.time),
            DoubleCellValue(booking.amount),
            TextCellValue(booking.status),
          ]);
        }
      }
    }

    final directory = await getExternalStorageDirectory();
    final filePath =
        '${directory!.path}/booked_slots_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    final bytes = excel.save();
    if (bytes == null) return;

    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Booked Slots',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booked Slots"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _showMonthPicker,
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
          ? const Center(
        child: Text(
          "No booked slots found",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        itemCount: _slots.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _slots.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final slot = _slots[index];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: booking details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.courtName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text("Date: ${slot.selectedDate}"),
                        Text("Booking ID: ${slot.id}"),
                        const SizedBox(height: 4),
                        const Text("Slots:", style: TextStyle(fontWeight: FontWeight.w600)),
                        ...slot.slots.map(
                              (s) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text("• ${s.time}", style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // RIGHT: amount + status + QR
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹${slot.amount}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slot.status,
                        style: TextStyle(
                          color: slot.status == "approved" ? Colors.green : Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                      if (slot.qrCode != null) ...[
                        const SizedBox(height: 8),
                        Image.network(
                          slot.qrCode!,
                          width: 60,
                          height: 60,
                          errorBuilder: (_, __, ___) => const Icon(Icons.qr_code),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );        },
      ),
    );
  }
}


