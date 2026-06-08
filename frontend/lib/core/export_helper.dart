import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportHelper {
  /// Converts a table (headers and rows) into Excel bytes and prompts the user to save it.
  static Future<bool> exportToExcel({
    required String defaultFileName,
    required List<String> headers,
    required List<List<String>> data,
  }) async {
    try {
      final excel = Excel.createExcel();
      // Access default sheet
      final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel[sheetName];

      // Add header row
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Add data rows
      for (final row in data) {
        sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
      }

      final bytes = excel.encode();
      if (bytes == null) return false;

      return await _saveFile(
        defaultFileName: '$defaultFileName.xlsx',
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      return false;
    }
  }

  /// Converts a table (headers and rows) into PDF bytes and prompts the user to save it.
  static Future<bool> exportToPdf({
    required String title,
    required String defaultFileName,
    required List<String> headers,
    required List<List<String>> data,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'Fecha: ${DateTime.now().toString().substring(0, 10)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
                  bottom: pw.BorderSide(width: 1, color: PdfColors.grey400),
                  top: pw.BorderSide(width: 1, color: PdfColors.grey400),
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                cellStyle: const pw.TextStyle(
                  fontSize: 9,
                ),
                rowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey50,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.white,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      return await _saveFile(
        defaultFileName: '$defaultFileName.pdf',
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      return false;
    }
  }

  /// Prompts the user with a native file dialog to save bytes to a file.
  static Future<bool> _saveFile({
    required String defaultFileName,
    required List<int> bytes,
  }) async {
    try {
      final selectedPath = await FilePicker.saveFile(
        dialogTitle: 'Guardar reporte',
        fileName: defaultFileName,
        type: FileType.any,
        bytes: Uint8List.fromList(bytes),
      );

      if (selectedPath == null) {
        return false; // User cancelled
      }

      // On Android/iOS, the plugin itself handles writing bytes.
      // On desktop, we write the bytes to the selected path if not already written.
      if (!Platform.isAndroid && !Platform.isIOS) {
        final file = File(selectedPath);
        await file.writeAsBytes(bytes);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving file to path: $e');
      return false;
    }
  }
}
