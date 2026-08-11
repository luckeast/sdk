import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/purchase_record.dart';
import '../repositories/purchase_record_repository.dart';
import 'iap_account_service.dart';
import 'iap_verification_service.dart';

/// Result of an IAP purchase attempt.
class PurchaseResult {
  final bool success;
  final String productId;
  final String? errorMessage;
  final bool restored;

  PurchaseResult({
    required this.success,
    required this.productId,
    this.errorMessage,
    this.restored = false,
  });
}

/// Service for handling In-App Purchases on iOS.
/// Products are defined locally, but purchases go through the real Apple IAP flow.
class IapService {
  static const List<String> productIds = [
    'vymra_2.99',
    'vymra_4.99',
    'vymra_5.99',
    'vymra_6.99',
    'vymra_7.99',
    'vymra_9.99',
    'vymra_29.99',
    'vymra_59.99',
    'vymra_99.99',
  ];

  static const Map<String, int> coinRewards = {
    'vymra_2.99': 150,
    'vymra_4.99': 250,
    'vymra_5.99': 300,
    'vymra_6.99': 350,
    'vymra_7.99': 400,
    'vymra_9.99': 500,
    'vymra_29.99': 1500,
    'vymra_59.99': 3000,
    'vymra_99.99': 5000,
  };

  static const Map<String, double> localPrices = {
    'vymra_2.99': 2.99,
    'vymra_4.99': 4.99,
    'vymra_5.99': 5.99,
    'vymra_6.99': 6.99,
    'vymra_7.99': 7.99,
    'vymra_9.99': 9.99,
    'vymra_29.99': 29.99,
    'vymra_59.99': 59.99,
    'vymra_99.99': 99.99,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  final PurchaseRecordRepository _repository;
  final IapVerificationService _verificationService;
  final IapAccountService _accountService;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isPurchasing = false;
  bool _isInitialized = false;

  final _pendingCompleters = <String, Completer<bool>>{};
  final _purchaseResultController =
      StreamController<PurchaseResult>.broadcast();

  IapService(this._repository, this._verificationService, this._accountService);

  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;
  bool get isConfiguredForProduction => _verificationService.isConfigured;
  List<ProductDetails> get products => _products;

  /// Broadcast stream of purchase results.
  Stream<PurchaseResult> get purchaseResultStream =>
      _purchaseResultController.stream;

  /// Initialize IAP: check availability, set up purchase stream listener, query products.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('IAP not available on this device');
        return;
      }

      _subscription = _iap.purchaseStream.listen(
        _onPurchaseStream,
        onDone: () => _subscription?.cancel(),
        onError: (dynamic error) {
          debugPrint('IAP purchase stream error: $error');
        },
      );

      await queryProducts();
      _isInitialized = true;

