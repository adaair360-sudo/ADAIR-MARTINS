import 'package:material_ui/material_ui.dart';
import 'package:printing/printing.dart';

import '../../material_id/domain/industrial_material.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/technical_drawing_pdf_service.dart';
import '../data/technical_drawing_storage.dart';
import '../domain/technical_drawing_geometry.dart';
import '../domain/technical_drawing_models.dart';
import 'widgets/technical_drawing_2d_painter.dart';
import 'widgets/technical_model_3d_view.dart';

class TechnicalDrawingScreen extends StatefulWidget {
  const TechnicalDrawingScreen({
    super.key,
    required this.settingsController,
    this.storage,
    this.pdfService,
  });

  final SettingsController settingsController;
  final TechnicalDrawingStorage? storage;
  final TechnicalDrawingPdfService? pdfService;

  @override
  State<TechnicalDrawingScreen> createState() => _TechnicalDrawingScreenState();
}

class _TechnicalDrawingScreenState extends State<TechnicalDrawingScreen> {
  late final TechnicalDrawingStorage _storage;
  late final TechnicalDrawingPdfService _pdfService;

  DrawingPartType _partType = DrawingPartType.hexBolt;
  DrawingViewMode _viewMode = DrawingViewMode.split;
  OrthographicViewFocus _viewFocus = OrthographicViewFocus.all;
  MeasurementUnit _unit = MeasurementUnit.millimeters;
  bool _showGrid = true;
  bool _showCenterLines = true;

  String _editingId = 'dwg_${DateTime.now().millisecondsSinceEpoch}';
  String _selectedMaterial = industrialMaterialsCatalog.first.name;

  final _partNameCtrl = TextEditingController();
  final _drawingCodeCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _toleranceCtrl = TextEditingController(text: 'ISO 2768-m');

  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _thicknessCtrl = TextEditingController();
  final _outerDiaCtrl = TextEditingController();
  final _innerDiaCtrl = TextEditingController();
  final _headHeightCtrl = TextEditingController();
  final _wrenchCtrl = TextEditingController();
  final _threadLenCtrl = TextEditingController();
  final _pitchCtrl = TextEditingController();
  final _stepDiaCtrl = TextEditingController();
  final _stepLenCtrl = TextEditingController();
  final _holeDiaCtrl = TextEditingController();

