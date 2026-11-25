import 'dart:math' as math;

import '../../settings/domain/app_settings.dart';
import 'weight_volume_models.dart';

class VolumeWeightCalculator {
  const VolumeWeightCalculator._();

  static double _toCm(double value, MeasurementUnit unit) {
    return switch (unit) {
      MeasurementUnit.millimeters => value / 10.0,
      MeasurementUnit.centimeters => value,
      MeasurementUnit.meters => value * 100.0,
    };
  }

  static VolumeAndWeightResult calculate({
    required VolumeCalculationInput input,
    required double? densityGcm3,
    required String materialName,
  }) {
    final volumeEval = _evaluateVolume(input);
    if (!volumeEval.isValid || volumeEval.volumeCm3 == null) {
      return VolumeAndWeightResult(
        isValid: false,
        volumeCm3: null,
        volumeM3: null,
        volumeLiters: null,
        grossVolumeCm3: null,
        weightGrams: null,
        weightKilograms: null,
        densityGcm3: densityGcm3,
        materialName: materialName,
        isHollowCalculation: volumeEval.isHollow,
        formulaUsed: volumeEval.formulaUsed,
        errorMessage: volumeEval.errorMessage,
        notes: const [],
      );
    }

    final volCm3 = volumeEval.volumeCm3!;
    final volM3 = volCm3 / 1000000.0;
    final volLiters = volCm3 / 1000.0;

    final validDensity = (densityGcm3 != null && densityGcm3 > 0)
        ? densityGcm3
        : null;
    final grams = validDensity != null ? volCm3 * validDensity : null;
    final kg = grams != null ? grams / 1000.0 : null;

    final notes = <String>[
      'Resultado estimado offline a partir das dimensões informadas e densidade de referência ($materialName).',
      if (validDensity == null)
        'Informe uma densidade positiva (g/cm³) para calcular o peso em gramas e quilogramas.',
    ];

    return VolumeAndWeightResult(
      isValid: true,
      volumeCm3: volCm3,
      volumeM3: volM3,
      volumeLiters: volLiters,
      grossVolumeCm3: volumeEval.grossVolumeCm3,
      weightGrams: grams,
      weightKilograms: kg,
      densityGcm3: validDensity,
      materialName: materialName,
      isHollowCalculation: volumeEval.isHollow,
      formulaUsed: volumeEval.formulaUsed,
      errorMessage: null,
      notes: notes,
    );
  }

