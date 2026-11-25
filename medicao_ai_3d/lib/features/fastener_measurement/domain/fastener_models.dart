enum FastenerType {
  hexBolt('Parafuso sextavado'),
  allenBolt('Parafuso Allen'),
  carriageBolt('Parafuso francês'),
  studBolt('Parafuso prisioneiro'),
  flangeBolt('Parafuso flangeado'),
  nut('Porca'),
  washer('Arruela');

  const FastenerType(this.label);
  final String label;
}

enum ThreadStandard {
  metricIso('Rosca métrica ISO'),
  unc('Rosca UNC (Polegada Grossa)'),
  unf('Rosca UNF (Polegada Fina)');

  const ThreadStandard(this.label);
  final String label;
}

enum ThreadSeries {
  coarse('Rosca grossa'),
  fine('Rosca fina'),
  notApplicable('Não aplicável');

  const ThreadSeries(this.label);
  final String label;
}

enum ThreadHand {
  right('Rosca direita'),
  left('Rosca esquerda');

  const ThreadHand(this.label);
  final String label;
}

enum StrengthClassSource {
  indeterminate('Indeterminada'),
  ocrReading('Leitura OCR da gravação'),
  manualEntry('Informada manualmente pelo usuário');

  const StrengthClassSource(this.label);
  final String label;
}

class StrengthClassSpec {
  const StrengthClassSpec({
    required this.code,
    required this.title,
    required this.materialGroup,
    required this.tensileStrengthMpa,
    required this.yieldOrProofMpa,
    required this.isStainless,
    required this.notes,
  });

  final String code;
  final String title;
  final String materialGroup;
  final int tensileStrengthMpa;
  final int yieldOrProofMpa;
  final bool isStainless;
  final String notes;
}

class ThreadSpec {
  const ThreadSpec({
    required this.designation,
    required this.standard,
    required this.series,
    required this.nominalDiameterMm,
    required this.pitchMm,
    this.tpi,
    this.hexWrenchMm,
    this.hexHeadHeightMm,
    this.allenHeadDiameterMm,
    this.allenHeadHeightMm,
    this.allenSocketMm,
    this.flangeDiameterMm,
  });

  final String designation;
  final ThreadStandard standard;
  final ThreadSeries series;
  final double nominalDiameterMm;
  final double pitchMm;
  final double? tpi;
  final double? hexWrenchMm;
  final double? hexHeadHeightMm;
  final double? allenHeadDiameterMm;
  final double? allenHeadHeightMm;
  final double? allenSocketMm;
  final double? flangeDiameterMm;
}

class FastenerDimensions {
  const FastenerDimensions({
    this.outerDiameterMm,
    this.totalLengthMm,
    this.threadedLengthMm,
    this.headHeightMm,
    this.wrenchWidthMm,
    this.headDiameterMm,
    this.threadPitchMm,
  });

  final double? outerDiameterMm;
  final double? totalLengthMm;
  final double? threadedLengthMm;
  final double? headHeightMm;
  final double? wrenchWidthMm;
  final double? headDiameterMm;
  final double? threadPitchMm;

  bool get hasAnyMeasurement =>
      outerDiameterMm != null ||
      totalLengthMm != null ||
      threadedLengthMm != null ||
      headHeightMm != null ||
      wrenchWidthMm != null ||
      headDiameterMm != null ||
      threadPitchMm != null;
}

class ThreadMatchCandidate {
  const ThreadMatchCandidate({
    required this.spec,
    required this.diameterDeltaMm,
    required this.pitchDeltaMm,
    required this.confidencePercent,
  });

  final ThreadSpec spec;
  final double diameterDeltaMm;
  final double? pitchDeltaMm;
  final int confidencePercent;
}

class StrengthClassificationResult {
  const StrengthClassificationResult({
    required this.spec,
    required this.source,
    required this.rawOcrText,
    required this.warnings,
  });

  final StrengthClassSpec? spec;
  final StrengthClassSource source;
  final String? rawOcrText;
  final List<String> warnings;

  bool get isIdentified => spec != null;
}
