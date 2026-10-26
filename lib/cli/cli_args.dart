import '../controllers/crunch_state_controller.dart';
import '../utils/file_naming_helper.dart';

/// Supported headless CLI action modes.
enum CliAction {
  ela,
  ascii,
  strings,
  resize,
  help,
  version,
}

/// Parsed command line arguments for imgcrunch.
class CliArgs {
  /// The headless action to perform, or null for GUI mode.
  final CliAction? action;

  /// Positional input file or directory path.
  final String? inputPath;

  /// Optional target output path (for ELA/Resize PNG or ASCII/Strings text).
  final String? outputPath;

  /// Optional initial view mode when launching in GUI mode.
  final ViewMode? initialGuiMode;

  /// ELA difference amplification scale factor (default: 25).
  final int elaScale;

  /// ASCII art width in characters (default: 100).
  final int asciiWidth;

  /// ASCII art character aspect ratio correction (default: 0.7).
  final double asciiAspect;

  /// Minimum printable ASCII contiguous byte sequence length (default: 6).
  final int stringsMinLen;

  /// Explicit target width for resize operation.
  final int? resizeWidth;

  /// Explicit target height for resize operation.
  final int? resizeHeight;

  /// Scaling percentage factor for resize operation (e.g. 50.0 = 50%).
  final double? resizePercent;

  const CliArgs({
    this.action,
    this.inputPath,
    this.outputPath,
    this.initialGuiMode,
    this.elaScale = 25,
    this.asciiWidth = 100,
    this.asciiAspect = 0.7,
    this.stringsMinLen = 6,
    this.resizeWidth,
    this.resizeHeight,
    this.resizePercent,
  });

  /// True if this invocation should execute headlessly in CLI mode.
  bool get isHeadless => action != null;

  /// Computes default collision-free ELA output path.
  static String computeDefaultElaPath(String input) {
    return FileNamingHelper.computeIncrementalPath(
      input,
      opTag: 'ela',
      targetExtension: 'png',
    );
  }

  /// Computes default collision-free Resize output path.
  static String computeDefaultResizePath(String input) {
    return FileNamingHelper.computeIncrementalPath(
      input,
      opTag: 'resized',
      targetExtension: 'png',
    );
  }

