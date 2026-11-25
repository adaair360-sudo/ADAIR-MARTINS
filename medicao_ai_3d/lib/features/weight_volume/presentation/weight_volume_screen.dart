import 'package:material_ui/material_ui.dart';

import '../../../core/theme/industrial_theme.dart';
import '../../material_id/domain/industrial_material.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/volume_weight_calculator.dart';
import '../domain/weight_volume_models.dart';

class WeightVolumeScreen extends StatefulWidget {
  const WeightVolumeScreen({
    super.key,
    required this.settingsController,
    this.initialMaterial,
  });

  final SettingsController settingsController;
  final IndustrialMaterial? initialMaterial;

  @override
  State<WeightVolumeScreen> createState() => _WeightVolumeScreenState();
}

class _WeightVolumeScreenState extends State<WeightVolumeScreen> {
  GeometryShapeType _shape = GeometryShapeType.rectangularBlock;
  late MeasurementUnit _dimensionUnit;
  IrregularInputMethod _irregularMethod =
      IrregularInputMethod.crossSectionAreaAndThickness;
  DirectVolumeUnit _directVolumeUnit = DirectVolumeUnit.cubicCentimeters;

  late IndustrialMaterial _selectedMaterial;
  bool _densityManuallyEdited = false;

  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _outerDiaCtrl = TextEditingController();
  final _innerDiaCtrl = TextEditingController();
  final _topDiaCtrl = TextEditingController(text: '0');
  final _wallCtrl = TextEditingController();
  final _outerVolCtrl = TextEditingController();
  final _cavityVolCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _fluidInitCtrl = TextEditingController();
  final _fluidFinalCtrl = TextEditingController();
  final _directVolCtrl = TextEditingController();
  late final TextEditingController _densityCtrl;

