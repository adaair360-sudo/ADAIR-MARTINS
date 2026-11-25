import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/technical_drawing_geometry.dart';
import '../../domain/technical_drawing_models.dart';

class TechnicalModel3DView extends StatefulWidget {
  const TechnicalModel3DView({
    super.key,
    required this.spec,
  });

  final TechnicalDrawingSpec spec;

  @override
  State<TechnicalModel3DView> createState() => _TechnicalModel3DViewState();
}

class _TechnicalModel3DViewState extends State<TechnicalModel3DView> {
  double _yaw = 0.65;
  double _pitch = 0.45;
  double _zoom = 1.0;
  bool _wireframe = false;
  bool _showAxes = true;

  void _setView(double yaw, double pitch) {
    setState(() {
      _yaw = yaw;
      _pitch = pitch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesh = Mesh3DBuilder.build(widget.spec);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [Color(0xFF0B1724), Color(0xFF132436)]
                    : const [Color(0xFFEAF2FA), Color(0xFFDCE8F4)],
              ),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF28435C)
                    : const Color(0xFFB3C7DC),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: AspectRatio(
              aspectRatio: 1.35,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _yaw += details.delta.dx * 0.012;
                    _pitch = (_pitch + details.delta.dy * 0.012).clamp(
                      -math.pi / 2 + 0.05,
                      math.pi / 2 - 0.05,
                    );
                  });
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _Model3DPainter(
                          mesh: mesh,
                          yaw: _yaw,
                          pitch: _pitch,
                          zoom: _zoom,
                          wireframe: _wireframe,
                          showAxes: _showAxes,
                          isDark: isDark,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Arraste para rotacionar • Zoom ${(_zoom * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              avatar: const Icon(Icons.view_in_ar_outlined, size: 16),
              label: const Text('Isométrica'),
              onPressed: () => _setView(0.65, 0.45),
            ),
            ActionChip(
              label: const Text('Frontal'),
              onPressed: () => _setView(0.0, 0.0),
            ),
            ActionChip(
              label: const Text('Topo'),
              onPressed: () => _setView(0.0, 1.52),
            ),
            ActionChip(
              label: const Text('Lateral'),
              onPressed: () => _setView(math.pi / 2, 0.0),
            ),
            FilterChip(
              label: const Text('Wireframe'),
              selected: _wireframe,
              onSelected: (v) => setState(() => _wireframe = v),
            ),
            FilterChip(
              label: const Text('Eixos XYZ'),
              selected: _showAxes,
              onSelected: (v) => setState(() => _showAxes = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Zoom:'),
            Expanded(
              child: Slider(
                value: _zoom,
                min: 0.6,
                max: 2.2,
                onChanged: (v) => setState(() => _zoom = v),
              ),
            ),
            IconButton(
              tooltip: 'Resetar câmera 3D',
              onPressed: () => setState(() {
                _yaw = 0.65;
                _pitch = 0.45;
                _zoom = 1.0;
              }),
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProjectedTri {
  _ProjectedTri({
    required this.a,
    required this.b,
    required this.c,
    required this.depth,
    required this.color,
  });

  final Offset a;
  final Offset b;
  final Offset c;
  final double depth;
  final Color color;
}

class _Model3DPainter extends CustomPainter {
  _Model3DPainter({
    required this.mesh,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.wireframe,
    required this.showAxes,
    required this.isDark,
  });

  final Mesh3D mesh;
  final double yaw;
  final double pitch;
  final double zoom;
  final bool wireframe;
  final bool showAxes;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (math.min(size.width, size.height) * 0.72 * zoom) /
        mesh.maxExtentMm;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final rotated = mesh.vertices
        .map((v) => v.rotateXY(yaw, pitch))
        .toList(growable: false);

    Offset toScreen(Vec3 v) => Offset(cx + v.x * scale, cy - v.y * scale);

    if (!wireframe) {
      final lightDir = const Vec3(0.45, 0.7, 0.55).normalized();
      final tris = <_ProjectedTri>[];
      for (final tri in mesh.triangles) {
        final v0 = rotated[tri.a];
        final v1 = rotated[tri.b];
        final v2 = rotated[tri.c];
        final normal = (v1 - v0).cross(v2 - v0).normalized();
        final diffuse = math.max(0.28, normal.dot(lightDir).abs());
        final shaded = Color.fromARGB(
          255,
          (tri.baseColor.r * 255 * (0.45 + 0.55 * diffuse)).round().clamp(0, 255),
          (tri.baseColor.g * 255 * (0.45 + 0.55 * diffuse)).round().clamp(0, 255),
          (tri.baseColor.b * 255 * (0.45 + 0.55 * diffuse)).round().clamp(0, 255),
        );
        tris.add(
          _ProjectedTri(
            a: toScreen(v0),
            b: toScreen(v1),
            c: toScreen(v2),
            depth: (v0.z + v1.z + v2.z) / 3,
            color: shaded,
          ),
        );
      }
      tris.sort((a, b) => a.depth.compareTo(b.depth));

      for (final t in tris) {
        final path = Path()
          ..moveTo(t.a.dx, t.a.dy)
          ..lineTo(t.b.dx, t.b.dy)
          ..lineTo(t.c.dx, t.c.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = t.color
            ..style = PaintingStyle.fill,
        );
      }
    }

    final edgePaint = Paint()
      ..color = wireframe
          ? (isDark ? const Color(0xFF4DD0E1) : const Color(0xFF0F2942))
          : (isDark
              ? const Color(0xFF152536).withValues(alpha: 0.7)
              : const Color(0xFF1B344D).withValues(alpha: 0.65))
      ..strokeWidth = wireframe ? 1.25 : 0.9;

    final accentEdgePaint = Paint()
      ..color = isDark ? const Color(0xFF80DEEA) : const Color(0xFF0277BD)
      ..strokeWidth = 1.15;

    for (final edge in mesh.edges) {
      final p1 = toScreen(rotated[edge.a]);
      final p2 = toScreen(rotated[edge.b]);
      canvas.drawLine(p1, p2, edge.accent ? accentEdgePaint : edgePaint);
    }

    if (showAxes) {
      const origin = Offset(34, 0);
      final base = Offset(origin.dx, size.height - 28);
      void drawAxis(Vec3 dir, String label, Color color) {
        final r = dir.rotateXY(yaw, pitch);
        final end = Offset(base.dx + r.x * 22, base.dy - r.y * 22);
        canvas.drawLine(
          base,
          end,
          Paint()
            ..color = color
            ..strokeWidth = 1.8,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(end.dx + 2, end.dy - 6));
      }

      drawAxis(const Vec3(1, 0, 0), 'X', const Color(0xFFEF5350));
      drawAxis(const Vec3(0, 1, 0), 'Y', const Color(0xFF66BB6A));
      drawAxis(const Vec3(0, 0, 1), 'Z', const Color(0xFF42A5F5));
    }
  }

  @override
  bool shouldRepaint(covariant _Model3DPainter oldDelegate) {
    return oldDelegate.mesh != mesh ||
        oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.zoom != zoom ||
        oldDelegate.wireframe != wireframe ||
        oldDelegate.showAxes != showAxes ||
        oldDelegate.isDark != isDark;
  }
}
