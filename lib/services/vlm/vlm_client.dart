import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    Uint8List? elaBytes,
    int? elaScale,
    String? extractedStrings,
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

      final messages = <Map<String, dynamic>>[];
      if (prompt.trim().isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': prompt.trim(),
        });
      }

      final userContent = <Map<String, dynamic>>[];

      // Resolve file and ground truth environment metadata
      String? filename;
      int? fileSize;
      DateTime? lastModified;
      bool isClipboard = false;

      try {
        final file = File(imagePath);
        if (await file.exists()) {
          final segments = file.uri.pathSegments;
          if (segments.isNotEmpty) {
            filename = segments.lastWhere((s) => s.isNotEmpty, orElse: () => 'unknown');
          }
          isClipboard = filename?.startsWith('imgcrunch_clipboard_') ?? false;
          final stat = await file.stat();
          fileSize = stat.size;
          lastModified = stat.modified;
        }
      } catch (_) {
        // Gracefully ignore stat errors
      }

      final nowUtc = DateTime.now().toUtc();
      final nowUtcStr =
          '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')} '
          '${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')} UTC';

      final groundingBuffer = StringBuffer();
      groundingBuffer.writeln('GROUND TRUTH ENVIRONMENT & METADATA:');
      groundingBuffer.writeln('- Current Analysis Timestamp: $nowUtcStr');
      if (filename != null) {
        if (isClipboard) {
          groundingBuffer.writeln('- Source: Pasted image from system clipboard');
          if (fileSize != null) {
            groundingBuffer.writeln('- Buffer Size: ${_formatBytes(fileSize)} ($fileSize bytes)');
          }
        } else {
          groundingBuffer.writeln('- Target Filename: $filename');
          if (fileSize != null) {
            groundingBuffer.writeln('- File Size: ${_formatBytes(fileSize)} ($fileSize bytes)');
          }
          if (lastModified != null) {
            final modUtc = lastModified.toUtc();
            final modUtcStr =
                '${modUtc.year.toString().padLeft(4, '0')}-${modUtc.month.toString().padLeft(2, '0')}-${modUtc.day.toString().padLeft(2, '0')} '
                '${modUtc.hour.toString().padLeft(2, '0')}:${modUtc.minute.toString().padLeft(2, '0')}:${modUtc.second.toString().padLeft(2, '0')} UTC';
            groundingBuffer.writeln('- Filesystem Modified: $modUtcStr');
          }
        }
      }

      if (elaBytes != null ||
          (extractedStrings != null && extractedStrings.trim().isNotEmpty)) {
        final buffer = StringBuffer();
        buffer.write(groundingBuffer.toString());
        buffer.writeln('\nFORENSIC MULTIMODAL TELEMETRY:');
        buffer.writeln('- Image 1: Original input image (RGB visual capture).');
        if (elaBytes != null) {
          buffer.writeln(
            '- Image 2: Error Level Analysis (ELA) difference map (compression scale factor: ${elaScale ?? 25}). High contrast/brightness denotes high compression error/potential splicing.',
          );
        }
        if (extractedStrings != null && extractedStrings.trim().isNotEmpty) {
          buffer.writeln('- Extracted Binary Strings (printable ASCII):');
          buffer.writeln('```');
          buffer.writeln(extractedStrings.trim());
          buffer.writeln('```');
        }
        buffer.writeln(
          '\nAnalyze and correlate Image 1 against Image 2 (ELA) and the binary strings according to your instructions.',
        );

        userContent.add({
          'type': 'text',
          'text': buffer.toString(),
        });
        userContent.add({
          'type': 'image_url',
          'image_url': {'url': dataUri},
        });
        if (elaBytes != null) {
          final elaDataUri = VlmVisionHelper.toDataUriFromBytes(
            elaBytes,
            mimeType: 'image/png',
          );
          userContent.add({
            'type': 'image_url',
            'image_url': {'url': elaDataUri},
          });
        }
      } else {
        final buffer = StringBuffer();
        buffer.write(groundingBuffer.toString());
        buffer.writeln(
          '\nAnalyze and inspect the provided image according to your instructions.',
        );
        userContent.add({
          'type': 'text',
          'text': buffer.toString(),
        });
        userContent.add({
          'type': 'image_url',
          'image_url': {'url': dataUri},
        });
      }

      messages.add({
        'role': 'user',
        'content': userContent,
      });

      final payload = {
        'model': config.model.trim(),
        'messages': messages,
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

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
