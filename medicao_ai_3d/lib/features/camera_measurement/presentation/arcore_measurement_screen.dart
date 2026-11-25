import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/arcore_service.dart';
import '../domain/camera_measurement_models.dart';
import '../domain/measurement_math.dart';

class ArCoreMeasurementScreen extends StatefulWidget {
  const ArCoreMeasurementScreen({
    super.key,
    required this.availability,
    required this.decimalPlaces,
  });

  final ArCoreAvailabilityInfo availability;
  final int decimalPlaces;

  @override
  State<ArCoreMeasurementScreen> createState() =>
      _ArCoreMeasurementScreenState();
}

class _ArCoreMeasurementScreenState extends State<ArCoreMeasurementScreen> {
  MethodChannel? _viewChannel;
  String _trackingState = 'INICIALIZANDO';
  int _anchorCount = 0;
  bool _depthSupported = false;
  double? _distanceMeters;
  double? _horizontalMeters;
  double? _verticalMeters;
  double? _centerDepthMm;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _depthSupported = widget.availability.depthSupported;
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('br.com.medicaoai3d/arcore_view_$viewId');
    channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'onMeasurementUpdate') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        setState(() {
          _trackingState = data['trackingState'] as String? ?? 'DESCONHECIDO';
          _anchorCount = (data['anchorCount'] as num?)?.toInt() ?? 0;
          _depthSupported =
              data['depthSupported'] as bool? ?? widget.availability.depthSupported;
          _distanceMeters = (data['distanceMeters'] as num?)?.toDouble();
          _horizontalMeters = (data['horizontalMeters'] as num?)?.toDouble();
          _verticalMeters = (data['verticalMeters'] as num?)?.toDouble();
          final depth = (data['centerDepthMm'] as num?)?.toDouble();
          if (depth != null) {
            _centerDepthMm = depth;
          }
        });
      } else if (call.method == 'onError') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        setState(() {
          _errorMessage = data['message'] as String?;
        });
      }
    });
    _viewChannel = channel;
  }

  @override
  void dispose() {
    _viewChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final canRunAr =
        isAndroid &&
        widget.availability.isSupported &&
        widget.availability.isInstalled;

    final distanceMm = _distanceMeters != null ? _distanceMeters! * 1000.0 : null;
    final uncertainty = _distanceMeters != null
        ? MeasurementMath.evaluateUncertainty(
            calibration: null,
            measuredPixels: 0,
            sharpnessVariance: 0,
            contrastStdDev: 0,
            arCoreDistanceMeters: _distanceMeters,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medição 3D ARCore'),
      ),
      body: Column(
        children: [
          Expanded(
            child: canRunAr
                ? Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: Colors.black)),
                      AndroidView(
                        viewType: 'br.com.medicaoai3d/arcore_view',
                        onPlatformViewCreated: _onPlatformViewCreated,
                      ),
                      Center(
                        child: IgnorePointer(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF00E5FF),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.add,
                                color: Color(0xFF00E5FF),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Rastreamento: $_trackingState  •  Pontos: $_anchorCount/2  •  Depth API: ${_depthSupported ? 'Ativa' : 'Indisponível'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.view_in_ar_outlined, size: 52),
                          const SizedBox(height: 12),
                          Text(
                            'ARCore indisponível neste dispositivo (${widget.availability.status}).',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Utilize o modo de Medição por Foto Calibrada (OpenCV + Referência Visual), compatível com qualquer aparelho Android.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                if (distanceMm != null) ...[
                  Text(
                    'Distância 3D Estimada (ARCore)',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    UnitConversions.formatAllUnits(
                      distanceMm,
                      decimals: widget.decimalPlaces,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (_horizontalMeters != null && _verticalMeters != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Horizontal: ${(_horizontalMeters! * 1000).toStringAsFixed(1)} mm  •  Altura ΔY: ${(_verticalMeters! * 1000).toStringAsFixed(1)} mm',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (uncertainty != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Qualidade: ${uncertainty.qualityLevel.label} • Incerteza estimada: ±${uncertainty.uncertaintyMm?.toStringAsFixed(1) ?? '--'} mm',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ] else
                  Text(
                    canRunAr
                        ? 'Movimente o celular para detectar superfícies e toque na tela (ou em "Marcar Ponto") para definir os 2 pontos 3D.'
                        : 'Modo ARCore requer aparelho compatível e Google Play Services for AR.',
                    style: theme.textTheme.bodySmall,
                  ),
                if (_centerDepthMm != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Profundidade até o alvo central: ${UnitConversions.formatAllUnits(_centerDepthMm!, decimals: widget.decimalPlaces)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: canRunAr
                          ? () => _viewChannel?.invokeMethod('placeCenterPoint')
                          : null,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Marcar Ponto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: (canRunAr && _depthSupported)
                          ? () =>
                              _viewChannel?.invokeMethod('measureCenterDepth')
                          : null,
                      icon: const Icon(Icons.straighten_outlined),
                      label: const Text('Medir Profundidade'),
                    ),
                    TextButton.icon(
                      onPressed: canRunAr
                          ? () => _viewChannel?.invokeMethod('clearPoints')
                          : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Limpar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
