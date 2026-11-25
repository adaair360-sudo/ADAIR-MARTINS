import 'dart:math' as math;

import '../../fastener_measurement/domain/fastener_models.dart';
import 'torque_models.dart';

class TorqueCalculatorEngine {
  const TorqueCalculatorEngine._();

  static TorqueCalculationResult calculate(TorqueCalculationInput input) {
    final missing = <String>[];
    if (input.threadSpec == null) {
      missing.add('Diâmetro e passo da rosca');
    }
    if (input.strengthClass == null) {
      missing.add('Classe de resistência (4.6, 5.8, 8.8, 10.9, 12.9, A2 ou A4)');
    }
    if (input.clampedMaterial == null) {
      missing.add('Material das peças unidas');
    }
    if (input.jointType == null) {
      missing.add('Tipo de união');
    }
    if (input.lubrication == null) {
      missing.add('Condição de lubrificação');
    }
    if (input.washer == null) {
      missing.add('Configuração de arruela');
    }
    if (input.assemblyCondition == null) {
      missing.add('Condição de montagem');
    }

    final warnings = <String>[];
    final conditions = <String>[];

    if (missing.isNotEmpty) {
      warnings.add(
        'Recomendação segura bloqueada: faltam dados essenciais da união parafusada.',
      );
      return TorqueCalculationResult(
        hasSafeCalculatedRecommendation: false,
        calculatedTorqueNm: null,
        calculatedMinNm: null,
        calculatedMaxNm: null,
        preloadKn: null,
        stressAreaMm2: null,
        specificationSummary: 'Dados insuficientes para especificação',
        technicalSource: input.applicableNorm.label,
        applicationConditions: const [],
        warnings: warnings,
        missingEssentialData: missing,
        manufacturerTorqueNm: input.manufacturerTorqueNm,
        manufacturerSource: input.manufacturerSource,
        projectTorqueNm: input.projectTorqueNm,
        projectSpecificationRef: input.projectSpecificationRef,
      );
    }

    final thread = input.threadSpec!;
    final strength = input.strengthClass!;
    final clamped = input.clampedMaterial!;
    final joint = input.jointType!;
    final lube = input.lubrication!;
    final washer = input.washer!;
    final assembly = input.assemblyCondition!;

    // Block generic calculated torque for polymer/gasket joints unless manufacturer/project spec exists
    final isCompressibleJoint =
        clamped.requiresManufacturerSpec || joint == JointType.gasketOrSeal;
    if (isCompressibleJoint) {
      warnings.add(
        'Uniões com polímeros ou juntas compressíveis dependem de esmagamento e fluência da junta. Não é seguro recomendar torque apenas por fórmula metálica: utilize a especificação do fabricante da junta ou o torque de projeto.',
      );
      return TorqueCalculationResult(
        hasSafeCalculatedRecommendation: false,
        calculatedTorqueNm: null,
        calculatedMinNm: null,
        calculatedMaxNm: null,
        preloadKn: null,
        stressAreaMm2: null,
        specificationSummary:
            '${thread.designation} • Classe ${strength.code} • ${clamped.label}',
        technicalSource: input.applicableNorm.label,
        applicationConditions: [
          'Tipo de união: ${joint.label}',
          'Lubrificação: ${lube.label}',
          'Arruela: ${washer.label}',
        ],
        warnings: warnings,
        missingEssentialData: const [
          'Especificação do fabricante da junta/componente não metálico ou torque de projeto',
        ],
        manufacturerTorqueNm: input.manufacturerTorqueNm,
        manufacturerSource: input.manufacturerSource,
        projectTorqueNm: input.projectTorqueNm,
        projectSpecificationRef: input.projectSpecificationRef,
      );
    }

    // Tensile stress area A_s (ISO 898-1 / ASME B1.1)
    final d = thread.nominalDiameterMm;
    final p = thread.pitchMm;
    final stressDia = thread.standard == ThreadStandard.metricIso
        ? d - 0.938194 * p
        : d - 0.9743 * p;
    final stressAreaMm2 = (math.pi / 4.0) * stressDia * stressDia;

    // Utilization of proof/yield strength: VDI 2230 standard ~0.75 elastic limit,
    // scaled conservatively for softer clamped materials & dynamic/reused joints.
    var utilization = 0.75 * clamped.preloadSafetyFactor;
    if (joint == JointType.dynamicVibration) {
      utilization *= 0.90;
      warnings.add(
        'União sob vibração: recomenda-se travamento mecânico/químico e verificação periódica de pré-carga.',
      );
    }
    if (joint == JointType.tappedHole &&
        clamped == ClampedPartMaterial.aluminum) {
      warnings.add(
        'Furo roscado em alumínio: verifique comprimento mínimo de engajamento >= 1,5×D a 2,0×D para evitar espanamento da rosca fêmea.',
      );
    }
    if (strength.isStainless && lube == LubricationCondition.dryDegreased) {
      warnings.add(
        'ALERTA DE ENGRIPAMENTO (Galling): fixadores inoxidáveis A2/A4 montados a seco apresentam alto risco de travamento/gripagem. Utilize pasta antiengripante.',
      );
    }
    if (assembly == AssemblyCondition.manualUncontrolled) {
      utilization *= 0.85;
      warnings.add(
        'Aperto manual sem torquímetro possui dispersão superior a ±25%. Utilize torquímetro calibrado para montagens críticas.',
      );
    } else if (assembly == AssemblyCondition.reusedFastener) {
      utilization *= 0.85;
      warnings.add(
        'Fixador reutilizado altera o coeficiente de atrito; classes 10.9/12.9 e porcas autotravantes não devem ser reutilizadas em uniões críticas.',
      );
    }

    // Preload F_M in Newtons (stressAreaMm2 * MPa = N)
    final preloadN = stressAreaMm2 * strength.yieldOrProofMpa * utilization;

    // Motosh / VDI 2230 torque equation
    final pitchM = p / 1000.0;
    final d2M = (d - 0.649519 * p) / 1000.0;
    final bearingDiameterMm = thread.hexWrenchMm != null
        ? (d * 1.1 + thread.hexWrenchMm!) / 2.0
        : d * 1.32;
    final dkmM = bearingDiameterMm / 1000.0;

    final muG = lube.threadFriction;
    final muK = (lube.bearingFriction * washer.bearingFactor).clamp(0.08, 0.24);

    final torqueNm =
        preloadN *
        ((pitchM / (2.0 * math.pi)) +
            (0.5775 * d2M * muG) +
            (0.5 * dkmM * muK));

    final scatter = assembly == AssemblyCondition.controlledTorqueWrench
        ? 0.08
        : 0.18;
    final minNm = torqueNm * (1.0 - scatter);
    final maxNm = torqueNm * (1.0 + scatter);

    conditions.addAll([
      'Elemento: ${thread.designation} (${thread.standard.label}, passo ${p.toStringAsFixed(2)} mm)',
      'Resistência: Classe ${strength.code} (Re=${strength.yieldOrProofMpa} MPa, utilização ${(utilization * 100).toStringAsFixed(0)}%)',
      'Peças unidas: ${clamped.label} • ${joint.label}',
      'Lubrificação: ${lube.label} (μG=${muG.toStringAsFixed(2)}, μK=${muK.toStringAsFixed(2)})',
      'Arruela: ${washer.label}',
      'Montagem: ${assembly.label}',
    ]);

    warnings.add(
      'Torque calculado é teórico (VDI 2230 / ISO 16047). Caso haja torque especificado em projeto ou recomendado pelo fabricante, estes têm prioridade absoluta.',
    );

    final sourceText =
        '${input.applicableNorm.label}; cálculo analítico Motosh / VDI 2230 com área resistente ISO 898-1 (As=${stressAreaMm2.toStringAsFixed(1)} mm²).';

    return TorqueCalculationResult(
      hasSafeCalculatedRecommendation: true,
      calculatedTorqueNm: torqueNm,
      calculatedMinNm: minNm,
      calculatedMaxNm: maxNm,
      preloadKn: preloadN / 1000.0,
      stressAreaMm2: stressAreaMm2,
      specificationSummary:
          '${thread.designation} • Classe ${strength.code} • ${lube.label}',
      technicalSource: sourceText,
      applicationConditions: conditions,
      warnings: warnings,
      missingEssentialData: const [],
      manufacturerTorqueNm: input.manufacturerTorqueNm,
      manufacturerSource: input.manufacturerSource,
      projectTorqueNm: input.projectTorqueNm,
      projectSpecificationRef: input.projectSpecificationRef,
    );
  }
}
