import 'dart:math' as math;

import 'fastener_models.dart';
import 'fastener_standards.dart';

class FastenerClassifier {
  const FastenerClassifier._();

  static List<ThreadMatchCandidate> matchThread({
    required double? outerDiameterMm,
    double? threadPitchMm,
    double? wrenchWidthMm,
  }) {
    if ((outerDiameterMm == null || outerDiameterMm <= 0) &&
        (wrenchWidthMm == null || wrenchWidthMm <= 0)) {
      return const [];
    }

    final candidates = <_ScoredThread>[];
    for (final spec in FastenerStandards.threadCatalog) {
      double dDelta = 0;
      var penalty = 0.0;

      if (outerDiameterMm != null && outerDiameterMm > 0) {
        // Real external threads typically measure ~0.05 to 0.25 mm below nominal
        final adjustedDiff = (outerDiameterMm - spec.nominalDiameterMm).abs();
        dDelta = outerDiameterMm - spec.nominalDiameterMm;
        if (adjustedDiff > 1.6) {
          continue;
        }
        penalty += adjustedDiff * 24.0;
      }

      double? pDelta;
      if (threadPitchMm != null && threadPitchMm > 0) {
        pDelta = threadPitchMm - spec.pitchMm;
        final absPitch = pDelta.abs();
        if (absPitch > 0.65) {
          penalty += absPitch * 55.0;
        } else {
          penalty += absPitch * 40.0;
        }
      } else {
        // Without pitch measurement, slight preference for coarse ISO standard
        if (spec.series == ThreadSeries.fine) {
          penalty += 4.5;
        }
      }

      if (wrenchWidthMm != null &&
          wrenchWidthMm > 0 &&
          spec.hexWrenchMm != null) {
        final wDiff = (wrenchWidthMm - spec.hexWrenchMm!).abs();
        penalty += wDiff * 8.0;
      }

      final confidence = (96.0 - penalty).round().clamp(15, 96);
      candidates.add(
        _ScoredThread(
          candidate: ThreadMatchCandidate(
            spec: spec,
            diameterDeltaMm: dDelta,
            pitchDeltaMm: pDelta,
            confidencePercent: confidence,
          ),
          penalty: penalty,
        ),
      );
    }

    candidates.sort((a, b) => a.penalty.compareTo(b.penalty));
    return candidates.take(5).map((e) => e.candidate).toList();
  }