  static _VolumeOutcome _evaluateVolume(VolumeCalculationInput input) {
    final u = input.dimensionUnit;

    switch (input.shape) {
      case GeometryShapeType.rectangularBlock:
        final l = input.length;
        final w = input.width;
        final h = input.heightOrThickness;
        if (_anyInvalid([l, w, h])) {
          return const _VolumeOutcome.invalid(
            'V = Comprimento × Largura × Altura',
            'Informe comprimento, largura e altura positivos.',
          );
        }
        final v = _toCm(l!, u) * _toCm(w!, u) * _toCm(h!, u);
        return _VolumeOutcome.valid(
          volumeCm3: v,
          formulaUsed: 'V = C × L × A',
        );

      case GeometryShapeType.plate:
        final l = input.length;
        final w = input.width;
        final t = input.heightOrThickness;
        if (_anyInvalid([l, w, t])) {
          return const _VolumeOutcome.invalid(
            'V = Comprimento × Largura × Espessura',
            'Informe comprimento, largura e espessura positivos para a chapa.',
          );
        }
        final v = _toCm(l!, u) * _toCm(w!, u) * _toCm(t!, u);
        return _VolumeOutcome.valid(
          volumeCm3: v,
          formulaUsed: 'V = C × L × Espessura',
        );

      case GeometryShapeType.cylinder:
        final d = input.outerDiameter;
        final h = input.heightOrThickness;
        if (_anyInvalid([d, h])) {
          return const _VolumeOutcome.invalid(
            'V = π × (D / 2)² × Comprimento',
            'Informe o diâmetro externo e o comprimento/altura positivos.',
          );
        }
        final rCm = _toCm(d!, u) / 2.0;
        final hCm = _toCm(h!, u);
        final v = math.pi * rCm * rCm * hCm;
        return _VolumeOutcome.valid(
          volumeCm3: v,
          formulaUsed: 'V = π × (D / 2)² × H',
        );

      case GeometryShapeType.tube:
        final dExt = input.outerDiameter;
        final h = input.heightOrThickness;
        if (_anyInvalid([dExt, h])) {
          return const _VolumeOutcome.invalid(
            'V = π × ((D_ext / 2)² - (D_int / 2)²) × L',
            'Informe diâmetro externo e comprimento positivos para o tubo.',
          );
        }
        double? dInt = input.innerDiameter;
        if ((dInt == null || dInt <= 0) &&
            input.wallThickness != null &&
            input.wallThickness! > 0) {
          dInt = dExt! - 2.0 * input.wallThickness!;
        }
        if (dInt == null || dInt <= 0) {
          return const _VolumeOutcome.invalid(
            'V = π × ((D_ext / 2)² - (D_int / 2)²) × L',
            'Informe o diâmetro interno ou a espessura de parede válida do tubo.',
          );
        }
        if (dInt >= dExt!) {
          return const _VolumeOutcome.invalid(
            'V = π × ((D_ext / 2)² - (D_int / 2)²) × L',
            'O diâmetro interno deve ser menor que o diâmetro externo.',
          );
        }
        final rExt = _toCm(dExt, u) / 2.0;
        final rInt = _toCm(dInt, u) / 2.0;
        final lenCm = _toCm(h!, u);
        final gross = math.pi * rExt * rExt * lenCm;
        final v = math.pi * (rExt * rExt - rInt * rInt) * lenCm;
        return _VolumeOutcome.valid(
          volumeCm3: v,
          grossVolumeCm3: gross,
          isHollow: true,
          formulaUsed: 'V = π × (R_ext² - R_int²) × L',
        );

      case GeometryShapeType.sphere:
        final dExt = input.outerDiameter;
        if (_anyInvalid([dExt])) {
          return const _VolumeOutcome.invalid(
            'V = (4/3) × π × R³',
            'Informe o diâmetro externo positivo da esfera.',
          );
        }
        final rExt = _toCm(dExt!, u) / 2.0;
        final gross = (4.0 / 3.0) * math.pi * math.pow(rExt, 3).toDouble();
        final dInt = input.innerDiameter;
        if (dInt != null && dInt > 0) {
          if (dInt >= dExt) {
            return const _VolumeOutcome.invalid(
              'V = (4/3) × π × (R_ext³ - R_int³)',
              'O diâmetro interno da esfera oca deve ser menor que o diâmetro externo.',
            );
          }
          final rInt = _toCm(dInt, u) / 2.0;
          final solid =
              (4.0 / 3.0) *
              math.pi *
              (math.pow(rExt, 3) - math.pow(rInt, 3)).toDouble();
          return _VolumeOutcome.valid(
            volumeCm3: solid,
            grossVolumeCm3: gross,
            isHollow: true,
            formulaUsed: 'V = (4/3) × π × (R_ext³ - R_int³)',
          );
        }
        return _VolumeOutcome.valid(
          volumeCm3: gross,
          formulaUsed: 'V = (4/3) × π × R³',
        );

      case GeometryShapeType.cone:
        final dBase = input.outerDiameter;
        final h = input.heightOrThickness;
        final dTop = input.topDiameter ?? 0.0;
        if (_anyInvalid([dBase, h]) || dTop < 0) {
          return const _VolumeOutcome.invalid(
            'V = (π × H / 12) × (D_base² + D_base·D_topo + D_topo²)',
            'Informe diâmetro da base e altura positivos (diâmetro do topo = 0 para cone completo).',
          );
        }
        final db = _toCm(dBase!, u);
        final dt = _toCm(dTop, u);
        final hCm = _toCm(h!, u);
        final v = (math.pi * hCm / 12.0) * (db * db + db * dt + dt * dt);
        return _VolumeOutcome.valid(
          volumeCm3: v,
          formulaUsed: dt == 0
              ? 'V = (1/3) × π × R² × H'
              : 'V = (π × H / 12) × (D₁² + D₁·D₂ + D₂²)',
        );

      case GeometryShapeType.hollowPart:
        final outerVol = input.outerVolumeCm3;
        final cavityVol = input.cavityVolumeCm3;
        if (outerVol != null && cavityVol != null) {
          if (outerVol <= 0 || cavityVol < 0 || cavityVol >= outerVol) {
            return const _VolumeOutcome.invalid(
              'V = V_externo - V_cavidade',
              'O volume da cavidade deve ser menor que o volume externo.',
            );
          }
          return _VolumeOutcome.valid(
            volumeCm3: outerVol - cavityVol,
            grossVolumeCm3: outerVol,
            isHollow: true,
            formulaUsed: 'V = V_externo - V_cavidades',
          );
        }

        // Hollow box by wall thickness
        final l = input.length;
        final w = input.width;
        final h = input.heightOrThickness;
        final t = input.wallThickness;
        if (_anyInvalid([l, w, h, t])) {
          return const _VolumeOutcome.invalid(
            'V = V_externo - V_interno',
            'Informe dimensões externas + espessura da parede, ou volumes externo e interno (cm³).',
          );
        }
        final lCm = _toCm(l!, u);
        final wCm = _toCm(w!, u);
        final hCm = _toCm(h!, u);
        final tCm = _toCm(t!, u);
        if (2 * tCm >= lCm || 2 * tCm >= wCm || 2 * tCm >= hCm) {
          return const _VolumeOutcome.invalid(
            'V = V_externo - V_interno',
            'A espessura de parede excede a metade da menor dimensão externa.',
          );
        }
        final gross = lCm * wCm * hCm;
        final inner = (lCm - 2 * tCm) * (wCm - 2 * tCm) * (hCm - 2 * tCm);
        return _VolumeOutcome.valid(
          volumeCm3: gross - inner,
          grossVolumeCm3: gross,
          isHollow: true,
          formulaUsed: 'V = (C·L·A) - (C-2e)·(L-2e)·(A-2e)',
        );

      case GeometryShapeType.irregularGeometry:
        if (input.irregularMethod ==
            IrregularInputMethod.crossSectionAreaAndThickness) {
          final area = input.sectionAreaCm2;
          final t = input.heightOrThickness;
          if (_anyInvalid([area, t])) {
            return const _VolumeOutcome.invalid(
              'V = Área_seção × Espessura',
              'Dados insuficientes: informe a área da face (cm²) e a espessura uniforme para calcular geometria irregular.',
            );
          }
          final v = area! * _toCm(t!, u);
          return _VolumeOutcome.valid(
            volumeCm3: v,
            formulaUsed: 'V = Área_seção (cm²) × Espessura (cm)',
          );
        } else {
          final v0 = input.fluidInitialMl;
          final v1 = input.fluidFinalMl;
          if (v0 == null || v1 == null || v0 < 0 || v1 <= v0) {
            return const _VolumeOutcome.invalid(
              'V = V_final - V_inicial (Arquimedes)',
              'Dados insuficientes: informe o volume inicial e final do fluido (mL) com V_final > V_inicial.',
            );
          }
          return _VolumeOutcome.valid(
            volumeCm3: v1 - v0,
            formulaUsed: 'V = Deslocamento de fluido (1 mL = 1 cm³)',
          );
        }

      case GeometryShapeType.directVolume:
        final val = input.directVolumeValue;
        if (_anyInvalid([val])) {
          return const _VolumeOutcome.invalid(
            'Conversão direta de volume',
            'Informe um volume positivo para converter e calcular o peso.',
          );
        }
        final cm3 = switch (input.directVolumeUnit) {
          DirectVolumeUnit.cubicCentimeters => val!,
          DirectVolumeUnit.cubicMeters => val! * 1000000.0,
          DirectVolumeUnit.liters => val! * 1000.0,
        };
        return _VolumeOutcome.valid(
          volumeCm3: cm3,
          formulaUsed: 'Volume informado diretamente (${input.directVolumeUnit.symbol})',
        );
    }
  }

  static bool _anyInvalid(List<double?> values) {
    return values.any((v) => v == null || v <= 0);
  }
}

class _VolumeOutcome {
  const _VolumeOutcome.valid({
    required this.volumeCm3,
    required this.formulaUsed,
    this.grossVolumeCm3,
    this.isHollow = false,
  }) : isValid = true,
       errorMessage = null;

  const _VolumeOutcome.invalid(this.formulaUsed, this.errorMessage)
    : isValid = false,
      volumeCm3 = null,
      grossVolumeCm3 = null,
      isHollow = false;

  final bool isValid;
  final double? volumeCm3;
  final double? grossVolumeCm3;
  final bool isHollow;
  final String formulaUsed;
  final String? errorMessage;
}
