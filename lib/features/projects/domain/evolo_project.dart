import 'capture_entry.dart';

class EvoloProject {
  const EvoloProject({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.coverImagePath,
    this.captures = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? coverImagePath;
  final List<CaptureEntry> captures;

  CaptureEntry? get latestCapture => captures.isEmpty ? null : captures.last;
  bool get hasReplay => captures.length > 1;

  EvoloProject copyWith({
    String? name,
    DateTime? updatedAt,
    String? coverImagePath,
    List<CaptureEntry>? captures,
  }) {
    return EvoloProject(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      captures: captures ?? this.captures,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'coverImagePath': coverImagePath,
      'captures': captures.map((entry) => entry.toJson()).toList(),
    };
  }

  factory EvoloProject.fromJson(Map<String, Object?> json) {
    final capturesJson = json['captures'] as List<Object?>? ?? [];

    return EvoloProject(
      id: json['id']! as String,
      name: json['name']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      coverImagePath: json['coverImagePath'] as String?,
      captures: capturesJson
          .cast<Map<String, Object?>>()
          .map(CaptureEntry.fromJson)
          .toList(),
    );
  }
}
