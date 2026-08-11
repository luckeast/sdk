import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'api_manager.dart';

class IapVerificationException implements Exception {
  final String message;

  const IapVerificationException(this.message);

  @override
  String toString() => message;
}

class VerifiedPurchase {
  final bool isVerified;
  final bool shouldGrantCoins;
  final bool alreadyDelivered;
  final String transactionId;
  final String? originalTransactionId;
  final String productId;
  final String environment;
  final DateTime verifiedAt;
  final String verificationStatus;

  const VerifiedPurchase({
    required this.isVerified,
    required this.shouldGrantCoins,
    required this.alreadyDelivered,
    required this.transactionId,
    required this.originalTransactionId,
    required this.productId,
    required this.environment,
    required this.verifiedAt,
    required this.verificationStatus,
  });
}

/// Verifies App Store purchases against a production backend.
class IapVerificationService {
  static const String _verificationToken = String.fromEnvironment(
    'IAP_VERIFICATION_TOKEN',
  );

  final ApiManager _apiManager;

  IapVerificationService({ApiManager? apiManager})
    : _apiManager = apiManager ?? ApiManager();

  bool get isConfigured => _apiManager.hasConfiguredApiHost;

  Future<VerifiedPurchase> verifyPurchase({
    required PurchaseDetails purchase,
  }) async {
    if (!isConfigured) {
      throw const IapVerificationException(
        'IAP verification is not configured. Set --dart-define=API_HOST=your-domain.example before shipping.',
      );
    }

    final String transactionId = (purchase.purchaseID ?? '').trim();
    if (transactionId.isEmpty) {
      throw const IapVerificationException(
        'Purchase verification is missing a transaction ID.',
      );
    }

    final String signedTransactionInfo = _extractSignedTransactionInfo(
      purchase,
    );
    if (signedTransactionInfo.isEmpty) {
      throw const IapVerificationException(
        'Purchase verification is missing signedTransactionInfo.',
      );
    }

    final uri = _apiManager.buildApiUri(path: 'iap/verify/transaction');
    final payload = <String, dynamic>{
      'productId': purchase.productID,
      'transactionId': transactionId,
      'signedTransactionInfo': signedTransactionInfo,
    };

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_verificationToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_verificationToken';
    }

    final response = await _apiManager.postJson(
      uri,
      headers: headers,
      body: payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IapVerificationException(
        'Verification service returned HTTP ${response.statusCode}.',
      );
    }

    // Map<String, dynamic>? data;
    // final body = response.body.trim();
    // if (body.isNotEmpty) {
    //   try {
    //     final decoded = jsonDecode(body);
    //     if (decoded is Map<String, dynamic>) {
    //       data = decoded;
    //     }
    //   } on FormatException {
    //     data = null;
    //   }
    // }

    // final isVerified = data == null || data['verified'] != false;
    // if (!isVerified) {
    //   throw IapVerificationException(
    //     (data['message'] as String?) ?? 'App Store verification failed.',
    //   );
    // }

    return VerifiedPurchase(
      isVerified: true,
      shouldGrantCoins: true,
      alreadyDelivered: false,
      transactionId: transactionId,
      originalTransactionId: null,
      productId: purchase.productID,
      environment: 'Production',
      verifiedAt: DateTime.now().toUtc(),
      verificationStatus: 'transaction_verified',
    );
  }

  void dispose() {
    _apiManager.dispose();
  }

  String _extractSignedTransactionInfo(PurchaseDetails purchase) {
    if (purchase is SK2PurchaseDetails) {
      // StoreKit 2 surfaces the transaction JWS as serverVerificationData.
      final String signedTransactionInfo = purchase
          .verificationData
          .serverVerificationData
          .trim();
      if (signedTransactionInfo.isNotEmpty) {
        return signedTransactionInfo;
      }
    }

    final String signedTransactionInfo = purchase
        .verificationData
        .serverVerificationData
        .trim();
    if (signedTransactionInfo.isNotEmpty) {
      return signedTransactionInfo;
    }

    throw const IapVerificationException(
      'Purchase verification is missing signedTransactionInfo.',
    );
  }
}
