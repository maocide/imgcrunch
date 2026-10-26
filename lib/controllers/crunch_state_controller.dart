import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/rust_image_service.dart';
import '../utils/clipboard_helper.dart';
import 'vlm_controller.dart';

enum ViewMode { normal, ela, ascii, strings, vlm }

sealed class PipelineState<T> {
  const PipelineState();
}

class PipelineIdle<T> extends PipelineState<T> {
  const PipelineIdle();
}

class PipelineProcessing<T> extends PipelineState<T> {
  final String statusMessage;
  const PipelineProcessing(this.statusMessage);
}

class PipelineReady<T> extends PipelineState<T> {
  final T data;
  const PipelineReady(this.data);
}

class PipelineError<T> extends PipelineState<T> {
  final String message;
  const PipelineError(this.message);
}

typedef AsciiCrunchResult = ({Uint8List imageBytes, String text});

class CrunchStateController extends ChangeNotifier {
  CrunchStateController({
    RustImageService? rustService,
    VlmController? vlmController,
    this.strMinLen = 6,
    this.asciiTargetWidth = 120,
    this.asciiCharAspect = 0.7,
    this.elaScale = 25,
  }) : _rustService = rustService ?? RustImageService.instance,
       _vlmController = vlmController ?? VlmController() {
    _lastVlmState = _vlmController.state;
    _vlmController.addListener(_onVlmStateChanged);
  }

  final RustImageService _rustService;
  final VlmController _vlmController;
  final int strMinLen;
  final int asciiTargetWidth;
  final double asciiCharAspect;
  final int elaScale;

  ViewMode _activeMode = ViewMode.normal;
  String? _currentPath;

  PipelineState<Uint8List> _elaState = const PipelineIdle<Uint8List>();
  PipelineState<AsciiCrunchResult> _asciiState =
      const PipelineIdle<AsciiCrunchResult>();
  PipelineState<String> _stringsState = const PipelineIdle<String>();
  PipelineState<String> _lastVlmState = const PipelineIdle<String>();

  ViewMode get activeMode => _activeMode;
  String? get currentPath => _currentPath;
  VlmController get vlmController => _vlmController;

  void _onVlmStateChanged() {
    // Only notify parent when the pipeline lifecycle state changes,
    // avoiding high-frequency rebuilds during streaming token accumulation!
    if (_lastVlmState != _vlmController.state) {
      _lastVlmState = _vlmController.state;
      notifyListeners();
    }
  }

  PipelineState<Uint8List> get elaState => _elaState;
  PipelineState<AsciiCrunchResult> get asciiState => _asciiState;
  PipelineState<String> get stringsState => _stringsState;
  PipelineState<String> get vlmState => _vlmController.state;

  /// Returns the state of the currently active view mode.
  PipelineState<dynamic> get activeState {
    switch (_activeMode) {
      case ViewMode.normal:
        return const PipelineReady<void>(null);
      case ViewMode.ela:
        return _elaState;
      case ViewMode.ascii:
        return _asciiState;
      case ViewMode.strings:
        return _stringsState;
      case ViewMode.vlm:
        return _vlmController.state;
    }
  }

  /// Generates the status bar ticker text according to the active pipeline state.
  String getStatusMessage(bool hasImages) {
    if (!hasImages) {
      return 'CRUNCH ENGINE READY. PRESS (O) TO LOAD.';
    }

    switch (_activeMode) {
      case ViewMode.normal:
        return 'Operation done.';
      case ViewMode.ela:
        return switch (_elaState) {
          PipelineProcessing(:final statusMessage) => statusMessage,
          PipelineError(:final message) => 'ELA ERROR: $message',
          PipelineReady() => 'Operation done.',
          PipelineIdle() => 'CRUNCH ENGINE READY.',
        };
      case ViewMode.ascii:
        return switch (_asciiState) {
          PipelineProcessing(:final statusMessage) => statusMessage,
          PipelineError(:final message) => 'ASCII ERROR: $message',
          PipelineReady() => 'Operation done.',
          PipelineIdle() => 'CRUNCH ENGINE READY.',
        };
      case ViewMode.strings:
        return switch (_stringsState) {
          PipelineProcessing(:final statusMessage) => statusMessage,
          PipelineError(:final message) => 'STRINGS ERROR: $message',
          PipelineReady() => 'Operation done.',
          PipelineIdle() => 'CRUNCH ENGINE READY.',
        };
      case ViewMode.vlm:
        return switch (_vlmController.state) {
          PipelineProcessing(:final statusMessage) => statusMessage,
          PipelineError(:final message) => 'VLM ERROR: $message',
          PipelineReady() => 'Operation done.',
          PipelineIdle() => 'VLM READY. PRESS (CTRL+ENTER) TO CRUNCH.',
        };
    }
  }

  /// Sets the active mode and triggers crunching if the target mode is idle.
  void setMode(ViewMode mode) {
    if (_activeMode == mode) return;
    _activeMode = mode;
    notifyListeners();
    _triggerActivePipelineIfNeeded();
  }

  /// Called when the image changes (e.g. Next / Prev / File open).
  void onImageChanged(String? newPath) {
    if (_currentPath == newPath) return;

    _currentPath = newPath;
    _elaState = const PipelineIdle<Uint8List>();
    _asciiState = const PipelineIdle<AsciiCrunchResult>();
    _stringsState = const PipelineIdle<String>();
    _vlmController.onImageChanged(newPath);
    notifyListeners();
    _triggerActivePipelineIfNeeded();
  }

