import 'package:hive/hive.dart';

/// AI chat record model storing vet assistant Q&A history.
@HiveType(typeId: 6)
class AiChatRecord extends HiveObject {
  @HiveField(0)
  String chatId;

  @HiveField(1)
  String petId;

  @HiveField(2)
  String question;

  @HiveField(3)
  String answer;

  @HiveField(4)
  bool isBookmarked;

  @HiveField(5)
  DateTime createdAt;

  AiChatRecord({
    required this.chatId,
    required this.petId,
    required this.question,
    required this.answer,
    this.isBookmarked = false,
    required this.createdAt,
  });

  factory AiChatRecord.fromJson(Map<String, dynamic> json) {
    return AiChatRecord(
      chatId: json['chatId'] as String,
      petId: json['petId'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'petId': petId,
      'question': question,
      'answer': answer,
      'isBookmarked': isBookmarked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AiChatRecord copyWith({
    String? chatId,
    String? petId,
    String? question,
    String? answer,
    bool? isBookmarked,
    DateTime? createdAt,
  }) {
    return AiChatRecord(
      chatId: chatId ?? this.chatId,
      petId: petId ?? this.petId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Hive adapter for AiChatRecord.
class AiChatRecordAdapter extends TypeAdapter<AiChatRecord> {
  @override
  final int typeId = 6;

  @override
  AiChatRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AiChatRecord(
      chatId: fields[0] as String,
      petId: fields[1] as String,
      question: fields[2] as String,
      answer: fields[3] as String,
      isBookmarked: fields[4] as bool? ?? false,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AiChatRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.chatId)
      ..writeByte(1)
      ..write(obj.petId)
      ..writeByte(2)
      ..write(obj.question)
      ..writeByte(3)
      ..write(obj.answer)
      ..writeByte(4)
      ..write(obj.isBookmarked)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiChatRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
