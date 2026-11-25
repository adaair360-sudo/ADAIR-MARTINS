import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/camera_measurement_models.dart';

class MeasurementPhotoCanvas extends StatefulWidget {
  const MeasurementPhotoCanvas({
    super.key,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.analysis,
    required this.showOverlayImage,
    required this.showContours,
    required this.calibrationP1,
    required this.calibrationP2,
    required this.pendingPoint,
    required this.marks,
    required this.onImageTapped,
  });

  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final ContourAnalysisResult? analysis;
  final bool showOverlayImage;
  final bool showContours;
  final ImagePoint? calibrationP1;
  final ImagePoint? calibrationP2;
  final ImagePoint? pendingPoint;
  final List<MeasurementMark> marks;
  final ValueChanged<ImagePoint> onImageTapped;

  @override
  State<MeasurementPhotoCanvas> createState() => _MeasurementPhotoCanvasState();
}

class _MeasurementPhotoCanvasState extends State<MeasurementPhotoCanvas> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  String get _effectiveImagePath {
    final overlay = widget.analysis?.overlayPath;
    if (widget.showOverlayImage &&
        overlay != null &&
        File(overlay).existsSync()) {
      return overlay;
    }
    return widget.imagePath;
  }

  Rect _fittedImageRect(Size boxSize) {
    final imgW = math.max(1, widget.imageWidth).toDouble();
    final imgH = math.max(1, widget.imageHeight).toDouble();
    final scale = math.min(boxSize.width / imgW, boxSize.height / imgH);
    final drawW = imgW * scale;
    final drawH = imgH * scale;
    final dx = (boxSize.width - drawW) / 2.0;
    final dy = (boxSize.height - drawH) / 2.0;
    return Rect.fromLTWH(dx, dy, drawW, drawH);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: const Color(0xFF0A0F14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final imageRect = _fittedImageRect(size);

              return Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final local = details.localPosition;
                        if (!imageRect.contains(local)) {
                          return;
                        }
                        final relX =
                            (local.dx - imageRect.left) / imageRect.width;
                        final relY =
                            (local.dy - imageRect.top) / imageRect.height;
                        final px = (relX * widget.imageWidth).clamp(
                          0.0,
                          widget.imageWidth.toDouble(),
                        );
                        final py = (relY * widget.imageHeight).clamp(
                          0.0,
                          widget.imageHeight.toDouble(),
                        );
                        widget.onImageTapped(ImagePoint(px, py));
                      },
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_effectiveImagePath),
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                            CustomPaint(
                              painter: _MeasurementOverlayPainter(
                                imageRect: imageRect,
                                imageWidth: widget.imageWidth,
                                imageHeight: widget.imageHeight,
                                analysis: widget.analysis,
                                showContours:
                                    widget.showContours &&
                                    !widget.showOverlayImage,
                                calibrationP1: widget.calibrationP1,
                                calibrationP2: widget.calibrationP2,
                                pendingPoint: widget.pendingPoint,
                                marks: widget.marks,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        tooltip: 'Resetar zoom',
                        icon: const Icon(
                          Icons.zoom_out_map_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          _transformController.value = Matrix4.identity();
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MeasurementOverlayPainter extends CustomPainter {
  _MeasurementOverlayPainter({
    required this.imageRect,
    required this.imageWidth,
    required this.imageHeight,
    required this.analysis,
    required this.showContours,
    required this.calibrationP1,
    required this.calibrationP2,
    required this.pendingPoint,
    required this.marks,
  });

  final Rect imageRect;
  final int imageWidth;
  final int imageHeight;
  final ContourAnalysisResult? analysis;
  final bool showContours;
  final ImagePoint? calibrationP1;
  final ImagePoint? calibrationP2;
  final ImagePoint? pendingPoint;
  final List<MeasurementMark> marks;

  Offset _toCanvas(ImagePoint pt) {
    final sx = imageRect.width / math.max(1, imageWidth);
    final sy = imageRect.height / math.max(1, imageHeight);
    return Offset(imageRect.left + pt.x * sx, imageRect.top + pt.y * sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showContours && analysis != null) {
      final contourPaint = Paint()
        ..color = const Color(0xFF26A69A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (final contour in analysis!.contours) {
        if (contour.boxPoints.length == 4) {
          final path = Path();
          final p0 = _toCanvas(contour.boxPoints[0]);
          path.moveTo(p0.dx, p0.dy);
          for (var i = 1; i < 4; i++) {
            final pi = _toCanvas(contour.boxPoints[i]);
            path.lineTo(pi.dx, pi.dy);
          }
          path.close();
          canvas.drawPath(path, contourPaint);
        }
      }

      final circlePaint = Paint()
        ..color = const Color(0xFF42A5F5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      final sx = imageRect.width / math.max(1, imageWidth);
      for (final circle in analysis!.circles) {
        final center = _toCanvas(ImagePoint(circle.centerX, circle.centerY));
        canvas.drawCircle(center, (circle.diameterPx / 2.0) * sx, circlePaint);
      }
    }

    if (calibrationP1 != null && calibrationP2 != null) {
      final a = _toCanvas(calibrationP1!);
      final b = _toCanvas(calibrationP2!);
      _drawSegment(
        canvas,
        a,
        b,
        const Color(0xFFFFB300),
        'REF',
      );
    }

    for (final mark in marks) {
      final a = _toCanvas(mark.p1);
      final b = _toCanvas(mark.p2);
      final label = mark.millimeters != null
          ? '${mark.millimeters!.toStringAsFixed(1)} mm'
          : '${mark.pixelDistance.toStringAsFixed(0)} px (N/C)';
      final color = mark.millimeters != null
          ? const Color(0xFF00E5FF)
          : const Color(0xFFFF7043);
      _drawSegment(canvas, a, b, color, '${mark.kind.label}: $label');
    }

    if (pendingPoint != null) {
      final pt = _toCanvas(pendingPoint!);
      final ringPaint = Paint()
        ..color = const Color(0xFFFFEA00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;
      canvas.drawCircle(pt, 10, ringPaint);
      canvas.drawCircle(
        pt,
        3.5,
        Paint()..color = const Color(0xFFFFEA00),
      );
    }
  }

  void _drawSegment(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color,
    String label,
  ) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, linePaint);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(a, 5.5, dotPaint);
    canvas.drawCircle(b, 5.5, dotPaint);

    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(
      center: mid.translate(0, -14),
      width: tp.width + 12,
      height: tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
    tp.paint(canvas, Offset(rect.left + 6, rect.top + 3));
  }

  @override
  bool shouldRepaint(covariant _MeasurementOverlayPainter oldDelegate) {
    return true;
  }
}
