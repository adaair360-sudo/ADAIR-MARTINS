import '../../material_id/domain/industrial_material.dart';
import '../../settings/domain/app_settings.dart';

enum GeometryShapeType {
  rectangularBlock('Bloco retangular'),
  cylinder('Cilindro'),
  tube('Tubo'),
  plate('Chapa'),
  sphere('Esfera'),
  cone('Cone / Tronco de cone'),
  hollowPart('Peça oca (bloco/casca)'),
  irregularGeometry('Geometria irregular'),
  directVolume('Volume direto informado');

  const GeometryShapeType(this.label);
  final String label;
}

enum IrregularInputMethod {
  crossSectionAreaAndThickness('Área da seção × espessura uniforme'),
  fluidDisplacement('Deslocamento de fluido (Arquimedes)');

  const IrregularInputMethod(this.label);
  final String label;
}

class VolumeCalculationInput {
  const VolumeCalculationInput({
    required this.shape,
    required this.dimensionUnit,
    this.length,
    this.width,
    this.heightOrThickness,
    this.outerDiameter,
    this.innerDiameter,
    this.topDiameter,
    this.wallThickness,
    this.outerVolumeCm3,
    this.cavityVolumeCm3,
    this.irregularMethod = IrregularInputMethod.crossSectionAreaAndThickness,
    this.sectionAreaCm2,
    this.fluidInitialMl,
    this.fluidFinalMl,
    this.directVolumeValue,
    this.directVolumeUnit = DirectVolumeUnit.cubicCentimeters,
  });

  final GeometryShapeType shape;
  final MeasurementUnit dimensionUnit;

  final double? length;
  final double? width;
  final double? heightOrThickness;
  final double? outerDiameter;
  final double? innerDiameter;
  final double? topDiameter;
  final double? wallThickness;

  final double? outerVolumeCm3;
  final double? cavityVolumeCm3;

  final IrregularInputMethod irregularMethod;
  final double? sectionAreaCm2;
  final double? fluidInitialMl;
  final double? fluidFinalMl;

  final double? directVolumeValue;
  final DirectVolumeUnit directVolumeUnit;
}

enum DirectVolumeUnit {
  cubicCentimeters('cm³'),
  cubicMeters('m³'),
  liters('L');

  const DirectVolumeUnit(this.symbol);
  final String symbol;
}

class VolumeAndWeightResult {
  const VolumeAndWeightResult({
    required this.isValid,
    required this.volumeCm3,
    required this.volumeM3,
    required this.volumeLiters,
    required this.grossVolumeCm3,
    required this.weightGrams,
    required this.weightKilograms,
    required this.densityGcm3,
    required this.materialName,
    required this.isHollowCalculation,
    required this.formulaUsed,
    required this.errorMessage,
    required this.notes,
  });

  final bool isValid;
  final double? volumeCm3;
  final double? volumeM3;
  final double? volumeLiters;
  final double? grossVolumeCm3;
  final double? weightGrams;
  final double? weightKilograms;
  final double? densityGcm3;
  final String materialName;
  final bool isHollowCalculation;
  final String formulaUsed;
  final String? errorMessage;
  final List<String> notes;

  double? get hollowWeightSavingsPercent {
    if (!isHollowCalculation ||
        volumeCm3 == null ||
        grossVolumeCm3 == null ||
        grossVolumeCm3! <= 0) {
      return null;
    }
    return ((grossVolumeCm3! - volumeCm3!) / grossVolumeCm3!) * 100.0;
  }
}

class MaterialDensitySelection {
  const MaterialDensitySelection({
    required this.material,
    required this.customDensityGcm3,
  });

  final IndustrialMaterial? material;
  final double? customDensityGcm3;
}
