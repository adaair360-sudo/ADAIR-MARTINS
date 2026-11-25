import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/industrial_theme.dart';
import '../../camera_measurement/data/opencv_service.dart';
import '../../camera_measurement/domain/camera_measurement_models.dart';
import '../../camera_measurement/domain/measurement_math.dart';
import '../../camera_measurement/presentation/widgets/measurement_photo_canvas.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/head_marking_ocr_service.dart';
import '../domain/fastener_classifier.dart';
import '../domain/fastener_models.dart';
import '../domain/fastener_standards.dart';

enum _FastenerCanvasTarget {
  calibration('Calibrar Referência'),
  outerDiameter('Diâmetro ext.'),
  totalLength('Compr. total'),
  threadedLength('Compr. roscado'),
  headHeight('Alt. cabeça'),
  wrenchWidth('Entre faces'),
  headDiameter('Diâm. cabeça');

  const _FastenerCanvasTarget(this.label);
  final String label;
}

class FastenerMeasurementScreen extends StatefulWidget {
  const FastenerMeasurementScreen({
    super.key,
    required this.settingsController,
    this.ocrService,
    this.openCvService,
    this.initialSideImagePath,
    this.initialHeadImagePath,
  });

  final SettingsController settingsController;
  final HeadMarkingOcrService? ocrService;
  final OpenCvService? openCvService;
  final String? initialSideImagePath;
  final String? initialHeadImagePath;

  @override
  State<FastenerMeasurementScreen> createState() =>
      _FastenerMeasurementScreenState();
}

class _FastenerMeasurementScreenState extends State<FastenerMeasurementScreen> {
  late final HeadMarkingOcrService _ocrService;
  late final OpenCvService _openCvService;
  final ImagePicker _imagePicker = ImagePicker();

  FastenerType _fastenerType = FastenerType.hexBolt;
  ThreadHand _threadHand = ThreadHand.right;

  // Manual & camera-populated dimension controllers (mm)
  final _outerDiaCtrl = TextEditingController();
  final _totalLenCtrl = TextEditingController();
  final _threadedLenCtrl = TextEditingController();
  final _headHeightCtrl = TextEditingController();
  final _wrenchWidthCtrl = TextEditingController();
  final _headDiaCtrl = TextEditingController();
  final _pitchCtrl = TextEditingController();

  // Calibrated side photo state
  String? _sideImagePath;
  ContourAnalysisResult? _sideAnalysis;
  bool _isAnalyzingSide = false;
  ReferenceObjectPreset _refPreset = ReferenceObjectPreset.defaults.first;
  ImagePoint? _calP1;
  ImagePoint? _calP2;
  CalibrationResult? _calibration;
  ImagePoint? _pendingPoint;
  _FastenerCanvasTarget _canvasTarget = _FastenerCanvasTarget.calibration;
  final List<MeasurementMark> _canvasMarks = [];

