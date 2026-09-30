import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/image_controller.dart';
import 'package:imgcrunch/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final controller = ImageController();
    await tester.pumpWidget(ImgCrunchApp(controller: controller));
    expect(find.text('No image loaded'), findsOneWidget);
  });
}
