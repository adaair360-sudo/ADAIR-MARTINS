import 'package:material_ui/material_ui.dart';

import '../../../core/theme/industrial_theme.dart';
import '../../fastener_measurement/domain/fastener_models.dart';
import '../../fastener_measurement/domain/fastener_standards.dart';
import '../../settings/presentation/settings_controller.dart';
import '../domain/torque_calculator_engine.dart';
import '../domain/torque_models.dart';

class TorqueCalculatorScreen extends StatefulWidget {
  const TorqueCalculatorScreen({
    super.key,
    required this.settingsController,
    this.initialThread,
    this.initialStrengthClass,
  });

  final SettingsController settingsController;
  final ThreadSpec? initialThread;
  final StrengthClassSpec? initialStrengthClass;

  @override
  State<TorqueCalculatorScreen> createState() => _TorqueCalculatorScreenState();
}

class _TorqueCalculatorScreenState extends State<TorqueCalculatorScreen> {
  ThreadSpec? _selectedThread;
  StrengthClassSpec? _selectedStrength;
  ClampedPartMaterial? _clampedMaterial;
  JointType? _jointType;
  LubricationCondition? _lubrication;
  WasherCondition? _washer;
  AssemblyCondition? _assemblyCondition;
  ApplicableTechnicalNorm _applicableNorm = ApplicableTechnicalNorm.vdi2230;

