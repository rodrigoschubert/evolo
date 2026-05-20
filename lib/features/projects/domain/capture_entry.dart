class CaptureEntry {
  const CaptureEntry({
    required this.id,
    required this.projectId,
    required this.imagePath,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String projectId;
  final String imagePath;
  final DateTime createdAt;
  final String? note;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  factory CaptureEntry.fromJson(Map<String, Object?> json) {
    return CaptureEntry(
      id: json['id']! as String,
      projectId: json['projectId']! as String,
      imagePath: json['imagePath']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      note: json['note'] as String?,
    );
  }
}
