import 'package:hive/hive.dart';

/// User account model for authentication state.
@HiveType(typeId: 7)
class UserAccount extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String username;

  @HiveField(2)
  String loginToken;

  @HiveField(3)
  bool isLoggedIn;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime? lastLoginAt;

  @HiveField(6)
  int freeAiUses;

  @HiveField(7)
  String avatarPath;

  UserAccount({
    required this.userId,
    required this.username,
    this.loginToken = '',
    this.isLoggedIn = false,
    required this.createdAt,
    this.lastLoginAt,
    this.freeAiUses = 0,
    this.avatarPath = '',
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      userId: json['userId'] as String,
      username: json['username'] as String,
      loginToken: json['loginToken'] as String? ?? '',
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      freeAiUses: json['freeAiUses'] as int? ?? 0,
      avatarPath: json['avatarPath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'loginToken': loginToken,
      'isLoggedIn': isLoggedIn,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'freeAiUses': freeAiUses,
      'avatarPath': avatarPath,
    };
  }

  UserAccount copyWith({
    String? userId,
    String? username,
    String? loginToken,
    bool? isLoggedIn,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    int? freeAiUses,
    String? avatarPath,
  }) {
    return UserAccount(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      loginToken: loginToken ?? this.loginToken,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      freeAiUses: freeAiUses ?? this.freeAiUses,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}

/// Hive adapter for UserAccount.
class UserAccountAdapter extends TypeAdapter<UserAccount> {
  @override
  final int typeId = 7;

  @override
  UserAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserAccount(
      userId: fields[0] as String,
      username: fields[1] as String,
      loginToken: fields[2] as String? ?? '',
      isLoggedIn: fields[3] as bool? ?? false,
      createdAt: fields[4] as DateTime,
      lastLoginAt: fields[5] as DateTime?,
      freeAiUses: fields[6] as int? ?? 0,
      avatarPath: fields[7] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, UserAccount obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.loginToken)
      ..writeByte(3)
      ..write(obj.isLoggedIn)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastLoginAt)
      ..writeByte(6)
      ..write(obj.freeAiUses)
      ..writeByte(7)
      ..write(obj.avatarPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
