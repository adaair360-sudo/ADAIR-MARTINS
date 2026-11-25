import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../domain/industrial_material.dart';
import '../domain/material_analysis_models.dart';

class MaterialAnalyzerService {
  static const MethodChannel _openCvChannel = MethodChannel(
    'br.com.medicaoai3d/opencv',
  );

  Future<VisualSurfaceFeatures> extractFeatures(
    String imagePath, {
    bool useCenterRoi = true,
  }) async {
    final roiLeft = useCenterRoi ? 0.20 : 0.0;
    final roiTop = useCenterRoi ? 0.20 : 0.0;
    final roiWidth = useCenterRoi ? 0.60 : 1.0;
    final roiHeight = useCenterRoi ? 0.60 : 1.0;

    try {
      final raw = await _openCvChannel.invokeMapMethod<String, dynamic>(
        'analyzeMaterialSurface',
        {
          'imagePath': imagePath,
          'roiLeft': roiLeft,
          'roiTop': roiTop,
          'roiWidth': roiWidth,
          'roiHeight': roiHeight,
        },
      );
      if (raw != null) {
        return VisualSurfaceFeatures(
          engine: raw['engine'] as String? ?? 'opencv_native',
          meanHue: (raw['meanHue'] as num).toDouble(),
          meanSaturation: (raw['meanSaturation'] as num).toDouble(),
          meanValue: (raw['meanValue'] as num).toDouble(),
          specularRatio: (raw['specularRatio'] as num).toDouble(),
          warmMetalRatio: (raw['warmMetalRatio'] as num).toDouble(),
          darkMatteRatio: (raw['darkMatteRatio'] as num).toDouble(),
          chromaticRatio: (raw['chromaticRatio'] as num).toDouble(),
          textureEnergy: (raw['textureEnergy'] as num).toDouble(),
          anisotropyRatio: (raw['anisotropyRatio'] as num).toDouble(),
          sharpnessVariance: (raw['sharpnessVariance'] as num).toDouble(),
        );
      }
    } on MissingPluginException {
      // Deterministic Dart fallback for tests and non-Android hosts
    } on PlatformException {
      // Deterministic Dart fallback if native OpenCV fails
    }

    return extractFeaturesInDart(
      imagePath,
      roiLeft: roiLeft,
      roiTop: roiTop,
      roiWidth: roiWidth,
      roiHeight: roiHeight,
    );
  }

  VisualSurfaceFeatures extractFeaturesInDart(
    String imagePath, {
    double roiLeft = 0.20,
    double roiTop = 0.20,
    double roiWidth = 0.60,
    double roiHeight = 0.60,
  }) {
    final bytes = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ArgumentError('Não foi possível decodificar a imagem em $imagePath');
    }

    final x0 = (roiLeft.clamp(0.0, 0.9) * decoded.width).round().clamp(
      0,
      decoded.width - 2,
    );
    final y0 = (roiTop.clamp(0.0, 0.9) * decoded.height).round().clamp(
      0,
      decoded.height - 2,
    );
    final rw = (roiWidth.clamp(0.1, 1.0) * decoded.width).round().clamp(
      2,
      decoded.width - x0,
    );
    final rh = (roiHeight.clamp(0.1, 1.0) * decoded.height).round().clamp(
      2,
      decoded.height - y0,
    );

    final cropped = img.copyCrop(decoded, x: x0, y: y0, width: rw, height: rh);
    final maxSide = math.max(cropped.width, cropped.height);
    final work = maxSide > 240
        ? img.copyResize(
            cropped,
            width: math.max(8, (cropped.width * 240 / maxSide).round()),
            height: math.max(8, (cropped.height * 240 / maxSide).round()),
          )
        : cropped;

    final w = work.width;
    final h = work.height;
    final total = math.max(1, w * h);
    final gray = List<double>.filled(total, 0);