  @override
  void initState() {
    super.initState();
    _dimensionUnit = widget.settingsController.settings.defaultUnit;
    _selectedMaterial = widget.initialMaterial ?? industrialMaterialsCatalog.first;
    _densityCtrl = TextEditingController(
      text: _selectedMaterial.densityGcm3.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _outerDiaCtrl.dispose();
    _innerDiaCtrl.dispose();
    _topDiaCtrl.dispose();
    _wallCtrl.dispose();
    _outerVolCtrl.dispose();
    _cavityVolCtrl.dispose();
    _areaCtrl.dispose();
    _fluidInitCtrl.dispose();
    _fluidFinalCtrl.dispose();
    _directVolCtrl.dispose();
    _densityCtrl.dispose();
    super.dispose();
  }

  double? _parseNum(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  VolumeAndWeightResult get _result {
    final density = _parseNum(_densityCtrl);
    final matLabel = _densityManuallyEdited
        ? '${_selectedMaterial.name} (densidade ajustada)'
        : _selectedMaterial.name;

    return VolumeWeightCalculator.calculate(
      input: VolumeCalculationInput(
        shape: _shape,
        dimensionUnit: _dimensionUnit,
        length: _parseNum(_lengthCtrl),
        width: _parseNum(_widthCtrl),
        heightOrThickness: _parseNum(_heightCtrl),
        outerDiameter: _parseNum(_outerDiaCtrl),
        innerDiameter: _parseNum(_innerDiaCtrl),
        topDiameter: _parseNum(_topDiaCtrl),
        wallThickness: _parseNum(_wallCtrl),
        outerVolumeCm3: _parseNum(_outerVolCtrl),
        cavityVolumeCm3: _parseNum(_cavityVolCtrl),
        irregularMethod: _irregularMethod,
        sectionAreaCm2: _parseNum(_areaCtrl),
        fluidInitialMl: _parseNum(_fluidInitCtrl),
        fluidFinalMl: _parseNum(_fluidFinalCtrl),
        directVolumeValue: _parseNum(_directVolCtrl),
        directVolumeUnit: _directVolumeUnit,
      ),
      densityGcm3: density,
      materialName: matLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;
    final decimals = widget.settingsController.settings.decimalPlaces;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildShapeSelectorCard(theme),
        const SizedBox(height: 12),
        _buildDimensionsCard(theme),
        const SizedBox(height: 12),
        _buildMaterialAndDensityCard(theme),
        const SizedBox(height: 12),
        _buildResultCard(theme, res, decimals),
      ],
    );
  }

  Widget _buildShapeSelectorCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '1. Geometria da Peça (Offline)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Chip(
                  avatar: Icon(Icons.offline_bolt_outlined, size: 16),
                  label: Text('100% Offline', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final shape in GeometryShapeType.values)
                  ChoiceChip(
                    label: Text(shape.label),
                    selected: _shape == shape,
                    onSelected: (_) => setState(() => _shape = shape),
                  ),
              ],
            ),
            if (_shape != GeometryShapeType.directVolume) ...[
              const SizedBox(height: 12),
              Text(
                'Unidade das medidas informadas',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<MeasurementUnit>(
                segments: [
                  for (final unit in MeasurementUnit.values)
                    ButtonSegment(
                      value: unit,
                      label: Text(unit.symbol.toUpperCase()),
                    ),
                ],
                selected: {_dimensionUnit},
                onSelectionChanged: (s) =>
                    setState(() => _dimensionUnit = s.first),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionsCard(ThemeData theme) {
    final unitSym = _dimensionUnit.symbol;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Dimensões (${_shape.label})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ..._buildShapeFields(unitSym),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildShapeFields(String unitSym) {
    switch (_shape) {
      case GeometryShapeType.rectangularBlock:
        return [
          _fieldRow([
            _DimInput(
              controller: _lengthCtrl,
              label: 'Comprimento ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _widthCtrl,
              label: 'Largura ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
          const SizedBox(height: 10),
          _DimInput(
            controller: _heightCtrl,
            label: 'Altura ($unitSym)',
            onChanged: () => setState(() {}),
          ),
        ];

      case GeometryShapeType.plate:
        return [
          _fieldRow([
            _DimInput(
              controller: _lengthCtrl,
              label: 'Comprimento ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _widthCtrl,
              label: 'Largura ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
          const SizedBox(height: 10),
          _DimInput(
            controller: _heightCtrl,
            label: 'Espessura ($unitSym)',
            onChanged: () => setState(() {}),
          ),
        ];

      case GeometryShapeType.cylinder:
        return [
          _fieldRow([
            _DimInput(
              controller: _outerDiaCtrl,
              label: 'Diâmetro ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _heightCtrl,
              label: 'Comprimento / Altura ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
        ];

      case GeometryShapeType.tube:
        return [
          _fieldRow([
            _DimInput(
              controller: _outerDiaCtrl,
              label: 'Diâmetro externo ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _heightCtrl,
              label: 'Comprimento ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
          const SizedBox(height: 10),
          _fieldRow([
            _DimInput(
              controller: _innerDiaCtrl,
              label: 'Diâmetro interno ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _wallCtrl,
              label: 'ou Espessura parede ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
        ];

      case GeometryShapeType.sphere:
        return [
          _fieldRow([
            _DimInput(
              controller: _outerDiaCtrl,
              label: 'Diâmetro externo ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _innerDiaCtrl,
              label: 'Diâm. interno (opcional p/ oca)',
              onChanged: () => setState(() {}),
            ),
          ]),
        ];

      case GeometryShapeType.cone:
        return [
          _fieldRow([
            _DimInput(
              controller: _outerDiaCtrl,
              label: 'Diâmetro da base ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _heightCtrl,
              label: 'Altura ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
          const SizedBox(height: 10),
          _DimInput(
            controller: _topDiaCtrl,
            label: 'Diâmetro do topo ($unitSym) — 0 para cone completo',
            onChanged: () => setState(() {}),
          ),
        ];

      case GeometryShapeType.hollowPart:
        return [
          _fieldRow([
            _DimInput(
              controller: _lengthCtrl,
              label: 'Comprimento ext. ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _widthCtrl,
              label: 'Largura ext. ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
          const SizedBox(height: 10),
          _fieldRow([
            _DimInput(
              controller: _heightCtrl,
              label: 'Altura ext. ($unitSym)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _wallCtrl,
              label: 'Espessura parede ($unitSym)',
              onChanged: () => setState(() {}),
            ),
          ]),
          const SizedBox(height: 10),
          const Text(
            'Ou informe volumes diretamente (cm³):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _fieldRow([
            _DimInput(
              controller: _outerVolCtrl,
              label: 'Volume externo (cm³)',
              onChanged: () => setState(() {}),
            ),
            _DimInput(
              controller: _cavityVolCtrl,
              label: 'Volume cavidades (cm³)',
              onChanged: () => setState(() {}),
            ),
          ]),
        ];

      case GeometryShapeType.irregularGeometry:
        return [
          SegmentedButton<IrregularInputMethod>(
            segments: [
              for (final m in IrregularInputMethod.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_irregularMethod},
            onSelectionChanged: (s) =>
                setState(() => _irregularMethod = s.first),
          ),
          const SizedBox(height: 10),
          if (_irregularMethod ==
              IrregularInputMethod.crossSectionAreaAndThickness)
            _fieldRow([
              _DimInput(
                controller: _areaCtrl,
                label: 'Área da face (cm²)',
                onChanged: () => setState(() {}),
              ),
              _DimInput(
                controller: _heightCtrl,
                label: 'Espessura ($unitSym)',
                onChanged: () => setState(() {}),
              ),
            ])
          else
            _fieldRow([
              _DimInput(
                controller: _fluidInitCtrl,
                label: 'Volume inicial (mL)',
                onChanged: () => setState(() {}),
              ),
              _DimInput(
                controller: _fluidFinalCtrl,
                label: 'Volume final (mL)',
                onChanged: () => setState(() {}),
              ),
            ]),
        ];

      case GeometryShapeType.directVolume:
        return [
          Row(
            children: [
              Expanded(
                child: _DimInput(
                  controller: _directVolCtrl,
                  label: 'Volume informado',
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<DirectVolumeUnit>(
                value: _directVolumeUnit,
                items: [
                  for (final du in DirectVolumeUnit.values)
                    DropdownMenuItem(value: du, child: Text(du.symbol)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _directVolumeUnit = v);
                },
              ),
            ],
          ),
        ];
    }
  }

  Widget _fieldRow(List<Widget> children) {
    return Row(
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 10),
        Expanded(child: children[1]),
      ],
    );
  }

  Widget _buildMaterialAndDensityCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Material e Densidade (Editável)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<IndustrialMaterial>(
              initialValue: _selectedMaterial,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Material selecionado',
              ),
              items: [
                for (final m in industrialMaterialsCatalog)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      '${m.name} (${m.densityGcm3.toStringAsFixed(2)} g/cm³)',
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _selectedMaterial = v;
                  _densityManuallyEdited = false;
                  _densityCtrl.text = v.densityGcm3.toStringAsFixed(2);
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _densityCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() => _densityManuallyEdited = true),
              decoration: InputDecoration(
                labelText: 'Densidade (g/cm³)',
                helperText: _selectedMaterial.densityRangeNote,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    ThemeData theme,
    VolumeAndWeightResult res,
    int decimals,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. Resultados de Volume e Peso Estimado',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fórmula: ${res.formulaUsed}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (!res.isValid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: IndustrialColors.safetyAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: IndustrialColors.safetyAmber.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  res.errorMessage ?? 'Preencha as dimensões para calcular.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.isHollowCalculation
                          ? 'VOLUME SÓLIDO (PEÇA OCA)'
                          : 'VOLUME CALCULADO (PEÇA MACIÇA)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${res.volumeCm3!.toStringAsFixed(decimals)} cm³',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${res.volumeM3!.toStringAsFixed(decimals + 4)} m³  •  ${res.volumeLiters!.toStringAsFixed(decimals + 2)} L',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (res.hollowWeightSavingsPercent != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Redução de material pelo vazio interno: ${res.hollowWeightSavingsPercent!.toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (res.weightGrams != null && res.weightKilograms != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF26A69A).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        res.isHollowCalculation
                            ? 'PESO ESTIMADO (PEÇA OCA)'
                            : 'PESO ESTIMADO (PEÇA MACIÇA)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF26A69A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${res.weightKilograms!.toStringAsFixed(decimals + 1)} kg  (${res.weightGrams!.toStringAsFixed(decimals)} g)',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Material: ${res.materialName} • Densidade: ${res.densityGcm3!.toStringAsFixed(2)} g/cm³',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              for (final note in res.notes) ...[
                const SizedBox(height: 6),
                Text('• $note', style: theme.textTheme.bodySmall),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DimInput extends StatelessWidget {
  const _DimInput({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
    );
  }
}
