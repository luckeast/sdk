import 'package:hive/hive.dart';

/// Persisted media entry used by the pet album and AI Time material library.
@HiveType(typeId: 9)
class PetMediaAsset {
  @HiveField(0)
  String assetId;

  @HiveField(1)
  String relativePath;

  @HiveField(2)
  String source;

  @HiveField(3)
  String title;

  @HiveField(4)
  String keywords;

  @HiveField(5)
  DateTime createdAt;

  PetMediaAsset({
    required this.assetId,
    required this.relativePath,
    required this.source,
    required this.title,
    this.keywords = '',
    required this.createdAt,
  });

  PetMediaAsset copyWith({
    String? assetId,
    String? relativePath,
    String? source,
    String? title,
    String? keywords,
    DateTime? createdAt,
  }) {
    return PetMediaAsset(
      assetId: assetId ?? this.assetId,
      relativePath: relativePath ?? this.relativePath,
      source: source ?? this.source,
      title: title ?? this.title,
      keywords: keywords ?? this.keywords,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Hive adapter for [PetMediaAsset].
class PetMediaAssetAdapter extends TypeAdapter<PetMediaAsset> {
  @override
  final int typeId = 9;

  @override
  PetMediaAsset read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return PetMediaAsset(
      assetId: fields[0] as String,
      relativePath: fields[1] as String,
      source: fields[2] as String,
      title: fields[3] as String,
      keywords: fields[4] as String? ?? '',
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PetMediaAsset obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.assetId)
      ..writeByte(1)
      ..write(obj.relativePath)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.keywords)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PetMediaAssetAdapter &&
            runtimeType == other.runtimeType &&
            typeId == other.typeId;
  }

  @override
  int get hashCode => typeId.hashCode;
}
