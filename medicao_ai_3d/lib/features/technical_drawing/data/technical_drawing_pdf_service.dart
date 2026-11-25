import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/technical_drawing_geometry.dart';
import '../domain/technical_drawing_models.dart';

class TechnicalDrawingPdfService {
  TechnicalDrawingPdfService({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<Directory> Function() _directoryProvider;

  static Future<Directory> _defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'technical_drawings_pdf'));
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

  Future<Uint8List> buildPdfBytes(TechnicalDrawingSpec spec) async {
    final validation = TechnicalDrawingValidator.validate(spec);
    if (!validation.isValid) {
      throw StateError(
        'Não é possível gerar PDF com dimensões inválidas ou ausentes.',
      );
    }

    final doc = pw.Document(
      title: _latinSafe(
        spec.partName.isEmpty ? spec.partType.label : spec.partName,
      ),
      author: _latinSafe(
        spec.authorName.isEmpty ? 'MEDICAO AI 3D' : spec.authorName,
      ),
      creator: 'MEDICAO AI 3D',
    );

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final dimensions = TechnicalDrawingValidator.summarizeDimensions(spec);
    final mesh = Mesh3DBuilder.build(spec);
    final dateStr = DateTime.now().toIso8601String().split('T').first;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey900, width: 1.4),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // 2D orthographic views area
                      pw.Expanded(
                        flex: 3,
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.blueGrey300,
                              width: 0.8,
                            ),
                          ),
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                _latinSafe(
                                  'VISTAS ORTOGRAFICAS 2D COTADAS (${spec.unit.symbol}) - 1o DIEDRO',
                                ),
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 9,
                                  color: PdfColors.blueGrey900,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Expanded(
                                child: pw.CustomPaint(
                                  painter: (canvas, size) {
                                    _paintPdf2DViews(
                                      pdfContext: context,
                                      canvas: canvas,
                                      size: size,
                                      spec: spec,
                                      font: fontRegular,
                                      fontBold: fontBold,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // Isometric 3D + dimensions table
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                    color: PdfColors.blueGrey300,
                                    width: 0.8,
                                  ),
                                ),
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'PERSPECTIVA ISOMETRICA 3D',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 9,
                                        color: PdfColors.blueGrey900,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    pw.Expanded(
                                      child: pw.CustomPaint(
                                        painter: (canvas, size) {
                                          _paintPdf3DView(
                                            canvas: canvas,
                                            size: size,
                                            mesh: mesh,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 8),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                    color: PdfColors.blueGrey300,
                                    width: 0.8,
                                  ),
                                ),
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'COTAS E ESPECIFICACOES',
                                      style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: 9,
                                        color: PdfColors.blueGrey900,
                                      ),
                                    ),
                                    pw.SizedBox(height: 4),
                                    for (final item in dimensions)
                                      pw.Padding(
                                        padding: const pw.EdgeInsets.only(bottom: 2),
                                        child: pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text(
                                              _latinSafe('${item.symbol} - ${item.label}'),
                                              style: pw.TextStyle(
                                                font: fontRegular,
                                                fontSize: 8.5,
                                              ),
                                            ),
                                            pw.Text(
                                              _latinSafe(item.formattedValue),
                                              style: pw.TextStyle(
                                                font: fontBold,
                                                fontSize: 8.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                // Technical title block (Carimbo)
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blueGrey900, width: 1.0),
                    color: PdfColors.grey100,
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _latinSafe(
                                spec.partName.trim().isEmpty
                                    ? spec.partType.label.toUpperCase()
                                    : spec.partName.trim().toUpperCase(),
                              ),
                              style: pw.TextStyle(font: fontBold, fontSize: 11),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              _latinSafe(
                                'Tipo: ${spec.partType.label} | Material: ${spec.materialName}',
                              ),
                              style: pw.TextStyle(font: fontRegular, fontSize: 8.5),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _latinSafe(
                                'Codigo: ${spec.drawingCode.trim().isEmpty ? 'N/I' : spec.drawingCode.trim()}',
                              ),
                              style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                            ),
                            pw.Text(
                              _latinSafe(
                                'Tolerancia geral: ${spec.toleranceNote.trim().isEmpty ? 'ISO 2768-m' : spec.toleranceNote.trim()}',
                              ),
                              style: pw.TextStyle(font: fontRegular, fontSize: 8.5),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _latinSafe(
                                'Resp.: ${spec.authorName.trim().isEmpty ? 'MEDICAO AI 3D' : spec.authorName.trim()}',
                              ),
                              style: pw.TextStyle(font: fontRegular, fontSize: 8.5),
                            ),
                            pw.Text(
                              'Unidade: ${spec.unit.symbol} | Data: $dateStr',
                              style: pw.TextStyle(font: fontRegular, fontSize: 8.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  Future<File> exportPdfToFile(TechnicalDrawingSpec spec) async {
    final bytes = await buildPdfBytes(spec);
    final dir = await _directoryProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final rawName = spec.drawingCode.trim().isNotEmpty
        ? spec.drawingCode.trim()
        : (spec.partName.trim().isNotEmpty ? spec.partName.trim() : spec.partType.name);
    final safeName = rawName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName =
        '${safeName.isEmpty ? 'desenho_tecnico' : safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _paintPdf2DViews({
    required pw.Context pdfContext,
    required PdfGraphics canvas,
    required PdfPoint size,
    required TechnicalDrawingSpec spec,
    required pw.Font font,
    required pw.Font fontBold,
  }) {
    final pdfFont = font.getFont(pdfContext);
    final pdfFontBold = fontBold.getFont(pdfContext);

    // Note: in PDF coordinates, y=0 is bottom, y=size.y is top.
    final frontBox = PdfRect(14, size.y * 0.44, size.x * 0.56, size.y * 0.50);
    final topBox = PdfRect(14, 14, size.x * 0.56, size.y * 0.36);
    final sideBox = PdfRect(size.x * 0.64, size.y * 0.44, size.x * 0.32, size.y * 0.50);

    void drawDimLine(
      double x1,
      double y1,
      double x2,
      double y2,
      String text, {
      double textOffsetX = 0,
      double textOffsetY = 4,
    }) {
      canvas
        ..setStrokeColor(PdfColors.blue700)
        ..setLineWidth(0.7)
        ..drawLine(x1, y1, x2, y2)
        ..strokePath();
      final mx = (x1 + x2) / 2 + textOffsetX;
      final my = (y1 + y2) / 2 + textOffsetY;
      canvas
        ..setFillColor(PdfColors.blue900)
        ..drawString(pdfFontBold, 7.5, _latinSafe(text), mx - text.length * 1.8, my);
    }

    void drawCenterLine(double x1, double y1, double x2, double y2) {
      canvas
        ..saveContext()
        ..setStrokeColor(PdfColors.red600)
        ..setLineWidth(0.6)
        ..setLineDashPattern([6, 2, 1.5, 2])
        ..drawLine(x1, y1, x2, y2)
        ..strokePath()
        ..restoreContext();
    }

    void labelView(PdfRect box, String title) {
      canvas
        ..setFillColor(PdfColors.blueGrey700)
        ..drawString(pdfFont, 7.5, title, box.left, box.bottom - 10);
    }

    switch (spec.partType) {
      case DrawingPartType.hexBolt:
      case DrawingPartType.socketBolt:
        final d = spec.outerDiameterMm;
        final l = spec.lengthMm;
        final k = spec.headHeightMm;
        final w = spec.wrenchSizeMm;
        final totalL = k + l;
        final scale = math.min(
          (frontBox.width - 36) / totalL,
          (frontBox.height - 28) / w,
        );
        final cx = frontBox.left + frontBox.width / 2;
        final cy = frontBox.bottom + frontBox.height / 2;
        final startX = cx - (totalL * scale) / 2;
        final headW = k * scale;
        final headH = w * scale;
        final shankW = l * scale;
        final shankH = d * scale;

        // Front view: horizontal bolt
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.1)
          ..drawRect(startX, cy - headH / 2, headW, headH)
          ..drawRect(startX + headW, cy - shankH / 2, shankW, shankH)
          ..strokePath();

        // Thread zone lines
        final threadLen = math.min(spec.threadLengthMm, l) * scale;
        final threadX = startX + headW + (shankW - threadLen);
        canvas
          ..setLineWidth(0.6)
          ..drawLine(threadX, cy - shankH * 0.42, startX + headW + shankW, cy - shankH * 0.42)
          ..drawLine(threadX, cy + shankH * 0.42, startX + headW + shankW, cy + shankH * 0.42)
          ..strokePath();

        drawCenterLine(startX - 8, cy, startX + headW + shankW + 8, cy);
        drawDimLine(
          startX,
          cy + headH / 2 + 10,
          startX + headW,
          cy + headH / 2 + 10,
          'K=${spec.formatValue(spec.headHeight!)}',
          textOffsetY: 3,
        );
        drawDimLine(
          startX + headW,
          cy + headH / 2 + 10,
          startX + headW + shankW,
          cy + headH / 2 + 10,
          'L=${spec.formatValue(spec.length!)}',
          textOffsetY: 3,
        );
        drawDimLine(
          startX + headW + shankW + 10,
          cy - shankH / 2,
          startX + headW + shankW + 10,
          cy + shankH / 2,
          'D=${spec.formatValue(spec.outerDiameter!)}',
          textOffsetX: 4,
          textOffsetY: -2,
        );
        labelView(frontBox, 'VISTA FRONTAL');

        // Side view (head profile)
        final sideScale = math.min(
          (sideBox.width - 28) / w,
          (sideBox.height - 28) / w,
        );
        final sx = sideBox.left + sideBox.width / 2;
        final sy = sideBox.bottom + sideBox.height / 2;
        final rHead = (w * sideScale) / 2;
        final rShank = (d * sideScale) / 2;
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.1)
          ..drawEllipse(sx, sy, rHead, rHead)
          ..strokePath()
          ..setLineWidth(0.7)
          ..drawEllipse(sx, sy, rShank, rShank)
          ..strokePath();
        drawCenterLine(sx - rHead - 6, sy, sx + rHead + 6, sy);
        drawCenterLine(sx, sy - rHead - 6, sx, sy + rHead + 6);
        drawDimLine(
          sx - rHead,
          sy - rHead - 10,
          sx + rHead,
          sy - rHead - 10,
          '${spec.partType == DrawingPartType.hexBolt ? "S" : "Dk"}=${spec.formatValue(spec.wrenchSize!)}',
          textOffsetY: -9,
        );
        labelView(sideBox, 'VISTA LATERAL');
        labelView(topBox, 'VISTA SUPERIOR (PROPORCIONAL)');
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.0)
          ..drawRect(
            cx - (totalL * scale) / 2,
            topBox.bottom + topBox.height / 2 - headH / 2,
            headW,
            headH,
          )
          ..drawRect(
            cx - (totalL * scale) / 2 + headW,
            topBox.bottom + topBox.height / 2 - shankH / 2,
            shankW,
            shankH,
          )
          ..strokePath();
        drawCenterLine(
          cx - (totalL * scale) / 2 - 8,
          topBox.bottom + topBox.height / 2,
          cx + (totalL * scale) / 2 + 8,
          topBox.bottom + topBox.height / 2,
        );

      case DrawingPartType.shaft:
      case DrawingPartType.tube:
        final d1 = spec.outerDiameterMm;
        final l = spec.lengthMm;
        final scale = math.min(
          (frontBox.width - 36) / l,
          (frontBox.height - 28) / d1,
        );
        final cx = frontBox.left + frontBox.width / 2;
        final cy = frontBox.bottom + frontBox.height / 2;
        final rectW = l * scale;
        final rectH = d1 * scale;
        final leftX = cx - rectW / 2;

        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.1)
          ..drawRect(leftX, cy - rectH / 2, rectW, rectH)
          ..strokePath();

        if (spec.partType == DrawingPartType.tube) {
          final innerH = spec.innerDiameterMm * scale;
          canvas
            ..saveContext()
            ..setLineDashPattern([4, 2])
            ..setLineWidth(0.8)
            ..drawLine(leftX, cy - innerH / 2, leftX + rectW, cy - innerH / 2)
            ..drawLine(leftX, cy + innerH / 2, leftX + rectW, cy + innerH / 2)
            ..strokePath()
            ..restoreContext();
        } else if (spec.stepDiameterMm > 0 && spec.stepLengthMm > 0) {
          final stepW = math.min(spec.stepLengthMm, l * 0.9) * scale;
          final stepH = spec.stepDiameterMm * scale;
          canvas
            ..setLineWidth(0.9)
            ..drawRect(leftX + rectW - stepW, cy - stepH / 2, stepW, stepH)
            ..strokePath();
        }

        drawCenterLine(leftX - 8, cy, leftX + rectW + 8, cy);
        drawDimLine(
          leftX,
          cy + rectH / 2 + 10,
          leftX + rectW,
          cy + rectH / 2 + 10,
          'L=${spec.formatValue(spec.length!)}',
          textOffsetY: 3,
        );
        drawDimLine(
          leftX + rectW + 10,
          cy - rectH / 2,
          leftX + rectW + 10,
          cy + rectH / 2,
          'De=${spec.formatValue(spec.outerDiameter!)}',
          textOffsetX: 4,
          textOffsetY: -2,
        );
        labelView(frontBox, 'VISTA FRONTAL');

        // Side circle
        final sideScale = math.min(
          (sideBox.width - 28) / d1,
          (sideBox.height - 28) / d1,
        );
        final sx = sideBox.left + sideBox.width / 2;
        final sy = sideBox.bottom + sideBox.height / 2;
        final rOut = (d1 * sideScale) / 2;
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.1)
          ..drawEllipse(sx, sy, rOut, rOut)
          ..strokePath();
        if (spec.partType == DrawingPartType.tube) {
          final rIn = (spec.innerDiameterMm * sideScale) / 2;
          canvas
            ..setLineWidth(0.9)
            ..drawEllipse(sx, sy, rIn, rIn)
            ..strokePath();
          drawDimLine(
            sx - rIn,
            sy - rOut - 10,
            sx + rIn,
            sy - rOut - 10,
            'Di=${spec.formatValue(spec.innerDiameter!)}',
            textOffsetY: -9,
          );
        }
        drawCenterLine(sx - rOut - 6, sy, sx + rOut + 6, sy);
        drawCenterLine(sx, sy - rOut - 6, sx, sy + rOut + 6);
        labelView(sideBox, 'VISTA LATERAL');

      case DrawingPartType.plate:
        final c = spec.lengthMm;
        final w = spec.widthMm;
        final e = spec.thicknessMm;
        final scaleFront = math.min(
          (frontBox.width - 36) / c,
          (frontBox.height - 28) / w,
        );
        final fw = c * scaleFront;
        final fh = w * scaleFront;
        final fx = frontBox.left + (frontBox.width - fw) / 2;
        final fy = frontBox.bottom + (frontBox.height - fh) / 2;
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.1)
          ..drawRect(fx, fy, fw, fh)
          ..strokePath();
        if (spec.holeDiameterMm > 0) {
          final rHole = (spec.holeDiameterMm * scaleFront) / 2;
          canvas
            ..drawEllipse(fx + fw / 2, fy + fh / 2, rHole, rHole)
            ..strokePath();
          drawCenterLine(fx + fw / 2, fy - 4, fx + fw / 2, fy + fh + 4);
          drawCenterLine(fx - 4, fy + fh / 2, fx + fw + 4, fy + fh / 2);
        }
        drawDimLine(
          fx,
          fy + fh + 8,
          fx + fw,
          fy + fh + 8,
          'C=${spec.formatValue(spec.length!)}',
          textOffsetY: 3,
        );
        drawDimLine(
          fx + fw + 8,
          fy,
          fx + fw + 8,
          fy + fh,
          'W=${spec.formatValue(spec.width!)}',
          textOffsetX: 4,
          textOffsetY: -2,
        );
        labelView(frontBox, 'VISTA SUPERIOR / PLANTA');

        // Top box = side elevation showing thickness E
        final scaleTop = math.min(
          (topBox.width - 36) / c,
          (topBox.height - 24) / math.max(e, c * 0.12),
        );
        final tw = c * scaleTop;
        final th = math.max(8.0, e * scaleTop);
        final tx = topBox.left + (topBox.width - tw) / 2;
        final ty = topBox.bottom + (topBox.height - th) / 2;
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1.1)
          ..drawRect(tx, ty, tw, th)
          ..strokePath();
        drawDimLine(
          tx + tw + 8,
          ty,
          tx + tw + 8,
          ty + th,
          'E=${spec.formatValue(spec.heightOrThickness!)}',
          textOffsetX: 4,
          textOffsetY: -2,
        );
        labelView(topBox, 'VISTA FRONTAL (ESPESSURA)');
    }
  }

  void _paintPdf3DView({
    required PdfGraphics canvas,
    required PdfPoint size,
    required Mesh3D mesh,
  }) {
    const yaw = 0.65;
    const pitch = 0.45;
    final scale = math.min(size.x, size.y) * 0.72 / mesh.maxExtentMm;
    final cx = size.x / 2;
    final cy = size.y / 2;

    final transformed = mesh.vertices
        .map((v) => v.rotateXY(yaw, pitch))
        .toList(growable: false);

    // Draw edges cleanly in vector PDF
    canvas
      ..setStrokeColor(PdfColors.blueGrey800)
      ..setLineWidth(0.65);

    for (final edge in mesh.edges) {
      final a = transformed[edge.a];
      final b = transformed[edge.b];
      canvas
        ..setStrokeColor(
          edge.accent ? PdfColors.blue700 : PdfColors.blueGrey900,
        )
        ..drawLine(
          cx + a.x * scale,
          cy + a.y * scale,
          cx + b.x * scale,
          cy + b.y * scale,
        )
        ..strokePath();
    }
  }
}
