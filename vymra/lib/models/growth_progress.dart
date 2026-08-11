import 'package:hive/hive.dart';

/// Growth progress model for gamified pet growth journey.
@HiveType(typeId: 4)
class GrowthProgress extends HiveObject {
  @HiveField(0)
  String progressId;

  @HiveField(1)
  String petId;

  @HiveField(2)
  int currentLevel;

  @HiveField(3)
  int currentExperience;

  @HiveField(4)
  int totalExperienceEarned;

  @HiveField(5)
  List<String> milestones;

  @HiveField(6)
  int streakDays;

  @HiveField(7)
  DateTime? lastActivityDate;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  List<String> processedPenaltyKeys;

  GrowthProgress({
    required this.progressId,
    required this.petId,
    this.currentLevel = 1,
    this.currentExperience = 0,
    this.totalExperienceEarned = 0,
    List<String>? milestones,
    this.streakDays = 0,
    this.lastActivityDate,
    required this.updatedAt,
    List<String>? processedPenaltyKeys,
  }) : milestones = milestones ?? [],
       processedPenaltyKeys = processedPenaltyKeys ?? [];

  factory GrowthProgress.fromJson(Map<String, dynamic> json) {
    return GrowthProgress(
      progressId: json['progressId'] as String,
      petId: json['petId'] as String,
      currentLevel: json['currentLevel'] as int? ?? 1,
      currentExperience: json['currentExperience'] as int? ?? 0,
      totalExperienceEarned: json['totalExperienceEarned'] as int? ?? 0,
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      streakDays: json['streakDays'] as int? ?? 0,
      lastActivityDate: json['lastActivityDate'] != null
          ? DateTime.parse(json['lastActivityDate'] as String)
          : null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      processedPenaltyKeys:
          (json['processedPenaltyKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'progressId': progressId,
      'petId': petId,
      'currentLevel': currentLevel,
      'currentExperience': currentExperience,
      'totalExperienceEarned': totalExperienceEarned,
      'milestones': milestones,
      'streakDays': streakDays,
      'lastActivityDate': lastActivityDate?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'processedPenaltyKeys': processedPenaltyKeys,
    };
  }

  /// Experience required for next level.
  int get experienceForNextLevel => currentLevel * 10;

  /// Progress percentage toward next level (0.0 - 1.0).
  double get levelProgress {
    final required = experienceForNextLevel;
    if (required == 0) return 1.0;
    return (currentExperience / required).clamp(0.0, 1.0);
  }

  GrowthProgress copyWith({
    String? progressId,
    String? petId,
    int? currentLevel,
    int? currentExperience,
    int? totalExperienceEarned,
    List<String>? milestones,
    int? streakDays,
    DateTime? lastActivityDate,
    DateTime? updatedAt,
    List<String>? processedPenaltyKeys,
  }) {
    return GrowthProgress(
      progressId: progressId ?? this.progressId,
      petId: petId ?? this.petId,
      currentLevel: currentLevel ?? this.currentLevel,
      currentExperience: currentExperience ?? this.currentExperience,
      totalExperienceEarned:
          totalExperienceEarned ?? this.totalExperienceEarned,
      milestones: milestones ?? List<String>.from(this.milestones),
      streakDays: streakDays ?? this.streakDays,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      updatedAt: updatedAt ?? this.updatedAt,
      processedPenaltyKeys:
          processedPenaltyKeys ?? List<String>.from(this.processedPenaltyKeys),
    );
  }
}

/// Hive adapter for GrowthProgress.
class GrowthProgressAdapter extends TypeAdapter<GrowthProgress> {
  @override
  final int typeId = 4;

  @override
  GrowthProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GrowthProgress(
      progressId: fields[0] as String,
      petId: fields[1] as String,
      currentLevel: fields[2] as int? ?? 1,
      currentExperience: fields[3] as int? ?? 0,
      totalExperienceEarned: fields[4] as int? ?? 0,
      milestones: (fields[5] as List?)?.cast<String>() ?? [],
      streakDays: fields[6] as int? ?? 0,
      lastActivityDate: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime,
      processedPenaltyKeys: (fields[9] as List?)?.cast<String>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, GrowthProgress obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.progressId)
      ..writeByte(1)
      ..write(obj.petId)
      ..writeByte(2)
      ..write(obj.currentLevel)
      ..writeByte(3)
      ..write(obj.currentExperience)
      ..writeByte(4)
      ..write(obj.totalExperienceEarned)
      ..writeByte(5)
      ..write(obj.milestones)
      ..writeByte(6)
      ..write(obj.streakDays)
      ..writeByte(7)
      ..write(obj.lastActivityDate)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.processedPenaltyKeys);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrowthProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