  // Head marking OCR state
  String? _headImagePath;
  bool _isRunningOcr = false;
  StrengthClassificationResult _strengthResult =
      const StrengthClassificationResult(
        spec: null,
        source: StrengthClassSource.indeterminate,
        rawOcrText: null,
        warnings: [
          'Fotografe a cabeça do parafuso para leitura OCR ou selecione a gravação manualmente. A resistência nunca é inferida apenas pela aparência.',
        ],
      );

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? HeadMarkingOcrService();
    _openCvService = widget.openCvService ?? OpenCvService();
    if (widget.initialSideImagePath != null) {
      _sideImagePath = widget.initialSideImagePath;
      _analyzeSidePhoto(_sideImagePath!);
    }
    if (widget.initialHeadImagePath != null) {
      _headImagePath = widget.initialHeadImagePath;
      _runHeadOcr(_headImagePath!);
    }
  }

  @override
  void dispose() {
    _outerDiaCtrl.dispose();
    _totalLenCtrl.dispose();
    _threadedLenCtrl.dispose();
    _headHeightCtrl.dispose();
    _wrenchWidthCtrl.dispose();
    _headDiaCtrl.dispose();
    _pitchCtrl.dispose();
    super.dispose();
  }

  double? _parseMm(TextEditingController c) {
    final text = c.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final v = double.tryParse(text);
    return (v != null && v > 0) ? v : null;
  }

  FastenerDimensions get _dimensions => FastenerDimensions(
    outerDiameterMm: _parseMm(_outerDiaCtrl),
    totalLengthMm: _parseMm(_totalLenCtrl),
    threadedLengthMm: _parseMm(_threadedLenCtrl),
    headHeightMm: _parseMm(_headHeightCtrl),
    wrenchWidthMm: _parseMm(_wrenchWidthCtrl),
    headDiameterMm: _parseMm(_headDiaCtrl),
    threadPitchMm: _parseMm(_pitchCtrl),
  );

  List<ThreadMatchCandidate> get _threadMatches {
    final d = _dimensions;
    return FastenerClassifier.matchThread(
      outerDiameterMm: d.outerDiameterMm,
      threadPitchMm: d.threadPitchMm,
      wrenchWidthMm: d.wrenchWidthMm,
    );
  }

  Future<String?> _acquirePhoto({required bool fromCamera}) async {
    if (fromCamera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão de câmera necessária para fotografar.'),
            ),
          );
        }
        return null;
      }
    }
    final picked = await _imagePicker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return null;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'parafusos_locais'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final dest = p.join(
      dir.path,
      'fix_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}',
    );
    await File(picked.path).copy(dest);
    return dest;
  }

  Future<void> _analyzeSidePhoto(String path) async {
    setState(() {
      _sideImagePath = path;
      _isAnalyzingSide = true;
      _calP1 = null;
      _calP2 = null;
      _calibration = null;
      _pendingPoint = null;
      _canvasMarks.clear();
      _canvasTarget = _FastenerCanvasTarget.calibration;
    });
    try {
      final res = await _openCvService.analyzeImage(path);
      if (!mounted) return;
      setState(() {
        _sideAnalysis = res;
        _isAnalyzingSide = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isAnalyzingSide = false);
    }
  }

  Future<void> _runHeadOcr(String path) async {
    setState(() {
      _headImagePath = path;
      _isRunningOcr = true;
    });
    final res = await _ocrService.readHeadMarking(path);
    if (!mounted) return;
    setState(() {
      _strengthResult = res;
      _isRunningOcr = false;
    });
  }

  void _handleSideCanvasTap(ImagePoint pt) {
    if (_pendingPoint == null) {
      setState(() => _pendingPoint = pt);
      return;
    }
    final p1 = _pendingPoint!;
    _pendingPoint = null;
    final pxSpan = p1.distanceTo(pt);
    if (pxSpan <= 2) return;

    if (_canvasTarget == _FastenerCanvasTarget.calibration) {
      final cal = MeasurementMath.buildVisualCalibration(
        referencePixelSpan: pxSpan,
        knownReferenceMm: _refPreset.knownMillimeters,
        referenceName: _refPreset.name,
      );
      if (cal == null) return;
      setState(() {
        _calP1 = p1;
        _calP2 = pt;
        _calibration = cal;
        _canvasTarget = _FastenerCanvasTarget.outerDiameter;
      });
      return;
    }

    final mm = MeasurementMath.convertPixelsToMillimeters(pxSpan, _calibration);
    final uncertainty = MeasurementMath.evaluateUncertainty(
      calibration: _calibration,
      measuredPixels: pxSpan,
      sharpnessVariance: _sideAnalysis?.sharpnessVariance ?? 80,
      contrastStdDev: _sideAnalysis?.contrastStdDev ?? 35,
    );

    final kind = switch (_canvasTarget) {
      _FastenerCanvasTarget.outerDiameter => MeasurementDimensionKind.diameter,
      _FastenerCanvasTarget.totalLength => MeasurementDimensionKind.length,
      _FastenerCanvasTarget.threadedLength => MeasurementDimensionKind.length,
      _FastenerCanvasTarget.headHeight => MeasurementDimensionKind.height,
      _FastenerCanvasTarget.wrenchWidth => MeasurementDimensionKind.width,
      _FastenerCanvasTarget.headDiameter => MeasurementDimensionKind.diameter,
      _FastenerCanvasTarget.calibration =>
        MeasurementDimensionKind.calibrationReference,
    };

    setState(() {
      _canvasMarks.add(
        MeasurementMark(
          id: 'fm_${DateTime.now().microsecondsSinceEpoch}',
          kind: kind,
          geometryType: ObjectGeometryType.cylindrical,
          p1: p1,
          p2: pt,
          pixelDistance: pxSpan,
          millimeters: mm,
          uncertainty: uncertainty,
          note: _canvasTarget.label,
        ),
      );
      if (mm != null) {
        final formatted = mm.toStringAsFixed(2);
        switch (_canvasTarget) {
          case _FastenerCanvasTarget.outerDiameter:
            _outerDiaCtrl.text = formatted;
          case _FastenerCanvasTarget.totalLength:
            _totalLenCtrl.text = formatted;
          case _FastenerCanvasTarget.threadedLength:
            _threadedLenCtrl.text = formatted;
          case _FastenerCanvasTarget.headHeight:
            _headHeightCtrl.text = formatted;
          case _FastenerCanvasTarget.wrenchWidth:
            _wrenchWidthCtrl.text = formatted;
          case _FastenerCanvasTarget.headDiameter:
            _headDiaCtrl.text = formatted;
          case _FastenerCanvasTarget.calibration:
            break;
        }
      }
    });
  }

  void _applyQuickMetricExample(String designation) {
    final spec = FastenerStandards.threadCatalog.firstWhere(
      (s) => s.designation == designation,
    );
    setState(() {
      _outerDiaCtrl.text = spec.nominalDiameterMm.toStringAsFixed(2);
      _pitchCtrl.text = spec.pitchMm.toStringAsFixed(2);
      if (spec.hexWrenchMm != null) {
        _wrenchWidthCtrl.text = spec.hexWrenchMm!.toStringAsFixed(2);
      }
      if (spec.hexHeadHeightMm != null) {
        _headHeightCtrl.text = spec.hexHeadHeightMm!.toStringAsFixed(2);
      }
      if (spec.allenHeadDiameterMm != null &&
          _fastenerType == FastenerType.allenBolt) {
        _headDiaCtrl.text = spec.allenHeadDiameterMm!.toStringAsFixed(2);
        _headHeightCtrl.text =
            spec.allenHeadHeightMm?.toStringAsFixed(2) ?? _headHeightCtrl.text;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = _threadMatches;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFastenerTypeCard(theme),
        const SizedBox(height: 12),
        _buildPhotoCalibrationCard(theme),
        const SizedBox(height: 12),
        _buildManualDimensionsCard(theme),
        const SizedBox(height: 12),
        _buildThreadIdentificationCard(theme, matches),
        const SizedBox(height: 12),
        _buildStrengthOcrCard(theme),
      ],
    );
  }

  Widget _buildFastenerTypeCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Elemento de Fixação e Sentido',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in FastenerType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _fastenerType == type,
                    onSelected: (_) => setState(() => _fastenerType = type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThreadHand>(
              segments: [
                for (final hand in ThreadHand.values)
                  ButtonSegment(value: hand, label: Text(hand.label)),
              ],
              selected: {_threadHand},
              onSelectionChanged: (s) => setState(() => _threadHand = s.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCalibrationCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2. Medição por Foto Calibrada (Opcional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fotografe o fixador ao lado de uma referência conhecida (ex.: cartão ISO ou moeda) para preencher as medidas automaticamente, ou insira os valores manualmente abaixo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final path = await _acquirePhoto(fromCamera: true);
                    if (path != null) await _analyzeSidePhoto(path);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Fotografar Peça'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await _acquirePhoto(fromCamera: false);
                    if (path != null) await _analyzeSidePhoto(path);
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Importar Foto'),
                ),
              ],
            ),
            if (_isAnalyzingSide) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ] else if (_sideImagePath != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<ReferenceObjectPreset>(
                initialValue: _refPreset,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Objeto de calibração na foto',
                ),
                items: [
                  for (final pItem in ReferenceObjectPreset.defaults.where(
                    (e) => !e.isCustom,
                  ))
                    DropdownMenuItem(value: pItem, child: Text(pItem.name)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _refPreset = v);
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final target in _FastenerCanvasTarget.values)
                    ChoiceChip(
                      label: Text(target.label),
                      selected: _canvasTarget == target,
                      onSelected: (_) => setState(() {
                        _canvasTarget = target;
                        _pendingPoint = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              MeasurementPhotoCanvas(
                imagePath: _sideImagePath!,
                imageWidth: _sideAnalysis?.imageWidth ?? 1280,
                imageHeight: _sideAnalysis?.imageHeight ?? 960,
                analysis: _sideAnalysis,
                showOverlayImage: false,
                showContours: true,
                calibrationP1: _calP1,
                calibrationP2: _calP2,
                pendingPoint: _pendingPoint,
                marks: _canvasMarks,
                onImageTapped: _handleSideCanvasTap,
              ),
              const SizedBox(height: 6),
              Text(
                _calibration == null
                    ? 'Atenção: calibre primeiro com "Calibrar Referência" antes de medir na foto.'
                    : 'Calibração ativa: ${_calibration!.pixelsPerMm.toStringAsFixed(2)} px/mm',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _calibration == null
                      ? IndustrialColors.safetyAmber
                      : const Color(0xFF26A69A),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualDimensionsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '3. Medidas do Fixador (mm)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Insira ou ajuste manualmente quando a câmera ou o pente de rosca exigirem confirmação.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Exemplos rápidos (M6, M8, M10, M12, M16, M20):',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final code in FastenerStandards.quickExamples)
                  ActionChip(
                    label: Text(code),
                    onPressed: () => _applyQuickMetricExample(code),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    controller: _outerDiaCtrl,
                    label: 'Diâmetro externo (mm)',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    controller: _pitchCtrl,
                    label: 'Passo da rosca (mm)',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    controller: _totalLenCtrl,
                    label: 'Comprimento total (mm)',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    controller: _threadedLenCtrl,
                    label: 'Compr. roscado (mm)',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    controller: _headHeightCtrl,
                    label: 'Altura da cabeça (mm)',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    controller: _wrenchWidthCtrl,
                    label: 'Largura entre faces (mm)',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _NumField(
              controller: _headDiaCtrl,
              label: 'Diâmetro da cabeça / flange / arruela (mm)',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadIdentificationCard(
    ThemeData theme,
    List<ThreadMatchCandidate> matches,
  ) {
    final dims = _dimensions;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '4. Identificação da Rosca (ISO / UNC / UNF)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (matches.isEmpty)
              Text(
                'Informe pelo menos o diâmetro externo ou a largura entre faces (chave) para identificar a rosca provável.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              if (dims.threadPitchMm == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Passo não informado: exibindo roscas grossas e finas compatíveis com o diâmetro. Confirme com pente de rosca.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: IndustrialColors.safetyAmber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (final match in matches)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${match.spec.designation}  •  ${_threadHand.label}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${match.spec.standard.label} • ${match.spec.series.label}',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              'Ø nom: ${match.spec.nominalDiameterMm.toStringAsFixed(2)} mm • Passo: ${match.spec.pitchMm.toStringAsFixed(2)} mm${match.spec.tpi != null ? ' (${match.spec.tpi!.toStringAsFixed(0)} TPI)' : ''}${match.spec.hexWrenchMm != null ? ' • Chave: ${match.spec.hexWrenchMm!.toStringAsFixed(1)} mm' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${match.confidencePercent}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthOcrCard(ThemeData theme) {
    final spec = _strengthResult.spec;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '5. Classe de Resistência (OCR da Cabeça)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'O reconhecimento por OCR lê marcações gravadas (4.6, 5.8, 8.8, 10.9, 12.9, A2, A4). Nunca classifica resistência apenas pela aparência externa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final path = await _acquirePhoto(fromCamera: true);
                    if (path != null) await _runHeadOcr(path);
                  },
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Ler Cabeça com OCR'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await _acquirePhoto(fromCamera: false);
                    if (path != null) await _runHeadOcr(path);
                  },
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Foto da Cabeça'),
                ),
              ],
            ),
            if (_isRunningOcr) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_headImagePath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Image.file(File(_headImagePath!), fit: BoxFit.cover),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (spec != null
                        ? const Color(0xFF26A69A)
                        : IndustrialColors.safetyAmber)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (spec != null
                          ? const Color(0xFF26A69A)
                          : IndustrialColors.safetyAmber)
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec != null
                        ? '${spec.title} • ${spec.materialGroup}'
                        : 'Classe de resistência: Indeterminada',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Origem: ${_strengthResult.source.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (spec != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Resistência à tração (Rm): ${spec.tensileStrengthMpa} MPa  •  Escoamento/Prova: ${spec.yieldOrProofMpa} MPa',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(spec.notes, style: theme.textTheme.bodySmall),
                  ],
                  if (_strengthResult.rawOcrText != null &&
                      _strengthResult.rawOcrText!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Texto OCR detectado: "${_strengthResult.rawOcrText!.trim()}"',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  for (final w in _strengthResult.warnings) ...[
                    const SizedBox(height: 4),
                    Text('• $w', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Informar marcação gravada manualmente:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final item in FastenerStandards.strengthClasses)
                  ChoiceChip(
                    label: Text(item.code),
                    selected: spec?.code == item.code,
                    onSelected: (_) {
                      setState(() {
                        _strengthResult =
                            FastenerClassifier.manualStrengthSelection(
                              item.code,
                            );
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
    );
  }
}
