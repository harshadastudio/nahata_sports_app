import 'dart:io';
import 'dart:ui' show Rect;

import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/admin_log.dart';

/// The three formats every admin table can be written to.
enum ExportFormat {
  csv('CSV', 'csv', 'text/csv'),
  excel('Excel', 'xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  pdf('PDF', 'pdf', 'application/pdf');

  const ExportFormat(this.label, this.extension, this.mimeType);

  final String label;
  final String extension;
  final String mimeType;
}

/// One column of an export: a heading and how to read it off a row.
///
/// Deliberately separate from the table widgets. A table column knows about
/// widths, chips and colours; an export column only has to turn a row into one
/// string, so the same definition works for CSV, Excel and PDF alike.
class ExportColumn<T> {
  const ExportColumn(this.label, this.value, {this.numeric = false});

  final String label;

  /// Must return a plain string — never a widget, and never null. Use the
  /// module's own "—" for a missing value so an export reads like the screen.
  final String Function(T row) value;

  /// Right-aligns the column in the PDF and keeps it out of the way of the
  /// wider text columns. Has no effect on CSV.
  final bool numeric;
}

/// What an export produced, so the caller can report it accurately.
class ExportResult {
  const ExportResult({
    required this.format,
    required this.fileName,
    required this.path,
    required this.rowCount,
  });

  final ExportFormat format;
  final String fileName;
  final String path;
  final int rowCount;
}

/// Writes an admin table to CSV, Excel or PDF and hands it to the OS share
/// sheet.
///
/// Built generically so the next module gets exports for the price of a column
/// list. Everything is written to the app's temporary directory: these are
/// throwaway artefacts the admin immediately shares or saves elsewhere, and
/// keeping them out of Documents means the app is not slowly filling a phone
/// with stale spreadsheets.
class AdminExport {
  const AdminExport._();

  /// Writes [rows] and opens the share sheet.
  ///
  /// [sharePositionOrigin] matters on iPad, where the share sheet is a popover
  /// that must be anchored to the control that opened it.
  static Future<ExportResult> run<T>({
    required ExportFormat format,
    required String fileName,
    required String title,
    required List<ExportColumn<T>> columns,
    required List<T> rows,
    String? subtitle,
    Rect? sharePositionOrigin,
  }) async {
    AdminLog.ui(
      'Export ${format.label}: $fileName (${rows.length} rows, '
      '${columns.length} columns)',
    );

    final bytes = switch (format) {
      ExportFormat.csv => _csvBytes(columns, rows),
      ExportFormat.excel => _excelBytes(title, columns, rows),
      ExportFormat.pdf => await _pdfBytes(title, subtitle, columns, rows),
    };

    final directory = await getTemporaryDirectory();
    final safeName = _sanitise(fileName);
    final full = '$safeName.${format.extension}';
    final file = File('${directory.path}${Platform.pathSeparator}$full');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: format.mimeType, name: full)],
        subject: title,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    AdminLog.success('Exported $full');
    return ExportResult(
      format: format,
      fileName: full,
      path: file.path,
      rowCount: rows.length,
    );
  }

  /// A file name safe on every platform, and stable enough to sort by.
  static String buildFileName(String module, DateTime now) {
    final stamp =
        '${now.year}-${_two(now.month)}-${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}';
    return '${_sanitise(module)}_$stamp';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _sanitise(String value) => value
      .trim()
      .replaceAll(RegExp(r'[^\w\-. ]'), '')
      .replaceAll(RegExp(r'\s+'), '-');

  // ---------------------------------------------------------------------------
  // CSV
  // ---------------------------------------------------------------------------

  static List<int> _csvBytes<T>(
    List<ExportColumn<T>> columns,
    List<T> rows,
  ) {
    final buffer = StringBuffer()
      ..writeln(columns.map((column) => _csvField(column.label)).join(','));

    for (final row in rows) {
      buffer.writeln(
        columns.map((column) => _csvField(column.value(row))).join(','),
      );
    }

    // A BOM, so Excel opens the file as UTF-8 instead of mangling the rupee
    // sign and the em dashes this console uses everywhere.
    return [0xEF, 0xBB, 0xBF, ...buffer.toString().codeUnits];
  }

  static String _csvField(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  // ---------------------------------------------------------------------------
  // Excel
  // ---------------------------------------------------------------------------

  static List<int> _excelBytes<T>(
    String title,
    List<ExportColumn<T>> columns,
    List<T> rows,
  ) {
    final workbook = xl.Excel.createExcel();

    // createExcel() seeds a sheet called Sheet1; renaming it avoids ending up
    // with an empty stray sheet beside the real one.
    final sheetName = _sheetName(title);
    workbook.rename(workbook.getDefaultSheet()!, sheetName);
    final sheet = workbook[sheetName];

    sheet.appendRow([
      for (final column in columns) xl.TextCellValue(column.label),
    ]);

    for (final row in rows) {
      sheet.appendRow([
        for (final column in columns) xl.TextCellValue(column.value(row)),
      ]);
    }

    final encoded = workbook.encode();
    if (encoded == null) {
      throw StateError('The spreadsheet could not be encoded.');
    }
    return encoded;
  }

  /// Excel sheet names cannot exceed 31 characters or contain `[]:*?/\`.
  static String _sheetName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    final name = cleaned.isEmpty ? 'Export' : cleaned;
    return name.length <= 31 ? name : name.substring(0, 31);
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  static Future<List<int>> _pdfBytes<T>(
    String title,
    String? subtitle,
    List<ExportColumn<T>> columns,
    List<T> rows,
  ) async {
    final document = pw.Document(title: title);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  title,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ),
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text(
              'No rows matched the current filters.',
              style: const pw.TextStyle(fontSize: 11),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: columns.map((column) => column.label).toList(),
              data: [
                for (final row in rows)
                  columns.map((column) => column.value(row)).toList(),
              ],
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1A237E),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellHeight: 20,
              // Repeated on every page, so a long export stays readable.
              headerCount: 1,
              cellAlignments: {
                for (var i = 0; i < columns.length; i++)
                  i: columns[i].numeric
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
              },
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
              ),
            ),
        ],
      ),
    );

    return document.save();
  }
}