  /// Parses OCR text read from a fastener head and maps ONLY explicit,
  /// legible strength markings (`4.6`, `5.8`, `8.8`, `10.9`, `12.9`, `A2`, `A4`).
  /// Never classifies strength from external appearance.
  static StrengthClassificationResult classifyStrengthFromOcr(
    String rawText, {
    bool hasStainlessAppearanceEvidence = false,
  }) {
    final cleaned = rawText
        .toUpperCase()
        .replaceAll(',', '.')
        .replaceAll('\n', ' ')
        .trim();

    if (cleaned.isEmpty) {
      return const StrengthClassificationResult(
        spec: null,
        source: StrengthClassSource.indeterminate,
        rawOcrText: '',
        warnings: [
          'Nenhuma marcação foi reconhecida por OCR na cabeça do parafuso.',
          'A classe de resistência nunca deve ser deduzida apenas pela aparência externa. Melhore o foco/iluminação ou informe a marcação manualmente.',
        ],
      );
    }

    // Check explicit stainless markings A2 / A4 (e.g., A2-70, A4-80, A2, A4)
    final stainlessMatch = RegExp(r'\b(A[24])(?:\s*[- ]\s*(50|70|80))?\b')
        .firstMatch(cleaned);
    if (stainlessMatch != null) {
      final code = stainlessMatch.group(1)!;
      final spec = FastenerStandards.strengthByCode(code);
      final warnings = <String>[
        'Marcação inoxidável "$code" detectada via OCR (${stainlessMatch.group(0)}).',
      ];
      if (!hasStainlessAppearanceEvidence) {
        warnings.add(
          'Confirme visualmente se a peça é realmente metálica prateada/austenítica (não magnética) para validar a leitura OCR.',
        );
      }
      return StrengthClassificationResult(
        spec: spec,
        source: StrengthClassSource.ocrReading,
        rawOcrText: rawText,
        warnings: warnings,
      );
    }

    // Check metric property classes 12.9, 10.9, 8.8, 5.8, 4.6 (allowing dot or space from stamp)
    final patterns = <String, RegExp>{
      '12.9': RegExp(r'(?<!\d)12\s*[.\-]?\s*9(?!\d)'),
      '10.9': RegExp(r'(?<!\d)10\s*[.\-]?\s*9(?!\d)'),
      '8.8': RegExp(r'(?<!\d)8\s*[.\-]?\s*8(?!\d)'),
      '5.8': RegExp(r'(?<!\d)5\s*[.\-]?\s*8(?!\d)'),
      '4.6': RegExp(r'(?<!\d)4\s*[.\-]?\s*6(?!\d)'),
    };

    for (final entry in patterns.entries) {
      final match = entry.value.firstMatch(cleaned);
      if (match != null) {
        final spec = FastenerStandards.strengthByCode(entry.key);
        return StrengthClassificationResult(
          spec: spec,
          source: StrengthClassSource.ocrReading,
          rawOcrText: rawText,
          warnings: [
            'Marcação "${entry.key}" reconhecida por OCR (${match.group(0)}). Confira visualmente na cabeça da peça antes da montagem.',
          ],
        );
      }
    }

    return StrengthClassificationResult(
      spec: null,
      source: StrengthClassSource.indeterminate,
      rawOcrText: rawText,
      warnings: [
        'Texto lido ("$cleaned") não corresponde com segurança às classes 4.6, 5.8, 8.8, 10.9, 12.9, A2 ou A4.',
        'Não classificamos resistência apenas pela aparência externa. Informe a marcação gravada manualmente.',
      ],
    );
  }

  static StrengthClassificationResult manualStrengthSelection(String code) {
    final spec = FastenerStandards.strengthByCode(code);
    if (spec == null) {
      return const StrengthClassificationResult(
        spec: null,
        source: StrengthClassSource.indeterminate,
        rawOcrText: null,
        warnings: ['Classe informada não reconhecida.'],
      );
    }
    return StrengthClassificationResult(
      spec: spec,
      source: StrengthClassSource.manualEntry,
      rawOcrText: null,
      warnings: [
        'Classe ${spec.code} informada manualmente com base na gravação observada na peça.',
      ],
    );
  }

  /// Estimates thread pitch (mm) from a calibrated 1D axial luminance profile
  /// using normalized autocorrelation of thread crests.
  /// Returns null if resolution is insufficient (< 6 px/mm) or periodicity is weak.
  static double? estimatePitchFromLuminanceProfile({
    required List<double> axialLuminance,
    required double pixelsPerMm,
  }) {
    if (pixelsPerMm < 6.0 || axialLuminance.length < 24) {
      return null;
    }

    final n = axialLuminance.length;
    final mean = axialLuminance.reduce((a, b) => a + b) / n;
    final centered = axialLuminance.map((v) => v - mean).toList();
    final zeroLag = centered.fold<double>(0.0, (acc, v) => acc + v * v);
    if (zeroLag <= 1e-6) return null;

    // Candidate pitches range from 0.5 mm to 4.0 mm
    final minLag = math.max(3, (0.5 * pixelsPerMm).floor());
    final maxLag = math.min(n ~/ 2, (4.0 * pixelsPerMm).ceil());
    if (maxLag <= minLag) return null;

    var bestLag = -1;
    var bestCorr = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var sum = 0.0;
      for (var i = 0; i < n - lag; i++) {
        sum += centered[i] * centered[i + lag];
      }
      final norm = sum / zeroLag;
      if (norm > bestCorr) {
        bestCorr = norm;
        bestLag = lag;
      }
    }

    if (bestLag < 0 || bestCorr < 0.28) {
      return null;
    }
    return bestLag / pixelsPerMm;
  }
}

class _ScoredThread {
  const _ScoredThread({required this.candidate, required this.penalty});

  final ThreadMatchCandidate candidate;
  final double penalty;
}
