import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists a stable per-install device identifier in secure storage.
class DeviceIdService {
  static const String _deviceIdKey = 'vymra_device_id';
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Random _random = Random.secure();

  Future<String> getOrCreateDeviceId() async {
    final existing = await _secureStorage.read(key: _deviceIdKey);
    if (_isUuid(existing)) {
      return existing!;
    }

    final created = _generateUuidV4();
    await _secureStorage.write(key: _deviceIdKey, value: created);
    return created;
  }

  bool _isUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hexByte(int value) => value.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(hexByte).join();
    return [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20, 32),
    ].join('-');
  }
}
