import 'dart:math' as math;
import 'dart:ui';

import 'technical_drawing_models.dart';

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);
  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);
  Vec3 operator *(double scalar) => Vec3(x * scalar, y * scalar, z * scalar);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) {
    return Vec3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final len = length;
    if (len < 1e-9) {
      return const Vec3(0, 0, 1);
    }
    return Vec3(x / len, y / len, z / len);
  }

  Vec3 rotateXY(double yawRad, double pitchRad) {
    // Rotate around Y (yaw) then around X (pitch)
    final cosY = math.cos(yawRad);
    final sinY = math.sin(yawRad);
    final x1 = x * cosY + z * sinY;
    final z1 = -x * sinY + z * cosY;

    final cosP = math.cos(pitchRad);
    final sinP = math.sin(pitchRad);
    final y2 = y * cosP - z1 * sinP;
    final z2 = y * sinP + z1 * cosP;

    return Vec3(x1, y2, z2);
  }
}

class MeshTriangle {
  const MeshTriangle({
    required this.a,
    required this.b,
    required this.c,
    required this.baseColor,
  });

  final int a;
  final int b;
  final int c;
  final Color baseColor;
}

class MeshEdge {
  const MeshEdge(this.a, this.b, {this.accent = false});

  final int a;
  final int b;
  final bool accent;
}

class Mesh3D {
  const Mesh3D({
    required this.vertices,
    required this.triangles,
    required this.edges,
    required this.maxExtentMm,
  });

  final List<Vec3> vertices;
  final List<MeshTriangle> triangles;
  final List<MeshEdge> edges;
  final double maxExtentMm;
}

class TechnicalDrawingValidator {
  const TechnicalDrawingValidator._();

  static DrawingValidationResult validate(TechnicalDrawingSpec spec) {
    final errors = <String>[];
    final warnings = <String>[];

    bool validPos(double? v) => v != null && v.isFinite && v > 0;

    switch (spec.partType) {
      case DrawingPartType.hexBolt:
      case DrawingPartType.socketBolt:
        if (!validPos(spec.outerDiameter)) {
          errors.add('Diâmetro da rosca (D) > 0');
        }
        if (!validPos(spec.length)) {
          errors.add('Comprimento da haste (L) > 0');
        }
        if (!validPos(spec.headHeight)) {
          errors.add('Altura da cabeça (K) > 0');
        }
        if (!validPos(spec.wrenchSize)) {
          errors.add(
            spec.partType == DrawingPartType.hexBolt
                ? 'Chave entre faces (S) > 0'
                : 'Diâmetro da cabeça (Dk) > 0',
          );
        }
        if (validPos(spec.outerDiameter) &&
            validPos(spec.wrenchSize) &&
            spec.wrenchSize! <= spec.outerDiameter!) {
          errors.add('A cabeça/chave deve ser maior que o diâmetro da rosca');
        }
        if (validPos(spec.threadLength) &&
            validPos(spec.length) &&
            spec.threadLength! > spec.length!) {
          errors.add('Comprimento roscado (b) não pode exceder L');
        }
        if (spec.threadPitch == null || spec.threadPitch! <= 0) {
          warnings.add('Passo da rosca não informado — será omitido na cota.');
        }

      case DrawingPartType.shaft:
        if (!validPos(spec.outerDiameter)) {
          errors.add('Diâmetro principal (D1) > 0');
        }
        if (!validPos(spec.length)) {
          errors.add('Comprimento total (L) > 0');
        }
        if (spec.stepDiameter != null || spec.stepLength != null) {
          if (!validPos(spec.stepDiameter) || !validPos(spec.stepLength)) {
            errors.add(
              'Para eixo escalonado, informe diâmetro e comprimento do degrau',
            );
          } else if (validPos(spec.length) && spec.stepLength! >= spec.length!) {
            errors.add('Comprimento do degrau (L2) deve ser menor que L');
          } else if (validPos(spec.outerDiameter) &&
              spec.stepDiameter! >= spec.outerDiameter!) {
            warnings.add(
              'Diâmetro do degrau (D2) maior ou igual a D1 será desenhado como flange/resalto.',
            );
          }
        }

      case DrawingPartType.tube:
        if (!validPos(spec.outerDiameter)) {
          errors.add('Diâmetro externo (De) > 0');
        }
        if (!validPos(spec.innerDiameter)) {
          errors.add('Diâmetro interno (Di) > 0');
        }
        if (!validPos(spec.length)) {
          errors.add('Comprimento (L) > 0');
        }
        if (validPos(spec.outerDiameter) &&
            validPos(spec.innerDiameter) &&
            spec.innerDiameter! >= spec.outerDiameter!) {
          errors.add('Diâmetro interno (Di) deve ser menor que externo (De)');
        }

      case DrawingPartType.plate:
        if (!validPos(spec.length)) {
          errors.add('Comprimento (C) > 0');
        }
        if (!validPos(spec.width)) {
          errors.add('Largura (W) > 0');
        }
        if (!validPos(spec.heightOrThickness)) {
          errors.add('Espessura (E) > 0');
        }
        if (spec.holeDiameter != null && spec.holeDiameter! > 0) {
          if (validPos(spec.length) &&
              validPos(spec.width) &&
              spec.holeDiameter! >= math.min(spec.length!, spec.width!)) {
            errors.add('Diâmetro do furo deve ser menor que largura e comprimento');
          }
        }
    }

    return DrawingValidationResult(
      isValid: errors.isEmpty,
      missingOrInvalidFields: errors,
      warnings: warnings,
    );
  }