  List<TechnicalDrawingSpec> _savedDrawings = const [];
  String? _statusMessage;
  String? _lastPdfPath;
  bool _busyPdf = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? TechnicalDrawingStorage();
    _pdfService = widget.pdfService ?? TechnicalDrawingPdfService();
    _unit = widget.settingsController.settings.defaultUnit;
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final items = await _storage.loadAll();
    if (!mounted) return;
    setState(() => _savedDrawings = items);
  }

  @override
  void dispose() {
    _partNameCtrl.dispose();
    _drawingCodeCtrl.dispose();
    _authorCtrl.dispose();
    _toleranceCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _thicknessCtrl.dispose();
    _outerDiaCtrl.dispose();
    _innerDiaCtrl.dispose();
    _headHeightCtrl.dispose();
    _wrenchCtrl.dispose();
    _threadLenCtrl.dispose();
    _pitchCtrl.dispose();
    _stepDiaCtrl.dispose();
    _stepLenCtrl.dispose();
    _holeDiaCtrl.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController ctrl) {
    final text = ctrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  TechnicalDrawingSpec _buildSpec() {
    return TechnicalDrawingSpec(
      id: _editingId,
      partType: _partType,
      partName: _partNameCtrl.text.trim(),
      drawingCode: _drawingCodeCtrl.text.trim(),
      materialName: _selectedMaterial,
      authorName: _authorCtrl.text.trim(),
      toleranceNote: _toleranceCtrl.text.trim(),
      unit: _unit,
      length: _parse(_lengthCtrl),
      width: _parse(_widthCtrl),
      heightOrThickness: _parse(_thicknessCtrl),
      outerDiameter: _parse(_outerDiaCtrl),
      innerDiameter: _parse(_innerDiaCtrl),
      headHeight: _parse(_headHeightCtrl),
      wrenchSize: _parse(_wrenchCtrl),
      threadLength: _parse(_threadLenCtrl),
      threadPitch: _parse(_pitchCtrl),
      stepDiameter: _parse(_stepDiaCtrl),
      stepLength: _parse(_stepLenCtrl),
      holeDiameter: _parse(_holeDiaCtrl),
    );
  }

  void _clearDimensions() {
    _lengthCtrl.clear();
    _widthCtrl.clear();
    _thicknessCtrl.clear();
    _outerDiaCtrl.clear();
    _innerDiaCtrl.clear();
    _headHeightCtrl.clear();
    _wrenchCtrl.clear();
    _threadLenCtrl.clear();
    _pitchCtrl.clear();
    _stepDiaCtrl.clear();
    _stepLenCtrl.clear();
    _holeDiaCtrl.clear();
    setState(() {
      _statusMessage = null;
      _lastPdfPath = null;
    });
  }

  void _loadExample(DrawingPartType type) {
    _clearDimensions();
    _partType = type;
    _unit = MeasurementUnit.millimeters;
    switch (type) {
      case DrawingPartType.hexBolt:
        _partNameCtrl.text = 'Parafuso Sextavado M10 x 40';
        _drawingCodeCtrl.text = 'DES-M10-001';
        _selectedMaterial = 'Aço carbono';
        _outerDiaCtrl.text = '10';
        _lengthCtrl.text = '40';
        _headHeightCtrl.text = '6.4';
        _wrenchCtrl.text = '17';
        _threadLenCtrl.text = '26';
        _pitchCtrl.text = '1.5';
      case DrawingPartType.socketBolt:
        _partNameCtrl.text = 'Parafuso Allen M8 x 30';
        _drawingCodeCtrl.text = 'DES-M8-002';
        _selectedMaterial = 'Aço inoxidável';
        _outerDiaCtrl.text = '8';
        _lengthCtrl.text = '30';
        _headHeightCtrl.text = '8';
        _wrenchCtrl.text = '13';
        _threadLenCtrl.text = '22';
        _pitchCtrl.text = '1.25';
      case DrawingPartType.shaft:
        _partNameCtrl.text = 'Eixo Escalonado Ø30 x 120';
        _drawingCodeCtrl.text = 'EIX-030-120';
        _selectedMaterial = 'Aço carbono';
        _outerDiaCtrl.text = '30';
        _lengthCtrl.text = '120';
        _stepDiaCtrl.text = '22';
        _stepLenCtrl.text = '35';
      case DrawingPartType.tube:
        _partNameCtrl.text = 'Bucha Cilíndrica Ø50 x Ø32';
        _drawingCodeCtrl.text = 'BUC-050-032';
        _selectedMaterial = 'Bronze';
        _outerDiaCtrl.text = '50';
        _innerDiaCtrl.text = '32';
        _lengthCtrl.text = '60';
      case DrawingPartType.plate:
        _partNameCtrl.text = 'Chapa Base 120 x 80 x 12';
        _drawingCodeCtrl.text = 'CHP-120-080';
        _selectedMaterial = 'Alumínio';
        _lengthCtrl.text = '120';
        _widthCtrl.text = '80';
        _thicknessCtrl.text = '12';
        _holeDiaCtrl.text = '24';
    }
    setState(() {
      _statusMessage =
          'Exemplo editável carregado. Ajuste as medidas reais antes de salvar ou exportar.';
    });
  }

  void _applySavedDrawing(TechnicalDrawingSpec spec) {
    _editingId = spec.id;
    _partType = spec.partType;
    _unit = spec.unit;
    _selectedMaterial = spec.materialName;
    _partNameCtrl.text = spec.partName;
    _drawingCodeCtrl.text = spec.drawingCode;
    _authorCtrl.text = spec.authorName;
    _toleranceCtrl.text = spec.toleranceNote;

    String fmt(double? v) => v == null ? '' : v.toString();
    _lengthCtrl.text = fmt(spec.length);
    _widthCtrl.text = fmt(spec.width);
    _thicknessCtrl.text = fmt(spec.heightOrThickness);
    _outerDiaCtrl.text = fmt(spec.outerDiameter);
    _innerDiaCtrl.text = fmt(spec.innerDiameter);
    _headHeightCtrl.text = fmt(spec.headHeight);
    _wrenchCtrl.text = fmt(spec.wrenchSize);
    _threadLenCtrl.text = fmt(spec.threadLength);
    _pitchCtrl.text = fmt(spec.threadPitch);
    _stepDiaCtrl.text = fmt(spec.stepDiameter);
    _stepLenCtrl.text = fmt(spec.stepLength);
    _holeDiaCtrl.text = fmt(spec.holeDiameter);

    setState(() {
      _statusMessage = 'Desenho "${spec.partName.isEmpty ? spec.partType.label : spec.partName}" carregado.';
    });
  }

  Future<void> _saveCurrentDrawing(TechnicalDrawingSpec spec) async {
    final saved = await _storage.save(spec);
    if (!mounted) return;
    setState(() {
      _savedDrawings = saved;
      _statusMessage = 'Desenho salvo localmente (${saved.length} no arquivo local).';
    });
  }

  Future<void> _deleteSavedDrawing(String id) async {
    final next = await _storage.delete(id);
    if (!mounted) return;
    setState(() {
      _savedDrawings = next;
      _statusMessage = 'Desenho removido do armazenamento local.';
    });
  }

  Future<void> _exportPdf(TechnicalDrawingSpec spec, {bool share = false}) async {
    setState(() {
      _busyPdf = true;
      _statusMessage = null;
    });
    try {
      final file = await _pdfService.exportPdfToFile(spec);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _lastPdfPath = file.path;
        _statusMessage = 'PDF técnico exportado em: ${file.path}';
      });
      if (share) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: file.uri.pathSegments.last,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Falha ao exportar PDF: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _busyPdf = false);
      }
    }
  }

  Widget _numField(TextEditingController ctrl, String label, {String? hint}) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  List<Widget> _buildDimensionFields() {
    final u = _unit.symbol;
    switch (_partType) {
      case DrawingPartType.hexBolt:
      case DrawingPartType.socketBolt:
        return [
          Row(
            children: [
              Expanded(child: _numField(_outerDiaCtrl, 'Diâmetro D ($u)*')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_lengthCtrl, 'Comprimento L ($u)*')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numField(_headHeightCtrl, 'Alt. cabeça K ($u)*')),
              const SizedBox(width: 10),
              Expanded(
                child: _numField(
                  _wrenchCtrl,
                  _partType == DrawingPartType.hexBolt
                      ? 'Chave S ($u)*'
                      : 'Diâm. cabeça Dk ($u)*',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numField(_threadLenCtrl, 'Comp. roscado b ($u)')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_pitchCtrl, 'Passo P (mm)')),
            ],
          ),
        ];

      case DrawingPartType.shaft:
        return [
          Row(
            children: [
              Expanded(child: _numField(_outerDiaCtrl, 'Diâmetro D1 ($u)*')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_lengthCtrl, 'Comprimento L ($u)*')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numField(_stepDiaCtrl, 'Diâm. degrau D2 ($u)')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_stepLenCtrl, 'Comp. degrau L2 ($u)')),
            ],
          ),
        ];

      case DrawingPartType.tube:
        return [
          Row(
            children: [
              Expanded(child: _numField(_outerDiaCtrl, 'Diâm. externo De ($u)*')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_innerDiaCtrl, 'Diâm. interno Di ($u)*')),
            ],
          ),
          const SizedBox(height: 10),
          _numField(_lengthCtrl, 'Comprimento L ($u)*'),
        ];

      case DrawingPartType.plate:
        return [
          Row(
            children: [
              Expanded(child: _numField(_lengthCtrl, 'Comprimento C ($u)*')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_widthCtrl, 'Largura W ($u)*')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numField(_thicknessCtrl, 'Espessura E ($u)*')),
              const SizedBox(width: 10),
              Expanded(child: _numField(_holeDiaCtrl, 'Furo central Df ($u)')),
            ],
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _buildSpec();
    final validation = TechnicalDrawingValidator.validate(spec);
    final summaryItems = TechnicalDrawingValidator.summarizeDimensions(spec);

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
                  'Tipo de peça e unidade das cotas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in DrawingPartType.values)
                      ChoiceChip(
                        label: Text(type.shortLabel),
                        selected: _partType == type,
                        onSelected: (_) {
                          setState(() {
                            _partType = type;
                            _statusMessage = null;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _partType.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Unidade:'),
                    for (final unit in MeasurementUnit.values)
                      ChoiceChip(
                        label: Text(unit.symbol),
                        selected: _unit == unit,
                        onSelected: (_) => setState(() => _unit = unit),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.auto_fix_high_outlined, size: 16),
                      label: Text('Exemplo ${_partType.shortLabel}'),
                      onPressed: () => _loadExample(_partType),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.clear_all_rounded, size: 16),
                      label: const Text('Limpar medidas'),
                      onPressed: _clearDimensions,
                    ),
                  ],
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
                  'Dimensões reais (campos com * são obrigatórios)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ..._buildDimensionFields(),
                const SizedBox(height: 12),
                Text(
                  'Carimbo técnico (legenda do PDF)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _partNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome da peça',
                          hintText: 'Ex.: Parafuso Sextavado M10',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _drawingCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Código',
                          hintText: 'DES-001',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedMaterial,
                  decoration: const InputDecoration(
                    labelText: 'Material (catálogo técnico)',
                  ),
                  items: [
                    for (final m in industrialMaterialsCatalog)
                      DropdownMenuItem(value: m.name, child: Text(m.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedMaterial = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _authorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Responsável',
                          hintText: 'Técnico / Eng.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _toleranceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tolerância geral',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!validation.isValid)
          Card(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.block_rounded,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Desenho 2D/3D e PDF bloqueados: faltam medidas válidas',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nenhuma cota é inventada automaticamente. Informe:',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  for (final err in validation.missingOrInvalidFields)
                    Text('• $err', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in DrawingViewMode.values)
                        ChoiceChip(
                          label: Text(mode.label),
                          selected: _viewMode == mode,
                          onSelected: (_) => setState(() => _viewMode = mode),
                        ),
                    ],
                  ),
                  if (validation.warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final w in validation.warnings)
                      Text(
                        'Aviso: $w',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                  ],
                  if (_viewMode == DrawingViewMode.views2D ||
                      _viewMode == DrawingViewMode.split) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Vistas ortográficas 2D cotadas (${_unit.symbol})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final f in OrthographicViewFocus.values)
                          ChoiceChip(
                            label: Text(f.label),
                            selected: _viewFocus == f,
                            onSelected: (_) => setState(() => _viewFocus = f),
                          ),
                        FilterChip(
                          label: const Text('Grade'),
                          selected: _showGrid,
                          onSelected: (v) => setState(() => _showGrid = v),
                        ),
                        FilterChip(
                          label: const Text('Linhas de centro'),
                          selected: _showCenterLines,
                          onSelected: (v) =>
                              setState(() => _showCenterLines = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TechnicalDrawing2DCanvas(
                      spec: spec,
                      focus: _viewFocus,
                      showGrid: _showGrid,
                      showCenterLines: _showCenterLines,
                    ),
                  ],
                  if (_viewMode == DrawingViewMode.model3D ||
                      _viewMode == DrawingViewMode.split) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Visualização 3D interativa',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TechnicalModel3DView(spec: spec),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Resumo das cotas (${_unit.symbol})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final item in summaryItems)
                        Chip(
                          label: Text(
                            '${item.symbol}: ${item.formattedValue} (${item.label})',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _saveCurrentDrawing(spec),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salvar desenho local'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            _busyPdf ? null : () => _exportPdf(spec, share: false),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          _busyPdf ? 'Gerando PDF...' : 'Exportar PDF técnico',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _busyPdf ? null : () => _exportPdf(spec, share: true),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Gerar e compartilhar PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_statusMessage != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusMessage!, style: theme.textTheme.bodySmall),
                  if (_lastPdfPath != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Arquivo PDF pronto para compartilhamento ou impressão técnica.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desenhos salvos localmente (${_savedDrawings.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (_savedDrawings.isEmpty)
                  Text(
                    'Nenhum desenho salvo ainda neste dispositivo.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final item in _savedDrawings)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.architecture_outlined),
                      title: Text(
                        item.partName.isEmpty
                            ? item.partType.label
                            : item.partName,
                      ),
                      subtitle: Text(
                        '${item.partType.shortLabel} • ${item.materialName} • ${item.unit.symbol}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Abrir para editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _applySavedDrawing(item),
                          ),
                          IconButton(
                            tooltip: 'Excluir desenho',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSavedDrawing(item.id),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
