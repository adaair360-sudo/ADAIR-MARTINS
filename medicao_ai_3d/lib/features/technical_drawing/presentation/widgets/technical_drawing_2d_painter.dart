import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/technical_drawing_models.dart';

enum OrthographicViewFocus {
  all('Todas as vistas'),
  front('Vista frontal'),
  side('Vista lateral');

  const OrthographicViewFocus(this.label);
  final String label;
}

class TechnicalDrawing2DCanvas extends StatelessWidget {
  const TechnicalDrawing2DCanvas({
    super.key,
    required this.spec,
    this.focus = OrthographicViewFocus.all,
    this.showGrid = true,
    this.showCenterLines = true,
  });

  final TechnicalDrawingSpec spec;
  final OrthographicViewFocus focus;
  final bool showGrid;
  final bool showCenterLines;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A1926) : const Color(0xFFF6FAFE),
          border: Border.all(
            color: isDark ? const Color(0xFF23425C) : const Color(0xFFB5C9DC),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AspectRatio(
          aspectRatio: 1.45,
          child: CustomPaint(
            painter: TechnicalDrawing2DPainter(
              spec: spec,
              focus: focus,
              showGrid: showGrid,
              showCenterLines: showCenterLines,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

class TechnicalDrawing2DPainter extends CustomPainter {
  TechnicalDrawing2DPainter({
    required this.spec,
    required this.focus,
    required this.showGrid,
    required this.showCenterLines,
    required this.isDark,
  });

  final TechnicalDrawingSpec spec;
  final OrthographicViewFocus focus;
  final bool showGrid;
  final bool showCenterLines;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    final primaryStroke = Paint()
      ..color = isDark ? const Color(0xFFE6F4FA) : const Color(0xFF0F2942)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final secondaryStroke = Paint()
      ..color = isDark ? const Color(0xFF8AB4CE) : const Color(0xFF3E5B76)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final dimPaint = Paint()
      ..color = isDark ? const Color(0xFF4DD0E1) : const Color(0xFF0277BD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final centerPaint = Paint()
      ..color = isDark ? const Color(0xFFFF8A65) : const Color(0xFFD84315)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Rect frontBox;
    final Rect sideBox;
    final Rect topBox;

    if (focus == OrthographicViewFocus.front) {
      frontBox = Rect.fromLTWH(
        24,
        24,
        size.width - 48,
        size.height - 48,
      );
      sideBox = Rect.zero;
      topBox = Rect.zero;
    } else if (focus == OrthographicViewFocus.side) {
      frontBox = Rect.zero;
      sideBox = Rect.fromLTWH(
        24,
        24,
        size.width - 48,
        size.height - 48,
      );
      topBox = Rect.zero;
    } else {
      frontBox = Rect.fromLTWH(
        18,
        22,
        size.width * 0.56,
        size.height * 0.48,
      );
      sideBox = Rect.fromLTWH(
        size.width * 0.62,
        22,
        size.width * 0.34,
        size.height * 0.48,
      );
      topBox = Rect.fromLTWH(
        18,
        size.height * 0.56,
        size.width * 0.56,
        size.height * 0.36,
      );
    }

    switch (spec.partType) {
      case DrawingPartType.hexBolt:
      case DrawingPartType.socketBolt:
        _paintBolt(
          canvas: canvas,
          frontBox: frontBox,
          sideBox: sideBox,
          topBox: topBox,
          primary: primaryStroke,
          secondary: secondaryStroke,
          dimPaint: dimPaint,
          centerPaint: centerPaint,
        );
      case DrawingPartType.shaft:
      case DrawingPartType.tube:
        _paintCylinderOrTube(
          canvas: canvas,
          frontBox: frontBox,
          sideBox: sideBox,
          topBox: topBox,
          primary: primaryStroke,
          secondary: secondaryStroke,
          dimPaint: dimPaint,
          centerPaint: centerPaint,
        );
      case DrawingPartType.plate:
        _paintPlate(
          canvas: canvas,
          frontBox: frontBox,
          sideBox: sideBox,
          topBox: topBox,
          primary: primaryStroke,
          secondary: secondaryStroke,
          dimPaint: dimPaint,
          centerPaint: centerPaint,
        );
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = isDark
          ? const Color(0xFF142B3E)
          : const Color(0xFFE3EEF7)
      ..strokeWidth = 0.7;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
  }

  void _drawDashLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dash = 6,
    double gap = 4,
  }) {
    final delta = p2 - p1;
    final len = delta.distance;
    if (len < 1) return;
    final dir = delta / len;
    var dist = 0.0;
    while (dist < len) {
      final end = math.min(dist + dash, len);
      canvas.drawLine(p1 + dir * dist, p1 + dir * end, paint);
      dist += dash + gap;
    }
  }

  void _drawCenterLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    if (!showCenterLines) return;
    _drawDashLine(canvas, p1, p2, paint, dash: 10, gap: 4);
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position, {
    Color? color,
    double fontSize = 10.5,
    FontWeight weight = FontWeight.w700,
    bool centerHorizontal = true,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ??
              (isDark ? const Color(0xFF9EC3DC) : const Color(0xFF23425C)),
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = centerHorizontal ? position.dx - painter.width / 2 : position.dx;
    painter.paint(canvas, Offset(dx, position.dy));
  }

  void _drawDimension(
    Canvas canvas, {
    required Offset a,
    required Offset b,
    required String label,
    required Paint paint,
    double offset = 18,
    bool vertical = false,
  }) {
    final dimColor = paint.color;
    if (!vertical) {
      final y = a.dy + offset;
      canvas.drawLine(a, Offset(a.dx, y), paint..strokeWidth = 0.8);
      canvas.drawLine(b, Offset(b.dx, y), paint..strokeWidth = 0.8);
      final pA = Offset(a.dx, y);
      final pB = Offset(b.dx, y);
      canvas.drawLine(pA, pB, paint..strokeWidth = 1.2);
      _drawArrow(canvas, pA, const Offset(1, 0), dimColor);
      _drawArrow(canvas, pB, const Offset(-1, 0), dimColor);
      _drawLabel(
        canvas,
        label,
        Offset((pA.dx + pB.dx) / 2, y + (offset < 0 ? -14 : 3)),
        color: dimColor,
        fontSize: 10,
      );
    } else {
      final x = a.dx + offset;
      canvas.drawLine(a, Offset(x, a.dy), paint..strokeWidth = 0.8);
      canvas.drawLine(b, Offset(x, b.dy), paint..strokeWidth = 0.8);
      final pA = Offset(x, a.dy);
      final pB = Offset(x, b.dy);
      canvas.drawLine(pA, pB, paint..strokeWidth = 1.2);
      _drawArrow(canvas, pA, const Offset(0, 1), dimColor);
      _drawArrow(canvas, pB, const Offset(0, -1), dimColor);
      _drawLabel(
        canvas,
        label,
        Offset(x + (offset < 0 ? -42 : 6), (pA.dy + pB.dy) / 2 - 6),
        color: dimColor,
        fontSize: 10,
        centerHorizontal: false,
      );
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Offset dir, Color color) {
    final perp = Offset(-dir.dy, dir.dx);
    const len = 6.0;
    const width = 2.6;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx + dir.dx * len + perp.dx * width,
        tip.dy + dir.dy * len + perp.dy * width,
      )
      ..lineTo(
        tip.dx + dir.dx * len - perp.dx * width,
        tip.dy + dir.dy * len - perp.dy * width,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintBolt({
    required Canvas canvas,
    required Rect frontBox,
    required Rect sideBox,
    required Rect topBox,
    required Paint primary,
    required Paint secondary,
    required Paint dimPaint,
    required Paint centerPaint,
  }) {
    final d = spec.outerDiameterMm;
    final l = spec.lengthMm;
    final k = spec.headHeightMm;
    final w = spec.wrenchSizeMm;
    final total = k + l;

    if (!frontBox.isEmpty) {
      final scale = math.min(
        (frontBox.width - 76) / total,
        (frontBox.height - 54) / w,
      );
      final cy = frontBox.center.dy;
      final headW = k * scale;
      final headH = w * scale;
      final shankW = l * scale;
      final shankH = d * scale;
      final startX = frontBox.center.dx - (headW + shankW) / 2;

      // Head
      final headRect = Rect.fromLTWH(startX, cy - headH / 2, headW, headH);
      canvas.drawRect(headRect, primary);
      if (spec.partType == DrawingPartType.hexBolt) {
        // Hex facets
        canvas.drawLine(
          Offset(startX, cy - headH * 0.25),
          Offset(startX + headW, cy - headH * 0.25),
          secondary,
        );
        canvas.drawLine(
          Offset(startX, cy + headH * 0.25),
          Offset(startX + headW, cy + headH * 0.25),
          secondary,
        );
      }

      // Shank
      final shankRect = Rect.fromLTWH(
        startX + headW,
        cy - shankH / 2,
        shankW,
        shankH,
      );
      canvas.drawRect(shankRect, primary);

      // Thread crest representation
      final tLen = math.min(spec.threadLengthMm, l) * scale;
      final tStartX = startX + headW + (shankW - tLen);
      canvas.drawLine(
        Offset(tStartX, cy - shankH * 0.41),
        Offset(startX + headW + shankW, cy - shankH * 0.41),
        secondary,
      );
      canvas.drawLine(
        Offset(tStartX, cy + shankH * 0.41),
        Offset(startX + headW + shankW, cy + shankH * 0.41),
        secondary,
      );

      _drawCenterLine(
        canvas,
        Offset(startX - 10, cy),
        Offset(startX + headW + shankW + 10, cy),
        centerPaint,
      );

      _drawDimension(
        canvas,
        a: Offset(startX, cy - headH / 2),
        b: Offset(startX + headW, cy - headH / 2),
        label: 'K=${spec.formatValue(spec.headHeight!)}',
        paint: dimPaint,
        offset: -16,
      );
      _drawDimension(
        canvas,
        a: Offset(startX + headW, cy - headH / 2),
        b: Offset(startX + headW + shankW, cy - headH / 2),
        label: 'L=${spec.formatValue(spec.length!)}',
        paint: dimPaint,
        offset: -16,
      );
      _drawDimension(
        canvas,
        a: Offset(startX + headW + shankW, cy - shankH / 2),
        b: Offset(startX + headW + shankW, cy + shankH / 2),
        label: 'D=${spec.formatValue(spec.outerDiameter!)}',
        paint: dimPaint,
        offset: 14,
        vertical: true,
      );

      _drawLabel(
        canvas,
        'VISTA FRONTAL',
        Offset(frontBox.center.dx, frontBox.bottom - 12),
      );
    }

    if (!sideBox.isEmpty) {
      final sideScale = math.min(
        (sideBox.width - 56) / w,
        (sideBox.height - 56) / w,
      );
      final c = sideBox.center;
      final rHead = (w * sideScale) / 2;
      final rShank = (d * sideScale) / 2;
      if (spec.partType == DrawingPartType.hexBolt) {
        final circumR = rHead / math.cos(math.pi / 6);
        final hex = Path();
        for (var i = 0; i < 6; i++) {
          final ang = math.pi / 6 + (2 * math.pi * i / 6);
          final pt = Offset(c.dx + circumR * math.cos(ang), c.dy + circumR * math.sin(ang));
          if (i == 0) {
            hex.moveTo(pt.dx, pt.dy);
          } else {
            hex.lineTo(pt.dx, pt.dy);
          }
        }
        hex.close();
        canvas.drawPath(hex, primary);
        canvas.drawCircle(c, rHead, secondary);
      } else {
        canvas.drawCircle(c, rHead, primary);
        final hex = Path();
        final socketR = rShank * 0.84;
        for (var i = 0; i < 6; i++) {
          final ang = 2 * math.pi * i / 6;
          final pt = Offset(c.dx + socketR * math.cos(ang), c.dy + socketR * math.sin(ang));
          if (i == 0) {
            hex.moveTo(pt.dx, pt.dy);
          } else {
            hex.lineTo(pt.dx, pt.dy);
          }
        }
        hex.close();
        canvas.drawPath(hex, secondary);
      }
      _drawCenterLine(
        canvas,
        Offset(c.dx - rHead - 8, c.dy),
        Offset(c.dx + rHead + 8, c.dy),
        centerPaint,
      );
      _drawCenterLine(
        canvas,
        Offset(c.dx, c.dy - rHead - 8),
        Offset(c.dx, c.dy + rHead + 8),
        centerPaint,
      );
      _drawDimension(
        canvas,
        a: Offset(c.dx - rHead, c.dy + rHead),
        b: Offset(c.dx + rHead, c.dy + rHead),
        label: '${spec.partType == DrawingPartType.hexBolt ? "S" : "Dk"}=${spec.formatValue(spec.wrenchSize!)}',
        paint: dimPaint,
        offset: 14,
      );
      _drawLabel(
        canvas,
        'VISTA LATERAL',
        Offset(sideBox.center.dx, sideBox.bottom - 12),
      );
    }

    if (!topBox.isEmpty) {
      final scale = math.min(
        (topBox.width - 76) / total,
        (topBox.height - 38) / w,
      );
      final cy = topBox.center.dy - 4;
      final headW = k * scale;
      final headH = w * scale;
      final shankW = l * scale;
      final shankH = d * scale;
      final startX = topBox.center.dx - (headW + shankW) / 2;

      canvas.drawRect(Rect.fromLTWH(startX, cy - headH / 2, headW, headH), primary);
      canvas.drawRect(
        Rect.fromLTWH(startX + headW, cy - shankH / 2, shankW, shankH),
        primary,
      );
      _drawCenterLine(
        canvas,
        Offset(startX - 8, cy),
        Offset(startX + headW + shankW + 8, cy),
        centerPaint,
      );
      _drawLabel(
        canvas,
        'VISTA SUPERIOR',
        Offset(topBox.center.dx, topBox.bottom - 10),
      );
    }
  }

  void _paintCylinderOrTube({
    required Canvas canvas,
    required Rect frontBox,
    required Rect sideBox,
    required Rect topBox,
    required Paint primary,
    required Paint secondary,
    required Paint dimPaint,
    required Paint centerPaint,
  }) {
    final d = spec.outerDiameterMm;
    final l = spec.lengthMm;

    if (!frontBox.isEmpty) {
      final scale = math.min(
        (frontBox.width - 76) / l,
        (frontBox.height - 56) / d,
      );
      final rectW = l * scale;
      final rectH = d * scale;
      final cx = frontBox.center.dx;
      final cy = frontBox.center.dy;
      final left = cx - rectW / 2;
      canvas.drawRect(Rect.fromLTWH(left, cy - rectH / 2, rectW, rectH), primary);

      if (spec.partType == DrawingPartType.tube) {
        final innerH = spec.innerDiameterMm * scale;
        _drawDashLine(
          canvas,
          Offset(left, cy - innerH / 2),
          Offset(left + rectW, cy - innerH / 2),
          secondary,
        );
        _drawDashLine(
          canvas,
          Offset(left, cy + innerH / 2),
          Offset(left + rectW, cy + innerH / 2),
          secondary,
        );
      } else if (spec.stepDiameterMm > 0 && spec.stepLengthMm > 0) {
        final sW = math.min(spec.stepLengthMm, l * 0.9) * scale;
        final sH = spec.stepDiameterMm * scale;
        canvas.drawRect(
          Rect.fromLTWH(left + rectW - sW, cy - sH / 2, sW, sH),
          secondary,
        );
      }

      _drawCenterLine(
        canvas,
        Offset(left - 10, cy),
        Offset(left + rectW + 10, cy),
        centerPaint,
      );
      _drawDimension(
        canvas,
        a: Offset(left, cy - rectH / 2),
        b: Offset(left + rectW, cy - rectH / 2),
        label: 'L=${spec.formatValue(spec.length!)}',
        paint: dimPaint,
        offset: -16,
      );
      _drawDimension(
        canvas,
        a: Offset(left + rectW, cy - rectH / 2),
        b: Offset(left + rectW, cy + rectH / 2),
        label: 'De=${spec.formatValue(spec.outerDiameter!)}',
        paint: dimPaint,
        offset: 12,
        vertical: true,
      );
      _drawLabel(
        canvas,
        'VISTA FRONTAL',
        Offset(frontBox.center.dx, frontBox.bottom - 12),
      );
    }

    if (!sideBox.isEmpty) {
      final sideScale = math.min(
        (sideBox.width - 56) / d,
        (sideBox.height - 56) / d,
      );
      final c = sideBox.center;
      final rOut = (d * sideScale) / 2;
      canvas.drawCircle(c, rOut, primary);
      if (spec.partType == DrawingPartType.tube) {
        final rIn = (spec.innerDiameterMm * sideScale) / 2;
        canvas.drawCircle(c, rIn, primary);
        _drawDimension(
          canvas,
          a: Offset(c.dx - rIn, c.dy + rOut),
          b: Offset(c.dx + rIn, c.dy + rOut),
          label: 'Di=${spec.formatValue(spec.innerDiameter!)}',
          paint: dimPaint,
          offset: 14,
        );
      }
      _drawCenterLine(
        canvas,
        Offset(c.dx - rOut - 8, c.dy),
        Offset(c.dx + rOut + 8, c.dy),
        centerPaint,
      );
      _drawCenterLine(
        canvas,
        Offset(c.dx, c.dy - rOut - 8),
        Offset(c.dx, c.dy + rOut + 8),
        centerPaint,
      );
      _drawLabel(
        canvas,
        'VISTA LATERAL',
        Offset(sideBox.center.dx, sideBox.bottom - 12),
      );
    }

    if (!topBox.isEmpty) {
      final scale = math.min(
        (topBox.width - 76) / l,
        (topBox.height - 38) / d,
      );
      final rectW = l * scale;
      final rectH = d * scale;
      final left = topBox.center.dx - rectW / 2;
      final cy = topBox.center.dy - 4;
      canvas.drawRect(Rect.fromLTWH(left, cy - rectH / 2, rectW, rectH), primary);
      _drawCenterLine(
        canvas,
        Offset(left - 10, cy),
        Offset(left + rectW + 10, cy),
        centerPaint,
      );
      _drawLabel(
        canvas,
        'VISTA SUPERIOR',
        Offset(topBox.center.dx, topBox.bottom - 10),
      );
    }
  }

  void _paintPlate({
    required Canvas canvas,
    required Rect frontBox,
    required Rect sideBox,
    required Rect topBox,
    required Paint primary,
    required Paint secondary,
    required Paint dimPaint,
    required Paint centerPaint,
  }) {
    final c = spec.lengthMm;
    final w = spec.widthMm;
    final e = spec.thicknessMm;

    if (!frontBox.isEmpty) {
      final scale = math.min(
        (frontBox.width - 76) / c,
        (frontBox.height - 54) / w,
      );
      final rw = c * scale;
      final rh = w * scale;
      final left = frontBox.center.dx - rw / 2;
      final top = frontBox.center.dy - rh / 2;
      canvas.drawRect(Rect.fromLTWH(left, top, rw, rh), primary);
      if (spec.holeDiameterMm > 0) {
        final hr = (spec.holeDiameterMm * scale) / 2;
        canvas.drawCircle(frontBox.center, hr, primary);
        _drawCenterLine(
          canvas,
          Offset(frontBox.center.dx - hr - 8, frontBox.center.dy),
          Offset(frontBox.center.dx + hr + 8, frontBox.center.dy),
          centerPaint,
        );
        _drawCenterLine(
          canvas,
          Offset(frontBox.center.dx, frontBox.center.dy - hr - 8),
          Offset(frontBox.center.dx, frontBox.center.dy + hr + 8),
          centerPaint,
        );
      }
      _drawDimension(
        canvas,
        a: Offset(left, top),
        b: Offset(left + rw, top),
        label: 'C=${spec.formatValue(spec.length!)}',
        paint: dimPaint,
        offset: -16,
      );
      _drawDimension(
        canvas,
        a: Offset(left + rw, top),
        b: Offset(left + rw, top + rh),
        label: 'W=${spec.formatValue(spec.width!)}',
        paint: dimPaint,
        offset: 12,
        vertical: true,
      );
      _drawLabel(
        canvas,
        'PLANTA / VISTA SUPERIOR',
        Offset(frontBox.center.dx, frontBox.bottom - 12),
      );
    }

    if (!topBox.isEmpty) {
      final scale = math.min(
        (topBox.width - 76) / c,
        (topBox.height - 38) / math.max(e, c * 0.14),
      );
      final rw = c * scale;
      final rh = math.max(12.0, e * scale);
      final left = topBox.center.dx - rw / 2;
      final top = topBox.center.dy - rh / 2 - 4;
      canvas.drawRect(Rect.fromLTWH(left, top, rw, rh), primary);
      if (spec.holeDiameterMm > 0) {
        final hr = (spec.holeDiameterMm * scale) / 2;
        _drawDashLine(
          canvas,
          Offset(topBox.center.dx - hr, top),
          Offset(topBox.center.dx - hr, top + rh),
          secondary,
        );
        _drawDashLine(
          canvas,
          Offset(topBox.center.dx + hr, top),
          Offset(topBox.center.dx + hr, top + rh),
          secondary,
        );
      }
      _drawDimension(
        canvas,
        a: Offset(left + rw, top),
        b: Offset(left + rw, top + rh),
        label: 'E=${spec.formatValue(spec.heightOrThickness!)}',
        paint: dimPaint,
        offset: 12,
        vertical: true,
      );
      _drawLabel(
        canvas,
        'ELEVAÇÃO FRONTAL',
        Offset(topBox.center.dx, topBox.bottom - 10),
      );
    }

    if (!sideBox.isEmpty) {
      final scale = math.min(
        (sideBox.width - 56) / math.max(e, w * 0.14),
        (sideBox.height - 54) / w,
      );
      final rw = math.max(12.0, e * scale);
      final rh = w * scale;
      final left = sideBox.center.dx - rw / 2;
      final top = sideBox.center.dy - rh / 2;
      canvas.drawRect(Rect.fromLTWH(left, top, rw, rh), primary);
      _drawLabel(
        canvas,
        'VISTA LATERAL',
        Offset(sideBox.center.dx, sideBox.bottom - 12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TechnicalDrawing2DPainter oldDelegate) {
    return oldDelegate.spec != spec ||
        oldDelegate.focus != focus ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showCenterLines != showCenterLines ||
        oldDelegate.isDark != isDark;
  }
}