  static List<DrawingDimensionSummaryItem> summarizeDimensions(
    TechnicalDrawingSpec spec,
  ) {
    final items = <DrawingDimensionSummaryItem>[];
    switch (spec.partType) {
      case DrawingPartType.hexBolt:
      case DrawingPartType.socketBolt:
        if (spec.outerDiameter != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'D',
              label: 'Diâmetro externo',
              formattedValue: spec.formatValue(spec.outerDiameter!),
            ),
          );
        }
        if (spec.length != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'L',
              label: 'Comprimento da haste',
              formattedValue: spec.formatValue(spec.length!),
            ),
          );
        }
        if (spec.headHeight != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'K',
              label: 'Altura da cabeça',
              formattedValue: spec.formatValue(spec.headHeight!),
            ),
          );
        }
        if (spec.wrenchSize != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: spec.partType == DrawingPartType.hexBolt ? 'S' : 'Dk',
              label: spec.partType == DrawingPartType.hexBolt
                  ? 'Chave entre faces'
                  : 'Diâmetro da cabeça',
              formattedValue: spec.formatValue(spec.wrenchSize!),
            ),
          );
        }
        if (spec.threadLength != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'b',
              label: 'Comprimento roscado',
              formattedValue: spec.formatValue(spec.threadLength!),
            ),
          );
        }
        if (spec.threadPitch != null && spec.threadPitch! > 0) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'P',
              label: 'Passo da rosca',
              formattedValue: '${spec.threadPitch!.toStringAsFixed(2)} mm',
            ),
          );
        }

      case DrawingPartType.shaft:
        if (spec.outerDiameter != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'D1',
              label: 'Diâmetro principal',
              formattedValue: spec.formatValue(spec.outerDiameter!),
            ),
          );
        }
        if (spec.length != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'L',
              label: 'Comprimento total',
              formattedValue: spec.formatValue(spec.length!),
            ),
          );
        }
        if (spec.stepDiameter != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'D2',
              label: 'Diâmetro do degrau',
              formattedValue: spec.formatValue(spec.stepDiameter!),
            ),
          );
        }
        if (spec.stepLength != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'L2',
              label: 'Comprimento do degrau',
              formattedValue: spec.formatValue(spec.stepLength!),
            ),
          );
        }

      case DrawingPartType.tube:
        if (spec.outerDiameter != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'De',
              label: 'Diâmetro externo',
              formattedValue: spec.formatValue(spec.outerDiameter!),
            ),
          );
        }
        if (spec.innerDiameter != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'Di',
              label: 'Diâmetro interno',
              formattedValue: spec.formatValue(spec.innerDiameter!),
            ),
          );
        }
        if (spec.length != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'L',
              label: 'Comprimento',
              formattedValue: spec.formatValue(spec.length!),
            ),
          );
        }
        if (spec.outerDiameter != null && spec.innerDiameter != null) {
          final wall = (spec.outerDiameter! - spec.innerDiameter!) / 2;
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 't',
              label: 'Espessura de parede',
              formattedValue: spec.formatValue(wall),
            ),
          );
        }

      case DrawingPartType.plate:
        if (spec.length != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'C',
              label: 'Comprimento',
              formattedValue: spec.formatValue(spec.length!),
            ),
          );
        }
        if (spec.width != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'W',
              label: 'Largura',
              formattedValue: spec.formatValue(spec.width!),
            ),
          );
        }
        if (spec.heightOrThickness != null) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'E',
              label: 'Espessura',
              formattedValue: spec.formatValue(spec.heightOrThickness!),
            ),
          );
        }
        if (spec.holeDiameter != null && spec.holeDiameter! > 0) {
          items.add(
            DrawingDimensionSummaryItem(
              symbol: 'Df',
              label: 'Furo passante',
              formattedValue: spec.formatValue(spec.holeDiameter!),
            ),
          );
        }
    }
    return items;
  }
}

