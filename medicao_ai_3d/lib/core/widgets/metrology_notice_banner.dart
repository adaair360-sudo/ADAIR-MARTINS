import 'package:material_ui/material_ui.dart';

import '../theme/industrial_theme.dart';

class MetrologyNoticeBanner extends StatelessWidget {
  const MetrologyNoticeBanner({super.key, this.onDetailsPressed});

  final VoidCallback? onDetailsPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? IndustrialColors.safetyAmber.withValues(alpha: 0.45)
        : const Color(0xFFD97706).withValues(alpha: 0.45);
    final bgColor = isDark
        ? IndustrialColors.safetyAmber.withValues(alpha: 0.10)
        : const Color(0xFFFEF3C7);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: isDark
                ? IndustrialColors.safetyAmber
                : const Color(0xFFB45309),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diretriz de Confiabilidade Metrológica',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? IndustrialColors.safetyAmber
                        : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ferramenta auxiliar de inspeção e manutenção. Não substitui instrumentos certificados e nunca apresenta medidas sem calibração como exatas.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
          if (onDetailsPressed != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onDetailsPressed,
              child: const Text('Diretrizes'),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showMetrologySafetyDialog(BuildContext context) {
  const rules = [
    'Solicita permissão explícita antes de acessar a câmera do aparelho.',
    'Não envia fotografias para serviços externos sem autorização do usuário.',
    'Nunca inventa medições, limites de torque ou resultados técnicos.',
    'Exige calibração visual ou referência conhecida para medições por câmera.',
    'Identifica claramente resultados estimados, qualidade e incerteza.',
    'Registra fontes técnicas e normas aplicáveis nos cálculos de torque.',
    'Não substitui paquímetro, micrômetro, torquímetro ou metrologia certificada.',
    'Mantém banco de dados local protegido e funcional em modo offline.',
  ];

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_outlined),
          SizedBox(width: 10),
          Expanded(child: Text('Segurança e Confiabilidade')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O MEDIÇÃO AI 3D segue princípios rigorosos de engenharia e metrologia industrial:',
            ),
            const SizedBox(height: 12),
            for (final rule in rules) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(rule)),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
