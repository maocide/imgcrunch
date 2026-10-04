import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/image_controller.dart';
import 'package:imgcrunch/main.dart';
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
}