      // Restore purchases on launch to surface any transactions that
      // were not finished in a previous session (e.g. app killed before
      // verification completed). These will arrive on the purchaseStream
      // and be re-processed.
      await restorePurchases();
    } catch (e) {
      debugPrint('IAP initialization error: $e');
      _isAvailable = false;
    }
  }

  /// Query available products from the App Store.
  Future<void> queryProducts() async {
    if (!_isAvailable) return;

    try {
      final response = await _iap.queryProductDetails(productIds.toSet());

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('Loaded ${_products.length} products from App Store');
    } catch (e) {
      debugPrint('Query products error: $e');
    }
  }

  Future<ProductDetails?> _getProductDetails(String productId) async {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }

    try {
      final response = await _iap.queryProductDetails({productId});
      if (response.error != null) {
        debugPrint(
          'Query product detail error for $productId: ${response.error}',
        );
      }
      if (response.productDetails.isEmpty) {
        if (response.notFoundIDs.isNotEmpty) {
          debugPrint('Product not found in App Store: ${response.notFoundIDs}');
        }
        return null;
      }

      final product = response.productDetails.first;
      final existingIndex = _products.indexWhere((p) => p.id == product.id);
      if (existingIndex >= 0) {
        _products[existingIndex] = product;
      } else {
        _products = [..._products, product];
      }
      return product;
    } catch (e) {
      debugPrint('Query product detail error for $productId: $e');
      return null;
    }
  }

  /// Initiate a real consumable purchase for the given product ID.
  /// Waits for the purchase stream callback to confirm success/failure.
  Future<bool> purchaseProduct(
    String productId, {
    String? applicationUserName,
  }) async {
    debugPrint('productId=$productId applicationUserName=$applicationUserName');
    if (_isPurchasing) {
      debugPrint('Purchase already in progress');
      return false;
    }
    if (!_isAvailable) {
      throw Exception('In-app purchases are not available on this device');
    }
    final product = await _getProductDetails(productId);
    if (product == null) {
      throw Exception('Product not found: $productId');
    }

    _isPurchasing = true;
    final completer = Completer<bool>();
    _pendingCompleters[productId] = completer;

    try {
      final accountToken =
          applicationUserName ??
          await _accountService.getOrCreateAccountToken();
      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: accountToken,
      );
      await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);

      // Wait for the purchase stream to deliver the result
      return await completer.future;
    } catch (e) {
      debugPrint('Purchase error: $e');
      _isPurchasing = false;
      _pendingCompleters.remove(productId);
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    }
  }

  /// Handle purchase stream events.
  void _onPurchaseStream(List<PurchaseDetails> detailsList) {
    for (final purchase in detailsList) {
      _processPurchase(purchase);
    }
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;

    switch (purchase.status) {
      case PurchaseStatus.pending:
        debugPrint('Purchase pending: $productId');
        break;

      case PurchaseStatus.purchased:
        debugPrint('Purchase completed: $productId');
        try {
          await _verifyAndDeliverPurchase(purchase, restored: false);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } catch (e) {
          debugPrint(
            'Purchase verification/delivery failed, keeping transaction pending: $e',
          );
        }
        break;

      case PurchaseStatus.restored:
        debugPrint('Purchase restored: $productId');
        try {
          await _verifyAndDeliverPurchase(purchase, restored: true);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } catch (e) {
          debugPrint(
            'Restored purchase verification/delivery failed, keeping transaction pending: $e',
          );
        }
        break;

      case PurchaseStatus.error:
        debugPrint('Purchase error: ${purchase.error?.message}');
        _resolvePending(productId, false);
        _purchaseResultController.add(
          PurchaseResult(
            success: false,
            productId: productId,
            errorMessage: purchase.error?.message ?? 'Purchase failed',
          ),
        );
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        break;

      case PurchaseStatus.canceled:
        debugPrint('Purchase canceled: $productId');
        _resolvePending(productId, false);
        _purchaseResultController.add(
          PurchaseResult(
            success: false,
            productId: productId,
            errorMessage: 'Purchase was canceled',
          ),
        );
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        break;
    }
  }

  void _resolvePending(String productId, bool success) {
    _isPurchasing = false;
    final completer = _pendingCompleters.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
  }

  Future<void> _verifyAndDeliverPurchase(
    PurchaseDetails purchase, {
    required bool restored,
  }) async {
    final productId = purchase.productID;

    if (!_verificationService.isConfigured) {
      await _deliverLocally(purchase, restored: restored);
      return;
    }

    try {
      final verified = await _verificationService.verifyPurchase(
        purchase: purchase,
      );

      final transactionId = verified.transactionId;
      final existing = transactionId.isEmpty
          ? null
          : await _repository.findByTransactionId(transactionId);

      var coins = 0;
      if (verified.shouldGrantCoins && !verified.alreadyDelivered) {
        final hasLocalDelivery = existing?.deliveryStatus == 'delivered';
        if (!hasLocalDelivery) {
          coins = coinRewards[productId] ?? 100;
          await _repository.addCoins(coins);
        }
      }

      final record = PurchaseRecord(
        recordId: transactionId.isNotEmpty
            ? transactionId
            : 'purchase_${DateTime.now().millisecondsSinceEpoch}',
        productId: productId,
        price: _resolveProductPrice(productId),
        coinsAwarded: coins,
        purchasedAt: DateTime.now(),
        status: restored ? 'restored' : 'completed',
        transactionId: transactionId,
        deliveryStatus: verified.alreadyDelivered
            ? 'already_delivered'
            : coins > 0
            ? 'delivered'
            : 'verified_no_delivery',
        verificationStatus: verified.verificationStatus,
        verifiedAt: verified.verifiedAt.toLocal(),
        originalTransactionId: verified.originalTransactionId,
        environment: verified.environment,
      );

      await _repository.saveRecord(record);
      _resolvePending(productId, true);
      _purchaseResultController.add(
        PurchaseResult(success: true, productId: productId, restored: restored),
      );
    } on IapVerificationException catch (e) {
      debugPrint('Purchase verification error: $e');
      _resolvePending(productId, false);
      _purchaseResultController.add(
        PurchaseResult(
          success: false,
          productId: productId,
          errorMessage: e.message,
          restored: restored,
        ),
      );
      rethrow;
    } catch (e) {
      debugPrint('Purchase delivery error: $e');
      _resolvePending(productId, false);
      _purchaseResultController.add(
        PurchaseResult(
          success: false,
          productId: productId,
          errorMessage: 'Unable to verify App Store purchase.',
          restored: restored,
        ),
      );
      rethrow;
    }
  }

  Future<void> _deliverLocally(
    PurchaseDetails purchase, {
    required bool restored,
  }) async {
    final productId = purchase.productID;
    final transactionId = purchase.purchaseID ?? '';
    final existing = transactionId.isEmpty
        ? null
        : await _repository.findByTransactionId(transactionId);

    var coins = 0;
    if (existing?.deliveryStatus != 'delivered') {
      coins = coinRewards[productId] ?? 100;
      await _repository.addCoins(coins);
    }

    final record = PurchaseRecord(
      recordId: transactionId.isNotEmpty
          ? transactionId
          : 'purchase_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      price: _resolveProductPrice(productId),
      coinsAwarded: coins,
      purchasedAt: DateTime.now(),
      status: restored ? 'restored' : 'completed',
      transactionId: purchase.purchaseID,
      deliveryStatus: coins > 0 ? 'delivered' : 'already_delivered',
      verificationStatus: 'local_unverified',
      verifiedAt: DateTime.now(),
      originalTransactionId: purchase.purchaseID,
      environment: 'local',
    );

    await _repository.saveRecord(record);
    _resolvePending(productId, true);
    _purchaseResultController.add(
      PurchaseResult(success: true, productId: productId, restored: restored),
    );
  }

  double _resolveProductPrice(String productId) {
    double price = localPrices[productId] ?? 0.99;
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      price = product.rawPrice;
    } catch (_) {
      // Fallback to local price while product metadata is still loading.
    }
    return price;
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  /// Get the real price string from App Store for a product.
  String? getProductPrice(String productId) {
    try {
      final product = _products.firstWhere((p) => p.id == productId);
      return product.price;
    } catch (_) {
      return null;
    }
  }

  /// Dispose resources.
  void dispose() {
    _subscription?.cancel();
    _verificationService.dispose();
    _purchaseResultController.close();
  }
}
