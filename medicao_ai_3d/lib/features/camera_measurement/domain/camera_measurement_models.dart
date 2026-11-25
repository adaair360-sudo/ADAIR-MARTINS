import 'dart:math' as math;

enum MeasurementDimensionKind {
  calibrationReference('Referência de calibração'),
  length('Comprimento'),
  width('Largura'),
  height('Altura'),
  diameter('Diâmetro'),
  depth('Profundidade');

  const MeasurementDimensionKind(this.label);
  final String label;
}

enum ObjectGeometryType {
  rectangular('Retangular'),
  cylindrical('Cilíndrico'),
  freeSegment('Segmento livre');

  const ObjectGeometryType(this.label);
  final String label;
}

enum CalibrationSource {
  none('Não calibrado'),
  knownObject('Objeto de referência conhecida'),
  arCore('ARCore 3D');

  const CalibrationSource(this.label);
  final String label;
}

enum MeasurementQualityLevel {
  uncalibrated('Não Calibrada'),
  low('Baixa'),
  moderate('Moderada'),
  high('Alta');

  const MeasurementQualityLevel(this.label);
  final String label;
}

class ImagePoint {
  const ImagePoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(ImagePoint other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class ReferenceObjectPreset {
  const ReferenceObjectPreset({
    required this.id,
    required this.name,
    required this.knownMillimeters,
    required this.description,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final double knownMillimeters;
  final String description;
  final bool isCustom;

  static const List<ReferenceObjectPreset> defaults = [
    ReferenceObjectPreset(
      id: 'iso_card_width',
      name: 'Cartão ISO ID-1 (Largura)',
      knownMillimeters: 85.60,
      description: 'Cartão bancário/documento padrão ISO/IEC 7810 (85,60 mm).',
    ),
    ReferenceObjectPreset(
      id: 'iso_card_height',
      name: 'Cartão ISO ID-1 (Altura)',
      knownMillimeters: 53.98,
      description: 'Altura padrão de cartão ISO/IEC 7810 (53,98 mm).',
    ),
    ReferenceObjectPreset(
      id: 'coin_1_real',
      name: 'Moeda R\$ 1,00 (Diâmetro)',
      knownMillimeters: 27.00,
      description: 'Moeda brasileira de 1 real (diâmetro nominal 27,00 mm).',
    ),
    ReferenceObjectPreset(
      id: 'coin_50_cent',
      name: 'Moeda R\$ 0,50 (Diâmetro)',
      knownMillimeters: 23.00,
      description: 'Moeda brasileira de 50 centavos (23,00 mm).',
    ),
    ReferenceObjectPreset(
      id: 'ruler_100',
      name: 'Escala / Régua (100 mm)',
      knownMillimeters: 100.00,
      description: 'Trecho de 100 mm (10 cm) em régua ou trena apoiada no plano.',
    ),
    ReferenceObjectPreset(
      id: 'custom',
      name: 'Objeto Personalizado',
      knownMillimeters: 50.00,
      description: 'Informe manualmente a dimensão conhecida do objeto de referência.',
      isCustom: true,
    ),
  ];
}

class CalibrationResult {
  const CalibrationResult({
    required this.source,
    required this.pixelsPerMm,
    required this.referencePixelSpan,
    required this.knownReferenceMm,
    required this.referenceName,
    required this.createdAt,
  });

  final CalibrationSource source;
  final double pixelsPerMm;
  final double referencePixelSpan;
  final double knownReferenceMm;
  final String referenceName;
  final DateTime createdAt;

  bool get isCalibrated =>
      source != CalibrationSource.none && pixelsPerMm > 0 && knownReferenceMm > 0;
}

class MeasurementUncertainty {
  const MeasurementUncertainty({
    required this.qualityLevel,
    required this.uncertaintyMm,
    required this.confidenceScore,
    required this.limitations,
  });

  final MeasurementQualityLevel qualityLevel;
  final double? uncertaintyMm;
  final int confidenceScore;
  final List<String> limitations;
}

class DetectedContour {
  const DetectedContour({
    required this.id,
    required this.majorPx,
    required this.minorPx,
    required this.areaPx2,
    required this.perimeterPx,
    required this.circularity,
    required this.vertexCount,
    required this.angleDeg,
    required this.centerX,
    required this.centerY,
    required this.shapeHint,
    required this.boxPoints,
  });

  final String id;
  final double majorPx;
  final double minorPx;
  final double areaPx2;
  final double perimeterPx;
  final double circularity;
  final int vertexCount;
  final double angleDeg;
  final double centerX;
  final double centerY;
  final String shapeHint;
  final List<ImagePoint> boxPoints;

  String get shapeLabelPt {
    return switch (shapeHint) {
      'cylindrical' => 'Cilíndrico / Circular',
      'rectangular' => 'Retangular',
      _ => 'Irregular',
    };
  }
}

class DetectedCircle {
  const DetectedCircle({
    required this.centerX,
    required this.centerY,
    required this.diameterPx,
  });

  final double centerX;
  final double centerY;
  final double diameterPx;
}

class ContourAnalysisResult {
  const ContourAnalysisResult({
    required this.engine,
    required this.imageWidth,
    required this.imageHeight,
    required this.overlayPath,
    required this.sharpnessVariance,
    required this.contrastStdDev,
    required this.contours,
    required this.circles,
  });

  final String engine;
  final int imageWidth;
  final int imageHeight;
  final String? overlayPath;
  final double sharpnessVariance;
  final double contrastStdDev;
  final List<DetectedContour> contours;
  final List<DetectedCircle> circles;
}

class MeasurementMark {
  const MeasurementMark({
    required this.id,
    required this.kind,
    required this.geometryType,
    required this.p1,
    required this.p2,
    required this.pixelDistance,
    required this.millimeters,
    required this.uncertainty,
    this.note,
  });

  final String id;
  final MeasurementDimensionKind kind;
  final ObjectGeometryType geometryType;
  final ImagePoint p1;
  final ImagePoint p2;
  final double pixelDistance;
  final double? millimeters;
  final MeasurementUncertainty uncertainty;
  final String? note;

  bool get isCalibrated => millimeters != null;
}

class UnitConversions {
  const UnitConversions._();

  static double toCentimeters(double millimeters) => millimeters / 10.0;
  static double toMeters(double millimeters) => millimeters / 1000.0;

  static String formatAllUnits(double millimeters, {int decimals = 2}) {
    final mmStr = millimeters.toStringAsFixed(decimals);
    final cmStr = toCentimeters(millimeters).toStringAsFixed(decimals);
    final mStr = toMeters(millimeters).toStringAsFixed(decimals + 2);
    return '$mmStr mm  •  $cmStr cm  •  $mStr m';
  }
}
