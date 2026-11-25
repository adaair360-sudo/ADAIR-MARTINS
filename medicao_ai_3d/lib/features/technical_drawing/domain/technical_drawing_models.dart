import '../../settings/domain/app_settings.dart';

enum DrawingPartType {
  hexBolt(
    label: 'Parafuso sextavado',
    shortLabel: 'Sextavado',
    description: 'Cabeça sextavada, haste cilíndrica e trecho roscado.',
  ),
  socketBolt(
    label: 'Parafuso Allen',
    shortLabel: 'Allen',
    description: 'Cabeça cilíndrica com sextavado interno e haste roscada.',
  ),
  shaft(
    label: 'Eixo cilíndrico',
    shortLabel: 'Eixo',
    description: 'Eixo maciço com degrau/rebaixo opcional.',
  ),
  tube(
    label: 'Tubo / bucha',
    shortLabel: 'Tubo',
    description: 'Peça cilíndrica vazada com diâmetros externo e interno.',
  ),
  plate(
    label: 'Chapa / bloco',
    shortLabel: 'Chapa',
    description: 'Chapa retangular com espessura e furo central opcional.',
  );

  const DrawingPartType({
    required this.label,
    required this.shortLabel,
    required this.description,
  });

  final String label;
  final String shortLabel;
  final String description;

  bool get isFastener =>
      this == DrawingPartType.hexBolt || this == DrawingPartType.socketBolt;
}

enum DrawingViewMode {
  views2D('Desenho 2D cotado'),
  model3D('Modelo 3D interativo'),
  split('2D + 3D');

  const DrawingViewMode(this.label);
  final String label;
}

class TechnicalDrawingSpec {
  const TechnicalDrawingSpec({
    required this.id,
    required this.partType,
    required this.partName,
    required this.drawingCode,
    required this.materialName,
    required this.authorName,
    required this.toleranceNote,
    required this.unit,
    this.length,
    this.width,
    this.heightOrThickness,
    this.outerDiameter,
    this.innerDiameter,
    this.headHeight,
    this.wrenchSize,
    this.threadLength,
    this.threadPitch,
    this.stepDiameter,
    this.stepLength,
    this.holeDiameter,
    this.updatedAtIso,
  });

  final String id;
  final DrawingPartType partType;
  final String partName;
  final String drawingCode;
  final String materialName;
  final String authorName;
  final String toleranceNote;
  final MeasurementUnit unit;

  // Dimensions expressed in [unit]
  final double? length;
  final double? width;
  final double? heightOrThickness;
  final double? outerDiameter;
  final double? innerDiameter;
  final double? headHeight;
  final double? wrenchSize;
  final double? threadLength;
  final double? threadPitch;
  final double? stepDiameter;
  final double? stepLength;
  final double? holeDiameter;
  final String? updatedAtIso;

  double _toMm(double? v) {
    if (v == null) return 0;
    return switch (unit) {
      MeasurementUnit.millimeters => v,
      MeasurementUnit.centimeters => v * 10.0,
      MeasurementUnit.meters => v * 1000.0,
    };
  }

  double _fromMm(double mm) {
    return switch (unit) {
      MeasurementUnit.millimeters => mm,
      MeasurementUnit.centimeters => mm / 10.0,
      MeasurementUnit.meters => mm / 1000.0,
    };
  }

  double get lengthMm => _toMm(length);
  double get widthMm => _toMm(width);
  double get thicknessMm => _toMm(heightOrThickness);
  double get outerDiameterMm => _toMm(outerDiameter);
  double get innerDiameterMm => _toMm(innerDiameter);
  double get headHeightMm => _toMm(headHeight);
  double get wrenchSizeMm => _toMm(wrenchSize);
  double get threadLengthMm =>
      threadLength != null ? _toMm(threadLength) : lengthMm * 0.65;
  double get stepDiameterMm => _toMm(stepDiameter);
  double get stepLengthMm => _toMm(stepLength);
  double get holeDiameterMm => _toMm(holeDiameter);

  String formatValue(double valueInUnit, {int decimals = 2}) {
    final trimmed = valueInUnit.toStringAsFixed(decimals);
    return '$trimmed ${unit.symbol}';
  }

  String formatMm(double valueMm, {int decimals = 2}) {
    final converted = _fromMm(valueMm);
    return '${converted.toStringAsFixed(decimals)} ${unit.symbol}';
  }

