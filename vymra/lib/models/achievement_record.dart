/// Unlocked achievement earned by the user's pet journey.
class AchievementRecord {
  final String achievementId;
  final String petId;
  final String code;
  final String title;
  final String description;
  final String iconKey;
  final DateTime unlockedAt;
  final String imagePath;
  final String detail;

  const AchievementRecord({
    required this.achievementId,
    required this.petId,
    required this.code,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.unlockedAt,
    this.imagePath = '',
    this.detail = '',
  });

  factory AchievementRecord.fromJson(Map<String, dynamic> json) {
    return AchievementRecord(
      achievementId: json['achievementId'] as String,
      petId: json['petId'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      iconKey: json['iconKey'] as String,
      unlockedAt: DateTime.parse(json['unlockedAt'] as String),
      imagePath: json['imagePath'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'achievementId': achievementId,
      'petId': petId,
      'code': code,
      'title': title,
      'description': description,
      'iconKey': iconKey,
      'unlockedAt': unlockedAt.toIso8601String(),
      'imagePath': imagePath,
      'detail': detail,
    };
  }

  AchievementRecord copyWith({
    String? achievementId,
    String? petId,
    String? code,
    String? title,
    String? description,
    String? iconKey,
    DateTime? unlockedAt,
    String? imagePath,
    String? detail,
  }) {
    return AchievementRecord(
      achievementId: achievementId ?? this.achievementId,
      petId: petId ?? this.petId,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      imagePath: imagePath ?? this.imagePath,
      detail: detail ?? this.detail,
    );
  }
}
