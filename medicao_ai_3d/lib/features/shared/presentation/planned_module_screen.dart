import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_modules.dart';
import '../../../core/theme/industrial_theme.dart';

class PlannedModuleScreen extends StatelessWidget {
  const PlannedModuleScreen({
    super.key,
    required this.module,
    required this.onOpenSettings,
    this.onBackToHome,
  });

  final AppModuleInfo module;
  final VoidCallback onOpenSettings;
  final VoidCallback? onBackToHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: module.accentColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: module.accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        module.icon,
                        size: 30,
                        color: module.accentColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MÓDULO ${module.formattedCode} • ETAPA ${module.stageNumber}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: module.accentColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            module.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  module.subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? IndustrialColors.darkSurfaceElevated
                        : IndustrialColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.engineering_outlined, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Implantação programada para a Etapa ${module.stageNumber}. Nenhuma leitura ou cálculo simulado é exibido antes da implementação real deste módulo.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escopo Técnico Previsto',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in module.technicalScope) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: module.accentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IndustrialColors.safetyAmber.withValues(
              alpha: isDark ? 0.12 : 0.16,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: IndustrialColors.safetyAmber.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark
                    ? IndustrialColors.safetyAmber
                    : const Color(0xFFB45309),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Critério de Segurança e Metrologia',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.safetyNotice,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Configurar Unidades e Privacidade'),
            ),
            if (onBackToHome != null)
              OutlinedButton.icon(
                onPressed: onBackToHome,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Voltar à Tela Principal'),
              ),
          ],
        ),
      ],
    );
  }
}
