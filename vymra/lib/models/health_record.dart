import 'package:hive/hive.dart';

/// Health record model for tracking various pet health metrics.
@HiveType(typeId: 2)
class HealthRecord extends HiveObject {
  @HiveField(0)
  String recordId;

  @HiveField(1)
  String petId;

  @HiveField(2)
  String recordType;

  @HiveField(3)
  double value;

  @HiveField(4)
  String unit;

  @HiveField(5)
  String note;

  @HiveField(6)
  String photoPath;

  @HiveField(7)
  DateTime recordedAt;

  HealthRecord({
    required this.recordId,
    required this.petId,
    required this.recordType,
    required this.value,
    required this.unit,
    this.note = '',
    this.photoPath = '',
    required this.recordedAt,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      recordId: json['recordId'] as String,
      petId: json['petId'] as String,
      recordType: json['recordType'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      note: json['note'] as String? ?? '',
      photoPath: json['photoPath'] as String? ?? '',
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recordId': recordId,
      'petId': petId,
      'recordType': recordType,
      'value': value,
      'unit': unit,
      'note': note,
      'photoPath': photoPath,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  HealthRecord copyWith({
    String? recordId,
    String? petId,
    String? recordType,
    double? value,
    String? unit,
    String? note,
    String? photoPath,
    DateTime? recordedAt,
  }) {
    return HealthRecord(
      recordId: recordId ?? this.recordId,
      petId: petId ?? this.petId,
      recordType: recordType ?? this.recordType,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      photoPath: photoPath ?? this.photoPath,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }
}

/// Hive adapter for HealthRecord.
class HealthRecordAdapter extends TypeAdapter<HealthRecord> {
  @override
  final int typeId = 2;

  @override
  HealthRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HealthRecord(
      recordId: fields[0] as String,
      petId: fields[1] as String,
      recordType: fields[2] as String,
      value: fields[3] as double,
      unit: fields[4] as String,
      note: fields[5] as String? ?? '',
      photoPath: fields[6] as String? ?? '',
      recordedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, HealthRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.recordId)
      ..writeByte(1)
      ..write(obj.petId)
      ..writeByte(2)
      ..write(obj.recordType)
      ..writeByte(3)
      ..write(obj.value)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.photoPath)
      ..writeByte(7)
      ..write(obj.recordedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
