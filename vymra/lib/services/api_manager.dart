import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_device_info_service.dart';

typedef ApiHeaderInterceptor =
    FutureOr<void> Function(Map<String, String> headers, AppDeviceInfo info);
typedef ApiErrorInterceptor = FutureOr<void> Function(ApiException exception);

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Uri? uri;
  final Object? cause;

  const ApiException(this.message, {this.statusCode, this.uri, this.cause});

  @override
  String toString() {
    final List<String> parts = <String>[message];
    if (statusCode != null) {
      parts.add('status=$statusCode');
    }
    if (uri != null) {
      parts.add('uri=$uri');
    }
    return parts.join(' ');
  }
}

class ApiResponse {
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List bodyBytes;
  final Uri uri;

  const ApiResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
    required this.uri,
  });

  String get body => utf8.decode(bodyBytes);

  Map<String, dynamic> jsonMap() {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Expected JSON object response', uri: uri);
    }
    return decoded;
  }
}

class ApiManager {
  static const String defaultApiScheme = String.fromEnvironment(
    'API_SCHEME',
    defaultValue: 'https',
  );
  static const String defaultApiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'jufeng.boomi-dev.com',
  );
  static const String defaultApiPathPrefix = String.fromEnvironment(
    'API_PATH_PREFIX',
    defaultValue: '/ios/v1/',
  );

  ApiManager({
    http.Client? client,
    AppDeviceInfoService? appDeviceInfoService,
    this.apiPathPrefix = defaultApiPathPrefix,
    this.headerInterceptor,
    this.errorInterceptor,
  }) : _client = client ?? http.Client(),
       _appDeviceInfoService =
           appDeviceInfoService ?? AppDeviceInfoService.instance;

  final http.Client _client;
  final AppDeviceInfoService _appDeviceInfoService;
  final String apiPathPrefix;
  final ApiHeaderInterceptor? headerInterceptor;
  final ApiErrorInterceptor? errorInterceptor;

  bool get hasConfiguredApiHost => defaultApiHost.trim().isNotEmpty;

  Future<ApiResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return sendRequest(
      method: 'GET',
      uri: uri,
      headers: headers,
      timeout: timeout,
    );
  }

  Future<ApiResponse> postJson(
    Uri uri, {
    required Object body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return sendRequest(
      method: 'POST',
      uri: uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
      timeout: timeout,
    );
  }

  Future<http.StreamedResponse> sendStreamedRequest(
    http.BaseRequest request, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    try {
      await _applyRequestHeaders(request.headers);
      _logRequest(request.method, request.url, request.headers);
      final http.StreamedResponse response = await _client
          .send(request)
          .timeout(timeout);
      _interceptStatus(
        response.statusCode,
        request.url,
        headers: response.headers,
        bodyPreview: null,
      );
      _logResponse(response.statusCode, request.url, response.headers);
      return response;
    } on TimeoutException catch (error) {
      final ApiException exception = ApiException(
        'Request timed out',
        uri: request.url,
        cause: error,
      );
      await _notifyErrorInterceptor(exception);
      throw exception;
    } on ApiException {
      rethrow;
    } catch (error) {
      final ApiException exception = ApiException(
        'Request failed',
        uri: request.url,
        cause: error,
      );
      await _notifyErrorInterceptor(exception);
      throw exception;
    }
  }

  Future<ApiResponse> sendRequest({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final http.Request request = http.Request(method, uri);
    if (headers != null) {
      request.headers.addAll(headers);
    }
    if (body is String) {
      request.body = body;
    } else if (body is List<int>) {
      request.bodyBytes = body;
    } else if (body != null) {
      throw ArgumentError.value(body, 'body', 'Unsupported request body');
    }

    try {
      await _applyRequestHeaders(request.headers);
      _logRequest(method, uri, request.headers, bodyPreview: request.body);
      final http.StreamedResponse streamedResponse = await _client
          .send(request)
          .timeout(timeout);
      final http.Response response = await http.Response.fromStream(
        streamedResponse,
      );
      _interceptStatus(
        response.statusCode,
        uri,
        headers: response.headers,
        bodyPreview: response.body,
      );
      _logResponse(response.statusCode, uri, response.headers);
      return ApiResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        bodyBytes: response.bodyBytes,
        uri: uri,
      );
    } on TimeoutException catch (error) {
      final ApiException exception = ApiException(
        'Request timed out',
        uri: uri,
        cause: error,
      );
      await _notifyErrorInterceptor(exception);
      throw exception;
    } on ApiException {
      rethrow;
    } catch (error) {
      final ApiException exception = ApiException(
        'Request failed',
        uri: uri,
        cause: error,
      );
      await _notifyErrorInterceptor(exception);
      throw exception;
    }
  }

  Uri buildUri({
    required String scheme,
    required String host,
    required String path,
    int? port,
    Map<String, dynamic>? queryParameters,
  }) {
    final String normalizedPrefix = _normalizePath(apiPathPrefix);
    final String normalizedPath = _normalizePath(path);
    final String mergedPath =
        '$normalizedPrefix${normalizedPrefix.isNotEmpty && normalizedPath.isNotEmpty ? '/' : ''}$normalizedPath';
    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      path: mergedPath,
      queryParameters: queryParameters?.map(
        (String key, dynamic value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Uri buildApiUri({
    required String path,
    Map<String, dynamic>? queryParameters,
  }) {
    final String host = defaultApiHost.trim();
    if (host.isEmpty) {
      throw const ApiException(
        'API host is not configured. Set --dart-define=API_HOST=your-domain.example',
      );
    }

    return buildUri(
      scheme: defaultApiScheme,
      host: host,
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<void> _applyRequestHeaders(Map<String, String> headers) async {
    final AppDeviceInfo info = await _appDeviceInfoService.getInfo();
    headers['User-Agent'] = info.userAgent;
    headers.putIfAbsent('Accept', () => 'application/json');
    await headerInterceptor?.call(headers, info);
  }

  void _interceptStatus(
    int statusCode,
    Uri uri, {
    required Map<String, String> headers,
    required String? bodyPreview,
  }) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }

    debugPrint(
      'API status interception: $statusCode $uri body=${_truncate(bodyPreview)} headers=$headers',
    );
    final ApiException exception = ApiException(
      'Unexpected HTTP status',
      statusCode: statusCode,
      uri: uri,
    );
    unawaited(_notifyErrorInterceptor(exception));
    throw exception;
  }

  void _logRequest(
    String method,
    Uri uri,
    Map<String, String> headers, {
    String? bodyPreview,
  }) {
    debugPrint(
      'API request: $method $uri headers=$headers body=${_truncate(bodyPreview)}',
    );
  }

  void _logResponse(int statusCode, Uri uri, Map<String, String> headers) {
    debugPrint('API response: $statusCode $uri headers=$headers');
  }

  String _truncate(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return value.length <= 240 ? value : '${value.substring(0, 240)}...';
  }

  String _normalizePath(String path) {
    return path
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'/+$'), '');
  }

  void dispose() {
    _client.close();
  }

  Future<void> _notifyErrorInterceptor(ApiException exception) async {
    debugPrint('API error intercepted: $exception');
    await errorInterceptor?.call(exception);
  }
}
