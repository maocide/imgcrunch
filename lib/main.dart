import 'package:flutter/material.dart';
import 'controllers/image_controller.dart';
import 'src/rust/frb_generated.dart';
import 'theme/app_theme.dart';
import 'views/viewer_view.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  final controller = ImageController();
  if (args.isNotEmpty) {
    controller.loadPath(args.first);
  }

  runApp(ImgCrunchApp(controller: controller));
}

class ImgCrunchApp extends StatelessWidget {
  final ImageController controller;

  const ImgCrunchApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'imgcrunch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      home: ViewerView(controller: controller),
    );
  }
}
