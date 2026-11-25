import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'features/settings/presentation/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsController = SettingsController();
  await settingsController.load();

  runApp(MedicaoAiApp(settingsController: settingsController));
}
