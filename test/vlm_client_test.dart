import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:imgcrunch/models/vlm_config.dart';
import 'package:imgcrunch/services/vlm/mime_utils.dart';
import 'package:imgcrunch/services/vlm/vlm_client.dart';
import 'package:imgcrunch/services/vlm/vlm_vision_helper.dart';

class MockStreamHttpClient extends http.BaseClient {
  MockStreamHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

void main() {
  group('MimeUtils', () {
    test('resolves known image MIME types case-insensitively', () {
      expect(MimeUtils.resolveImageMimeType('photo.png'), equals('image/png'));
      expect(MimeUtils.resolveImageMimeType('/path/to/PHOTO.PNG'), equals('image/png'));
      expect(MimeUtils.resolveImageMimeType('photo.jpg'), equals('image/jpeg'));
      expect(MimeUtils.resolveImageMimeType('photo.jpeg'), equals('image/jpeg'));
      expect(MimeUtils.resolveImageMimeType('image.webp'), equals('image/webp'));
      expect(MimeUtils.resolveImageMimeType('anim.gif'), equals('image/gif'));
      expect(MimeUtils.resolveImageMimeType('render.bmp'), equals('image/bmp'));
      expect(MimeUtils.resolveImageMimeType('asset.avif'), equals('image/avif'));
      expect(MimeUtils.resolveImageMimeType('scan.tiff'), equals('image/tiff'));
      expect(MimeUtils.resolveImageMimeType('scan.tif'), equals('image/tiff'));
    });

    test('falls back to image/jpeg for unknown or missing extensions', () {
      expect(MimeUtils.resolveImageMimeType('no_extension'), equals('image/jpeg'));
      expect(MimeUtils.resolveImageMimeType('file.xyz'), equals('image/jpeg'));
      expect(MimeUtils.resolveImageMimeType('.'), equals('image/jpeg'));
    });
  });

  group('VlmVisionHelper', () {
    test('formats base64 data URI correctly from bytes', () {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
      final uri = VlmVisionHelper.toDataUriFromBytes(
        sampleBytes,
        mimeType: 'image/png',
      );
      final expectedBase64 = base64Encode(sampleBytes);
      expect(uri, equals('data:image/png;base64,$expectedBase64'));
    });

    test('reads image file and resolves data URI', () async {
      final tempDir = await Directory.systemTemp.createTemp('vlm_img_test_');
      final tempFile = File('${tempDir.path}/test_image.png');
      await tempFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG header signature

      try {
        final dataUri = await VlmVisionHelper.toDataUri(tempFile.path);
        expect(dataUri, startsWith('data:image/png;base64,'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('VlmClient', () {
    test('normalizes various endpoint formats correctly', () {
      expect(
        VlmClient.normalizeEndpoint('http://localhost:11434'),
        equals('http://localhost:11434/v1/chat/completions'),
      );
      expect(
        VlmClient.normalizeEndpoint('http://localhost:11434/'),
        equals('http://localhost:11434/v1/chat/completions'),
      );
      expect(
        VlmClient.normalizeEndpoint('http://localhost:11434/v1'),
        equals('http://localhost:11434/v1/chat/completions'),
      );
      expect(
        VlmClient.normalizeEndpoint('http://localhost:11434/v1/'),
        equals('http://localhost:11434/v1/chat/completions'),
      );
      expect(
        VlmClient.normalizeEndpoint('https://api.openai.com/v1/chat/completions'),
        equals('https://api.openai.com/v1/chat/completions'),
      );
      expect(
        VlmClient.normalizeEndpoint('https://generativelanguage.googleapis.com/v1beta/openai'),
        equals('https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'),
      );
    });

    test('streams token chunks successfully from SSE response', () async {
      final sseLines = [
        'data: {"choices":[{"delta":{"content":"A retro "}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"Amiga workstation"}}]}\n\n',
        'data: [DONE]\n\n',
      ];

      final mockClient = MockStreamHttpClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, endsWith('/chat/completions'));

        final body = (request as http.Request).body;
        final decoded = jsonDecode(body);
        expect(decoded['model'], equals('qwen2.5-vl'));
        expect(decoded['stream'], isTrue);

        final messages = (decoded['messages'] as List).cast<Map<String, dynamic>>();
        expect(messages.first['role'], equals('system'));
        expect(messages.first['content'], equals('Describe image'));
        expect(messages.last['role'], equals('user'));
        final userContent = (messages.last['content'] as List).cast<Map<String, dynamic>>();
        expect(userContent.first['type'], equals('text'));
        expect(userContent.last['type'], equals('image_url'));

        final controller = StreamController<List<int>>();
        for (final line in sseLines) {
          controller.add(utf8.encode(line));
        }
        controller.close();

        return http.StreamedResponse(
          controller.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final tempDir = await Directory.systemTemp.createTemp('vlm_sse_test_');
      final testFile = File('${tempDir.path}/test.png');
      await testFile.writeAsBytes([1, 2, 3]);

      try {
        final client = VlmClient(httpClient: mockClient);
        const config = VlmConfig(
          endpoint: 'http://localhost:11434/v1',
          model: 'qwen2.5-vl',
        );

        final receivedTokens = <String>[];
        await for (final token in client.streamCaption(
          imagePath: testFile.path,
          prompt: 'Describe image',
          config: config,
        )) {
          receivedTokens.add(token);
        }

        expect(receivedTokens, equals(['A retro ', 'Amiga workstation']));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('sends multimodal forensic telemetry payload with ELA and strings', () async {
      Map<String, dynamic>? capturedPayload;
      final mockClient = MockStreamHttpClient((request) async {
        if (request is http.Request) {
          capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        }
        final sse = 'data: {"choices":[{"delta":{"content":"Tampering detected"}}]}\n\ndata: [DONE]\n\n';
        return http.StreamedResponse(
          Stream.value(utf8.encode(sse)),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final tempDir = await Directory.systemTemp.createTemp('vlm_forensic_test_');
      final testFile = File('${tempDir.path}/test.png');
      await testFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      try {
        final client = VlmClient(httpClient: mockClient);
        const config = VlmConfig();
        final dummyEla = Uint8List.fromList([1, 2, 3, 4]);

        final tokens = await client.streamCaption(
          imagePath: testFile.path,
          prompt: 'Inspect anomalies',
          config: config,
          elaBytes: dummyEla,
          elaScale: 25,
          extractedStrings: 'PHOTOSHOP_TAG_DETECTED\nCREATOR: USAGI',
        ).toList();

        expect(tokens, equals(['Tampering detected']));
        expect(capturedPayload, isNotNull);

        final messages = capturedPayload!['messages'] as List;
        final userMsg = messages.firstWhere((m) => m['role'] == 'user') as Map<String, dynamic>;
        final contentList = userMsg['content'] as List;

        expect(contentList.length, equals(3));
        expect(contentList[0]['type'], equals('text'));
        expect(contentList[0]['text'], contains('GROUND TRUTH ENVIRONMENT & METADATA'));
        expect(contentList[0]['text'], contains('Current Analysis Timestamp:'));
        expect(contentList[0]['text'], contains('Target Filename: test.png'));
        expect(contentList[0]['text'], contains('FORENSIC MULTIMODAL TELEMETRY'));
        expect(contentList[0]['text'], contains('compression scale factor: 25'));
        expect(contentList[0]['text'], contains('PHOTOSHOP_TAG_DETECTED'));

        expect(contentList[1]['type'], equals('image_url'));
        expect(contentList[1]['image_url']['url'], startsWith('data:image/png;base64,'));

        expect(contentList[2]['type'], equals('image_url'));
        expect(contentList[2]['image_url']['url'], startsWith('data:image/png;base64,'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws VlmApiException on HTTP error', () async {
      final mockClient = MockStreamHttpClient((request) async {
        const errorJson = '{"error": {"message": "Invalid API key"}}';
        return http.StreamedResponse(
          Stream.value(utf8.encode(errorJson)),
          401,
        );
      });

      final tempDir = await Directory.systemTemp.createTemp('vlm_err_test_');
      final testFile = File('${tempDir.path}/test.png');
      await testFile.writeAsBytes([1, 2, 3]);

      try {
        final client = VlmClient(httpClient: mockClient);
        const config = VlmConfig(apiKey: 'bad-key');

        await expectLater(
          client.fetchCaption(
            imagePath: testFile.path,
            prompt: 'Test',
            config: config,
          ),
          throwsA(
            isA<VlmApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.message, 'message', contains('Invalid API key')),
          ),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('abort cancels active stream immediately', () async {
      final mockClient = MockStreamHttpClient((request) async {
        final controller = StreamController<List<int>>();
        controller.add(
          utf8.encode('data: {"choices":[{"delta":{"content":"Token 1"}}]}\n\n'),
        );
        return http.StreamedResponse(
          controller.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final tempDir = await Directory.systemTemp.createTemp('vlm_abort_test_');
      final testFile = File('${tempDir.path}/test.png');
      await testFile.writeAsBytes([1, 2, 3]);

      try {
        final client = VlmClient(httpClient: mockClient);
        const config = VlmConfig();

        final received = <String>[];
        final completer = Completer<void>();
        final subscription = client
            .streamCaption(
              imagePath: testFile.path,
              prompt: 'Test',
              config: config,
            )
            .listen((token) {
              received.add(token);
              client.abort();
              if (!completer.isCompleted) completer.complete();
            });

        await completer.future.timeout(const Duration(seconds: 3));
        await subscription.cancel();

        expect(received, equals(['Token 1']));
        expect(client.isStreaming, isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('extracts reasoning chunks from Ollama reasoning, DeepSeek reasoning_content, and think tags', () async {
      final sseLines = [
        'data: {"choices":[{"delta":{"reasoning":"Analyzing lighting "}}]}\n\n',
        'data: {"choices":[{"delta":{"reasoning_content":"and marble texture."}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"<think>Internal anomaly detected</think>Final Report."}}]}\n\n',
        'data: [DONE]\n\n',
      ];

      final mockClient = MockStreamHttpClient((request) async {
        final controller = StreamController<List<int>>();
        for (final line in sseLines) {
          controller.add(utf8.encode(line));
        }
        controller.close();
        return http.StreamedResponse(
          controller.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final tempDir = await Directory.systemTemp.createTemp('vlm_reasoning_test_');
      final testFile = File('${tempDir.path}/test.png');
      await testFile.writeAsBytes([1, 2, 3]);

      try {
        final client = VlmClient(httpClient: mockClient);
        const config = VlmConfig();

        final chunks = await client.streamChunks(
          imagePath: testFile.path,
          prompt: 'Inspect',
          config: config,
        ).toList();

        final reasoning = chunks.where((c) => c.isReasoning).map((c) => c.text).toList();
        final text = chunks.where((c) => !c.isReasoning).map((c) => c.text).toList();

        expect(reasoning, equals(['Analyzing lighting ', 'and marble texture.', 'Internal anomaly detected']));
        expect(text, equals(['Final Report.']));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
