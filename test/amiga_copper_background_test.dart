import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/crunch_state_controller.dart';
import 'package:imgcrunch/widgets/amiga_copper_background.dart';

void main() {
  group('AmigaCopperBackground Widget', () {
    testWidgets('renders child widget when idle (isProcessing: false)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AmigaCopperBackground(
            isProcessing: false,
            mode: ViewMode.normal,
            child: Text('TERMINAL IDLE'),
          ),
        ),
      );

      expect(find.text('TERMINAL IDLE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders child and loops animation when isProcessing: true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AmigaCopperBackground(
            isProcessing: true,
            mode: ViewMode.ela,
            child: Text('CRUNCHING ELA'),
          ),
        ),
      );

      expect(find.text('CRUNCHING ELA'), findsOneWidget);

      // Advance frames to simulate active Copper waves
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('switches between all ViewMode palettes cleanly without error', (tester) async {
      for (final mode in ViewMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: AmigaCopperBackground(
              isProcessing: true,
              mode: mode,
              child: Text('MODE: ${mode.name}'),
            ),
          ),
        );

        expect(find.text('MODE: ${mode.name}'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('stops animation cleanly when toggled from processing to idle', (tester) async {
      bool processing = true;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: GestureDetector(
                onTap: () => setState(() => processing = false),
                child: AmigaCopperBackground(
                  isProcessing: processing,
                  mode: ViewMode.ascii,
                  child: const Text('ASCII ENGINE'),
                ),
              ),
            );
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // Toggle to idle
      await tester.tap(find.text('ASCII ENGINE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('respects custom bandHeight and rasterStep values', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AmigaCopperBackground(
            isProcessing: true,
            mode: ViewMode.ela,
            bandHeight: 400.0,
            rasterStep: 4.0,
            child: Text('STEPPED RASTER'),
          ),
        ),
      );

      expect(find.text('STEPPED RASTER'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
    });
  });
}
