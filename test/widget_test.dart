import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/image_controller.dart';
import 'package:imgcrunch/main.dart';
import 'package:imgcrunch/theme/app_theme.dart';
import 'package:imgcrunch/widgets/amiga_copper_background.dart';
import 'package:imgcrunch/widgets/retro_status_bar.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final controller = ImageController();
    await tester.pumpWidget(ImgCrunchApp(controller: controller));
    expect(find.text('NO IMAGE LOADED'), findsOneWidget);
  });

  testWidgets('RetroStatusBar does not overflow when squished', (tester) async {
    tester.view.physicalSize = const Size(200, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RetroStatusBar(
            statusText: 'Extremely long status line that goes on forever',
            zoomScale: 1.0,
            currentIndex: 40,
            totalCount: 2261,
            trailing: Text('MENU'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('RetroStatusBar displays dimensions when space permits', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RetroStatusBar(
            statusText: 'READY',
            dimensions: Size(1920, 1080),
            zoomScale: 1.0,
            currentIndex: 0,
            totalCount: 1,
            trailing: Text('MENU'),
          ),
        ),
      ),
    );

    expect(find.text('1920x1080'), findsOneWidget);
    expect(find.text('RES: '), findsOneWidget);
  });

  testWidgets('ViewerView AmigaCopperBackground reflects processing state', (tester) async {
    final controller = ImageController();
    await tester.pumpWidget(ImgCrunchApp(controller: controller));

    final bgFinder = find.byType(AmigaCopperBackground);
    expect(bgFinder, findsOneWidget);
    final AmigaCopperBackground initialBg = tester.widget(bgFinder);
    expect(initialBg.isProcessing, isFalse);
  });

  testWidgets('RetroStatusBar renders prompt and color correctly for normal and error modes', (
    tester,
  ) async {
    // 1. Normal mode: '>' in amber, text in green
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RetroStatusBar(
            statusText: 'OPERATION DONE.',
            isError: false,
          ),
        ),
      ),
    );

    expect(find.text('> '), findsOneWidget);
    expect(find.text('! '), findsNothing);
    final Text normalText = tester.widget(find.text('OPERATION DONE.'));
    expect(normalText.style?.color, AppTheme.xCopyGreen);

    // 2. Error mode: '!' in red, text in red
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RetroStatusBar(
            statusText: 'ERR: CANNOT DELETE FILE',
            isError: true,
          ),
        ),
      ),
    );

    expect(find.text('! '), findsOneWidget);
    expect(find.text('> '), findsNothing);
    final Text errorText = tester.widget(find.text('ERR: CANNOT DELETE FILE'));
    expect(errorText.style?.color, AppTheme.xCopyRed);
  });
}
