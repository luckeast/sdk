import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_manager.dart';

/// Doubao (Volcano Engine) AI API service.
/// Provides chat completions and visual understanding using configured models.
class DoubaoAiService {
  static const String _baseUrl = 'api.vymra.uk';
  static const String _textModelId = String.fromEnvironment(
    'DOUBAO_TEXT_MODEL',
    defaultValue: 'doubao-seed-2-0-mini-260428',
  );

  final ApiManager _apiManager;

  DoubaoAiService({ApiManager? apiManager})
    : _apiManager = apiManager ?? ApiManager(apiPathPrefix: '');

  /// Send a chat completion request with text only.
  Future<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
    String? model,
  }) async {
    try {
      final uri = Uri.https(_baseUrl, '/doubao/chat/completions');
      final response = await _apiManager.postJson(
        uri,
        body: <String, dynamic>{
          'model': model ?? _textModelId,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        },
        timeout: const Duration(seconds: 120),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String?;
          if (content != null && content.isNotEmpty) {
            return content;
          }
        }
        throw Exception('Empty response from AI');
      } else {
        debugPrint('Doubao API error: ${response.statusCode} ${response.body}');
        throw Exception('AI service error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Doubao API call failed: $e');
      rethrow;
    }
  }

  /// Send a chat completion request with image (base64).
  Future<String> chatCompletionWithImage({
    required String base64Image,
    required String textPrompt,
    double temperature = 0.7,
    int maxTokens = 1024,
    String? model,
  }) async {
    final messages = [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': textPrompt},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
          },
        ],
      },
    ];

    return chatCompletion(
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      model: model ?? _textModelId,
    );
  }

  /// Stream a text completion. Falls back to chunked local streaming when
  /// server streaming is unavailable.
  Stream<String> streamChatCompletion({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
    String? model,
  }) async* {
    final uri = Uri.https(_baseUrl, '/doubao/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': model ?? _textModelId,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      });

    try {
      final streamedResponse = await _apiManager.sendStreamedRequest(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception(
          'Streaming request failed: ${streamedResponse.statusCode}',
        );
      }

      await for (final chunk
          in streamedResponse.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final trimmed = chunk.trim();
        if (!trimmed.startsWith('data:')) {
          continue;
        }
        final payload = trimmed.substring(5).trim();
        if (payload == '[DONE]') {
          break;
        }
        final piece = _extractDeltaText(payload);
        if (piece.isNotEmpty) {
          yield piece;
        }
      }
      return;
    } catch (e) {
      debugPrint('Doubao stream failed, falling back to local chunking: $e');
    }

    final full = await chatCompletion(
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
      model: model,
    );
    for (final piece in _chunkText(full)) {
      yield piece;
      await Future<void>.delayed(const Duration(milliseconds: 28));
    }
  }

  String _extractDeltaText(String rawPayload) {
    try {
      final Map<String, dynamic> json =
          jsonDecode(rawPayload) as Map<String, dynamic>;
      final List<dynamic>? choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return '';
      }

      final Map<String, dynamic>? choice =
          choices.first as Map<String, dynamic>?;
      final dynamic delta = choice?['delta'];
      if (delta is Map<String, dynamic>) {
        final dynamic content = delta['content'];
        if (content is String) {
          return content;
        }
        if (content is List) {
          return content
              .whereType<Map<String, dynamic>>()
              .map((item) => item['text'])
              .whereType<String>()
              .join();
        }
      }

      final dynamic message = choice?['message'];
      if (message is Map<String, dynamic>) {
        final dynamic content = message['content'];
        if (content is String) {
          return content;
        }
      }
    } catch (_) {
      return '';
    }
    return '';
  }

  List<String> _chunkText(String text) {
    final RegExp chunkPattern = RegExp(r'.{1,24}(\s|$)', dotAll: true);
    final Iterable<Match> matches = chunkPattern.allMatches(text);
    return matches
        .map((match) => match.group(0) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Convert image file to base64 string.
  static Future<String> imageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  /// Generate an image using Doubao Seedream model.
  /// Returns the raw image bytes (PNG/JPEG).
  Future<Uint8List> generateImage({
    required String prompt,
    String size = '2K',
    String? referenceImageBase64,
    bool watermark = false,
  }) async {
    try {
      final uri = Uri.https(_baseUrl, '/doubao/images/generations');
      final body = <String, dynamic>{
        'model': 'doubao-seedream-4-5-251128',
        'prompt': prompt,
        'size': size,
        'watermark': watermark,
        'response_format': 'b64_json',
        'n': 1,
      };
      if (referenceImageBase64 != null && referenceImageBase64.isNotEmpty) {
        body['image'] = 'data:image/jpeg;base64,$referenceImageBase64';
      }

      final response = await _apiManager.postJson(
        uri,
        body: body,
        timeout: const Duration(seconds: 120),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final images = data['data'] as List<dynamic>?;
        if (images != null && images.isNotEmpty) {
          final b64 = images[0]['b64_json'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            return base64Decode(b64);
          }
          final url = images[0]['url'] as String?;
          if (url != null && url.isNotEmpty) {
            final imgResp = await _apiManager.get(Uri.parse(url));
            if (imgResp.statusCode == 200) {
              return imgResp.bodyBytes;
            }
          }
        }
        throw Exception('Empty image data in response');
      } else {
        debugPrint(
          'Seedream API error: ${response.statusCode} ${response.body}',
        );
        throw Exception('Image generation failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Seedream API call failed: $e');
      rethrow;
    }
  }
}
