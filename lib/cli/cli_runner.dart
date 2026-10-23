import 'dart:io';
import '../services/rust_image_service.dart';
import 'cli_args.dart';

/// Headless CLI execution runner for imgcrunch.
class CliRunner {
  /// Executes the headless command specified in [args].
  static Future<void> run(CliArgs args) async {
    switch (args.action) {
      case CliAction.help:
        _printHelp();
        return;
      case CliAction.version:
        stdout.writeln('imgcrunch v1.0.0 (X-Copy Pro Engine)');
        return;
      case CliAction.ela:
        await _handleEla(args);
        return;
      case CliAction.ascii:
        await _handleAscii(args);
        return;
      case CliAction.strings:
        await _handleStrings(args);
        return;
      case null:
        return;
    }
  }

  static Future<void> _handleEla(CliArgs args) async {
    final input = args.inputPath;
    if (input == null || input.isEmpty) {
      throw ArgumentError(
        'Error: ELA action requires an input image path.\nUsage: imgcrunch --ela <IMAGE_PATH> [-o <OUTPUT_PATH>]',
      );
    }

    final file = File(input);
    if (!await file.exists()) {
      throw FileSystemException('Input file not found', input);
    }

    final outPath = args.outputPath ?? CliArgs.computeDefaultElaPath(input);
    final bytes = await RustImageService.instance.generateElaFromFile(
      input,
      scale: args.elaScale,
    );

    await File(outPath).writeAsBytes(bytes);
    stdout.writeln('[IMGCRUNCH] ELA saved to: $outPath');
  }

  static Future<void> _handleAscii(CliArgs args) async {
    final input = args.inputPath;
    if (input == null || input.isEmpty) {
      throw ArgumentError(
        'Error: ASCII action requires an input image path.\nUsage: imgcrunch --ascii <IMAGE_PATH> [-w <WIDTH>]',
      );
    }

    final file = File(input);
    if (!await file.exists()) {
      throw FileSystemException('Input file not found', input);
    }

    final text = await RustImageService.instance.convertToAsciiFromFile(
      input,
      targetWidth: args.asciiWidth,
      charAspect: args.asciiAspect,
    );

    if (args.outputPath != null && args.outputPath!.isNotEmpty) {
      await File(args.outputPath!).writeAsString(text);
      stdout.writeln('[IMGCRUNCH] ASCII art saved to: ${args.outputPath}');
    } else {
      stdout.writeln(text);
    }
  }

  static Future<void> _handleStrings(CliArgs args) async {
    final input = args.inputPath;
    if (input == null || input.isEmpty) {
      throw ArgumentError(
        'Error: Strings action requires an input image path.\nUsage: imgcrunch --strings <IMAGE_PATH> [-n <MIN_LEN>]',
      );
    }

    final file = File(input);
    if (!await file.exists()) {
      throw FileSystemException('Input file not found', input);
    }

    final text = await RustImageService.instance.extractStringsFromFile(
      input,
      minLen: args.stringsMinLen,
    );

    if (args.outputPath != null && args.outputPath!.isNotEmpty) {
      await File(args.outputPath!).writeAsString(text);
      stdout.writeln(
        '[IMGCRUNCH] Extracted strings saved to: ${args.outputPath}',
      );
    } else {
      stdout.write(text);
    }
  }

  static void _printHelp() {
    stdout.writeln(
      r'''
================================================================================
  IMGCRUNCH // IMAGE TERMINAL & VIEWER
================================================================================

USAGE:
  imgcrunch [OPTIONS] [IMAGE_PATH]

MODES (HEADLESS CLI):
  -e, --ela <PATH>            Compute Error Level Analysis (ELA)
  -a, --ascii <PATH>          Convert image to CRT terminal ASCII art
  -s, --strings <PATH>        Extract printable ASCII forensic strings
  -h, --help                  Show this help reference
  -v, --version               Show application version

OPTIONS:
  -o, --output <PATH>         Target output file path
                              (Defaults to <name>_ela.png for ELA, stdout for ASCII/Strings)
      --scale <INT>           ELA difference amplification factor (default: 25)
  -w, --width <INT>           Target ASCII art character width (default: 100)
      --aspect <FLOAT>        ASCII font aspect ratio correction (default: 0.7)
  -n, --min-len <INT>         Minimum contiguous string byte length (default: 6)
  -m, --mode <MODE>           Launch GUI in specific mode (normal, ela, ascii, strings, vlm)

EXAMPLES:
  imgcrunch photo.jpg                     Launch interactive desktop GUI
  imgcrunch --mode=ela photo.jpg          Launch GUI directly in ELA mode
  imgcrunch --mode=vlm photo.jpg          Launch GUI directly in VLM Neural mode
  imgcrunch --ela photo.jpg               Save photo_ela.png in same directory
  imgcrunch --ela photo.jpg -o diff.png   Save diff.png with scale 25
  imgcrunch --ascii photo.jpg -w 120      Print ASCII art directly to terminal
  imgcrunch --strings photo.jpg -n 8      Print forensic strings >= 8 bytes
================================================================================''',
    );
  }
}