  /// Parses raw command-line arguments into a structured [CliArgs] object.
  static CliArgs parse(List<String> rawArgs) {
    CliAction? action;
    String? inputPath;
    String? outputPath;
    ViewMode? initialGuiMode;
    int elaScale = 25;
    int asciiWidth = 100;
    double asciiAspect = 0.7;
    int stringsMinLen = 6;
    int? resizeWidth;
    int? resizeHeight;
    double? resizePercent;

    int i = 0;
    while (i < rawArgs.length) {
      final arg = rawArgs[i];

      if (arg == '--help' || arg == '-h') {
        action = CliAction.help;
        i++;
      } else if (arg == '--version' || arg == '-v') {
        action = CliAction.version;
        i++;
      } else if (arg == '--ela' || arg == '-e') {
        action = CliAction.ela;
        i++;
      } else if (arg == '--ascii' || arg == '-a') {
        action = CliAction.ascii;
        i++;
      } else if (arg == '--strings' || arg == '-s') {
        action = CliAction.strings;
        i++;
      } else if (arg == '--resize' || arg == '-r') {
        action = CliAction.resize;
        i++;
      } else if (arg == '--output' || arg == '-o') {
        if (i + 1 < rawArgs.length) {
          outputPath = rawArgs[i + 1];
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--output=')) {
        outputPath = arg.substring('--output='.length);
        i++;
      } else if (arg.startsWith('-o=')) {
        outputPath = arg.substring('-o='.length);
        i++;
      } else if (arg == '--scale') {
        if (i + 1 < rawArgs.length) {
          elaScale = int.tryParse(rawArgs[i + 1]) ?? elaScale;
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--scale=')) {
        elaScale = int.tryParse(arg.substring('--scale='.length)) ?? elaScale;
        i++;
      } else if (arg == '--width' || arg == '-w') {
        if (i + 1 < rawArgs.length) {
          final val = int.tryParse(rawArgs[i + 1]);
          if (val != null) {
            asciiWidth = val;
            resizeWidth = val;
          }
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--width=')) {
        final val = int.tryParse(arg.substring('--width='.length));
        if (val != null) {
          asciiWidth = val;
          resizeWidth = val;
        }
        i++;
      } else if (arg.startsWith('-w=')) {
        final val = int.tryParse(arg.substring('-w='.length));
        if (val != null) {
          asciiWidth = val;
          resizeWidth = val;
        }
        i++;
      } else if (arg == '--height' || arg == '-H') {
        if (i + 1 < rawArgs.length) {
          resizeHeight = int.tryParse(rawArgs[i + 1]);
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--height=')) {
        resizeHeight = int.tryParse(arg.substring('--height='.length));
        i++;
      } else if (arg.startsWith('-H=')) {
        resizeHeight = int.tryParse(arg.substring('-H='.length));
        i++;
      } else if (arg == '--percent' || arg == '-p') {
        if (i + 1 < rawArgs.length) {
          resizePercent = double.tryParse(rawArgs[i + 1]);
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--percent=')) {
        resizePercent = double.tryParse(arg.substring('--percent='.length));
        i++;
      } else if (arg.startsWith('-p=')) {
        resizePercent = double.tryParse(arg.substring('-p='.length));
        i++;
      } else if (arg == '--aspect') {
        if (i + 1 < rawArgs.length) {
          asciiAspect = double.tryParse(rawArgs[i + 1]) ?? asciiAspect;
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--aspect=')) {
        asciiAspect =
            double.tryParse(arg.substring('--aspect='.length)) ?? asciiAspect;
        i++;
      } else if (arg == '--min-len' || arg == '-n') {
        if (i + 1 < rawArgs.length) {
          stringsMinLen = int.tryParse(rawArgs[i + 1]) ?? stringsMinLen;
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--min-len=')) {
        stringsMinLen =
            int.tryParse(arg.substring('--min-len='.length)) ?? stringsMinLen;
        i++;
      } else if (arg.startsWith('-n=')) {
        stringsMinLen =
            int.tryParse(arg.substring('-n='.length)) ?? stringsMinLen;
        i++;
      } else if (arg == '--mode' || arg == '-m') {
        if (i + 1 < rawArgs.length) {
          initialGuiMode = _parseViewMode(rawArgs[i + 1]);
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('--mode=')) {
        initialGuiMode = _parseViewMode(arg.substring('--mode='.length));
        i++;
      } else if (arg.startsWith('-m=')) {
        initialGuiMode = _parseViewMode(arg.substring('-m='.length));
        i++;
      } else if (!arg.startsWith('-')) {
        inputPath ??= arg;
        i++;
      } else {
        // Unknown flag, skip gracefully
        i++;
      }
    }

    return CliArgs(
      action: action,
      inputPath: inputPath,
      outputPath: outputPath,
      initialGuiMode: initialGuiMode,
      elaScale: elaScale,
      asciiWidth: asciiWidth,
      asciiAspect: asciiAspect,
      stringsMinLen: stringsMinLen,
      resizeWidth: resizeWidth,
      resizeHeight: resizeHeight,
      resizePercent: resizePercent,
    );
  }

  static ViewMode? _parseViewMode(String val) {
    switch (val.toLowerCase().trim()) {
      case 'ela':
        return ViewMode.ela;
      case 'ascii':
        return ViewMode.ascii;
      case 'strings':
        return ViewMode.strings;
      case 'vlm':
        return ViewMode.vlm;
      case 'normal':
        return ViewMode.normal;
      default:
        return null;
    }
  }
}
