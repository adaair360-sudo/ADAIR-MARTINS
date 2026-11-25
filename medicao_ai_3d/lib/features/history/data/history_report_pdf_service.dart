import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/history_models.dart';

class HistoryReportPdfService {
  HistoryReportPdfService({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'technical_reports'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _latinSafe(String input) {
    return input
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('·', '.')
        .replaceAll('≥', '>=')
        .replaceAll('≤', '<=')
        .replaceAll('±', '+/-')
        .replaceAll('∅', 'Dia.')
        .replaceAll('Ø', 'Dia.');
  }

  Future<Uint8List> buildReportBytes({
    MaintenanceProject? project,
    required List<HistoryRecord> records,
    required String reportTitle,
  }) async {
    if (records.isEmpty) {
      throw StateError(
        'Selecione ao menos um registro técnico para gerar o relatório PDF.',
      );
    }

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final dateStr = DateTime.now().toIso8601String().split('T').first;

    // Preload valid image bytes for records that reference existing files
    final imageByRecordId = <String, pw.MemoryImage>{};
    for (final rec in records) {
      final path = rec.photoPath;
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) {
          try {
            final bytes = await f.readAsBytes();
            if (bytes.isNotEmpty) {
              imageByRecordId[rec.id] = pw.MemoryImage(bytes);
            }
          } catch (_) {
            // Skip unreadable image file gracefully without fabricating data
          }
        }
      }
    }

    final doc = pw.Document(
      title: _latinSafe(reportTitle),
      creator: 'MEDICAO AI 3D',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.2),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'MEDICAO AI 3D - RELATORIO TECNICO OFFLINE',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.Text(
                'Data: $dateStr | Pag. ${context.pageNumber}/${context.pagesCount}',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 9,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: 0.7),
            ),
          ),
          child: pw.Text(
            _latinSafe(
              'Aviso metrologico: medicoes por camera e analises visuais sao assistivas e nao substituem instrumentos calibrados ou ensaios laboratoriais certificados.',
            ),
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 7.5,
              color: PdfColors.blueGrey600,
            ),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text(
            _latinSafe(reportTitle),
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 16,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),
          if (project != null)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.blueGrey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _latinSafe('Projeto: ${project.name}'),
                    style: pw.TextStyle(font: fontBold, fontSize: 11),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _latinSafe(
                      'TAG / Equipamento: ${project.equipmentTag.isEmpty ? "N/I" : project.equipmentTag} | Area/Cliente: ${project.locationOrClient.isEmpty ? "N/I" : project.locationOrClient}',
                    ),
                    style: pw.TextStyle(font: fontRegular, fontSize: 9.5),
                  ),
                  if (project.notes.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _latinSafe('Notas: ${project.notes}'),
                      style: pw.TextStyle(font: fontRegular, fontSize: 9),
                    ),
                  ],
                ],
              ),
            ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Total de registros incluidos: ${records.length}',
            style: pw.TextStyle(font: fontBold, fontSize: 10.5),
          ),
          pw.SizedBox(height: 8),
          for (final rec in records)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey400, width: 0.9),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          _latinSafe(
                            '[${rec.recordType.label}] ${rec.title}',
                          ),
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 11,
                            color: PdfColors.blueGrey900,
                          ),
                        ),
                      ),
                      pw.Text(
                        rec.updatedAtIso.split('T').first,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8.5,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                    ],
                  ),
                  if (rec.summary.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _latinSafe(rec.summary),
                      style: pw.TextStyle(font: fontRegular, fontSize: 9.5),
                    ),
                  ],
                  if (rec.measurementsText.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _latinSafe('Medidas e dados: ${rec.measurementsText}'),
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                    ),
                  ],
                  if (rec.technicalSource.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _latinSafe('Fonte tecnica / norma: ${rec.technicalSource}'),
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ],
                  if (rec.uncertaintyOrNote.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      _latinSafe('Incerteza / observacoes: ${rec.uncertaintyOrNote}'),
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ],
                  if (imageByRecordId.containsKey(rec.id)) ...[
                    pw.SizedBox(height: 6),
                    pw.Image(
                      imageByRecordId[rec.id]!,
                      height: 110,
                      fit: pw.BoxFit.contain,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<File> exportReportToFile({
    MaintenanceProject? project,
    required List<HistoryRecord> records,
    required String reportTitle,
  }) async {
    final bytes = await buildReportBytes(
      project: project,
      records: records,
      reportTitle: reportTitle,
    );
    final dir = await _directoryProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final base = (project?.name ?? reportTitle)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final file = File(
      p.join(
        dir.path,
        '${base.isEmpty ? 'relatorio_tecnico' : base}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
