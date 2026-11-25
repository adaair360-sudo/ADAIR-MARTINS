import 'dart:math' as math;

import 'camera_measurement_models.dart';

class MeasurementMath {
  const MeasurementMath._();

  static CalibrationResult? buildVisualCalibration({
    required double referencePixelSpan,
    required double knownReferenceMm,
    required String referenceName,
  }) {
    if (referencePixelSpan <= 0 || knownReferenceMm <= 0) {
      return null;
    }
    return CalibrationResult(
      source: CalibrationSource.knownObject,
      pixelsPerMm: referencePixelSpan / knownReferenceMm,
      referencePixelSpan: referencePixelSpan,
      knownReferenceMm: knownReferenceMm,
      referenceName: referenceName,
      createdAt: DateTime.now(),
    );
  }

  static double? convertPixelsToMillimeters(
    double pixelDistance,
    CalibrationResult? calibration,
  ) {
    if (calibration == null || !calibration.isCalibrated || pixelDistance <= 0) {
      return null;
    }
    return pixelDistance / calibration.pixelsPerMm;
  }

  static MeasurementUncertainty evaluateUncertainty({
    required CalibrationResult? calibration,
    required double measuredPixels,
    required double sharpnessVariance,
    required double contrastStdDev,
    double? arCoreDistanceMeters,
  }) {
    if (arCoreDistanceMeters != null) {
      // ARCore 3D tracking error typically scales with distance (~1-3% under good light)
      final distMm = arCoreDistanceMeters * 1000.0;
      final arErrorMm = math.max(4.0, distMm * 0.02);
      return MeasurementUncertainty(
        qualityLevel: distMm > 2500
            ? MeasurementQualityLevel.low
            : MeasurementQualityLevel.moderate,
        uncertaintyMm: arErrorMm,
        confidenceScore: distMm > 2500 ? 55 : 74,
        limitations: const [
          'Medição 3D estimada por ARCore; sujeita a textura da superfície e iluminação.',
          'Não substitui instrumento de metrologia certificado.',
        ],
      );
    }

    if (calibration == null || !calibration.isCalibrated) {
      return const MeasurementUncertainty(
        qualityLevel: MeasurementQualityLevel.uncalibrated,
        uncertaintyMm: null,
        confidenceScore: 0,
        limitations: [
          'Sem calibração ativa: resultado exibido apenas em pixels (px).',
          'Nunca utilize valores não calibrados como medida industrial.',
        ],
      );
    }

    // Quantization error: +/- 1.5 px on endpoints + reference endpoint error propagated
    final pxPerMm = calibration.pixelsPerMm;
    final endpointErrMm = 1.5 / pxPerMm;
    final refRelErr = 1.5 / math.max(calibration.referencePixelSpan, 1.0);
    final measuredMm = measuredPixels / pxPerMm;
    final propagatedRefErrMm = measuredMm * refRelErr;

    // Optical quality multiplier from real Laplacian sharpness & contrast
    var opticalFactor = 1.0;
    final limitations = <String>[
      'Medição 2D por referência visual: assume que o objeto e a referência estão no mesmo plano paralelo à câmera.',
    ];

    if (sharpnessVariance < 45) {
      opticalFactor += 0.65;
      limitations.add('Nitidez baixa detectada na imagem (possível desfoque).');
    } else if (sharpnessVariance < 120) {
      opticalFactor += 0.25;
    }

    if (contrastStdDev < 22) {
      opticalFactor += 0.4;
      limitations.add('Baixo contraste de iluminação pode deslocar bordas.');
    }

    if (calibration.referencePixelSpan < 80) {
      opticalFactor += 0.5;
      limitations.add(
        'Referência visual pequena em pixels (< 80 px) aumenta a incerteza.',
      );
    }

    final totalUncertaintyMm =
        math.sqrt(
          endpointErrMm * endpointErrMm +
              propagatedRefErrMm * propagatedRefErrMm,
        ) *
        opticalFactor;

    final relativeErrorPct = (totalUncertaintyMm / math.max(measuredMm, 0.1)) * 100;

    final quality = (relativeErrorPct <= 2.5 &&
            sharpnessVariance >= 100 &&
            calibration.referencePixelSpan >= 100)
        ? MeasurementQualityLevel.high
        : (relativeErrorPct <= 6.5)
        ? MeasurementQualityLevel.moderate
        : MeasurementQualityLevel.low;

    final confidence = (95 - (relativeErrorPct * 6.5) - (opticalFactor - 1.0) * 18)
        .round()
        .clamp(25, 95);

    limitations.add(
      'Incerteza estimada: ±${totalUncertaintyMm.toStringAsFixed(2)} mm (${relativeErrorPct.toStringAsFixed(1)}%). Não substitui paquímetro/micrômetro.',
    );

    return MeasurementUncertainty(
      qualityLevel: quality,
      uncertaintyMm: totalUncertaintyMm,
      confidenceScore: confidence,
      limitations: limitations,
    );
  }

  static String depthLimitationExplanation({required bool arCoreSupported}) {
    if (arCoreSupported) {
      return 'Profundidade pode ser estimada via sensor/API de profundidade do ARCore no modo 3D ao vivo.';
    }
    return 'Profundidade não pode ser medida diretamente em uma única foto 2D. Para medir profundidade, utilize uma segunda foto em vista lateral calibrada ou um aparelho compatível com ARCore Depth.';
  }
}
