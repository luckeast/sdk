import 'package:hive/hive.dart';

/// Meal analysis model storing AI analysis results for pet meals.
@HiveType(typeId: 3)
class MealAnalysis extends HiveObject {
  @HiveField(0)
  String analysisId;

  @HiveField(1)
  String petId;

  @HiveField(2)
  String photoPath;

  @HiveField(3)
  String foodType;

  @HiveField(4)
  String portionSize;

  @HiveField(5)
  int nutritionScore;

  @HiveField(6)
  int estimatedCalories;

  @HiveField(7)
  double proteinPercent;

  @HiveField(8)
  double carbsPercent;

  @HiveField(9)
  double fatPercent;

  @HiveField(10)
  String feedingAdvice;

  @HiveField(11)
  DateTime analyzedAt;

  MealAnalysis({
    required this.analysisId,
    required this.petId,
    required this.photoPath,
    required this.foodType,
    required this.portionSize,
    required this.nutritionScore,
    required this.estimatedCalories,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
    required this.feedingAdvice,
    required this.analyzedAt,
  });

  factory MealAnalysis.fromJson(Map<String, dynamic> json) {
    return MealAnalysis(
      analysisId: json['analysisId'] as String,
      petId: json['petId'] as String,
      photoPath: json['photoPath'] as String,
      foodType: json['foodType'] as String,
      portionSize: json['portionSize'] as String,
      nutritionScore: json['nutritionScore'] as int,
      estimatedCalories: json['estimatedCalories'] as int,
      proteinPercent: (json['proteinPercent'] as num).toDouble(),
      carbsPercent: (json['carbsPercent'] as num).toDouble(),
      fatPercent: (json['fatPercent'] as num).toDouble(),
      feedingAdvice: json['feedingAdvice'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'analysisId': analysisId,
      'petId': petId,
      'photoPath': photoPath,
      'foodType': foodType,
      'portionSize': portionSize,
      'nutritionScore': nutritionScore,
      'estimatedCalories': estimatedCalories,
      'proteinPercent': proteinPercent,
      'carbsPercent': carbsPercent,
      'fatPercent': fatPercent,
      'feedingAdvice': feedingAdvice,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }

  MealAnalysis copyWith({
    String? analysisId,
    String? petId,
    String? photoPath,
    String? foodType,
    String? portionSize,
    int? nutritionScore,
    int? estimatedCalories,
    double? proteinPercent,
    double? carbsPercent,
    double? fatPercent,
    String? feedingAdvice,
    DateTime? analyzedAt,
  }) {
    return MealAnalysis(
      analysisId: analysisId ?? this.analysisId,
      petId: petId ?? this.petId,
      photoPath: photoPath ?? this.photoPath,
      foodType: foodType ?? this.foodType,
      portionSize: portionSize ?? this.portionSize,
      nutritionScore: nutritionScore ?? this.nutritionScore,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      proteinPercent: proteinPercent ?? this.proteinPercent,
      carbsPercent: carbsPercent ?? this.carbsPercent,
      fatPercent: fatPercent ?? this.fatPercent,
      feedingAdvice: feedingAdvice ?? this.feedingAdvice,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }
}

/// Hive adapter for MealAnalysis.
class MealAnalysisAdapter extends TypeAdapter<MealAnalysis> {
  @override
  final int typeId = 3;

  @override
  MealAnalysis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealAnalysis(
      analysisId: fields[0] as String,
      petId: fields[1] as String,
      photoPath: fields[2] as String,
      foodType: fields[3] as String,
      portionSize: fields[4] as String,
      nutritionScore: fields[5] as int,
      estimatedCalories: fields[6] as int,
      proteinPercent: fields[7] as double,
      carbsPercent: fields[8] as double,
      fatPercent: fields[9] as double,
      feedingAdvice: fields[10] as String,
      analyzedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MealAnalysis obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.analysisId)
      ..writeByte(1)
      ..write(obj.petId)
      ..writeByte(2)
      ..write(obj.photoPath)
      ..writeByte(3)
      ..write(obj.foodType)
      ..writeByte(4)
      ..write(obj.portionSize)
      ..writeByte(5)
      ..write(obj.nutritionScore)
      ..writeByte(6)
      ..write(obj.estimatedCalories)
      ..writeByte(7)
      ..write(obj.proteinPercent)
      ..writeByte(8)
      ..write(obj.carbsPercent)
      ..writeByte(9)
      ..write(obj.fatPercent)
      ..writeByte(10)
      ..write(obj.feedingAdvice)
      ..writeByte(11)
      ..write(obj.analyzedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealAnalysisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
