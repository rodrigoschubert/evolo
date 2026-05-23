class EvoloProfile {
  final String id;
  final bool isPremium;
  final String? premiumSource;
  final DateTime? premiumSince;
  final DateTime createdAt;
  final DateTime updatedAt;

  EvoloProfile({
    required this.id,
    required this.isPremium,
    this.premiumSource,
    this.premiumSince,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EvoloProfile.fromJson(Map<String, dynamic> json) {
    return EvoloProfile(
      id: json['id'] as String,
      isPremium: json['is_premium'] as bool? ?? false,
      premiumSource: json['premium_source'] as String?,
      premiumSince: json['premium_since'] != null
          ? DateTime.parse(json['premium_since'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_premium': isPremium,
      'premium_source': premiumSource,
      'premium_since': premiumSince?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EvoloProfile copyWith({
    String? id,
    bool? isPremium,
    String? premiumSource,
    DateTime? premiumSince,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EvoloProfile(
      id: id ?? this.id,
      isPremium: isPremium ?? this.isPremium,
      premiumSource: premiumSource ?? this.premiumSource,
      premiumSince: premiumSince ?? this.premiumSince,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
