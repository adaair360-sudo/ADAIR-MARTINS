import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/industrial_theme.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/arcore_service.dart';
import '../data/opencv_service.dart';
import '../domain/camera_measurement_models.dart';
import '../domain/measurement_math.dart';
import 'arcore_measurement_screen.dart';
import 'widgets/measurement_photo_canvas.dart';

enum _CanvasToolMode { calibrate, measure }

class CameraMeasurementScreen extends StatefulWidget {
  const CameraMeasurementScreen({
    super.key,
    required this.settingsController,
    this.openCvService,
    this.arCoreService,
    this.initialImagePath,
    this.skipHardwareChecks = false,
  });

  final SettingsController settingsController;
  final OpenCvService? openCvService;
  final ArCoreService? arCoreService;
  final String? initialImagePath;
  final bool skipHardwareChecks;

  @override
  State<CameraMeasurementScreen> createState() =>
      _CameraMeasurementScreenState();
}

class _CameraMeasurementScreenState extends State<CameraMeasurementScreen> {
  late final OpenCvService _openCvService;
  late final ArCoreService _arCoreService;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _customRefController = TextEditingController(
    text: '50.0',
  );

  PermissionStatus _cameraPermission = PermissionStatus.denied;
  bool _checkingHardware = true;
  CameraController? _cameraController;
  FlashMode _flashMode = FlashMode.off;
  String? _cameraError;

  ArCoreAvailabilityInfo _arCoreInfo = ArCoreAvailabilityInfo.unavailable;

  String? _capturedImagePath;
  ContourAnalysisResult? _analysis;
  bool _isAnalyzing = false;
  String? _analysisError;

  bool _showOverlayImage = true;
  bool _showContours = true;

  _CanvasToolMode _toolMode = _CanvasToolMode.calibrate;
  ReferenceObjectPreset _selectedPreset = ReferenceObjectPreset.defaults.first;
  MeasurementUnit _customRefUnit = MeasurementUnit.millimeters;

  ImagePoint? _calibrationP1;
  ImagePoint? _calibrationP2;
  CalibrationResult? _calibration;

  ObjectGeometryType _geometryType = ObjectGeometryType.rectangular;
  MeasurementDimensionKind _dimensionKind = MeasurementDimensionKind.length;
  ImagePoint? _pendingPoint;
  final List<MeasurementMark> _marks = [];

  @override
  void initState() {
    super.initState();
    _openCvService = widget.openCvService ?? OpenCvService();
    _arCoreService = widget.arCoreService ?? ArCoreService();
    if (widget.initialImagePath != null) {
      _capturedImagePath = widget.initialImagePath;
    }
    _initializeEnvironment();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _customRefController.dispose();
    super.dispose();
  }

  Future<void> _initializeEnvironment() async {
    if (widget.skipHardwareChecks) {
      setState(() => _checkingHardware = false);
      if (_capturedImagePath != null) {
        await _analyzeCapturedPhoto(_capturedImagePath!);
      }
      return;
    }

    final arFuture = _arCoreService.checkAvailability();
    PermissionStatus status = PermissionStatus.denied;
    try {
      status = await Permission.camera.status;
    } catch (_) {
      status = PermissionStatus.denied;
    }
    final arInfo = await arFuture;

    if (!mounted) return;
    setState(() {
      _cameraPermission = status;
      _arCoreInfo = arInfo;
      _checkingHardware = false;
    });

    if (status.isGranted && _capturedImagePath == null) {
      await _initCamera();
    }
    if (_capturedImagePath != null) {
      await _analyzeCapturedPhoto(_capturedImagePath!);
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermission = status);
    if (status.isGranted) {
      await _initCamera();
      final arInfo = await _arCoreService.checkAvailability();
      if (mounted) {
        setState(() => _arCoreInfo = arInfo);
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = 'Nenhuma câmera física detectada.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _cameraController?.dispose();
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
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
        setState(
          () => _cameraError = 'Não foi possível iniciar a câmera: $e',
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final next =
        _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {}
  }

  Future<String> _saveLocalPrivateCopy(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docsDir.path, 'medicoes_locais'));
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dest = p.join(
      folder.path,
      'peca_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final xFile = await controller.takePicture();
      final localPath = await _saveLocalPrivateCopy(xFile.path);
      if (!mounted) return;
      _resetSessionForNewPhoto(localPath);
      await _analyzeCapturedPhoto(localPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao capturar fotografia: $e')),
        );
      }
    }
  }

