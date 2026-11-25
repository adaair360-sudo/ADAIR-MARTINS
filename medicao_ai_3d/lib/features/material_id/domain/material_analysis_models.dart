import 'industrial_material.dart';

class VisualSurfaceFeatures {
  const VisualSurfaceFeatures({
    required this.engine,
    required this.meanHue,
    required this.meanSaturation,
    required this.meanValue,
    required this.specularRatio,
    required this.warmMetalRatio,
    required this.darkMatteRatio,
    required this.chromaticRatio,
    required this.textureEnergy,
    required this.anisotropyRatio,
    required this.sharpnessVariance,
  });

  final String engine;
  final double meanHue; // 0..360
  final double meanSaturation; // 0..255
  final double meanValue; // 0..255
  final double specularRatio; // 0..1
  final double warmMetalRatio; // 0..1
  final double darkMatteRatio; // 0..1
  final double chromaticRatio; // 0..1
  final double textureEnergy;
  final double anisotropyRatio; // >= 1.0
  final double sharpnessVariance;

  List<String> describeInPortuguese() {
    final traits = <String>[];
    if (specularRatio >= 0.08) {
      traits.add(
        'Reflexo especular elevado (${(specularRatio * 100).toStringAsFixed(1)}%)',
      );
    } else if (specularRatio >= 0.02) {
      traits.add(
        'Brilho superficial moderado (${(specularRatio * 100).toStringAsFixed(1)}%)',
      );
    } else {
      traits.add('Superfície predominantemente fosca/difusa');
    }

    if (warmMetalRatio >= 0.25) {
      traits.add('Tonalidade quente/amarelada-avermelhada detectada');
    } else if (meanSaturation < 38) {
      traits.add('Coloração neutra/acromática (tons de cinza/prata/branco)');
    } else {
      traits.add(
        'Saturação cromática perceptível (H=${meanHue.toStringAsFixed(0)}°)',
      );
    }

    if (textureEnergy >= 22) {
      traits.add('Microtextura granular ou rugosidade acentuada');
    } else if (textureEnergy <= 8) {
      traits.add('Acabamento liso de baixa rugosidade aparente');
    } else {
      traits.add('Textura superficial intermediária');
    }

    if (anisotropyRatio >= 1.35) {
      traits.add(
        'Padrão direcional detectado (veios ou escovamento linear)',
      );
    }
    return traits;
  }
}

class MaterialCandidate {
  const MaterialCandidate({
    required this.material,
    required this.confidencePercent,
    required this.observedReasons,
  });

  final IndustrialMaterial material;
  final int confidencePercent;
  final List<String> observedReasons;
}

class MaterialIdentificationResult {
  const MaterialIdentificationResult({
    required this.features,
    required this.candidates,
    required this.selectedMaterial,
    required this.isManuallyCorrected,
    required this.opticalWarnings,
    required this.analyzedAt,
  });

  final VisualSurfaceFeatures features;
  final List<MaterialCandidate> candidates;
  final IndustrialMaterial selectedMaterial;
  final bool isManuallyCorrected;
  final List<String> opticalWarnings;
  final DateTime analyzedAt;

  MaterialCandidate get topCandidate => candidates.first;

  MaterialIdentificationResult copyWithManualSelection(
    IndustrialMaterial manualMaterial,
  ) {
    return MaterialIdentificationResult(
      features: features,
      candidates: candidates,
      selectedMaterial: manualMaterial,
      isManuallyCorrected: true,
      opticalWarnings: opticalWarnings,
      analyzedAt: analyzedAt,
    );
  }
}
