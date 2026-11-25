import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import '../../settings/presentation/settings_controller.dart';
import '../data/history_database.dart';
import '../data/history_report_pdf_service.dart';
import '../domain/history_models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.settingsController,
    this.database,
    this.pdfService,
  });

  final SettingsController settingsController;
  final HistoryDatabase? database;
  final HistoryReportPdfService? pdfService;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final HistoryDatabase _db;
  late final HistoryReportPdfService _pdfService;
  final _picker = ImagePicker();
  final _searchCtrl = TextEditingController();

  List<MaintenanceProject> _projects = const [];
  List<HistoryRecord> _records = const [];
  String? _selectedProjectId;
  HistoryRecordType? _selectedType;
  bool _loading = true;
  bool _exportingPdf = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? HistoryDatabase();
    _pdfService = widget.pdfService ?? HistoryReportPdfService();
    _refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final projects = await _db.listProjects();
    final records = await _db.listRecords(
      projectId: _selectedProjectId,
      recordType: _selectedType,
      searchQuery: _searchCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _records = records;
      _loading = false;
    });
  }

  MaintenanceProject? get _selectedProject {
    if (_selectedProjectId == null) return null;
    for (final p in _projects) {
      if (p.id == _selectedProjectId) return p;
    }
    return null;
  }

  Future<void> _openProjectDialog({MaintenanceProject? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final tagCtrl = TextEditingController(text: existing?.equipmentTag ?? '');
    final areaCtrl = TextEditingController(
      text: existing?.locationOrClient ?? '',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? 'Novo projeto de manutenção' : 'Editar projeto',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do projeto*',
                  hintText: 'Ex.: Revisão Bomba Centrífuga B-04',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(
                  labelText: 'TAG / Equipamento',
                  hintText: 'Ex.: BMB-04 / Redutor R-12',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: areaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Área / Cliente',
                  hintText: 'Ex.: Utilidades / Linha 2',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Salvar projeto'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final now = DateTime.now().toIso8601String();
      final project = MaintenanceProject(
        id: existing?.id ?? 'prj_${DateTime.now().microsecondsSinceEpoch}',
        name: nameCtrl.text.trim(),
        equipmentTag: tagCtrl.text.trim(),
        locationOrClient: areaCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
        createdAtIso: existing?.createdAtIso ?? now,
        updatedAtIso: now,
      );
      await _db.upsertProject(project);
      _selectedProjectId = project.id;
      _statusMessage = 'Projeto "${project.name}" salvo no SQLite local.';
      await _refresh();
    }

    nameCtrl.dispose();
    tagCtrl.dispose();
    areaCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _deleteSelectedProject() async {
    final project = _selectedProject;
    if (project == null) return;
    await _db.deleteProject(project.id);
    _selectedProjectId = null;
    _statusMessage = 'Projeto "${project.name}" excluído.';
    await _refresh();
  }

  Future<void> _openRecordDialog({HistoryRecord? existing}) async {
    var recordType = existing?.recordType ?? HistoryRecordType.cameraMeasurement;
    String? projectId = existing?.projectId ?? _selectedProjectId;
    String? photoPath = existing?.photoPath;

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final summaryCtrl = TextEditingController(text: existing?.summary ?? '');
    final measCtrl = TextEditingController(
      text: existing?.measurementsText ?? '',
    );
    final sourceCtrl = TextEditingController(
      text: existing?.technicalSource ?? '',
    );
    final noteCtrl = TextEditingController(
      text: existing?.uncertaintyOrNote ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Novo registro técnico' : 'Editar registro técnico',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<HistoryRecordType>(
                  initialValue: recordType,
                  decoration: const InputDecoration(labelText: 'Tipo de registro'),
                  items: [
                    for (final t in HistoryRecordType.values)
                      DropdownMenuItem(value: t, child: Text(t.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => recordType = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _projects.any((p) => p.id == projectId)
                      ? projectId
                      : null,
                  decoration: const InputDecoration(labelText: 'Projeto'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sem projeto vinculado'),
                    ),
                    for (final p in _projects)
                      DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setDialogState(() => projectId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título*',
                    hintText: 'Ex.: Flange bomba Ø120 mm / Parafuso M10 8.8',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: measCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Medidas e parâmetros reais',
                    hintText: 'Ex.: D=120.4 mm, furo=25.0 mm, torque=49.0 N·m',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: summaryCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Resumo técnico',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sourceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fonte técnica / norma',
                    hintText: 'Ex.: VDI 2230 / ISO 898-1 / Paquímetro',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Incerteza / observações',
                    hintText: 'Ex.: Incerteza estimada ±0.35 mm (calibração boa)',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final perm = await Permission.camera.request();
                        if (!perm.isGranted) return;
                        final file = await _picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 85,
                        );
                        if (file != null) {
                          setDialogState(() => photoPath = file.path);
                        }
                      },
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Foto câmera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await _picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (file != null) {
                          setDialogState(() => photoPath = file.path);
                        }
                      },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeria'),
                    ),
                    if (photoPath != null && photoPath!.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setDialogState(() => photoPath = null),
                        icon: const Icon(Icons.close),
                        label: const Text('Remover foto'),
                      ),
                  ],
                ),
                if (photoPath != null && photoPath!.isNotEmpty)
                  Text(
                    'Foto vinculada: ${photoPath!.split('/').last}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Salvar registro'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final now = DateTime.now().toIso8601String();
      final record = HistoryRecord(
        id: existing?.id ?? 'rec_${DateTime.now().microsecondsSinceEpoch}',
        projectId: projectId,
        recordType: recordType,
        title: titleCtrl.text.trim(),
        summary: summaryCtrl.text.trim(),
        measurementsText: measCtrl.text.trim(),
        technicalSource: sourceCtrl.text.trim(),
        uncertaintyOrNote: noteCtrl.text.trim(),
        photoPath: photoPath,
        createdAtIso: existing?.createdAtIso ?? now,
        updatedAtIso: now,
      );
      await _db.upsertRecord(record);
      _statusMessage = 'Registro "${record.title}" salvo no banco SQLite local.';
      await _refresh();
    }

    titleCtrl.dispose();
    summaryCtrl.dispose();
    measCtrl.dispose();
    sourceCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _deleteRecord(HistoryRecord record) async {
    await _db.deleteRecord(record.id);
    _statusMessage = 'Registro "${record.title}" excluído do histórico.';
    await _refresh();
  }

  Future<void> _exportReport({bool share = false}) async {
    if (_records.isEmpty) {
      setState(() {
        _statusMessage =
            'Não há registros visíveis para incluir no relatório PDF.';
      });
      return;
    }
    setState(() {
      _exportingPdf = true;
      _statusMessage = null;
    });
    try {
      final proj = _selectedProject;
      final title = proj != null
          ? 'Relatório Técnico — ${proj.name}'
          : 'Relatório Técnico Geral — MEDIÇÃO AI 3D';
      final file = await _pdfService.exportReportToFile(
        project: proj,
        records: _records,
        reportTitle: title,
      );
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Relatório PDF exportado em: ${file.path}';
      });
      if (share) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: file.uri.pathSegments.last,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Falha ao gerar relatório PDF: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _exportingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProj = _selectedProject;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Projetos de manutenção (SQLite offline)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _openProjectDialog(),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Novo projeto'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos os projetos'),
                      selected: _selectedProjectId == null,
                      onSelected: (_) {
                        setState(() => _selectedProjectId = null);
                        _refresh();
                      },
                    ),
                    for (final project in _projects)
                      ChoiceChip(
                        label: Text(project.name),
                        selected: _selectedProjectId == project.id,
                        onSelected: (_) {
                          setState(() => _selectedProjectId = project.id);
                          _refresh();
                        },
                      ),
                  ],
                ),
                if (selectedProj != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (selectedProj.equipmentTag.isNotEmpty)
                        Chip(label: Text('TAG: ${selectedProj.equipmentTag}')),
                      if (selectedProj.locationOrClient.isNotEmpty)
                        Chip(label: Text(selectedProj.locationOrClient)),
                      ActionChip(
                        avatar: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Editar projeto'),
                        onPressed: () =>
                            _openProjectDialog(existing: selectedProj),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Excluir projeto'),
                        onPressed: _deleteSelectedProject,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Buscar no histórico',
                    hintText: 'Título, medidas, fonte técnica ou observações...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              _refresh();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (_) => _refresh(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos os tipos'),
                      selected: _selectedType == null,
                      onSelected: (_) {
                        setState(() => _selectedType = null);
                        _refresh();
                      },
                    ),
                    for (final type in HistoryRecordType.values)
                      ChoiceChip(
                        label: Text(type.label),
                        selected: _selectedType == type,
                        onSelected: (_) {
                          setState(() => _selectedType = type);
                          _refresh();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openRecordDialog(),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Novo registro técnico'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed:
                          _exportingPdf ? null : () => _exportReport(share: false),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _exportingPdf
                            ? 'Gerando PDF...'
                            : 'Exportar relatório PDF',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _exportingPdf ? null : () => _exportReport(share: true),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartilhar PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _statusMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_records.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Nenhum registro encontrado no histórico SQLite. Crie um projeto ou adicione um novo registro técnico.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else ...[
          Text(
            'Registros salvos (${_records.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final rec in _records) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rec.recordType.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rec.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Editar registro',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openRecordDialog(existing: rec),
                        ),
                        IconButton(
                          tooltip: 'Excluir registro',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteRecord(rec),
                        ),
                      ],
                    ),
                    if (rec.measurementsText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Medidas: ${rec.measurementsText}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (rec.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(rec.summary, style: theme.textTheme.bodySmall),
                    ],
                    if (rec.technicalSource.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Fonte técnica: ${rec.technicalSource}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    if (rec.uncertaintyOrNote.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Incerteza / obs.: ${rec.uncertaintyOrNote}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (rec.photoPath != null &&
                        rec.photoPath!.isNotEmpty &&
                        File(rec.photoPath!).existsSync()) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(rec.photoPath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}