  Future<void> _pickPhotoFromDevice() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final localPath = await _saveLocalPrivateCopy(picked.path);
      if (!mounted) return;
      _resetSessionForNewPhoto(localPath);
      await _analyzeCapturedPhoto(localPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível carregar a imagem: $e')),
        );
      }
    }
  }

  void _resetSessionForNewPhoto(String path) {
    setState(() {
      _capturedImagePath = path;
      _analysis = null;
      _analysisError = null;
      _calibrationP1 = null;
      _calibrationP2 = null;
      _calibration = null;
      _pendingPoint = null;
      _marks.clear();
      _toolMode = _CanvasToolMode.calibrate;
    });
  }

  Future<void> _analyzeCapturedPhoto(String imagePath) async {
    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });
    try {
      final result = await _openCvService.analyzeImage(imagePath);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _analysisError = 'Erro na análise de contornos: $e';
      });
    }
  }

  double get _knownReferenceMm {
    if (!_selectedPreset.isCustom) {
      return _selectedPreset.knownMillimeters;
    }
    final raw = double.tryParse(_customRefController.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) return 0;
    return switch (_customRefUnit) {
      MeasurementUnit.millimeters => raw,
      MeasurementUnit.centimeters => raw * 10.0,
      MeasurementUnit.meters => raw * 1000.0,
    };
  }

  void _applyCalibrationFromPoints(
    ImagePoint p1,
    ImagePoint p2, {
    String? customLabel,
  }) {
    final pixelSpan = p1.distanceTo(p2);
    final refMm = _knownReferenceMm;
    if (pixelSpan <= 2 || refMm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Marque dois pontos distintos e informe uma dimensão de referência válida.',
          ),
        ),
      );
      return;
    }

    final nextCalibration = MeasurementMath.buildVisualCalibration(
      referencePixelSpan: pixelSpan,
      knownReferenceMm: refMm,
      referenceName: customLabel ?? _selectedPreset.name,
    );

    if (nextCalibration == null) return;

    // Recalculate existing marks cleanly using the new calibration
    final updatedMarks = _marks.map((mark) {
      final mm = MeasurementMath.convertPixelsToMillimeters(
        mark.pixelDistance,
        nextCalibration,
      );
      final uncertainty = MeasurementMath.evaluateUncertainty(
        calibration: nextCalibration,
        measuredPixels: mark.pixelDistance,
        sharpnessVariance: _analysis?.sharpnessVariance ?? 80,
        contrastStdDev: _analysis?.contrastStdDev ?? 35,
      );
      return MeasurementMark(
        id: mark.id,
        kind: mark.kind,
        geometryType: mark.geometryType,
        p1: mark.p1,
        p2: mark.p2,
        pixelDistance: mark.pixelDistance,
        millimeters: mm,
        uncertainty: uncertainty,
        note: mark.note,
      );
    }).toList();

    setState(() {
      _calibrationP1 = p1;
      _calibrationP2 = p2;
      _calibration = nextCalibration;
      _pendingPoint = null;
      _marks
        ..clear()
        ..addAll(updatedMarks);
      _toolMode = _CanvasToolMode.measure;
    });
  }

  void _addMeasurementSegment(
    ImagePoint p1,
    ImagePoint p2, {
    MeasurementDimensionKind? kindOverride,
    ObjectGeometryType? geometryOverride,
    String? note,
  }) {
    final px = p1.distanceTo(p2);
    if (px <= 1) return;

    final mm = MeasurementMath.convertPixelsToMillimeters(px, _calibration);
    final uncertainty = MeasurementMath.evaluateUncertainty(
      calibration: _calibration,
      measuredPixels: px,
      sharpnessVariance: _analysis?.sharpnessVariance ?? 80,
      contrastStdDev: _analysis?.contrastStdDev ?? 35,
    );

    setState(() {
      _marks.add(
        MeasurementMark(
          id: 'm_${DateTime.now().microsecondsSinceEpoch}',
          kind: kindOverride ?? _dimensionKind,
          geometryType: geometryOverride ?? _geometryType,
          p1: p1,
          p2: p2,
          pixelDistance: px,
          millimeters: mm,
          uncertainty: uncertainty,
          note: note,
        ),
      );
    });
  }

  void _handleCanvasTap(ImagePoint point) {
    if (_pendingPoint == null) {
      setState(() => _pendingPoint = point);
      return;
    }
    final first = _pendingPoint!;
    _pendingPoint = null;

    if (_toolMode == _CanvasToolMode.calibrate) {
      _applyCalibrationFromPoints(first, point);
    } else {
      _addMeasurementSegment(first, point);
    }
  }

  void _adoptContour(DetectedContour contour, {required bool asCalibration}) {
    if (contour.boxPoints.length < 4) return;
    final p0 = contour.boxPoints[0];
    final p1 = contour.boxPoints[1];
    final p2 = contour.boxPoints[2];
    final edge01 = p0.distanceTo(p1);
    final edge12 = p1.distanceTo(p2);
    final majorA = edge01 >= edge12 ? p0 : p1;
    final majorB = edge01 >= edge12 ? p1 : p2;
    final minorA = edge01 >= edge12 ? p1 : p0;
    final minorB = edge01 >= edge12 ? p2 : p1;

    if (asCalibration) {
      _applyCalibrationFromPoints(
        majorA,
        majorB,
        customLabel: '${_selectedPreset.name} (Contorno ${contour.id})',
      );
      return;
    }

    if (contour.shapeHint == 'cylindrical') {
      _addMeasurementSegment(
        majorA,
        majorB,
        kindOverride: MeasurementDimensionKind.diameter,
        geometryOverride: ObjectGeometryType.cylindrical,
        note: 'Diâmetro estimado por contorno circular ${contour.id}',
      );
    } else {
      _addMeasurementSegment(
        majorA,
        majorB,
        kindOverride: MeasurementDimensionKind.length,
        geometryOverride: ObjectGeometryType.rectangular,
        note: 'Comprimento por contorno retangular ${contour.id}',
      );
      _addMeasurementSegment(
        minorA,
        minorB,
        kindOverride: MeasurementDimensionKind.width,
        geometryOverride: ObjectGeometryType.rectangular,
        note: 'Largura por contorno retangular ${contour.id}',
      );
    }
  }

  void _adoptCircle(DetectedCircle circle, {required bool asCalibration}) {
    final radius = circle.diameterPx / 2.0;
    final p1 = ImagePoint(circle.centerX - radius, circle.centerY);
    final p2 = ImagePoint(circle.centerX + radius, circle.centerY);

    if (asCalibration) {
      _applyCalibrationFromPoints(
        p1,
        p2,
        customLabel: '${_selectedPreset.name} (Círculo Hough)',
      );
    } else {
      _addMeasurementSegment(
        p1,
        p2,
        kindOverride: MeasurementDimensionKind.diameter,
        geometryOverride: ObjectGeometryType.cylindrical,
        note: 'Diâmetro detectado via HoughCircles (OpenCV)',
      );
    }
  }

  Future<void> _openArCoreMode() async {
    if (!_cameraPermission.isGranted) {
      await _requestCameraPermission();
      if (!_cameraPermission.isGranted) return;
    }
    if (_arCoreInfo.needsInstall) {
      await _arCoreService.requestInstall();
      final refreshed = await _arCoreService.checkAvailability();
      if (mounted) setState(() => _arCoreInfo = refreshed);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArCoreMeasurementScreen(
          availability: _arCoreInfo,
          decimalPlaces: widget.settingsController.settings.decimalPlaces,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingHardware) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_capturedImagePath != null) {
      return _buildPhotoMeasurementWorkspace(context);
    }

    return _buildCaptureLandingView(context);
  }

  Widget _buildCaptureLandingView(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _cameraController;
    final cameraReady = controller != null && controller.value.isInitialized;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Captura e Inspeção Dimensional',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Posicione um objeto de dimensão conhecida no mesmo plano da peça para calibrar a escala com precisão. Nenhuma foto é enviada externamente.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_cameraPermission.isGranted)
                  _buildPermissionCard(context)
                else if (cameraReady)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                tooltip: 'Alternar flash',
                                onPressed: _toggleFlash,
                                icon: Icon(
                                  _flashMode == FlashMode.torch
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    height: 200,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _cameraError ?? 'Inicializando visualização da câmera...',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: cameraReady ? _capturePhoto : null,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Fotografar Peça'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickPhotoFromDevice,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Importar Foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openArCoreMode,
                      icon: const Icon(Icons.view_in_ar_outlined),
                      label: Text(
                        _arCoreInfo.isSupported
                            ? 'Modo ARCore 3D'
                            : 'ARCore (${_arCoreInfo.status})',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard(BuildContext context) {
    final isPermanent = _cameraPermission.isPermanentlyDenied;
    return Container(
      padding: const EdgeInsets.all(14),
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
          const Row(
            children: [
              Icon(Icons.camera_alt_outlined),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permissão de câmera necessária',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'O MEDIÇÃO AI 3D utiliza a câmera apenas localmente para capturar imagens de peças e detectar contornos.',
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: isPermanent
                ? () => openAppSettings()
                : _requestCameraPermission,
            child: Text(
              isPermanent ? 'Abrir Configurações do Android' : 'Permitir Câmera',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoMeasurementWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    final decimals = widget.settingsController.settings.decimalPlaces;
    final analysis = _analysis;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (_calibration == null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IndustrialColors.safetyAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: IndustrialColors.safetyAmber.withValues(alpha: 0.5),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: IndustrialColors.safetyAmber),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'MEDIDA NÃO CALIBRADA: Antes de calibrar com um objeto de referência conhecida, nenhuma dimensão em mm/cm/m será exibida como medida exata.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF26A69A).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF26A69A).withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF26A69A),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Calibração ativa: ${_calibration!.referenceName} (${_calibration!.knownReferenceMm.toStringAsFixed(decimals)} mm = ${_calibration!.referencePixelSpan.toStringAsFixed(1)} px • ${_calibration!.pixelsPerMm.toStringAsFixed(2)} px/mm)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<_CanvasToolMode>(
                        segments: const [
                          ButtonSegment(
                            value: _CanvasToolMode.calibrate,
                            icon: Icon(Icons.straighten_rounded, size: 18),
                            label: Text('1. Calibrar'),
                          ),
                          ButtonSegment(
                            value: _CanvasToolMode.measure,
                            icon: Icon(Icons.architecture_rounded, size: 18),
                            label: Text('2. Medir'),
                          ),
                        ],
                        selected: {_toolMode},
                        onSelectionChanged: (s) {
                          setState(() {
                            _toolMode = s.first;
                            _pendingPoint = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Nova captura',
                      onPressed: () {
                        setState(() {
                          _capturedImagePath = null;
                          _analysis = null;
                          _calibration = null;
                          _calibrationP1 = null;
                          _calibrationP2 = null;
                          _marks.clear();
                        });
                        if (_cameraPermission.isGranted &&
                            !widget.skipHardwareChecks) {
                          _initCamera();
                        }
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isAnalyzing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Processando contornos com OpenCV...'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  MeasurementPhotoCanvas(
                    imagePath: _capturedImagePath!,
                    imageWidth: analysis?.imageWidth ?? 1280,
                    imageHeight: analysis?.imageHeight ?? 960,
                    analysis: analysis,
                    showOverlayImage: _showOverlayImage,
                    showContours: _showContours,
                    calibrationP1: _calibrationP1,
                    calibrationP2: _calibrationP2,
                    pendingPoint: _pendingPoint,
                    marks: _marks,
                    onImageTapped: _handleCanvasTap,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pendingPoint == null
                        ? (_toolMode == _CanvasToolMode.calibrate
                            ? 'Toque no 1º extremo do objeto de referência para calibrar.'
                            : 'Toque no 1º ponto da peça para iniciar uma medição.')
                        : 'Agora toque no 2º ponto para concluir o segmento.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (analysis?.overlayPath != null)
                        FilterChip(
                          label: const Text('Overlay OpenCV'),
                          selected: _showOverlayImage,
                          onSelected: (v) =>
                              setState(() => _showOverlayImage = v),
                        ),
                      FilterChip(
                        label: const Text('Contornos vetoriais'),
                        selected: _showContours,
                        onSelected: (v) => setState(() => _showContours = v),
                      ),
                      if (_marks.isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Limpar medidas'),
                          onPressed: () => setState(() => _marks.clear()),
                        ),
                    ],
                  ),
                ],
                if (_analysisError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _analysisError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_toolMode == _CanvasToolMode.calibrate)
          _buildCalibrationPanel(context, decimals)
        else
          _buildMeasurementToolPanel(context),
        const SizedBox(height: 12),
        _buildResultsList(context, decimals),
        if (analysis != null) ...[
          const SizedBox(height: 12),
          _buildOpenCvTelemetryPanel(context, analysis),
        ],
      ],
    );
  }

  Widget _buildCalibrationPanel(BuildContext context, int decimals) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calibração por Objeto Conhecido',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ReferenceObjectPreset>(
              initialValue: _selectedPreset,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Objeto de referência visual',
              ),
              items: [
                for (final preset in ReferenceObjectPreset.defaults)
                  DropdownMenuItem(
                    value: preset,
                    child: Text(preset.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedPreset = value);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedPreset.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_selectedPreset.isCustom) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customRefController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Medida conhecida',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<MeasurementUnit>(
                    value: _customRefUnit,
                    items: [
                      for (final unit in MeasurementUnit.values)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(unit.symbol),
                        ),
                    ],
                    onChanged: (u) {
                      if (u != null) setState(() => _customRefUnit = u);
                    },
                  ),
                ],
              ),
            ],
            if (_calibration != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF26A69A).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'Calibração ativa: ${_calibration!.referenceName} (${_calibration!.knownReferenceMm.toStringAsFixed(decimals)} mm = ${_calibration!.referencePixelSpan.toStringAsFixed(1)} px • ${_calibration!.pixelsPerMm.toStringAsFixed(2)} px/mm)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementToolPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuração da Medição',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Geometria da peça',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<ObjectGeometryType>(
              segments: [
                for (final type in ObjectGeometryType.values)
                  ButtonSegment(value: type, label: Text(type.label)),
              ],
              selected: {_geometryType},
              onSelectionChanged: (s) {
                setState(() {
                  _geometryType = s.first;
                  if (_geometryType == ObjectGeometryType.cylindrical) {
                    _dimensionKind = MeasurementDimensionKind.diameter;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Grandeza a marcar na foto',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final kind in MeasurementDimensionKind.values.where(
                  (k) => k != MeasurementDimensionKind.calibrationReference,
                ))
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _dimensionKind == kind,
                    onSelected: (_) => setState(() => _dimensionKind = kind),
                  ),
              ],
            ),
            if (_dimensionKind == MeasurementDimensionKind.depth) ...[
              const SizedBox(height: 10),
              Text(
                MeasurementMath.depthLimitationExplanation(
                  arCoreSupported: _arCoreInfo.isSupported &&
                      _arCoreInfo.depthSupported,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: IndustrialColors.safetyAmber,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, int decimals) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medições Registradas (${_marks.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (_marks.isEmpty)
              Text(
                'Nenhuma medição marcada ainda. Toque em 2 pontos na foto ou selecione um contorno detectado abaixo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final mark in _marks) ...[
                _MeasurementResultTile(
                  mark: mark,
                  decimals: decimals,
                  onDelete: () => setState(() => _marks.remove(mark)),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpenCvTelemetryPanel(
    BuildContext context,
    ContourAnalysisResult analysis,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visão Computacional (${analysis.engine})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Resolução: ${analysis.imageWidth}×${analysis.imageHeight} px  •  Nitidez: ${analysis.sharpnessVariance.toStringAsFixed(0)}  •  Contraste: ${analysis.contrastStdDev.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall,
            ),
            if (analysis.contours.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Contornos detectados (${analysis.contours.length})',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              for (final c in analysis.contours.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${c.id} • ${c.shapeLabelPt} (${c.majorPx.toStringAsFixed(0)}×${c.minorPx.toStringAsFixed(0)} px)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _adoptContour(c, asCalibration: true),
                        child: const Text('Calibrar'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _adoptContour(c, asCalibration: false),
                        child: const Text('Medir'),
                      ),
                    ],
                  ),
                ),
            ],
            if (analysis.circles.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Círculos / Cilindros Hough (${analysis.circles.length})',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final circle in analysis.circles.take(4))
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ø ${circle.diameterPx.toStringAsFixed(0)} px',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _adoptCircle(circle, asCalibration: true),
                      child: const Text('Calibrar'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _adoptCircle(circle, asCalibration: false),
                      child: const Text('Medir Ø'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeasurementResultTile extends StatelessWidget {
  const _MeasurementResultTile({
    required this.mark,
    required this.decimals,
    required this.onDelete,
  });

  final MeasurementMark mark;
  final int decimals;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uncertainty = mark.uncertainty;
    final qualityColor = switch (uncertainty.qualityLevel) {
      MeasurementQualityLevel.high => const Color(0xFF26A69A),
      MeasurementQualityLevel.moderate => const Color(0xFF42A5F5),
      MeasurementQualityLevel.low => IndustrialColors.safetyAmber,
      MeasurementQualityLevel.uncalibrated => const Color(0xFFFF7043),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${mark.kind.label} (${mark.geometryType.label})',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: qualityColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Qualidade: ${uncertainty.qualityLevel.label}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: qualityColor,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remover medição',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (mark.millimeters != null) ...[
            Text(
              UnitConversions.formatAllUnits(
                mark.millimeters!,
                decimals: decimals,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Incerteza: ±${uncertainty.uncertaintyMm?.toStringAsFixed(decimals) ?? '--'} mm  •  Confiança: ${uncertainty.confidenceScore}%  •  (${mark.pixelDistance.toStringAsFixed(1)} px)',
              style: theme.textTheme.bodySmall,
            ),
          ] else
            Text(
              '${mark.pixelDistance.toStringAsFixed(1)} px — Não calibrado (realize a calibração para converter em mm, cm e m)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFFF7043),
                fontWeight: FontWeight.w700,
              ),
            ),
          if (uncertainty.limitations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              uncertainty.limitations.first,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