  final _mfgTorqueCtrl = TextEditingController();
  final _mfgSourceCtrl = TextEditingController();
  final _projectTorqueCtrl = TextEditingController();
  final _projectRefCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedThread = widget.initialThread;
    _selectedStrength = widget.initialStrengthClass;
  }

  @override
  void dispose() {
    _mfgTorqueCtrl.dispose();
    _mfgSourceCtrl.dispose();
    _projectTorqueCtrl.dispose();
    _projectRefCtrl.dispose();
    super.dispose();
  }

  double? _parseTorque(TextEditingController ctrl) {
    final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    return (v != null && v > 0) ? v : null;
  }

  TorqueCalculationResult get _result {
    return TorqueCalculatorEngine.calculate(
      TorqueCalculationInput(
        threadSpec: _selectedThread,
        strengthClass: _selectedStrength,
        clampedMaterial: _clampedMaterial,
        jointType: _jointType,
        lubrication: _lubrication,
        washer: _washer,
        assemblyCondition: _assemblyCondition,
        applicableNorm: _applicableNorm,
        manufacturerTorqueNm: _parseTorque(_mfgTorqueCtrl),
        manufacturerSource: _mfgSourceCtrl.text.trim().isEmpty
            ? null
            : _mfgSourceCtrl.text.trim(),
        projectTorqueNm: _parseTorque(_projectTorqueCtrl),
        projectSpecificationRef: _projectRefCtrl.text.trim().isEmpty
            ? null
            : _projectRefCtrl.text.trim(),
      ),
    );
  }

  void _fillTypicalSteelPreset() {
    setState(() {
      _selectedThread ??= FastenerStandards.threadCatalog.firstWhere(
        (t) => t.designation == 'M10',
      );
      _selectedStrength ??= FastenerStandards.strengthByCode('8.8');
      _clampedMaterial ??= ClampedPartMaterial.steel;
      _jointType ??= JointType.throughBoltNut;
      _lubrication ??= LubricationCondition.lightlyOiled;
      _washer ??= WasherCondition.flatHardened;
      _assemblyCondition ??= AssemblyCondition.controlledTorqueWrench;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;
    final decimals = widget.settingsController.settings.decimalPlaces;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHierarchyBanner(theme),
        const SizedBox(height: 12),
        _buildEssentialParametersCard(theme),
        const SizedBox(height: 12),
        _buildManufacturerAndProjectCard(theme),
        const SizedBox(height: 12),
        _buildResultsCard(theme, res, decimals),
      ],
    );
  }

  Widget _buildHierarchyBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialColors.safetyAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: IndustrialColors.safetyAmber.withValues(alpha: 0.45),
        ),
      ),
      child: const Text(
        'Hierarquia de decisão: 1º Torque especificado em projeto → 2º Torque recomendado pelo fabricante → 3º Torque calculado teoricamente. O app não inventa limites nem recomenda aperto quando faltam dados essenciais.',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEssentialParametersCard(ThemeData theme) {
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
                    '1. Dados Essenciais da União Parafusada',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _fillTypicalSteelPreset,
                  child: const Text('Exemplo M10 8.8'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ThreadSpec>(
              initialValue: _selectedThread,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Diâmetro e passo da rosca *',
              ),
              items: [
                for (final t in FastenerStandards.threadCatalog)
                  DropdownMenuItem(
                    value: t,
                    child: Text(
                      '${t.designation} (Ø ${t.nominalDiameterMm.toStringAsFixed(2)} mm • Passo ${t.pitchMm.toStringAsFixed(2)} mm)',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedThread = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<StrengthClassSpec>(
              initialValue: _selectedStrength,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Classe de resistência *',
              ),
              items: [
                for (final s in FastenerStandards.strengthClasses)
                  DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.title} (${s.materialGroup} • Re=${s.yieldOrProofMpa} MPa)',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _selectedStrength = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ClampedPartMaterial>(
              initialValue: _clampedMaterial,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Material das peças unidas *',
              ),
              items: [
                for (final m in ClampedPartMaterial.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: (v) => setState(() => _clampedMaterial = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<JointType>(
              initialValue: _jointType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de união *'),
              items: [
                for (final j in JointType.values)
                  DropdownMenuItem(value: j, child: Text(j.label)),
              ],
              onChanged: (v) => setState(() => _jointType = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<LubricationCondition>(
              initialValue: _lubrication,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Lubrificação *'),
              items: [
                for (final l in LubricationCondition.values)
                  DropdownMenuItem(value: l, child: Text(l.label)),
              ],
              onChanged: (v) => setState(() => _lubrication = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<WasherCondition>(
              initialValue: _washer,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Arruelas *'),
              items: [
                for (final w in WasherCondition.values)
                  DropdownMenuItem(value: w, child: Text(w.label)),
              ],
              onChanged: (v) => setState(() => _washer = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<AssemblyCondition>(
              initialValue: _assemblyCondition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Condição de montagem *',
              ),
              items: [
                for (final a in AssemblyCondition.values)
                  DropdownMenuItem(value: a, child: Text(a.label)),
              ],
              onChanged: (v) => setState(() => _assemblyCondition = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ApplicableTechnicalNorm>(
              initialValue: _applicableNorm,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Norma técnica aplicável',
              ),
              items: [
                for (final n in ApplicableTechnicalNorm.values)
                  DropdownMenuItem(value: n, child: Text(n.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _applicableNorm = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManufacturerAndProjectCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Especificações do Fabricante e de Projeto (Opcional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Quando disponíveis no manual do equipamento ou desenho técnico, registre os valores abaixo para compará-los com o torque calculado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mfgTorqueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Torque fabricante (N·m)',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _mfgSourceCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Fonte / Manual',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _projectTorqueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Torque de projeto (N·m)',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _projectRefCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Desenho / Norma projeto',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(
    ThemeData theme,
    TorqueCalculationResult res,
    int decimals,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Resultado Técnico de Torque',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (res.projectTorqueNm != null)
              _TorqueCategoryBox(
                badge: 'TORQUE ESPECIFICADO EM PROJETO (PRIORIDADE 1)',
                value: '${res.projectTorqueNm!.toStringAsFixed(decimals)} N·m',
                detail:
                    'Referência: ${res.projectSpecificationRef ?? 'Informe o código do desenho/documento de projeto'}',
                accent: const Color(0xFF26A69A),
              ),
            if (res.manufacturerTorqueNm != null) ...[
              if (res.projectTorqueNm != null) const SizedBox(height: 8),
              _TorqueCategoryBox(
                badge: 'TORQUE RECOMENDADO PELO FABRICANTE (PRIORIDADE 2)',
                value:
                    '${res.manufacturerTorqueNm!.toStringAsFixed(decimals)} N·m',
                detail:
                    'Fonte: ${res.manufacturerSource ?? 'Informe o manual/catálogo do fabricante'}',
                accent: const Color(0xFF42A5F5),
              ),
            ],
            if (res.projectTorqueNm != null || res.manufacturerTorqueNm != null)
              const SizedBox(height: 10),
            if (res.hasSafeCalculatedRecommendation &&
                res.calculatedTorqueNm != null)
              _TorqueCategoryBox(
                badge: 'TORQUE CALCULADO TEÓRICO (REFERÊNCIA ANALÍTICA)',
                value:
                    '${res.calculatedTorqueNm!.toStringAsFixed(decimals)} N·m',
                detail:
                    'Faixa de dispersão: ${res.calculatedMinNm!.toStringAsFixed(decimals)} a ${res.calculatedMaxNm!.toStringAsFixed(decimals)} N·m  •  Pré-carga estimada: ${res.preloadKn!.toStringAsFixed(2)} kN',
                accent: theme.colorScheme.primary,
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: IndustrialColors.safetyAmber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: IndustrialColors.safetyAmber.withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cálculo bloqueado — faltam dados essenciais',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    for (final item in res.missingEssentialData)
                      Text('• Falta informar: $item'),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Especificação utilizada',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(res.specificationSummary, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              'Fonte técnica',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(res.technicalSource, style: theme.textTheme.bodySmall),
            if (res.applicationConditions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Condições de aplicação',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final cond in res.applicationConditions)
                Text('• $cond', style: theme.textTheme.bodySmall),
            ],
            if (res.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Advertências',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: IndustrialColors.safetyAmber,
                ),
              ),
              for (final warn in res.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $warn', style: theme.textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TorqueCategoryBox extends StatelessWidget {
  const _TorqueCategoryBox({
    required this.badge,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final String badge;
  final String value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badge,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(detail, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
