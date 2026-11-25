import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/industrial_theme.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/material_analyzer_service.dart';
import '../domain/industrial_material.dart';
import '../domain/material_analysis_models.dart';

class MaterialIdentificationScreen extends StatefulWidget {
  const MaterialIdentificationScreen({
    super.key,
    required this.settingsController,
    this.analyzerService,
    this.initialImagePath,
    this.skipHardwareChecks = false,
  });

  final SettingsController settingsController;
  final MaterialAnalyzerService? analyzerService;
  final String? initialImagePath;
  final bool skipHardwareChecks;

  @override
  State<MaterialIdentificationScreen> createState() =>
      _MaterialIdentificationScreenState();
}

class _MaterialIdentificationScreenState
    extends State<MaterialIdentificationScreen> {
  late final MaterialAnalyzerService _analyzerService;
  final ImagePicker _imagePicker = ImagePicker();

  PermissionStatus _cameraPermission = PermissionStatus.denied;
  bool _checkingHardware = true;
  CameraController? _cameraController;
  String? _cameraError;

  String? _imagePath;
  bool _useCenterRoi = true;
  bool _isAnalyzing = false;
  MaterialIdentificationResult? _result;
  IndustrialMaterial? _manualOnlySelection;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    _analyzerService = widget.analyzerService ?? MaterialAnalyzerService();
    if (widget.initialImagePath != null) {
      _imagePath = widget.initialImagePath;
    }
    _initialize();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (widget.skipHardwareChecks) {
      setState(() => _checkingHardware = false);
      if (_imagePath != null) {
        await _analyzePhoto(_imagePath!);
      }
      return;
    }

    PermissionStatus status = PermissionStatus.denied;
    try {
      status = await Permission.camera.status;
    } catch (_) {
      status = PermissionStatus.denied;
    }

    if (!mounted) return;
    setState(() {
      _cameraPermission = status;
      _checkingHardware = false;
    });

    if (status.isGranted && _imagePath == null) {
      await _initCamera();
    }
    if (_imagePath != null) {
      await _analyzePhoto(_imagePath!);
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermission = status);
    if (status.isGranted) {
      await _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'Nenhuma câmera disponível no aparelho.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _cameraController?.dispose();
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Falha ao iniciar câmera: $e');
      }
    }
  }

  Future<String> _saveLocalCopy(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'materiais_locais'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(
      dir.path,
      'mat_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(target);
    return target;
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      final localPath = await _saveLocalCopy(file.path);
      if (!mounted) return;
      setState(() {
        _imagePath = localPath;
        _manualOnlySelection = null;
      });
      await _analyzePhoto(localPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fotografar material: $e')),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final localPath = await _saveLocalCopy(picked.path);
      if (!mounted) return;
      setState(() {
        _imagePath = localPath;
        _manualOnlySelection = null;
      });
      await _analyzePhoto(localPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir imagem: $e')),
        );
      }
    }
  }

  Future<void> _analyzePhoto(String path) async {
    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });
    try {
      final result = await _analyzerService.analyzeImage(
        path,
        useCenterRoi: _useCenterRoi,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisError = 'Erro na análise visual do material: $e';
      });
    }
  }

  Future<void> _openManualMaterialSelector() async {
    var search = '';
    final chosen = await showModalBottomSheet<IndustrialMaterial>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = industrialMaterialsCatalog.where((m) {
              if (search.trim().isEmpty) return true;
              final q = search.trim().toLowerCase();
              return m.name.toLowerCase().contains(q) ||
                  m.family.label.toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecionar / Corrigir Material (${industrialMaterialsCatalog.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Buscar material (ex: aço, latão, nylon...)',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (v) => setModalState(() => search = v),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return ListTile(
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${item.family.label} • ${item.densityGcm3.toStringAsFixed(2)} g/cm³',
                              ),
                              trailing: const Icon(Icons.check_circle_outline),
                              onTap: () => Navigator.of(sheetContext).pop(item),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (chosen == null || !mounted) return;
    setState(() {
      if (_result != null) {
        _result = _result!.copyWithManualSelection(chosen);
      } else {
        _manualOnlySelection = chosen;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingHardware) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = widget.settingsController.settings;
    final theme = Theme.of(context);
    final activeMaterial = _result?.selectedMaterial ?? _manualOnlySelection;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.offlineOnlyMode || !settings.allowCloudAiUpload
                            ? 'Processamento 100% local offline (nenhuma imagem é enviada externamente).'
                            : 'Análise local ativa; envio externo requer confirmação explícita.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                          ),
                          if (_useCenterRoi)
                            Center(
                              child: FractionallySizedBox(
                                widthFactor: 0.60,
                                heightFactor: 0.60,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: IndustrialColors.cyanAccent,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Amostrar área central (60%)'),
                        selected: _useCenterRoi,
                        onSelected: (value) async {
                          setState(() => _useCenterRoi = value);
                          await _analyzePhoto(_imagePath!);
                        },
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _imagePath = null;
                            _result = null;
                          });
                          if (_cameraPermission.isGranted &&
                              !widget.skipHardwareChecks) {
                            _initCamera();
                          }
                        },
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Nova Foto'),
                      ),
                    ],
                  ),
                ] else ...[
                  _buildCapturePanel(context),
                ],
              ],
            ),
          ),
        ),
        if (_isAnalyzing) ...[
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Extraindo cor, brilho especular e microtextura...'),
                ],
              ),
            ),
          ),
        ],
        if (_analysisError != null) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                _analysisError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
        if (activeMaterial != null) ...[
          const SizedBox(height: 14),
          _buildSelectedMaterialCard(context, activeMaterial),
        ],
        if (_result != null) ...[
          const SizedBox(height: 14),
          _buildAlternativesAndTelemetryCard(context, _result!),
        ],
      ],
    );
  }

  Widget _buildCapturePanel(BuildContext context) {
    final controller = _cameraController;
    final cameraReady = controller != null && controller.value.isInitialized;
    final isPermanent = _cameraPermission.isPermanentlyDenied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_cameraPermission.isGranted)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IndustrialColors.safetyAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: IndustrialColors.safetyAmber.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permissão de câmera necessária para identificar materiais pela imagem.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: isPermanent
                      ? () => openAppSettings()
                      : _requestPermission,
                  child: Text(
                    isPermanent ? 'Abrir Configurações' : 'Permitir Câmera',
                  ),
                ),
              ],
            ),
          )
        else if (cameraReady)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CameraPreview(controller),
            ),
          )
        else
          Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_cameraError ?? 'Inicializando câmera...'),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: cameraReady ? _capturePhoto : null,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Analisar com Câmera'),
            ),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Importar Foto'),
            ),
            OutlinedButton.icon(
              onPressed: _openManualMaterialSelector,
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Consultar / Selecionar Material'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedMaterialCard(
    BuildContext context,
    IndustrialMaterial material,
  ) {
    final theme = Theme.of(context);
    final result = _result;
    final isManual = result?.isManuallyCorrected ?? true;
    final confidence = result?.candidates
        .firstWhere((c) => c.material.id == material.id)
        .confidencePercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isManual
                        ? 'Material Confirmado Manualmente'
                        : 'Material Mais Provável (IA Visual)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isManual
                          ? const Color(0xFF26A69A)
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (!isManual && confidence != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Confiança: $confidence%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              material.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Família: ${material.family.label}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Densidade de referência',
              value:
                  '${material.densityGcm3.toStringAsFixed(2)} g/cm³ (${material.densityKgM3.toStringAsFixed(0)} kg/m³)\n${material.densityRangeNote}',
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Características visuais',
              value: material.visualCharacteristics,
            ),
            const SizedBox(height: 10),
            Text(
              'Aplicações comuns',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final app in material.commonApplications)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $app', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: IndustrialColors.safetyAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: IndustrialColors.safetyAmber.withValues(alpha: 0.45),
                ),
              ),
              child: const Text(
                materialChemicalDisclaimer,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _openManualMaterialSelector,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Corrigir Material Manualmente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativesAndTelemetryCard(
    BuildContext context,
    MaterialIdentificationResult result,
  ) {
    final theme = Theme.of(context);
    final traits = result.features.describeInPortuguese();
    final topAlternatives = result.candidates.take(4).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hipóteses Visuais e Telemetria (${result.features.engine})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final trait in traits)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $trait', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Text(
              'Materiais prováveis ranqueados',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            for (final candidate in topAlternatives)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${candidate.material.name} (${candidate.material.family.label})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(candidate.observedReasons.join(' • ')),
                trailing: Text(
                  '${candidate.confidencePercent}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _result = result.copyWithManualSelection(
                      candidate.material,
                    );
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(height: 1.35)),
      ],
    );
  }
}
