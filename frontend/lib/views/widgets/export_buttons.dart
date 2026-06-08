import 'package:flutter/material.dart';
import '../../core/export_helper.dart';

class ExportButtons extends StatefulWidget {
  final String title;
  final String defaultFileName;
  final List<String> headers;
  final List<List<String>> Function() onFetchData;

  const ExportButtons({
    super.key,
    required this.title,
    required this.defaultFileName,
    required this.headers,
    required this.onFetchData,
  });

  @override
  State<ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<ExportButtons> {
  bool _isExportingExcel = false;
  bool _isExportingPdf = false;

  void _showSnackbar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleExcelExport() async {
    final data = widget.onFetchData();
    if (data.isEmpty) {
      _showSnackbar('No hay datos disponibles para exportar.', false);
      return;
    }

    setState(() => _isExportingExcel = true);

    final success = await ExportHelper.exportToExcel(
      defaultFileName: widget.defaultFileName,
      headers: widget.headers,
      data: data,
    );

    setState(() => _isExportingExcel = false);

    if (success) {
      _showSnackbar('Reporte de Excel guardado con éxito.', true);
    } else {
      _showSnackbar('Exportación a Excel cancelada o fallida.', false);
    }
  }

  Future<void> _handlePdfExport() async {
    final data = widget.onFetchData();
    if (data.isEmpty) {
      _showSnackbar('No hay datos disponibles para exportar.', false);
      return;
    }

    setState(() => _isExportingPdf = true);

    final success = await ExportHelper.exportToPdf(
      title: widget.title,
      defaultFileName: widget.defaultFileName,
      headers: widget.headers,
      data: data,
    );

    setState(() => _isExportingPdf = false);

    if (success) {
      _showSnackbar('Reporte PDF guardado con éxito.', true);
    } else {
      _showSnackbar('Exportación a PDF cancelada o fallida.', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Excel Button
        ElevatedButton.icon(
          onPressed: (_isExportingExcel || _isExportingPdf) ? null : _handleExcelExport,
          icon: _isExportingExcel
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.table_view_rounded, size: 18),
          label: const Text('Exportar Excel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.green.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        // PDF Button
        ElevatedButton.icon(
          onPressed: (_isExportingExcel || _isExportingPdf) ? null : _handlePdfExport,
          icon: _isExportingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Exportar PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.red.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
