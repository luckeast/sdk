import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'device_id_service.dart';

class AppDeviceInfo {
  final String appName;
  final String appVersion;
  final String bundleId;
  final String osVersion;
  final String deviceModel;
  final String lang;
  final String region;
  final String locale;
  final String deviceId;
  final String deviceIdMd5;

  const AppDeviceInfo({
    required this.appName,
    required this.appVersion,
    required this.bundleId,
    required this.osVersion,
    required this.deviceModel,
    required this.lang,
    required this.region,
    required this.locale,
    required this.deviceId,
    required this.deviceIdMd5,
  });

  String get userAgent =>
      '$appName/$appVersion $deviceIdMd5 (iOS $osVersion; $deviceModel)';

  Map<String, String> toSystemPayload() {
    return <String, String>{
      'deviceId': deviceIdMd5,
      'appVersion': appVersion,
      'bundleId': bundleId,
      'osVersion': osVersion,
      'lang': lang,
      'region': region,
      'locale': locale,
      'model': deviceModel,
    };
  }
}

class AppDeviceInfoService {
  AppDeviceInfoService._();

  static final AppDeviceInfoService instance = AppDeviceInfoService._();

  static const MethodChannel _channel = MethodChannel('vymra/app_device_info');

  AppDeviceInfo? _cachedInfo;

  Future<AppDeviceInfo> getInfo() async {
    final AppDeviceInfo? cachedInfo = _cachedInfo;
    if (cachedInfo != null) {
      return cachedInfo;
    }

    final String deviceId = await DeviceIdService().getOrCreateDeviceId();
    final String deviceIdMd5 = md5.convert(utf8.encode(deviceId)).toString();
    final Map<Object?, Object?>? nativeInfo = await _channel
        .invokeMapMethod<Object?, Object?>('getInfo');

    final Locale locale = PlatformDispatcher.instance.locale;
    final String fallbackLocale = _normalizeLocale(locale.toLanguageTag());
    final String fallbackLang = _normalizeLang(locale.languageCode);
    final String fallbackRegion = _normalizeRegion(locale.countryCode);

    final AppDeviceInfo info = AppDeviceInfo(
      appName: _readString(nativeInfo, 'appName', fallback: 'vymra'),
      appVersion: _readString(nativeInfo, 'appVersion', fallback: '1.0.0'),
      bundleId: _readString(nativeInfo, 'bundleId', fallback: 'unknown'),
      osVersion: _readString(nativeInfo, 'osVersion', fallback: 'unknown'),
      deviceModel: _readString(nativeInfo, 'deviceModel', fallback: 'iPhone'),
      lang: _normalizeLang(
        _readString(nativeInfo, 'lang', fallback: fallbackLang),
      ),
      region: _normalizeRegion(
        _readString(nativeInfo, 'region', fallback: fallbackRegion),
      ),
      locale: _normalizeLocale(
        _readString(nativeInfo, 'locale', fallback: fallbackLocale),
      ),
      deviceId: deviceId,
      deviceIdMd5: deviceIdMd5,
    );

    _cachedInfo = info;
    return info;
  }

  void clearCache() {
    _cachedInfo = null;
  }

  String _readString(
    Map<Object?, Object?>? source,
    String key, {
    required String fallback,
  }) {
    final String? value = source?[key] as String?;
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }
    return value.trim();
  }

  String _normalizeLang(String? value) {
    final String resolved = (value ?? '').trim();
    if (resolved.isEmpty) {
      return 'en';
    }
    return resolved.split(RegExp('[-_]')).first.toLowerCase();
  }

  String _normalizeRegion(String? value) {
    final String resolved = (value ?? '').trim();
    if (resolved.isEmpty) {
      return 'US';
    }
    return resolved.toUpperCase();
  }

  String _normalizeLocale(String? value) {
    final String resolved = (value ?? '').trim();
    if (resolved.isEmpty) {
      return 'en-US';
    }
    return resolved.replaceAll('_', '-');
  }
}
