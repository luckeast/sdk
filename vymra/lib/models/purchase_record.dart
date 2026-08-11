import 'package:hive/hive.dart';

/// Purchase record model for IAP transactions.
@HiveType(typeId: 8)
class PurchaseRecord extends HiveObject {
  @HiveField(0)
  String recordId;

  @HiveField(1)
  String productId;

  @HiveField(2)
  double price;

  @HiveField(3)
  int coinsAwarded;

  @HiveField(4)
  DateTime purchasedAt;

  @HiveField(5)
  String status;

  @HiveField(6)
  bool isPromotional;

  @HiveField(7)
  String? transactionId;

  @HiveField(8)
  String deliveryStatus;

  @HiveField(9)
  String verificationStatus;

  @HiveField(10)
  DateTime? verifiedAt;

  @HiveField(11)
  String? originalTransactionId;

  @HiveField(12)
  String environment;

  PurchaseRecord({
    required this.recordId,
    required this.productId,
    required this.price,
    required this.coinsAwarded,
    required this.purchasedAt,
    this.status = 'completed',
    this.isPromotional = false,
    this.transactionId,
    this.deliveryStatus = 'local_only',
    this.verificationStatus = 'unverified',
    this.verifiedAt,
    this.originalTransactionId,
    this.environment = 'local',
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      recordId: json['recordId'] as String,
      productId: json['productId'] as String,
      price: (json['price'] as num).toDouble(),
      coinsAwarded: json['coinsAwarded'] as int,
      purchasedAt: DateTime.parse(json['purchasedAt'] as String),
      status: json['status'] as String? ?? 'completed',
      isPromotional: json['isPromotional'] as bool? ?? false,
      transactionId: json['transactionId'] as String?,
      deliveryStatus: json['deliveryStatus'] as String? ?? 'local_only',
      verificationStatus: json['verificationStatus'] as String? ?? 'unverified',
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'] as String)
          : null,
      originalTransactionId: json['originalTransactionId'] as String?,
      environment: json['environment'] as String? ?? 'local',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recordId': recordId,
      'productId': productId,
      'price': price,
      'coinsAwarded': coinsAwarded,
      'purchasedAt': purchasedAt.toIso8601String(),
      'status': status,
      'isPromotional': isPromotional,
      'transactionId': transactionId,
      'deliveryStatus': deliveryStatus,
      'verificationStatus': verificationStatus,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'originalTransactionId': originalTransactionId,
      'environment': environment,
    };
  }

  PurchaseRecord copyWith({
    String? recordId,
    String? productId,
    double? price,
    int? coinsAwarded,
    DateTime? purchasedAt,
    String? status,
    bool? isPromotional,
    String? transactionId,
    String? deliveryStatus,
    String? verificationStatus,
    DateTime? verifiedAt,
    String? originalTransactionId,
    String? environment,
  }) {
    return PurchaseRecord(
      recordId: recordId ?? this.recordId,
      productId: productId ?? this.productId,
      price: price ?? this.price,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      status: status ?? this.status,
      isPromotional: isPromotional ?? this.isPromotional,
      transactionId: transactionId ?? this.transactionId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      originalTransactionId:
          originalTransactionId ?? this.originalTransactionId,
      environment: environment ?? this.environment,
    );
  }
}

/// Hive adapter for PurchaseRecord.
class PurchaseRecordAdapter extends TypeAdapter<PurchaseRecord> {
  @override
  final int typeId = 8;

  @override
  PurchaseRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseRecord(
      recordId: fields[0] as String,
      productId: fields[1] as String,
      price: fields[2] as double,
      coinsAwarded: fields[3] as int,
      purchasedAt: fields[4] as DateTime,
      status: fields[5] as String? ?? 'completed',
      isPromotional: fields[6] as bool? ?? false,
      transactionId: fields[7] as String?,
      deliveryStatus: fields[8] as String? ?? 'local_only',
      verificationStatus: fields[9] as String? ?? 'unverified',
      verifiedAt: fields[10] as DateTime?,
      originalTransactionId: fields[11] as String?,
      environment: fields[12] as String? ?? 'local',
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.recordId)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.coinsAwarded)
      ..writeByte(4)
      ..write(obj.purchasedAt)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.isPromotional)
      ..writeByte(7)
      ..write(obj.transactionId)
      ..writeByte(8)
      ..write(obj.deliveryStatus)
      ..writeByte(9)
      ..write(obj.verificationStatus)
      ..writeByte(10)
      ..write(obj.verifiedAt)
      ..writeByte(11)
      ..write(obj.originalTransactionId)
      ..writeByte(12)
      ..write(obj.environment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
