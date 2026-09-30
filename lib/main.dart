import 'package:flutter/material.dart';
import 'controllers/image_controller.dart';
import 'theme/app_theme.dart';
import 'views/viewer_view.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();

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