  TechnicalDrawingSpec copyWith({
    String? id,
    DrawingPartType? partType,
    String? partName,
    String? drawingCode,
    String? materialName,
    String? authorName,
    String? toleranceNote,
    MeasurementUnit? unit,
    double? length,
    double? width,
    double? heightOrThickness,
    double? outerDiameter,
    double? innerDiameter,
    double? headHeight,
    double? wrenchSize,
    double? threadLength,
    double? threadPitch,
    double? stepDiameter,
    double? stepLength,
    double? holeDiameter,
    String? updatedAtIso,
  }) {
    return TechnicalDrawingSpec(
      id: id ?? this.id,
      partType: partType ?? this.partType,
      partName: partName ?? this.partName,
      drawingCode: drawingCode ?? this.drawingCode,
      materialName: materialName ?? this.materialName,
      authorName: authorName ?? this.authorName,
      toleranceNote: toleranceNote ?? this.toleranceNote,
      unit: unit ?? this.unit,
      length: length ?? this.length,
      width: width ?? this.width,
      heightOrThickness: heightOrThickness ?? this.heightOrThickness,
      outerDiameter: outerDiameter ?? this.outerDiameter,
      innerDiameter: innerDiameter ?? this.innerDiameter,
      headHeight: headHeight ?? this.headHeight,
      wrenchSize: wrenchSize ?? this.wrenchSize,
      threadLength: threadLength ?? this.threadLength,
      threadPitch: threadPitch ?? this.threadPitch,
      stepDiameter: stepDiameter ?? this.stepDiameter,
      stepLength: stepLength ?? this.stepLength,
      holeDiameter: holeDiameter ?? this.holeDiameter,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partType': partType.name,
      'partName': partName,
      'drawingCode': drawingCode,
      'materialName': materialName,
      'authorName': authorName,
      'toleranceNote': toleranceNote,
      'unit': unit.name,
      'length': length,
      'width': width,
      'heightOrThickness': heightOrThickness,
      'outerDiameter': outerDiameter,
      'innerDiameter': innerDiameter,
      'headHeight': headHeight,
      'wrenchSize': wrenchSize,
      'threadLength': threadLength,
      'threadPitch': threadPitch,
      'stepDiameter': stepDiameter,
      'stepLength': stepLength,
      'holeDiameter': holeDiameter,
      'updatedAtIso': updatedAtIso,
    };
  }

  factory TechnicalDrawingSpec.fromJson(Map<String, dynamic> json) {
    final partName = json['partType'] as String? ?? DrawingPartType.hexBolt.name;
    final unitName = json['unit'] as String? ?? MeasurementUnit.millimeters.name;
    return TechnicalDrawingSpec(
      id: json['id'] as String? ?? 'dwg-1',
      partType: DrawingPartType.values.firstWhere(
        (e) => e.name == partName,
        orElse: () => DrawingPartType.hexBolt,
      ),
      partName: json['partName'] as String? ?? '',
      drawingCode: json['drawingCode'] as String? ?? '',
      materialName: json['materialName'] as String? ?? 'Aço carbono',
      authorName: json['authorName'] as String? ?? '',
      toleranceNote: json['toleranceNote'] as String? ?? 'ISO 2768-m',
      unit: MeasurementUnit.values.firstWhere(
        (e) => e.name == unitName,
        orElse: () => MeasurementUnit.millimeters,
      ),
      length: (json['length'] as num?)?.toDouble(),
      width: (json['width'] as num?)?.toDouble(),
      heightOrThickness: (json['heightOrThickness'] as num?)?.toDouble(),
      outerDiameter: (json['outerDiameter'] as num?)?.toDouble(),
      innerDiameter: (json['innerDiameter'] as num?)?.toDouble(),
      headHeight: (json['headHeight'] as num?)?.toDouble(),
      wrenchSize: (json['wrenchSize'] as num?)?.toDouble(),
      threadLength: (json['threadLength'] as num?)?.toDouble(),
      threadPitch: (json['threadPitch'] as num?)?.toDouble(),
      stepDiameter: (json['stepDiameter'] as num?)?.toDouble(),
      stepLength: (json['stepLength'] as num?)?.toDouble(),
      holeDiameter: (json['holeDiameter'] as num?)?.toDouble(),
      updatedAtIso: json['updatedAtIso'] as String?,
    );
  }
}

class DrawingValidationResult {
  const DrawingValidationResult({
    required this.isValid,
    required this.missingOrInvalidFields,
    required this.warnings,
  });

  final bool isValid;
  final List<String> missingOrInvalidFields;
  final List<String> warnings;
}

class DrawingDimensionSummaryItem {
  const DrawingDimensionSummaryItem({
    required this.symbol,
    required this.label,
    required this.formattedValue,
  });

  final String symbol;
  final String label;
  final String formattedValue;
}
