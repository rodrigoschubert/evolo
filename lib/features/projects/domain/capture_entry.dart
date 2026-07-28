class CaptureEntry {
  const CaptureEntry({
    required this.id,
    required this.projectId,
    required this.imagePath,
    required this.createdAt,
    this.note,
    this.source,
    this.sortOrder,
  });

  final String id;
  final String projectId;
  final String imagePath;
  final DateTime createdAt;
  final String? note;

  /// Origin of this capture: 'camera', 'import', or null (legacy = camera).
  final String? source;

  /// Manual sort position within the project timeline (lower = earlier).
  final int? sortOrder;

  CaptureEntry copyWith({
    String? id,
    String? projectId,
    String? imagePath,
    DateTime? createdAt,
    String? note,
    String? source,
    int? sortOrder,
  }) {
    return CaptureEntry(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      source: source ?? this.source,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
      'source': source,
      'sortOrder': sortOrder,
    };
  }

  factory CaptureEntry.fromJson(Map<String, Object?> json) {
    return CaptureEntry(
      id: json['id']! as String,
      projectId: json['projectId']! as String,
      imagePath: json['imagePath']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      note: json['note'] as String?,
      source: json['source'] as String?,
      sortOrder: json['sortOrder'] as int?,
    );
  }
}
