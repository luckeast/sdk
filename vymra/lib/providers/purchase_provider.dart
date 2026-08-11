import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/purchase_record.dart';
import '../repositories/purchase_record_repository.dart';
import '../services/iap_service.dart';

/// Provider for managing purchase and balance state.
class PurchaseProvider extends ChangeNotifier {
  final PurchaseRecordRepository _repository;
  final IapService _iapService;
  StreamSubscription? _purchaseResultSub;
  Future<void>? _initializationFuture;
  int _balance = 0;
  List<PurchaseRecord> _records = [];
  bool _isLoading = false;
  bool _isPurchasing = false;
  bool _isInitialized = false;
  String? _error;

  PurchaseProvider(this._repository, this._iapService);

  int get balance => _balance;
  List<PurchaseRecord> get records => List.unmodifiable(_records);
  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  bool get isStoreAvailable => _iapService.isAvailable;
  bool get isVerificationConfigured => _iapService.isConfiguredForProduction;
  String? get error => _error;

  /// Local product catalog. Falls back to local prices when App Store prices
  /// are not yet loaded.
  Map<String, Map<String, dynamic>> get localProducts {
    return {
      for (final id in IapService.productIds)
        id: {
          'id': id,
          'price': _effectivePrice(id),
          'priceLabel': _iapService.getProductPrice(id),
          'coins': IapService.coinRewards[id] ?? 100,
          'isPromotional': _isPromotional(id),
        },
    };
  }

  double _effectivePrice(String productId) {
    return IapService.localPrices[productId] ?? 0.99;
  }

  bool _isPromotional(String productId) {
    return ['vymra_29.99', 'vymra_59.99', 'vymra_99.99'].contains(productId);
  }

  Future<void> _ensureInitialized() {
    return initialize();
  }

  /// Initialize IAP and listen for purchase results.
  Future<void> initialize() {
    if (_isInitialized) {
      return Future.wait<void>([loadBalance(), loadRecords()]).then((_) {});
    }

    return _initializationFuture ??= _initialize().whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    _purchaseResultSub = _iapService.purchaseResultStream.listen((result) {
      if (result.success) {
        _isPurchasing = false;
        loadBalance();
        loadRecords();
        notifyListeners();
      } else {
        _error = result.errorMessage ?? AppStrings.tr('Purchase failed');
        _isPurchasing = false;
        notifyListeners();
      }
    });

    await _iapService.initialize();
    await loadBalance();
    await loadRecords();
    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> loadBalance() async {
    try {
      _balance = await _repository.getBalance();
    } catch (e) {
      _balance = 0;
      _error = AppStrings.tr('Failed to load balance');
    }
    notifyListeners();
  }

  Future<void> loadRecords() async {
    try {
      _records = await _repository.getAllRecords();
    } catch (e) {
      _records = [];
      _error = AppStrings.tr('Failed to load purchase records');
    }
    notifyListeners();
  }

  void reset() {
    _balance = 0;
    _records = [];
    _error = null;
    notifyListeners();
  }

  /// Initiate a real in-app purchase.
  Future<bool> purchaseProduct(
    String productId, {
    String? applicationUserName,
  }) async {
    await _ensureInitialized();
    _isPurchasing = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _iapService.purchaseProduct(
        productId,
        applicationUserName: applicationUserName,
      );
      if (!success) {
        _isPurchasing = false;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      _isPurchasing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await _ensureInitialized();
    _isPurchasing = true;
    _error = null;
    notifyListeners();

    try {
      await _iapService.restorePurchases();
    } catch (e) {
      _error = e.toString();
      _isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> spendCoins(int amount) async {
    try {
      await _repository.spendCoins(amount);
      await loadBalance();
    } catch (e) {
      _error = AppStrings.tr('Failed to spend coins');
      notifyListeners();
    }
  }

  Future<void> addCoins(int amount) async {
    try {
      await _repository.addCoins(amount);
      await loadBalance();
    } catch (e) {
      _error = AppStrings.tr('Failed to add coins');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _purchaseResultSub?.cancel();
    super.dispose();
  }
}