  /// Triggers processing for the active mode if currently in an idle state.
  void _triggerActivePipelineIfNeeded() {
    if (_currentPath == null) return;

    switch (_activeMode) {
      case ViewMode.normal:
        //print("NORMAL");
        //print(_currentPath);
        break;
      case ViewMode.ela:
        if (_elaState is PipelineIdle<Uint8List>) {
          generateEla();
        }
        break;
      case ViewMode.ascii:
        if (_asciiState is PipelineIdle<AsciiCrunchResult>) {
          generateAscii();
        }
        break;
      case ViewMode.strings:
        if (_stringsState is PipelineIdle<String>) {
          generateStrings();
        }
        break;
      case ViewMode.vlm:
        // VLM requests are triggered on-demand via Ctrl+Enter or [CRUNCH]
        // to avoid unprompted API token consumption while browsing images.
        break;
    }
  }

  Future<void> generateEla() async {
    final path = _currentPath;
    if (path == null) return;
    _elaState = PipelineProcessing<Uint8List>(
      'CRUNCHING ELA IN RUST (SCALE: ${elaScale}x)...',
    );
    notifyListeners();

    try {
      final bytes = await _rustService.generateElaFromFile(
        path,
        scale: elaScale,
      );
      if (_currentPath == path) {
        _elaState = PipelineReady<Uint8List>(bytes);
        notifyListeners();
      }
    } catch (e) {
      if (_currentPath == path) {
        _elaState = PipelineError<Uint8List>(e.toString());
        notifyListeners();
      }
    }
  }

  Future<void> generateAscii() async {
    final path = _currentPath;
    if (path == null) return;
    _asciiState = PipelineProcessing<AsciiCrunchResult>(
      'CRUNCHING ASCII IN RUST ($asciiTargetWidth COLS)...',
    );
    notifyListeners();

    try {
      final (imageBytes, text) = await _rustService.convertToAsciiImageFromFile(
        path,
        targetWidth: asciiTargetWidth,
        charAspect: asciiCharAspect,
      );
      if (_currentPath == path) {
        _asciiState = PipelineReady<AsciiCrunchResult>((
          imageBytes: imageBytes,
          text: text,
        ));
        notifyListeners();
      }
    } catch (e) {
      if (_currentPath == path) {
        _asciiState = PipelineError<AsciiCrunchResult>(e.toString());
        notifyListeners();
      }
    }
  }

  Future<void> generateStrings() async {
    final path = _currentPath;
    if (path == null) return;
    _stringsState = PipelineProcessing<String>(
      'EXTRACTING STRINGS IN RUST (MIN_LEN: $strMinLen)...',
    );
    notifyListeners();

    try {
      final strings = await _rustService.extractStringsFromFile(
        path,
        minLen: strMinLen,
      );
      if (_currentPath == path) {
        _stringsState = PipelineReady<String>(strings);
        notifyListeners();
      }
    } catch (e) {
      if (_currentPath == path) {
        _stringsState = PipelineError<String>(e.toString());
        notifyListeners();
      }
    }
  }

  /// Contextually copies the active content to clipboard.
  /// Returns a user-facing status message describing the result.
  Future<String> copyActiveContent() async {
    final path = _currentPath;
    if (path == null) {
      return 'No image loaded to copy';
    }

    switch (_activeMode) {
      case ViewMode.normal:
        try {
          final bytes = await File(path).readAsBytes();
          final ok = await ClipboardHelper.copyImageBytes(bytes);
          return ok
              ? 'Image copied to clipboard! (PNG)'
              : 'Failed to copy image to clipboard';
        } catch (e) {
          return 'Failed to copy image: $e';
        }

      case ViewMode.ela:
        if (_elaState case PipelineReady<Uint8List>(:final data)) {
          final ok = await ClipboardHelper.copyImageBytes(data);
          return ok
              ? 'ELA forensic image copied to clipboard! (PNG)'
              : 'Failed to copy ELA image';
        } else if (_elaState is PipelineProcessing) {
          return 'ELA is still crunching, please wait...';
        } else {
          return 'ELA image not ready to copy';
        }

      case ViewMode.ascii:
        if (_asciiState case PipelineReady<AsciiCrunchResult>(:final data)) {
          await Clipboard.setData(ClipboardData(text: data.text));
          return 'ASCII art copied to clipboard!';
        } else if (_asciiState is PipelineProcessing) {
          return 'ASCII art is still crunching, please wait...';
        } else {
          return 'ASCII art not ready to copy';
        }

      case ViewMode.strings:
        if (_stringsState case PipelineReady<String>(:final data)) {
          await Clipboard.setData(ClipboardData(text: data));
          return 'Extracted strings copied to clipboard!';
        } else if (_stringsState is PipelineProcessing) {
          return 'Strings extraction is still in progress...';
        } else {
          return 'Extracted strings not ready to copy';
        }

      case ViewMode.vlm:
        if (_vlmController.state case PipelineReady<String>(:final data)) {
          await Clipboard.setData(ClipboardData(text: data));
          return 'VLM caption copied to clipboard!';
        } else if (_vlmController.state is PipelineProcessing) {
          return 'VLM caption is still crunching...';
        } else {
          return 'No VLM caption ready to copy';
        }
    }
  }

  @override
  void dispose() {
    _vlmController.removeListener(_onVlmStateChanged);
    _vlmController.dispose();
    super.dispose();
  }
}
