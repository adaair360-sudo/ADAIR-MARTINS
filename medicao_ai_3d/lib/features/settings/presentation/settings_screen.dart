import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/metrology_notice_banner.dart';
import '../domain/app_settings.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
  });

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = controller.settings;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Unidades e Exibição Técnica',
          subtitle:
              'Defina a unidade padrão aplicada aos módulos de medição e cálculos.',
          children: [
            Text(
              'Unidade padrão de comprimento',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<MeasurementUnit>(
              segments: [
                for (final unit in MeasurementUnit.values)
                  ButtonSegment<MeasurementUnit>(
                    value: unit,
                    label: Text(unit.symbol.toUpperCase()),
                  ),
              ],
              selected: {settings.defaultUnit},
              onSelectionChanged: (selection) {
                controller.updateDefaultUnit(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Casas decimais nos resultados',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(value: 1, label: Text('0.0 (1 casa)')),
                ButtonSegment<int>(value: 2, label: Text('0.00 (2 casas)')),
                ButtonSegment<int>(value: 3, label: Text('0.000 (3 casas)')),
              ],
              selected: {settings.decimalPlaces},
              onSelectionChanged: (selection) {
                controller.updateDecimalPlaces(selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Aparência da Interface',
          subtitle: 'Escolha o contraste adequado para oficina ou campo.',
          children: [
            SegmentedButton<AppThemePreference>(
              segments: [
                for (final pref in AppThemePreference.values)
                  ButtonSegment<AppThemePreference>(
                    value: pref,
                    label: Text(pref.label),
                  ),
              ],
              selected: {settings.themePreference},
              onSelectionChanged: (selection) {
                controller.updateThemePreference(selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Segurança, Privacidade e Modo Offline',
          subtitle:
              'Controle local de fotografias, conexão e avisos de metrologia.',
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Operar somente offline'),
              subtitle: const Text(
                'Bloqueia qualquer envio externo. Cálculos, medições calibradas e histórico funcionam sem internet.',
              ),
              value: settings.offlineOnlyMode,
              onChanged: (value) {
                controller.updateOfflineOnlyMode(value);
              },
            ),
            const Divider(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Autorizar envio de fotos para IA externa'),
              subtitle: Text(
                settings.offlineOnlyMode
                    ? 'Desativado automaticamente enquanto o modo offline estiver ligado.'
                    : 'Permite enviar fotografias somente quando você confirmar uma análise avançada.',
              ),
              value: settings.allowCloudAiUpload,
              onChanged: settings.offlineOnlyMode
                  ? null
                  : (value) {
                      controller.updateAllowCloudAiUpload(value);
                    },
            ),
            const Divider(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exibir aviso metrológico na tela inicial'),
              subtitle: const Text(
                'Mantém visível o lembrete sobre calibração e limitações técnicas.',
              ),
              value: settings.showMetrologyBanner,
              onChanged: (value) {
                controller.updateShowMetrologyBanner(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Sistema e Confiabilidade',
          subtitle: 'MEDIÇÃO AI 3D • Estrutura base Android (Etapa 1).',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Diretrizes de Segurança e Metrologia'),
              subtitle: const Text('Consultar regras de confiabilidade do app'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showMetrologySafetyDialog(context),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await controller.resetToDefaults();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Configurações restauradas para os padrões de fábrica.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Restaurar Padrões'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
