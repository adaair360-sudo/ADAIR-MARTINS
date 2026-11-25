import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_modules.dart';
import '../../../core/theme/industrial_theme.dart';
import '../../../core/widgets/metrology_notice_banner.dart';
import '../../settings/presentation/settings_controller.dart';
import 'widgets/module_grid_card.dart';

enum _ModuleFilter { all, active, upcoming }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settingsController,
    required this.onOpenModule,
  });

  final SettingsController settingsController;
  final ValueChanged<AppModuleInfo> onOpenModule;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  _ModuleFilter _selectedFilter = _ModuleFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppModuleInfo> get _filteredModules {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    return appModules.where((module) {
      final matchesFilter = switch (_selectedFilter) {
        _ModuleFilter.all => true,
        _ModuleFilter.active => module.isImplemented,
        _ModuleFilter.upcoming => !module.isImplemented,
      };
      if (!matchesFilter) {
        return false;
      }
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return module.title.toLowerCase().contains(normalizedQuery) ||
          module.subtitle.toLowerCase().contains(normalizedQuery) ||
          module.formattedCode.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settingsController.settings;
    final modules = _filteredModules;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IndustrialHeaderCard(
                  defaultUnitSymbol: settings.defaultUnit.symbol,
                  offlineOnly: settings.offlineOnlyMode,
                  onSafetyTap: () => showMetrologySafetyDialog(context),
                ),
                if (settings.showMetrologyBanner) ...[
                  const SizedBox(height: 12),
                  MetrologyNoticeBanner(
                    onDetailsPressed: () => showMetrologySafetyDialog(context),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar módulo (ex: parafusos, torque, 3D...)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Todos (${appModules.length})'),
                      selected: _selectedFilter == _ModuleFilter.all,
                      onSelected: (_) =>
                          setState(() => _selectedFilter = _ModuleFilter.all),
                    ),
                    ChoiceChip(
                      label: const Text('Ativos agora'),
                      selected: _selectedFilter == _ModuleFilter.active,
                      onSelected: (_) => setState(
                        () => _selectedFilter = _ModuleFilter.active,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Próximas etapas'),
                      selected: _selectedFilter == _ModuleFilter.upcoming,
                      onSelected: (_) => setState(
                        () => _selectedFilter = _ModuleFilter.upcoming,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Módulos do Sistema',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (modules.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nenhum módulo encontrado para o filtro aplicado.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final crossAxisCount = width >= 900
                    ? 4
                    : width >= 600
                    ? 3
                    : 2;
                final aspectRatio = width >= 600 ? 1.05 : 0.84;

                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final module = modules[index];
                      return ModuleGridCard(
                        module: module,
                        onTap: () => widget.onOpenModule(module),
                      );
                    },
                    childCount: modules.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: aspectRatio,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _IndustrialHeaderCard extends StatelessWidget {
  const _IndustrialHeaderCard({
    required this.defaultUnitSymbol,
    required this.offlineOnly,
    required this.onSafetyTap,
  });

  final String defaultUnitSymbol;
  final bool offlineOnly;
  final VoidCallback onSafetyTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF132231), Color(0xFF1A2D40)]
              : const [Color(0xFF0F2942), Color(0xFF1A3F63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? IndustrialColors.cyanAccent.withValues(alpha: 0.35)
              : const Color(0xFF2B547E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: IndustrialColors.cyanAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.straighten_rounded,
                  color: IndustrialColors.cyanBright,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEDIÇÃO AI 3D',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Metrologia assistida e manutenção mecânica industrial',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFC9D8E6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusTag(
                icon: offlineOnly
                    ? Icons.offline_bolt_outlined
                    : Icons.cloud_outlined,
                label: offlineOnly ? 'Modo Offline Ativo' : 'Modo Híbrido',
                color: offlineOnly
                    ? const Color(0xFF4DD0E1)
                    : IndustrialColors.safetyAmber,
              ),
              _StatusTag(
                icon: Icons.square_foot_outlined,
                label: 'Unidade: $defaultUnitSymbol',
                color: const Color(0xFFB2DFDB),
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.policy_outlined,
                  size: 16,
                  color: Color(0xFFFFE082),
                ),
                label: const Text(
                  'Normas e Limitações',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                onPressed: onSafetyTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
