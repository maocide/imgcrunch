import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/controllers/image_controller.dart';
import 'package:imgcrunch/main.dart';
import 'package:imgcrunch/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    final controller = ImageController();
    await tester.pumpWidget(ImgCrunchApp(controller: controller));
    expect(find.text('No image loaded'), findsOneWidget);
  });
}
