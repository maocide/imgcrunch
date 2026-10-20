import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/vlm_config.dart';
import 'vlm_vision_helper.dart';

/// Exception thrown when the VLM API endpoint responds with an error status code.
class VlmApiException implements Exception {
  const VlmApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'VlmApiException (HTTP $statusCode): $message';
}

/// Vision Language Model client for OpenAI-compatible completions endpoints
/// (Ollama, vLLM, OpenRouter, LM Studio, OpenAI).
///
/// Supports real-time Server-Sent Events (SSE) token streaming and instant abort/cancellation.
class VlmClient {
  VlmClient({http.Client? httpClient}) : _customHttpClient = httpClient;

  final http.Client? _customHttpClient;
  http.Client? _activeClient;
  bool _isAborted = false;

  /// Whether a request is currently actively streaming.
  bool get isStreaming => _activeClient != null;

  /// Aggressively normalizes the base URL to point to the `/chat/completions` endpoint.
  static String normalizeEndpoint(String rawUrl) {
    String url = rawUrl.trim();
    if (url.isEmpty) return url;

    // Strip trailing slashes
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (url.endsWith('/chat/completions')) return url;

    // Google's OpenAI-compatible shim
    if (url.contains('generativelanguage.googleapis.com')) {
      return '$url/chat/completions';
    }

    if (url.endsWith('/v1')) {
      return '$url/chat/completions';
    }

    return '$url/v1/chat/completions';
  }

  /// Cancels any ongoing streaming request immediately.
  void abort() {
    _isAborted = true;
    _activeClient?.close();
    _activeClient = null;
  }

  /// Streams token-by-token response chunks for a given [imagePath] and [prompt].
  Stream<String> streamCaption({
    required String imagePath,
    required String prompt,
    required VlmConfig config,
  }) async* {
    abort(); // Reset any existing request
    _isAborted = false;

    final client = _customHttpClient ?? http.Client();
    _activeClient = client;

    try {
      final endpointUrl = normalizeEndpoint(config.endpoint);
      final uri = Uri.parse(endpointUrl);

      final dataUri = await VlmVisionHelper.toDataUri(imagePath);
      if (_isAborted) return;

      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      if (config.apiKey.trim().isNotEmpty) {
        request.headers['Authorization'] = 'Bearer ${config.apiKey.trim()}';
      }

      final payload = {
        'model': config.model.trim(),
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': dataUri},
              },
            ],
          },
        ],
        'stream': true,
      };

      request.body = jsonEncode(payload);

      final http.StreamedResponse response;
      try {
        response = await client.send(request);
      } catch (e) {
        if (_isAborted) return;
        throw VlmApiException(0, 'Failed to connect to VLM endpoint: $e');
      }

      if (_isAborted) return;

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        String errorMsg = errorBody;
        try {
          final decoded = jsonDecode(errorBody);
          if (decoded is Map && decoded['error'] != null) {
            final err = decoded['error'];
            if (err is Map && err['message'] != null) {
              errorMsg = err['message'].toString();
            } else {
              errorMsg = err.toString();
            }
          }
        } catch (_) {}
        throw VlmApiException(response.statusCode, errorMsg);
      }

      // Parse Server-Sent Events stream
      final lineStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        if (_isAborted) break;
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        if (!trimmedLine.startsWith('data:')) continue;

        final data = trimmedLine.substring(5).trim();
        if (data == '[DONE]') break;

        try {
          final json = jsonDecode(data);
          if (json is Map<String, dynamic>) {
            final choices = json['choices'];
            if (choices is List && choices.isNotEmpty) {
              final firstChoice = choices[0];
              if (firstChoice is Map) {
                // OpenAI streaming format
                final delta = firstChoice['delta'];
                if (delta is Map && delta['content'] != null) {
                  final content = delta['content'].toString();
                  if (content.isNotEmpty) {
                    yield content;
                  }
                } else if (firstChoice['text'] != null) {
                  // Legacy completion format
                  final content = firstChoice['text'].toString();
                  if (content.isNotEmpty) {
                    yield content;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('VlmClient: Error decoding SSE line: $e (line: $trimmedLine)');
        }
      }
    } finally {
      if (identical(_activeClient, client)) {
        _activeClient = null;
      }
      if (_customHttpClient == null) {
        client.close();
      }
    }
  }

  /// Convenience method to collect full output from [streamCaption].
  Future<String> fetchCaption({
    required String imagePath,
    required String prompt,
    required VlmConfig config,
  }) async {
    final buffer = StringBuffer();
    await for (final token in streamCaption(
      imagePath: imagePath,
      prompt: prompt,
      config: config,
    )) {
      buffer.write(token);
    }
    return buffer.toString();
  }
}
