import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../settings/presentation/settings_controller.dart';
import '../data/component_code_ocr_service.dart';
import '../domain/mechanical_component_matcher.dart';
import '../domain/mechanical_component_models.dart';

class MechanicalComponentsScreen extends StatefulWidget {
  const MechanicalComponentsScreen({
    super.key,
    required this.settingsController,
    this.ocrService,
  });

  final SettingsController settingsController;
  final ComponentCodeOcrService? ocrService;

  @override
  State<MechanicalComponentsScreen> createState() =>
      _MechanicalComponentsScreenState();
}

class _MechanicalComponentsScreenState
    extends State<MechanicalComponentsScreen> {
  late final ComponentCodeOcrService _ocrService;
  final _picker = ImagePicker();

  MechanicalComponentCategory _category = MechanicalComponentCategory.all;
  final _refCtrl = TextEditingController();
  final _innerDiaCtrl = TextEditingController();
  final _outerDiaCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _pitchCtrl = TextEditingController();
  final _teethCtrl = TextEditingController();
  final _spanCtrl = TextEditingController();

  String? _ocrStatusMessage;
  bool _runningOcr = false;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? ComponentCodeOcrService();
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _innerDiaCtrl.dispose();
    _outerDiaCtrl.dispose();
    _widthCtrl.dispose();
    _pitchCtrl.dispose();
    _teethCtrl.dispose();
    _spanCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? _parseInt(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  void _clearAll() {
    _refCtrl.clear();
    _innerDiaCtrl.clear();
    _outerDiaCtrl.clear();
    _widthCtrl.clear();
    _pitchCtrl.clear();
    _teethCtrl.clear();
    _spanCtrl.clear();
    setState(() {
      _ocrStatusMessage = null;
    });
  }

  Future<void> _scanCodeFromPhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _ocrStatusMessage =
              'Permissão da câmera negada. Informe o código manualmente ou importe da galeria.';
        });
        return;
      }
    }

    final file = await _picker.pickImage(source: source, imageQuality: 92);
    if (file == null) return;

    setState(() {
      _runningOcr = true;
      _ocrStatusMessage = null;
    });

    final ocr = await _ocrService.extractFromImage(file.path);
    if (!mounted) return;
    setState(() {
      _runningOcr = false;
      if (ocr.extractedCodeCandidate.isNotEmpty) {
        _refCtrl.text = ocr.extractedCodeCandidate;
        _ocrStatusMessage =
            'OCR local detectou "${ocr.extractedCodeCandidate}" (texto bruto: "${ocr.rawText.replaceAll('\n', ' ').trim()}").';
      } else {
        _ocrStatusMessage = ocr.errorMessage ??
            'Nenhum código alfanumérico legível encontrado na foto. Informe manualmente ou preencha as dimensões.';
      }
    });
  }

  ComponentQueryInput _buildQuery() {
    return ComponentQueryInput(
      category: _category,
      referenceText: _refCtrl.text.trim(),
      innerDiameterMm: _parseDouble(_innerDiaCtrl),
      outerDiameterMm: _parseDouble(_outerDiaCtrl),
      widthOrLengthMm: _parseDouble(_widthCtrl),
      pitchMm: _parseDouble(_pitchCtrl),
      teethCount: _parseInt(_teethCtrl),
      mountingSpanMm: _parseDouble(_spanCtrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = MechanicalComponentMatcher.identify(_buildQuery());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Categoria de componente mecânico',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cat in MechanicalComponentCategory.values)
                      ChoiceChip(
                        label: Text(cat.shortLabel),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _category.requiredMeasuresHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Código de referência, fabricante ou leitura OCR',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código ou fabricante',
                    hintText: 'Ex.: 6204, UCP 205, 08B-1, SPA-1250, Sabó',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _runningOcr
                          ? null
                          : () => _scanCodeFromPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(_runningOcr ? 'Lendo OCR...' : 'Ler código na foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _runningOcr
                          ? null
                          : () => _scanCodeFromPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Importar foto'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.clear_all_rounded, size: 16),
                      label: const Text('Limpar busca'),
                      onPressed: _clearAll,
                    ),
                  ],
                ),
                if (_ocrStatusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _ocrStatusMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dimensões principais medidas (mm)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _innerDiaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Diâm. interno / eixo d (mm)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _outerDiaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Diâm. externo D (mm)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _widthCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Largura / Altura B (mm)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _pitchCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Passo P (mm)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _teethCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nº de dentes Z',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _spanCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Entre furos mancal J (mm)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (result.estimatedGearModuleMm != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Módulo estimado pela relação De / (Z + 2): ${result.estimatedGearModuleMm!.toStringAsFixed(2)} mm',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (result.status == ComponentMatchStatus.needsMoreData ||
            result.status == ComponentMatchStatus.noMatch)
          Card(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.32),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        result.status == ComponentMatchStatus.needsMoreData
                            ? Icons.help_outline_rounded
                            : Icons.search_off_rounded,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.status == ComponentMatchStatus.needsMoreData
                              ? 'Dados complementares necessários antes de sugerir equivalência'
                              : 'Sem correspondência exata no catálogo',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(result.summaryMessage, style: theme.textTheme.bodySmall),
                  if (result.requestedAdditionalData.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final req in result.requestedAdditionalData)
                      Text('• $req', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          )
        else
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.summaryMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (result.candidates.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            result.status == ComponentMatchStatus.needsMoreData
                ? 'Candidatos preliminares (confirme as medidas antes da troca)'
                : 'Componentes identificados e equivalências',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final candidate in result.candidates) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            candidate.spec.referenceCode,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            candidate.spec.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${candidate.score.round()}%',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Categoria: ${candidate.spec.category.label} • Norma: ${candidate.spec.standard}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dimensões: ${candidate.spec.dimensionsSummary}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fabricantes de referência: ${candidate.spec.manufacturers.join(', ')}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aplicação: ${candidate.spec.applicationNotes}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Regra de equivalência: ${candidate.spec.equivalenceRule}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final hit in candidate.matchedBy)
                          Chip(label: Text(hit)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}
