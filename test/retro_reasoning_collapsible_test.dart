import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/widgets/vlm/retro_reasoning_collapsible.dart';

void main() {
  testWidgets('RetroReasoningCollapsible renders collapsed by default and expands on tap', (tester) async {
    bool isExpanded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return RetroReasoningCollapsible(
                reasoning: 'Cognitive reasoning thoughts: detecting anomalies in marble statue.',
                isExpanded: isExpanded,
                onToggle: () {
                  setState(() {
                    isExpanded = !isExpanded;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial state: header visible, body collapsed
    expect(find.text('🧠 COGNITIVE MATRIX // REASONING TRACE'), findsOneWidget);
    expect(find.text('[EXPAND]'), findsOneWidget);
    expect(find.text('Cognitive reasoning thoughts: detecting anomalies in marble statue.'), findsNothing);

    // Tap to expand
    await tester.tap(find.text('🧠 COGNITIVE MATRIX // REASONING TRACE'));
    await tester.pumpAndSettle();

    expect(isExpanded, isTrue);
    expect(find.text('[COLLAPSE]'), findsOneWidget);
    expect(find.textContaining('Cognitive reasoning thoughts: detecting anomalies in marble statue.'), findsOneWidget);

    // Tap to collapse
    await tester.tap(find.text('🧠 COGNITIVE MATRIX // REASONING TRACE'));
    await tester.pumpAndSettle();

    expect(isExpanded, isFalse);
    expect(find.text('[EXPAND]'), findsOneWidget);
    expect(find.textContaining('Cognitive reasoning thoughts: detecting anomalies in marble statue.'), findsNothing);
  });

  testWidgets('RetroReasoningCollapsible renders nothing when reasoning is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetroReasoningCollapsible(
            reasoning: '',
            isExpanded: false,
            onToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('🧠 COGNITIVE MATRIX // REASONING TRACE'), findsNothing);
  });
}
