import 'dart:io';
import 'package:flutter/material.dart';
import 'cli/cli_args.dart';
import 'cli/cli_runner.dart';
import 'controllers/crunch_state_controller.dart';
import 'controllers/image_controller.dart';
import 'src/rust/frb_generated.dart';
import 'theme/app_theme.dart';
import 'views/viewer_view.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  // Headless CLI action interceptor
  final cli = CliArgs.parse(args);
  if (cli.isHeadless) {
    try {
      await CliRunner.run(cli);
      exit(0);
    } catch (e) {
      stderr.writeln('IMGCRUNCH ERROR: $e');
      exit(1);
    }
  }

  // Interactive GUI mode
  final controller = ImageController();
  if (cli.inputPath != null) {
    await controller.loadPath(cli.inputPath!);
  }

  runApp(ImgCrunchApp(
    controller: controller,
    initialMode: cli.initialGuiMode,
  ));
}

class ImgCrunchApp extends StatelessWidget {
  final ImageController controller;
  final ViewMode? initialMode;

  const ImgCrunchApp({
    super.key,
    required this.controller,
    this.initialMode,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'imgcrunch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      home: ViewerView(
        controller: controller,
        initialMode: initialMode,
      ),
    );
  }
}
