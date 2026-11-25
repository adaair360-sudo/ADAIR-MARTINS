import '../../fastener_measurement/domain/fastener_models.dart';

enum ClampedPartMaterial {
  steel('Aço estrutural / Aço ligado', 1.0, false),
  castIron('Ferro fundido', 0.90, false),
  aluminum('Alumínio / Liga leve', 0.72, false),
  copperAlloy('Bronze / Latão', 0.80, false),
  polymerOrGasket('Polímero / Junta não metálica', 0.0, true);

  const ClampedPartMaterial(
    this.label,
    this.preloadSafetyFactor,
    this.requiresManufacturerSpec,
  );

  final String label;
  final double preloadSafetyFactor;
  final bool requiresManufacturerSpec;
}

enum JointType {
  throughBoltNut('União rígida com porca (furo passante)'),
  tappedHole('Furo roscado no próprio componente'),
  gasketOrSeal('União com junta / vedação compressível'),
  dynamicVibration('União sujeita a vibração / carga dinâmica');

  const JointType(this.label);
  final String label;
}

enum LubricationCondition {
  dryDegreased('Seco / desengraxado (atrito alto)', 0.18, 0.18),
  lightlyOiled('Levemente oleado (padrão de fábrica)', 0.13, 0.13),
  molyGrease('Graxa / Pasta MoS₂ (baixo atrito)', 0.09, 0.10),
  antiSeize('Pasta antiengripante (cobre/níquel/PTFE)', 0.12, 0.12),
  threadLocker('Travante químico anaeróbico', 0.15, 0.14);

  const LubricationCondition(
    this.label,
    this.threadFriction,
    this.bearingFriction,
  );

  final String label;
  final double threadFriction;
  final double bearingFriction;
}

enum WasherCondition {
  none('Sem arruela', 1.04),
  flatHardened('Arruela lisa endurecida (ISO 7089)', 1.00),
  springLock('Arruela de pressão / travamento', 1.08);

  const WasherCondition(this.label, this.bearingFactor);

  final String label;
  final double bearingFactor;
}

enum AssemblyCondition {
  controlledTorqueWrench('Aperto controlado (torquímetro calibrado, rosca limpa)'),
  manualUncontrolled('Aperto manual sem controle de torque'),
  reusedFastener('Parafuso/porca reutilizado (atrito alterado)');

  const AssemblyCondition(this.label);
  final String label;
}

enum ApplicableTechnicalNorm {
  vdi2230('VDI 2230 / ISO 898-1 (Cálculo elástico de uniões parafusadas)'),
  iso16047('ISO 16047 (Ensaio torque-força tensora em fixadores)'),
  iso3506('ISO 3506 (Fixadores em aço inoxidável A2/A4)'),
  asmeB11('ASME B1.1 / SAE J429 (Roscas UNC/UNF em polegadas)');

  const ApplicableTechnicalNorm(this.label);
  final String label;
}

class TorqueCalculationInput {
  const TorqueCalculationInput({
    required this.threadSpec,
    required this.strengthClass,
    required this.clampedMaterial,
    required this.jointType,
    required this.lubrication,
    required this.washer,
    required this.assemblyCondition,
    required this.applicableNorm,
    this.manufacturerTorqueNm,
    this.manufacturerSource,
    this.projectTorqueNm,
    this.projectSpecificationRef,
  });

  final ThreadSpec? threadSpec;
  final StrengthClassSpec? strengthClass;
  final ClampedPartMaterial? clampedMaterial;
  final JointType? jointType;
  final LubricationCondition? lubrication;
  final WasherCondition? washer;
  final AssemblyCondition? assemblyCondition;
  final ApplicableTechnicalNorm applicableNorm;

  final double? manufacturerTorqueNm;
  final String? manufacturerSource;
  final double? projectTorqueNm;
  final String? projectSpecificationRef;
}

class TorqueCalculationResult {
  const TorqueCalculationResult({
    required this.hasSafeCalculatedRecommendation,
    required this.calculatedTorqueNm,
    required this.calculatedMinNm,
    required this.calculatedMaxNm,
    required this.preloadKn,
    required this.stressAreaMm2,
    required this.specificationSummary,
    required this.technicalSource,
    required this.applicationConditions,
    required this.warnings,
    required this.missingEssentialData,
    required this.manufacturerTorqueNm,
    required this.manufacturerSource,
    required this.projectTorqueNm,
    required this.projectSpecificationRef,
  });

  final bool hasSafeCalculatedRecommendation;
  final double? calculatedTorqueNm;
  final double? calculatedMinNm;
  final double? calculatedMaxNm;
  final double? preloadKn;
  final double? stressAreaMm2;
  final String specificationSummary;
  final String technicalSource;
  final List<String> applicationConditions;
  final List<String> warnings;
  final List<String> missingEssentialData;

  final double? manufacturerTorqueNm;
  final String? manufacturerSource;
  final double? projectTorqueNm;
  final String? projectSpecificationRef;
}
