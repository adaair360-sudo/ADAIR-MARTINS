enum MechanicalComponentCategory {
  all(
    label: 'Todas as categorias',
    shortLabel: 'Todas',
    requiredMeasuresHint: 'Informe código de referência ou ao menos duas dimensões principais.',
  ),
  bearing(
    label: 'Rolamentos',
    shortLabel: 'Rolamentos',
    requiredMeasuresHint: 'Informe o código (ex.: 6204) ou d (interno) + D (externo) + B (largura).',
  ),
  oilSeal(
    label: 'Retentores',
    shortLabel: 'Retentores',
    requiredMeasuresHint: 'Informe código ou medida d × D × H (eixo × alojamento × altura).',
  ),
  gear(
    label: 'Engrenagens',
    shortLabel: 'Engrenagens',
    requiredMeasuresHint: 'Informe módulo (ou De + nº de dentes Z) e largura/furo.',
  ),
  shaft(
    label: 'Eixos',
    shortLabel: 'Eixos',
    requiredMeasuresHint: 'Informe diâmetro nominal (mm) e norma/chaveta ou comprimento.',
  ),
  pulley(
    label: 'Polias',
    shortLabel: 'Polias',
    requiredMeasuresHint: 'Informe perfil do canal (SPA/SPB/A/B), diâmetro primitivo e nº de canais.',
  ),
  bushing(
    label: 'Buchas',
    shortLabel: 'Buchas',
    requiredMeasuresHint: 'Informe diâmetro interno (d), externo (D) e comprimento (L).',
  ),
  coupling(
    label: 'Acoplamentos',
    shortLabel: 'Acoplamentos',
    requiredMeasuresHint: 'Informe código/tamanho, diâmetro externo e faixa de furo.',
  ),
  chain(
    label: 'Correntes',
    shortLabel: 'Correntes',
    requiredMeasuresHint: 'Informe código ANSI/ISO (ex.: 08B-1, #40) ou passo (mm) + largura interna.',
  ),
  belt(
    label: 'Correias',
    shortLabel: 'Correias',
    requiredMeasuresHint: 'Informe perfil/código (ex.: SPA-1250, HTD 5M) ou largura × altura / passo.',
  ),
  housing(
    label: 'Mancais',
    shortLabel: 'Mancais',
    requiredMeasuresHint: 'Informe código (ex.: UCP 205) ou diâmetro do eixo + distância entre furos.',
  );

  const MechanicalComponentCategory({
    required this.label,
    required this.shortLabel,
    required this.requiredMeasuresHint,
  });

  final String label;
  final String shortLabel;
  final String requiredMeasuresHint;
}

class MechanicalComponentSpec {
  const MechanicalComponentSpec({
    required this.id,
    required this.category,
    required this.referenceCode,
    required this.name,
    required this.standard,
    required this.manufacturers,
    required this.dimensionsSummary,
    required this.applicationNotes,
    required this.equivalenceRule,
    this.innerDiameterMm,
    this.outerDiameterMm,
    this.widthOrLengthMm,
    this.pitchMm,
    this.teethCount,
    this.moduleMm,
    this.mountingSpanMm,
    this.profileCode,
  });

  final String id;
  final MechanicalComponentCategory category;
  final String referenceCode;
  final String name;
  final String standard;
  final List<String> manufacturers;
  final String dimensionsSummary;
  final String applicationNotes;
  final String equivalenceRule;

  final double? innerDiameterMm;
  final double? outerDiameterMm;
  final double? widthOrLengthMm;
  final double? pitchMm;
  final int? teethCount;
  final double? moduleMm;
  final double? mountingSpanMm;
  final String? profileCode;
}

class ComponentQueryInput {
  const ComponentQueryInput({
    this.category = MechanicalComponentCategory.all,
    this.referenceText = '',
    this.innerDiameterMm,
    this.outerDiameterMm,
    this.widthOrLengthMm,
    this.pitchMm,
    this.teethCount,
    this.mountingSpanMm,
    this.toleranceMm = 0.6,
  });

  final MechanicalComponentCategory category;
  final String referenceText;
  final double? innerDiameterMm;
  final double? outerDiameterMm;
  final double? widthOrLengthMm;
  final double? pitchMm;
  final int? teethCount;
  final double? mountingSpanMm;
  final double toleranceMm;
}

enum ComponentMatchStatus {
  identified,
  needsMoreData,
  noMatch,
}

class ComponentMatchCandidate {
  const ComponentMatchCandidate({
    required this.spec,
    required this.score,
    required this.matchedBy,
  });

  final MechanicalComponentSpec spec;
  final double score;
  final List<String> matchedBy;
}

class ComponentIdentificationResult {
  const ComponentIdentificationResult({
    required this.status,
    required this.candidates,
    required this.requestedAdditionalData,
    required this.summaryMessage,
    this.estimatedGearModuleMm,
  });

  final ComponentMatchStatus status;
  final List<ComponentMatchCandidate> candidates;
  final List<String> requestedAdditionalData;
  final String summaryMessage;
  final double? estimatedGearModuleMm;
}