class Mesh3DBuilder {
  const Mesh3DBuilder._();

  static Mesh3D build(TechnicalDrawingSpec spec) {
    final vertices = <Vec3>[];
    final triangles = <MeshTriangle>[];
    final edges = <MeshEdge>[];

    const steelBody = Color(0xFF8DA2B5);
    const steelHead = Color(0xFFA9BCCF);
    const threadColor = Color(0xFF5D7B96);
    const boreColor = Color(0xFF475B6D);

    void addPrism({
      required double yStart,
      required double yEnd,
      required double radius,
      required int sides,
      required Color color,
      bool addCircumferenceEdges = true,
      bool capEnds = true,
      double rotationOffset = 0,
    }) {
      final baseIndex = vertices.length;
      for (var i = 0; i < sides; i++) {
        final angle = rotationOffset + (2 * math.pi * i / sides);
        final x = radius * math.cos(angle);
        final z = radius * math.sin(angle);
        vertices.add(Vec3(x, yStart, z));
        vertices.add(Vec3(x, yEnd, z));
      }

      for (var i = 0; i < sides; i++) {
        final next = (i + 1) % sides;
        final b0 = baseIndex + i * 2;
        final t0 = baseIndex + i * 2 + 1;
        final b1 = baseIndex + next * 2;
        final t1 = baseIndex + next * 2 + 1;

        triangles.add(MeshTriangle(a: b0, b: b1, c: t1, baseColor: color));
        triangles.add(MeshTriangle(a: b0, b: t1, c: t0, baseColor: color));

        if (addCircumferenceEdges) {
          edges.add(MeshEdge(b0, b1));
          edges.add(MeshEdge(t0, t1));
        }
        if (sides <= 8) {
          edges.add(MeshEdge(b0, t0));
        }
      }

      if (capEnds) {
        final bottomCenter = vertices.length;
        vertices.add(Vec3(0, yStart, 0));
        final topCenter = vertices.length;
        vertices.add(Vec3(0, yEnd, 0));
        for (var i = 0; i < sides; i++) {
          final next = (i + 1) % sides;
          final b0 = baseIndex + i * 2;
          final b1 = baseIndex + next * 2;
          final t0 = baseIndex + i * 2 + 1;
          final t1 = baseIndex + next * 2 + 1;
          triangles.add(
            MeshTriangle(a: bottomCenter, b: b1, c: b0, baseColor: color),
          );
          triangles.add(
            MeshTriangle(a: topCenter, b: t0, c: t1, baseColor: color),
          );
        }
      }
    }

    switch (spec.partType) {
      case DrawingPartType.hexBolt:
      case DrawingPartType.socketBolt:
        final d = spec.outerDiameterMm;
        final l = spec.lengthMm;
        final k = spec.headHeightMm;
        final totalLen = k + l;
        final yHeadTop = totalLen / 2;
        final yHeadBot = yHeadTop - k;
        final yTip = -totalLen / 2;
        final threadLen = math.min(spec.threadLengthMm, l);
        final yThreadStart = yTip + threadLen;

        if (spec.partType == DrawingPartType.hexBolt) {
          final circumradius = (spec.wrenchSizeMm / 2) / math.cos(math.pi / 6);
          addPrism(
            yStart: yHeadBot,
            yEnd: yHeadTop,
            radius: circumradius,
            sides: 6,
            color: steelHead,
          );
        } else {
          final headRadius = spec.wrenchSizeMm / 2;
          addPrism(
            yStart: yHeadBot,
            yEnd: yHeadTop,
            radius: headRadius,
            sides: 24,
            color: steelHead,
          );
          // Hex socket outline on top face
          final socketRadius = d * 0.42;
          final sBase = vertices.length;
          for (var i = 0; i < 6; i++) {
            final ang = 2 * math.pi * i / 6;
            vertices.add(
              Vec3(
                socketRadius * math.cos(ang),
                yHeadTop + 0.05,
                socketRadius * math.sin(ang),
              ),
            );
          }
          for (var i = 0; i < 6; i++) {
            edges.add(MeshEdge(sBase + i, sBase + (i + 1) % 6, accent: true));
          }
        }

        // Smooth shank portion
        if (yHeadBot - yThreadStart > 0.2) {
          addPrism(
            yStart: yThreadStart,
            yEnd: yHeadBot,
            radius: d / 2,
            sides: 24,
            color: steelBody,
          );
        }

        // Threaded portion
        addPrism(
          yStart: yTip,
          yEnd: yThreadStart,
          radius: d / 2,
          sides: 24,
          color: threadColor,
        );

        // Visual thread pitch rings along threaded portion
        final ringStep = (spec.threadPitch != null && spec.threadPitch! > 0)
            ? math.max(spec.threadPitch!, threadLen / 14)
            : math.max(1.2, threadLen / 10);
        for (var y = yTip + ringStep; y < yThreadStart - 0.3; y += ringStep) {
          final rBase = vertices.length;
          const segs = 20;
          for (var i = 0; i < segs; i++) {
            final ang = 2 * math.pi * i / segs;
            vertices.add(
              Vec3((d / 2) * 1.01 * math.cos(ang), y, (d / 2) * 1.01 * math.sin(ang)),
            );
          }
          for (var i = 0; i < segs; i++) {
            edges.add(MeshEdge(rBase + i, rBase + (i + 1) % segs, accent: true));
          }
        }

      case DrawingPartType.shaft:
        final d1 = spec.outerDiameterMm;
        final l = spec.lengthMm;
        final hasStep = spec.stepDiameterMm > 0 && spec.stepLengthMm > 0;
        final yTop = l / 2;
        final yBot = -l / 2;

        if (!hasStep) {
          addPrism(
            yStart: yBot,
            yEnd: yTop,
            radius: d1 / 2,
            sides: 28,
            color: steelBody,
          );
        } else {
          final l2 = math.min(spec.stepLengthMm, l * 0.9);
          final yStep = yTop - l2;
          addPrism(
            yStart: yBot,
            yEnd: yStep,
            radius: d1 / 2,
            sides: 28,
            color: steelBody,
          );
          addPrism(
            yStart: yStep,
            yEnd: yTop,
            radius: spec.stepDiameterMm / 2,
            sides: 28,
            color: steelHead,
          );
        }

      case DrawingPartType.tube:
        final ro = spec.outerDiameterMm / 2;
        final ri = spec.innerDiameterMm / 2;
        final l = spec.lengthMm;
        final yBot = -l / 2;
        final yTop = l / 2;
        const sides = 28;
        final base = vertices.length;
        for (var i = 0; i < sides; i++) {
          final ang = 2 * math.pi * i / sides;
          final cosA = math.cos(ang);
          final sinA = math.sin(ang);
          vertices.add(Vec3(ro * cosA, yBot, ro * sinA)); // 0: outer bot
          vertices.add(Vec3(ro * cosA, yTop, ro * sinA)); // 1: outer top
          vertices.add(Vec3(ri * cosA, yBot, ri * sinA)); // 2: inner bot
          vertices.add(Vec3(ri * cosA, yTop, ri * sinA)); // 3: inner top
        }
        for (var i = 0; i < sides; i++) {
          final next = (i + 1) % sides;
          final ob0 = base + i * 4;
          final ot0 = base + i * 4 + 1;
          final ib0 = base + i * 4 + 2;
          final it0 = base + i * 4 + 3;
          final ob1 = base + next * 4;
          final ot1 = base + next * 4 + 1;
          final ib1 = base + next * 4 + 2;
          final it1 = base + next * 4 + 3;

          // Outer wall
          triangles.add(MeshTriangle(a: ob0, b: ob1, c: ot1, baseColor: steelBody));
          triangles.add(MeshTriangle(a: ob0, b: ot1, c: ot0, baseColor: steelBody));
          // Inner bore
          triangles.add(MeshTriangle(a: ib0, b: it1, c: ib1, baseColor: boreColor));
          triangles.add(MeshTriangle(a: ib0, b: it0, c: it1, baseColor: boreColor));
          // Top annulus
          triangles.add(MeshTriangle(a: ot0, b: ot1, c: it1, baseColor: steelHead));
          triangles.add(MeshTriangle(a: ot0, b: it1, c: it0, baseColor: steelHead));
          // Bottom annulus
          triangles.add(MeshTriangle(a: ob0, b: ib1, c: ob1, baseColor: steelHead));
          triangles.add(MeshTriangle(a: ob0, b: ib0, c: ib1, baseColor: steelHead));

          edges.add(MeshEdge(ob0, ob1));
          edges.add(MeshEdge(ot0, ot1));
          edges.add(MeshEdge(ib0, ib1, accent: true));
          edges.add(MeshEdge(it0, it1, accent: true));
        }

      case DrawingPartType.plate:
        final hx = spec.lengthMm / 2;
        final hy = spec.thicknessMm / 2;
        final hz = spec.widthMm / 2;
        final vBase = vertices.length;
        vertices.addAll([
          Vec3(-hx, -hy, -hz),
          Vec3(hx, -hy, -hz),
          Vec3(hx, -hy, hz),
          Vec3(-hx, -hy, hz),
          Vec3(-hx, hy, -hz),
          Vec3(hx, hy, -hz),
          Vec3(hx, hy, hz),
          Vec3(-hx, hy, hz),
        ]);
        const boxFaces = [
          [0, 1, 2, 3], // bottom
          [4, 7, 6, 5], // top
          [0, 4, 5, 1], // back
          [1, 5, 6, 2], // right
          [2, 6, 7, 3], // front
          [3, 7, 4, 0], // left
        ];
        for (final f in boxFaces) {
          final color = f[0] == 4 ? steelHead : steelBody;
          triangles.add(
            MeshTriangle(
              a: vBase + f[0],
              b: vBase + f[1],
              c: vBase + f[2],
              baseColor: color,
            ),
          );
          triangles.add(
            MeshTriangle(
              a: vBase + f[0],
              b: vBase + f[2],
              c: vBase + f[3],
              baseColor: color,
            ),
          );
        }
        const boxEdges = [
          [0, 1],
          [1, 2],
          [2, 3],
          [3, 0],
          [4, 5],
          [5, 6],
          [6, 7],
          [7, 4],
          [0, 4],
          [1, 5],
          [2, 6],
          [3, 7],
        ];
        for (final e in boxEdges) {
          edges.add(MeshEdge(vBase + e[0], vBase + e[1]));
        }

        // Optional through-hole ring outlines on top and bottom
        if (spec.holeDiameterMm > 0) {
          final hr = spec.holeDiameterMm / 2;
          const segs = 24;
          final hBase = vertices.length;
          for (var i = 0; i < segs; i++) {
            final ang = 2 * math.pi * i / segs;
            final x = hr * math.cos(ang);
            final z = hr * math.sin(ang);
            vertices.add(Vec3(x, -hy - 0.05, z));
            vertices.add(Vec3(x, hy + 0.05, z));
          }
          for (var i = 0; i < segs; i++) {
            final next = (i + 1) % segs;
            final b0 = hBase + i * 2;
            final t0 = hBase + i * 2 + 1;
            final b1 = hBase + next * 2;
            final t1 = hBase + next * 2 + 1;
            triangles.add(
              MeshTriangle(a: b0, b: t1, c: b1, baseColor: boreColor),
            );
            triangles.add(
              MeshTriangle(a: b0, b: t0, c: t1, baseColor: boreColor),
            );
            edges.add(MeshEdge(b0, b1, accent: true));
            edges.add(MeshEdge(t0, t1, accent: true));
          }
        }
    }

    var maxExt = 1.0;
    for (final v in vertices) {
      maxExt = math.max(maxExt, math.max(v.x.abs(), math.max(v.y.abs(), v.z.abs())));
    }

    return Mesh3D(
      vertices: vertices,
      triangles: triangles,
      edges: edges,
      maxExtentMm: maxExt * 2,
    );
  }
}
