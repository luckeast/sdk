import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists a stable per-install IAP account token for Apple fraud signals
/// and server-side delivery idempotency.
class IapAccountService {
  static const String _accountTokenKey = 'vymra_iap_account_token';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Random _random = Random.secure();

  Future<String> getOrCreateAccountToken() async {
    final existing = await _secureStorage.read(key: _accountTokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _generateToken();
    await _secureStorage.write(key: _accountTokenKey, value: created);
    return created;
  }

  String _generateToken() {
    const hex = '0123456789abcdef';
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(hex[_random.nextInt(hex.length)]);
    }
    return buffer.toString();
  }
}
