enum HistoryRecordType {
  cameraMeasurement('Medição câmera / 3D'),
  materialId('Material'),
  fastener('Parafuso / rosca'),
  torque('Torque'),
  weightVolume('Peso / volume'),
  technicalDrawing('Desenho 2D/3D'),
  mechanicalComponent('Componente mecânico'),
  generalInspection('Inspeção geral');

  const HistoryRecordType(this.label);
  final String label;

  static HistoryRecordType fromName(String? value) {
    return HistoryRecordType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HistoryRecordType.generalInspection,
    );
  }
}

class MaintenanceProject {
  const MaintenanceProject({
    required this.id,
    required this.name,
    required this.equipmentTag,
    required this.locationOrClient,
    required this.notes,
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  final String id;
  final String name;
  final String equipmentTag;
  final String locationOrClient;
  final String notes;
  final String createdAtIso;
  final String updatedAtIso;

  MaintenanceProject copyWith({
    String? id,
    String? name,
    String? equipmentTag,
    String? locationOrClient,
    String? notes,
    String? createdAtIso,
    String? updatedAtIso,
  }) {
    return MaintenanceProject(
      id: id ?? this.id,
      name: name ?? this.name,
      equipmentTag: equipmentTag ?? this.equipmentTag,
      locationOrClient: locationOrClient ?? this.locationOrClient,
      notes: notes ?? this.notes,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'equipment_tag': equipmentTag,
      'location_or_client': locationOrClient,
      'notes': notes,
      'created_at_iso': createdAtIso,
      'updated_at_iso': updatedAtIso,
    };
  }

  factory MaintenanceProject.fromMap(Map<String, Object?> map) {
    return MaintenanceProject(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      equipmentTag: map['equipment_tag'] as String? ?? '',
      locationOrClient: map['location_or_client'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAtIso: map['created_at_iso'] as String? ?? '',
      updatedAtIso: map['updated_at_iso'] as String? ?? '',
    );
  }
}

class HistoryRecord {
  const HistoryRecord({
    required this.id,
    this.projectId,
    required this.recordType,
    required this.title,
    required this.summary,
    required this.measurementsText,
    required this.technicalSource,
    required this.uncertaintyOrNote,
    this.photoPath,
    required this.createdAtIso,
    required this.updatedAtIso,
  });

  final String id;
  final String? projectId;
  final HistoryRecordType recordType;
  final String title;
  final String summary;
  final String measurementsText;
  final String technicalSource;
  final String uncertaintyOrNote;
  final String? photoPath;
  final String createdAtIso;
  final String updatedAtIso;

  HistoryRecord copyWith({
    String? id,
    String? projectId,
    bool clearProjectId = false,
    HistoryRecordType? recordType,
    String? title,
    String? summary,
    String? measurementsText,
    String? technicalSource,
    String? uncertaintyOrNote,
    String? photoPath,
    bool clearPhotoPath = false,
    String? createdAtIso,
    String? updatedAtIso,
  }) {
    return HistoryRecord(
      id: id ?? this.id,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      recordType: recordType ?? this.recordType,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      measurementsText: measurementsText ?? this.measurementsText,
      technicalSource: technicalSource ?? this.technicalSource,
      uncertaintyOrNote: uncertaintyOrNote ?? this.uncertaintyOrNote,
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
      createdAtIso: createdAtIso ?? this.createdAtIso,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'record_type': recordType.name,
      'title': title,
      'summary': summary,
      'measurements_text': measurementsText,
      'technical_source': technicalSource,
      'uncertainty_or_note': uncertaintyOrNote,
      'photo_path': photoPath,
      'created_at_iso': createdAtIso,
      'updated_at_iso': updatedAtIso,
    };
  }

  factory HistoryRecord.fromMap(Map<String, Object?> map) {
    return HistoryRecord(
      id: map['id'] as String,
      projectId: map['project_id'] as String?,
      recordType: HistoryRecordType.fromName(map['record_type'] as String?),
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      measurementsText: map['measurements_text'] as String? ?? '',
      technicalSource: map['technical_source'] as String? ?? '',
      uncertaintyOrNote: map['uncertainty_or_note'] as String? ?? '',
      photoPath: map['photo_path'] as String?,
      createdAtIso: map['created_at_iso'] as String? ?? '',
      updatedAtIso: map['updated_at_iso'] as String? ?? '',
    );
  }
}
