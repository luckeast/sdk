import 'package:hive/hive.dart';

/// Vaccine and health reminder model for tracking scheduled pet care.
@HiveType(typeId: 5)
class VaccineReminder extends HiveObject {
  @HiveField(0)
  String reminderId;

  @HiveField(1)
  String petId;

  @HiveField(2)
  String reminderType;

  @HiveField(3)
  String name;

  @HiveField(4)
  DateTime? lastDate;

  @HiveField(5)
  DateTime? nextDate;

  @HiveField(6)
  int intervalDays;

  @HiveField(7)
  bool isActive;

  @HiveField(8)
  bool isCompleted;

  @HiveField(9)
  String notes;

  VaccineReminder({
    required this.reminderId,
    required this.petId,
    required this.reminderType,
    required this.name,
    this.lastDate,
    this.nextDate,
    required this.intervalDays,
    this.isActive = true,
    this.isCompleted = false,
    this.notes = '',
  });

  factory VaccineReminder.fromJson(Map<String, dynamic> json) {
    return VaccineReminder(
      reminderId: json['reminderId'] as String,
      petId: json['petId'] as String,
      reminderType: json['reminderType'] as String,
      name: json['name'] as String,
      lastDate: json['lastDate'] != null
          ? DateTime.parse(json['lastDate'] as String)
          : null,
      nextDate: json['nextDate'] != null
          ? DateTime.parse(json['nextDate'] as String)
          : null,
      intervalDays: json['intervalDays'] as int,
      isActive: json['isActive'] as bool? ?? true,
      isCompleted: json['isCompleted'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reminderId': reminderId,
      'petId': petId,
      'reminderType': reminderType,
      'name': name,
      'lastDate': lastDate?.toIso8601String(),
      'nextDate': nextDate?.toIso8601String(),
      'intervalDays': intervalDays,
      'isActive': isActive,
      'isCompleted': isCompleted,
      'notes': notes,
    };
  }

  /// Calculate next date based on last date and interval.
  DateTime? calculateNextDate() {
    if (lastDate == null) return null;
    return lastDate!.add(Duration(days: intervalDays));
  }

  /// Days until next reminder. Negative if overdue.
  int? get daysUntilNext {
    if (nextDate == null) return null;
    return nextDate!.difference(DateTime.now()).inDays;
  }

  bool get isOverdue {
    if (nextDate == null) return false;
    return nextDate!.isBefore(DateTime.now());
  }

  VaccineReminder copyWith({
    String? reminderId,
    String? petId,
    String? reminderType,
    String? name,
    DateTime? lastDate,
    DateTime? nextDate,
    int? intervalDays,
    bool? isActive,
    bool? isCompleted,
    String? notes,
  }) {
    return VaccineReminder(
      reminderId: reminderId ?? this.reminderId,
      petId: petId ?? this.petId,
      reminderType: reminderType ?? this.reminderType,
      name: name ?? this.name,
      lastDate: lastDate ?? this.lastDate,
      nextDate: nextDate ?? this.nextDate,
      intervalDays: intervalDays ?? this.intervalDays,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
    );
  }
}

/// Hive adapter for VaccineReminder.
class VaccineReminderAdapter extends TypeAdapter<VaccineReminder> {
  @override
  final int typeId = 5;

  @override
  VaccineReminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VaccineReminder(
      reminderId: fields[0] as String,
      petId: fields[1] as String,
      reminderType: fields[2] as String,
      name: fields[3] as String,
      lastDate: fields[4] as DateTime?,
      nextDate: fields[5] as DateTime?,
      intervalDays: fields[6] as int,
      isActive: fields[7] as bool? ?? true,
      isCompleted: fields[8] as bool? ?? false,
      notes: fields[9] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, VaccineReminder obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.reminderId)
      ..writeByte(1)
      ..write(obj.petId)
      ..writeByte(2)
      ..write(obj.reminderType)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.lastDate)
      ..writeByte(5)
      ..write(obj.nextDate)
      ..writeByte(6)
      ..write(obj.intervalDays)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.isCompleted)
      ..writeByte(9)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaccineReminderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
