import 'package:hive/hive.dart';
import 'pet_media_asset.dart';

/// Pet profile model storing basic information about the pet.
@HiveType(typeId: 1)
class PetProfile extends HiveObject {
  @HiveField(0)
  String petId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String species;

  @HiveField(3)
  String breed;

  @HiveField(4)
  DateTime birthDate;

  @HiveField(5)
  double currentWeight;

  @HiveField(6)
  double targetWeight;

  @HiveField(7)
  String avatarPath;

  @HiveField(8)
  String gender;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  DateTime updatedAt;

  @HiveField(11)
  List<PetMediaAsset> albumEntries;

  @HiveField(12)
  List<PetMediaAsset> studioAssets;

  PetProfile({
    required this.petId,
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.currentWeight,
    required this.targetWeight,
    this.avatarPath = '',
    required this.gender,
    required this.createdAt,
    required this.updatedAt,
    this.albumEntries = const <PetMediaAsset>[],
    this.studioAssets = const <PetMediaAsset>[],
  });

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile(
      petId: json['petId'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
      currentWeight: (json['currentWeight'] as num).toDouble(),
      targetWeight: (json['targetWeight'] as num).toDouble(),
      avatarPath: json['avatarPath'] as String? ?? '',
      gender: json['gender'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      albumEntries: const <PetMediaAsset>[],
      studioAssets: const <PetMediaAsset>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'petId': petId,
      'name': name,
      'species': species,
      'breed': breed,
      'birthDate': birthDate.toIso8601String(),
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'avatarPath': avatarPath,
      'gender': gender,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  PetProfile copyWith({
    String? petId,
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    double? currentWeight,
    double? targetWeight,
    String? avatarPath,
    String? gender,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PetMediaAsset>? albumEntries,
    List<PetMediaAsset>? studioAssets,
  }) {
    return PetProfile(
      petId: petId ?? this.petId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      avatarPath: avatarPath ?? this.avatarPath,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      albumEntries: albumEntries ?? this.albumEntries,
      studioAssets: studioAssets ?? this.studioAssets,
    );
  }
}

/// Hive adapter for PetProfile.
class PetProfileAdapter extends TypeAdapter<PetProfile> {
  @override
  final int typeId = 1;

  @override
  PetProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PetProfile(
      petId: fields[0] as String,
      name: fields[1] as String,
      species: fields[2] as String,
      breed: fields[3] as String,
      birthDate: fields[4] as DateTime,
      currentWeight: fields[5] as double,
      targetWeight: fields[6] as double,
      avatarPath: fields[7] as String? ?? '',
      gender: fields[8] as String,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
      albumEntries: (fields[11] as List?)?.cast<PetMediaAsset>() ?? const <PetMediaAsset>[],
      studioAssets: (fields[12] as List?)?.cast<PetMediaAsset>() ?? const <PetMediaAsset>[],
    );
  }

  @override
  void write(BinaryWriter writer, PetProfile obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.petId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.species)
      ..writeByte(3)
      ..write(obj.breed)
      ..writeByte(4)
      ..write(obj.birthDate)
      ..writeByte(5)
      ..write(obj.currentWeight)
      ..writeByte(6)
      ..write(obj.targetWeight)
      ..writeByte(7)
      ..write(obj.avatarPath)
      ..writeByte(8)
      ..write(obj.gender)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt)
      ..writeByte(11)
      ..write(obj.albumEntries)
      ..writeByte(12)
      ..write(obj.studioAssets);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