    var sumHue = 0.0;
    var sumSat = 0.0;
    var sumVal = 0.0;
    var specularCount = 0;
    var warmMetalCount = 0;
    var darkMatteCount = 0;
    var chromaticCount = 0;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final px = work.getPixel(x, y);
        final r = px.r / 255.0;
        final g = px.g / 255.0;
        final b = px.b / 255.0;
        gray[y * w + x] = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b);

        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final delta = maxC - minC;

        var hue = 0.0;
        if (delta > 1e-6) {
          if (maxC == r) {
            hue = 60.0 * (((g - b) / delta) % 6.0);
          } else if (maxC == g) {
            hue = 60.0 * (((b - r) / delta) + 2.0);
          } else {
            hue = 60.0 * (((r - g) / delta) + 4.0);
          }
          if (hue < 0) hue += 360.0;
        }
        final sat = maxC > 1e-6 ? (delta / maxC) * 255.0 : 0.0;
        final val = maxC * 255.0;

        sumHue += hue;
        sumSat += sat;
        sumVal += val;

        if (val >= 220.0 && sat <= 50.0) specularCount++;
        if (hue >= 8.0 &&
            hue <= 48.0 &&
            sat >= 45.0 &&
            sat <= 235.0 &&
            val >= 60.0) {
          warmMetalCount++;
        }
        if (val <= 85.0 && sat <= 55.0) darkMatteCount++;
        if (sat >= 65.0) chromaticCount++;
      }
    }

    var gxSum = 0.0;
    var gySum = 0.0;
    var lapSum = 0.0;
    var lapSqSum = 0.0;
    var edgeCount = 0;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final gx =
            (-gray[(y - 1) * w + (x - 1)] +
                    gray[(y - 1) * w + (x + 1)] -
                    2 * gray[y * w + (x - 1)] +
                    2 * gray[y * w + (x + 1)] -
                    gray[(y + 1) * w + (x - 1)] +
                    gray[(y + 1) * w + (x + 1)])
                .abs();
        final gy =
            (-gray[(y - 1) * w + (x - 1)] -
                    2 * gray[(y - 1) * w + x] -
                    gray[(y - 1) * w + (x + 1)] +
                    gray[(y + 1) * w + (x - 1)] +
                    2 * gray[(y + 1) * w + x] +
                    gray[(y + 1) * w + (x + 1)])
                .abs();
        gxSum += gx;
        gySum += gy;

        final lap =
            gray[(y - 1) * w + x] +
            gray[(y + 1) * w + x] +
            gray[y * w + (x - 1)] +
            gray[y * w + (x + 1)] -
            4 * gray[y * w + x];
        lapSum += lap;
        lapSqSum += lap * lap;
        edgeCount++;
      }
    }

    final meanGx = edgeCount > 0 ? gxSum / edgeCount : 0.0;
    final meanGy = edgeCount > 0 ? gySum / edgeCount : 0.0;
    final lapMean = edgeCount > 0 ? lapSum / edgeCount : 0.0;
    final sharpnessVariance = edgeCount > 0
        ? math.max(0.0, (lapSqSum / edgeCount) - lapMean * lapMean)
        : 0.0;

    return VisualSurfaceFeatures(
      engine: 'dart_hsv_sobel_fallback',
      meanHue: sumHue / total,
      meanSaturation: sumSat / total,
      meanValue: sumVal / total,
      specularRatio: specularCount / total,
      warmMetalRatio: warmMetalCount / total,
      darkMatteRatio: darkMatteCount / total,
      chromaticRatio: chromaticCount / total,
      textureEnergy: (meanGx + meanGy) / 2.0,
      anisotropyRatio: math.max(meanGx, meanGy) / math.max(math.min(meanGx, meanGy), 0.5),
      sharpnessVariance: sharpnessVariance,
    );
  }

  Future<MaterialIdentificationResult> analyzeImage(
    String imagePath, {
    bool useCenterRoi = true,
  }) async {
    final features = await extractFeatures(
      imagePath,
      useCenterRoi: useCenterRoi,
    );
    return classifyFeatures(features);
  }

  MaterialIdentificationResult classifyFeatures(VisualSurfaceFeatures f) {
    final warnings = <String>[
      materialChemicalDisclaimer,
    ];
    if (f.sharpnessVariance < 35) {
      warnings.add('Nitidez reduzida na área analisada: aproxime a câmera e estabilize o foco.');
    }
    if (f.meanValue < 45) {
      warnings.add('Iluminação baixa detectada: sombras podem confundir metais escuros, borracha e ferro fundido.');
    } else if (f.specularRatio > 0.35) {
      warnings.add('Excesso de reflexo direto: reduza o brilho especular inclinando levemente a peça.');
    }

    final scored = <_ScoredMaterial>[];
    for (final material in industrialMaterialsCatalog) {
      final eval = _scoreMaterial(material, f);
      scored.add(eval);
    }

    scored.sort((a, b) => b.rawScore.compareTo(a.rawScore));

    // Convert top scores to bounded visual probabilities (capped at 84% because camera alone cannot prove alloy)
    final maxScore = scored.first.rawScore;
    final expWeights = scored
        .map((s) => math.exp(((s.rawScore - maxScore) / 14.0).clamp(-10.0, 0.0)))
        .toList();
    final sumWeights = expWeights.fold<double>(0.0, (acc, w) => acc + w);

    final sharpnessPenalty = f.sharpnessVariance < 30 ? 0.80 : 1.0;
    final candidates = <MaterialCandidate>[];
    for (var i = 0; i < scored.length; i++) {
      final share = expWeights[i] / math.max(sumWeights, 1e-6);
      // Scale into realistic engineering visual confidence [8..84]
      final bounded = (share * 100.0 * sharpnessPenalty)
          .clamp(6.0, 84.0)
          .round();
      candidates.add(
        MaterialCandidate(
          material: scored[i].material,
          confidencePercent: bounded,
          observedReasons: scored[i].reasons,
        ),
      );
    }

    return MaterialIdentificationResult(
      features: f,
      candidates: candidates,
      selectedMaterial: candidates.first.material,
      isManuallyCorrected: false,
      opticalWarnings: warnings,
      analyzedAt: DateTime.now(),
    );
  }

  _ScoredMaterial _scoreMaterial(
    IndustrialMaterial m,
    VisualSurfaceFeatures f,
  ) {
    var score = 50.0;
    final reasons = <String>[];

    double closeness(double value, double target, double tolerance) {
      final diff = (value - target).abs() / math.max(tolerance, 1e-3);
      return math.max(0.0, 1.0 - diff);
    }

    switch (m.id) {
      case 'copper':
        score += 28 * closeness(f.meanHue, 14, 10);
        score += 18 * closeness(f.meanSaturation, 145, 70);
        score += 16 * closeness(f.warmMetalRatio, 0.65, 0.45);
        score += 10 * closeness(f.specularRatio, 0.12, 0.12);
        score -= 20 * f.darkMatteRatio;
        if (f.warmMetalRatio > 0.25 && f.meanHue <= 24) {
          reasons.add('Tom alaranjado-avermelhado compatível com cobre');
        }
        break;

      case 'brass':
        score += 26 * closeness(f.meanHue, 42, 12);
        score += 16 * closeness(f.meanSaturation, 130, 65);
        score += 16 * closeness(f.warmMetalRatio, 0.60, 0.45);
        score += 14 * closeness(f.specularRatio, 0.16, 0.14);
        score -= 18 * f.darkMatteRatio;
        if (f.warmMetalRatio > 0.2 && f.meanHue >= 30 && f.meanHue <= 55) {
          reasons.add('Tom amarelo-dourado compatível com latão');
        }
        break;

      case 'bronze':
        score += 24 * closeness(f.meanHue, 27, 10);
        score += 14 * closeness(f.meanSaturation, 105, 55);
        score += 14 * closeness(f.meanValue, 125, 55);
        score += 12 * closeness(f.warmMetalRatio, 0.50, 0.40);
        score += 8 * closeness(f.textureEnergy, 14, 14);
        if (f.warmMetalRatio > 0.2 && f.meanValue < 170) {
          reasons.add('Tonalidade dourado-acastanhada compatível com bronze');
        }
        break;

      case 'wood':
        score += 24 * closeness(f.meanHue, 28, 12);
        score += 14 * closeness(f.meanSaturation, 115, 60);
        score += 22 * closeness(f.anisotropyRatio, 1.8, 0.8);
        score += 14 * closeness(f.specularRatio, 0.005, 0.03);
        score += 10 * closeness(f.textureEnergy, 24, 18);
        if (f.anisotropyRatio >= 1.35) {
          reasons.add('Veios direcionais e baixo brilho compatíveis com madeira');
        }
        break;

      case 'stainless_steel':
        score += 24 * closeness(f.meanSaturation, 18, 22);
        score += 20 * closeness(f.meanValue, 178, 50);
        score += 22 * closeness(f.specularRatio, 0.18, 0.14);
        score += 10 * closeness(f.textureEnergy, 10, 12);
        score -= 22 * f.warmMetalRatio;
        if (f.meanSaturation < 40 && f.specularRatio >= 0.05) {
          reasons.add('Cinza prateado claro com reflexo especular');
        }
        break;

      case 'aluminum':
        score += 24 * closeness(f.meanSaturation, 16, 20);
        score += 20 * closeness(f.meanValue, 188, 45);
        score += 16 * closeness(f.specularRatio, 0.06, 0.07);
        score += 12 * closeness(f.textureEnergy, 9, 10);
        score -= 20 * f.warmMetalRatio;
        if (f.meanSaturation < 38 && f.meanValue >= 150) {
          reasons.add('Luminância clara acetinada típica de alumínio');
        }
        break;

      case 'carbon_steel':
        score += 22 * closeness(f.meanSaturation, 22, 24);
        score += 20 * closeness(f.meanValue, 122, 42);
        score += 14 * closeness(f.specularRatio, 0.08, 0.09);
        score += 12 * closeness(f.textureEnergy, 15, 14);
        score -= 16 * f.warmMetalRatio;
        if (f.meanSaturation < 45 && f.meanValue >= 80 && f.meanValue <= 165) {
          reasons.add('Cinza metálico intermediário compatível com aço carbono');
        }
        break;

      case 'cast_iron':
        score += 22 * closeness(f.meanSaturation, 18, 22);
        score += 18 * closeness(f.meanValue, 78, 35);
        score += 20 * closeness(f.textureEnergy, 28, 18);
        score += 14 * closeness(f.specularRatio, 0.01, 0.03);
        score += 10 * closeness(f.darkMatteRatio, 0.45, 0.45);
        if (f.textureEnergy >= 18 && f.meanValue < 110) {
          reasons.add('Superfície escura granular compatível com ferro fundido');
        }
        break;

      case 'rubber':
        score += 26 * closeness(f.darkMatteRatio, 0.78, 0.45);
        score += 20 * closeness(f.meanValue, 42, 32);
        score += 16 * closeness(f.meanSaturation, 18, 24);
        score += 16 * closeness(f.specularRatio, 0.0, 0.02);
        if (f.darkMatteRatio >= 0.4 && f.specularRatio < 0.02) {
          reasons.add('Escuro, acromático e fosco, típico de borracha técnica');
        }
        break;

      case 'pvc':
        score += 18 * closeness(f.textureEnergy, 6, 8);
        score += 16 * closeness(f.specularRatio, 0.03, 0.04);
        score += 16 * closeness(f.chromaticRatio, 0.55, 0.45);
        score += 12 * closeness(f.meanValue, 138, 65);
        if (f.textureEnergy < 12) {
          reasons.add('Superfície uniforme e lisa típica de termoplástico');
        }
        break;

      case 'nylon':
        score += 18 * closeness(f.meanSaturation, 28, 32);
        score += 18 * closeness(f.meanValue, 195, 48);
        score += 16 * closeness(f.textureEnergy, 6, 8);
        score += 14 * closeness(f.specularRatio, 0.03, 0.04);
        if (f.meanValue >= 165 && f.textureEnergy < 12) {
          reasons.add('Superfície clara acetinada e lisa compatível com nylon');
        }
        break;

      case 'polyethylene':
        score += 18 * closeness(f.textureEnergy, 5, 7);
        score += 16 * closeness(f.specularRatio, 0.02, 0.03);
        score += 14 * closeness(f.meanValue, 165, 65);
        score += 12 * closeness(f.chromaticRatio, 0.45, 0.45);
        if (f.specularRatio < 0.04 && f.textureEnergy < 10) {
          reasons.add('Aspecto ceroso de baixo reflexo compatível com polietileno');
        }
        break;

      case 'glass':
        score += 22 * closeness(f.specularRatio, 0.24, 0.16);
        score += 18 * closeness(f.textureEnergy, 4, 6);
        score += 14 * closeness(f.meanValue, 185, 55);
        score += 12 * closeness(f.meanSaturation, 22, 26);
        if (f.specularRatio >= 0.12 && f.textureEnergy < 10) {
          reasons.add('Reflexo especular limpo com textura nula');
        }
        break;

      case 'ceramic':
        score += 18 * closeness(f.meanValue, 185, 60);
        score += 16 * closeness(f.meanSaturation, 35, 38);
        score += 14 * closeness(f.specularRatio, 0.07, 0.08);
        score += 12 * closeness(f.textureEnergy, 14, 14);
        if (f.meanValue >= 140 && f.warmMetalRatio < 0.2) {
          reasons.add('Aparência mineral homogênea compatível com cerâmica');
        }
        break;
    }

    if (reasons.isEmpty) {
      reasons.add('Características dentro da faixa secundária de referência');
    }

    return _ScoredMaterial(
      material: m,
      rawScore: score,
      reasons: reasons,
    );
  }
}

class _ScoredMaterial {
  const _ScoredMaterial({
    required this.material,
    required this.rawScore,
    required this.reasons,
  });

  final IndustrialMaterial material;
  final double rawScore;
  final List<String> reasons;
}
