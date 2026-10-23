import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:imgcrunch/widgets/vlm/retro_markdown_view.dart';

void main() {
  testWidgets('RetroMarkdownView renders MarkdownBody inside SelectionArea',
      (WidgetTester tester) async {
    const markdownContent = '''
# Forensic Dossier
**Status:** Synthesized image detected.
- Feature 1: ComfyUI prompt in metadata
- Feature 2: High frequency ELA discrepancy
```json
{"synthetic": true}
```
''';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RetroMarkdownView(data: markdownContent),
        ),
      ),
    );

    // Verify SelectionArea exists for clipboard/mouse selection
    expect(find.byType(SelectionArea), findsOneWidget);

    // Verify MarkdownBody parsed and rendered
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Forensic Dossier'), findsOneWidget);
    expect(find.textContaining('Synthesized image detected.'), findsOneWidget);
  });
}
