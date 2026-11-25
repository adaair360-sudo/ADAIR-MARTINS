import 'package:material_ui/material_ui.dart';

import 'core/constants/app_modules.dart';
import 'core/theme/industrial_theme.dart';
import 'core/widgets/metrology_notice_banner.dart';
import 'features/camera_measurement/presentation/camera_measurement_screen.dart';
import 'features/fastener_measurement/presentation/fastener_measurement_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/material_id/presentation/material_identification_screen.dart';
import 'features/mechanical_components/presentation/mechanical_components_screen.dart';
import 'features/settings/presentation/settings_controller.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/shared/presentation/planned_module_screen.dart';
import 'features/technical_drawing/presentation/technical_drawing_screen.dart';
import 'features/torque_calculator/presentation/torque_calculator_screen.dart';
import 'features/weight_volume/presentation/weight_volume_screen.dart';

class MedicaoAiApp extends StatelessWidget {
  const MedicaoAiApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        return MaterialApp(
          title: 'MEDIÇÃO AI 3D',
          debugShowCheckedModeBanner: false,
          theme: IndustrialTheme.light(),
          darkTheme: IndustrialTheme.dark(),
          themeMode: settingsController.themeMode,
          home: AppShellScreen(settingsController: settingsController),
        );
      },
    );
  }
}

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  // null means Tela Principal (Home). Non-null shows the selected module.
  AppModuleId? _activeModuleId;

  static const List<AppModuleId> _quickNavModules = [
    AppModuleId.cameraMeasurement,
    AppModuleId.torqueCalculator,
    AppModuleId.historyAndReports,
    AppModuleId.settings,
  ];

  int get _selectedNavIndex {
    if (_activeModuleId == null) {
      return 0;
    }
    final quickIndex = _quickNavModules.indexOf(_activeModuleId!);
    return quickIndex >= 0 ? quickIndex + 1 : 0;
  }

  void _openModule(AppModuleInfo module) {
    setState(() => _activeModuleId = module.id);
  }

  void _openHome() {
    setState(() => _activeModuleId = null);
  }

  @override
  Widget build(BuildContext context) {
    final activeModule = _activeModuleId == null
        ? null
        : moduleById(_activeModuleId!);

    return PopScope(
      canPop: activeModule == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && activeModule != null) {
          _openHome();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: activeModule == null
              ? const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.precision_manufacturing_rounded),
                )
              : IconButton(
                  tooltip: 'Voltar à Tela Principal',
                  onPressed: _openHome,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
          title: Text(
            activeModule == null ? 'MEDIÇÃO AI 3D' : activeModule.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            IconButton(
              tooltip: 'Diretrizes de Segurança',
              onPressed: () => showMetrologySafetyDialog(context),
              icon: const Icon(Icons.verified_user_outlined),
            ),
            if (activeModule != null &&
                activeModule.id != AppModuleId.settings)
              IconButton(
                tooltip: 'Configurações',
                onPressed: () => _openModule(moduleById(AppModuleId.settings)),
                icon: const Icon(Icons.tune_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: activeModule == null
              ? HomeScreen(
                  settingsController: widget.settingsController,
                  onOpenModule: _openModule,
                )
              : activeModule.id == AppModuleId.cameraMeasurement
              ? CameraMeasurementScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.materialIdentification
              ? MaterialIdentificationScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.fastenerMeasurement
              ? FastenerMeasurementScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.torqueCalculator
              ? TorqueCalculatorScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.weightAndVolume
              ? WeightVolumeScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.technicalDrawing
              ? TechnicalDrawingScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.mechanicalComponents
              ? MechanicalComponentsScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.historyAndReports
              ? HistoryScreen(
                  settingsController: widget.settingsController,
                )
              : activeModule.id == AppModuleId.settings
              ? SettingsScreen(controller: widget.settingsController)
              : PlannedModuleScreen(
                  module: activeModule,
                  onOpenSettings: () =>
                      _openModule(moduleById(AppModuleId.settings)),
                  onBackToHome: _openHome,
                ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedNavIndex,
          onDestinationSelected: (index) {
            if (index == 0) {
              _openHome();
              return;
            }
            _openModule(moduleById(_quickNavModules[index - 1]));
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Início',
            ),
            for (final id in _quickNavModules)
              NavigationDestination(
                icon: Icon(moduleById(id).icon),
                label: moduleById(id).shortLabel,
              ),
          ],
        ),
      ),
    );
  }
}
