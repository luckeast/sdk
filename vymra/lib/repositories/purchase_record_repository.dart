import 'package:hive/hive.dart';
import '../models/purchase_record.dart';

/// Repository interface for purchase record and balance operations.
abstract class PurchaseRecordRepository {
  Future<List<PurchaseRecord>> getAllRecords();
  Future<PurchaseRecord?> getRecord(String recordId);
  Future<void> saveRecord(PurchaseRecord record);
  Future<void> deleteRecord(String recordId);
  Future<PurchaseRecord?> findByTransactionId(String transactionId);
  Future<int> getBalance();
  Future<void> setBalance(int balance);
  Future<void> addCoins(int amount);
  Future<void> spendCoins(int amount);
}

/// Hive implementation of PurchaseRecordRepository.
class HivePurchaseRecordRepository implements PurchaseRecordRepository {
  static const String _boxName = 'purchase_records';
  static const String _balanceKey = 'vymra_pawcoins_balance';
  Box<PurchaseRecord>? _box;

  Future<Box<PurchaseRecord>> get _boxInstance async {
    if (_box != null && !_box!.isOpen) {
      _box = null;
    }
    _box ??= await Hive.openBox<PurchaseRecord>(_boxName);
    return _box!;
  }

  @override
  Future<List<PurchaseRecord>> getAllRecords() async {
    final box = await _boxInstance;
    return box.values.toList()
      ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
  }

  @override
  Future<PurchaseRecord?> getRecord(String recordId) async {
    final box = await _boxInstance;
    return box.get(recordId);
  }

  @override
  Future<void> saveRecord(PurchaseRecord record) async {
    final box = await _boxInstance;
    await box.put(record.recordId, record);
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    final box = await _boxInstance;
    await box.delete(recordId);
  }

  @override
  Future<PurchaseRecord?> findByTransactionId(String transactionId) async {
    final box = await _boxInstance;
    for (final record in box.values) {
      if (record.transactionId == transactionId) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<int> getBalance() async {
    final box = await _boxInstance;
    final record = box.get(_balanceKey);
    return record?.coinsAwarded ?? 0;
  }

  @override
  Future<void> setBalance(int balance) async {
    final box = await _boxInstance;
    // Store balance as a special PurchaseRecord with empty productId
    await box.put(
      _balanceKey,
      PurchaseRecord(
        recordId: _balanceKey,
        productId: 'balance',
        price: 0,
        coinsAwarded: balance,
        purchasedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> addCoins(int amount) async {
    final current = await getBalance();
    await setBalance(current + amount);
  }

  @override
  Future<void> spendCoins(int amount) async {
    final current = await getBalance();
    final newBalance = (current - amount).clamp(0, current);
    await setBalance(newBalance);
  }
}
