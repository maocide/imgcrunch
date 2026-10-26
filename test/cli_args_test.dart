import 'package:flutter_test/flutter_test.dart';
import 'package:imgcrunch/cli/cli_args.dart';
import 'package:imgcrunch/controllers/crunch_state_controller.dart';

void main() {
  group('CliArgs.parse', () {
    test('empty args defaults to GUI mode with no input', () {
      final cli = CliArgs.parse([]);
      expect(cli.isHeadless, isFalse);
      expect(cli.action, isNull);
      expect(cli.inputPath, isNull);
      expect(cli.outputPath, isNull);
      expect(cli.initialGuiMode, isNull);
    });

    test('single positional argument sets inputPath for GUI mode', () {
      final cli = CliArgs.parse(['/home/user/photo.jpg']);
      expect(cli.isHeadless, isFalse);
      expect(cli.action, isNull);
      expect(cli.inputPath, equals('/home/user/photo.jpg'));
    });

    test('GUI mode with --mode flag sets initialGuiMode', () {
      final cli1 = CliArgs.parse(['--mode=ela', 'image.png']);
      expect(cli1.isHeadless, isFalse);
      expect(cli1.initialGuiMode, equals(ViewMode.ela));
      expect(cli1.inputPath, equals('image.png'));

      final cli2 = CliArgs.parse(['-m', 'ascii', 'image.png']);
      expect(cli2.isHeadless, isFalse);
      expect(cli2.initialGuiMode, equals(ViewMode.ascii));
      expect(cli2.inputPath, equals('image.png'));
    });

    test('--ela flag triggers headless ELA action with options', () {
      final cli = CliArgs.parse([
        '--ela',
        'sample.jpg',
        '-o',
        'custom_ela.png',
        '--scale',
        '35',
      ]);
      expect(cli.isHeadless, isTrue);
      expect(cli.action, equals(CliAction.ela));
      expect(cli.inputPath, equals('sample.jpg'));
      expect(cli.outputPath, equals('custom_ela.png'));
      expect(cli.elaScale, equals(35));
    });

    test('-e short flag with --scale= inline syntax', () {
      final cli = CliArgs.parse(['-e', 'test.png', '--scale=50', '-o=out.png']);
      expect(cli.isHeadless, isTrue);
      expect(cli.action, equals(CliAction.ela));
      expect(cli.inputPath, equals('test.png'));
      expect(cli.outputPath, equals('out.png'));
      expect(cli.elaScale, equals(50));
    });

    test('--ascii action parses width and aspect ratio', () {
      final cli = CliArgs.parse([
        '--ascii',
        'render.png',
        '-w',
        '140',
        '--aspect',
        '0.45',
      ]);
      expect(cli.isHeadless, isTrue);
      expect(cli.action, equals(CliAction.ascii));
      expect(cli.inputPath, equals('render.png'));
      expect(cli.asciiWidth, equals(140));
      expect(cli.asciiAspect, closeTo(0.45, 0.001));
    });

    test('--strings action parses min-len correctly', () {
      final cli = CliArgs.parse([
        '--strings',
        'firmware.bin',
        '-n',
        '10',
        '-o',
        'strings.txt',
      ]);
      expect(cli.isHeadless, isTrue);
      expect(cli.action, equals(CliAction.strings));
      expect(cli.inputPath, equals('firmware.bin'));
      expect(cli.stringsMinLen, equals(10));
      expect(cli.outputPath, equals('strings.txt'));
    });

    test('--help and -h flags trigger help action', () {
      final cliLong = CliArgs.parse(['--help']);
      expect(cliLong.isHeadless, isTrue);
      expect(cliLong.action, equals(CliAction.help));

      final cliShort = CliArgs.parse(['-h']);
      expect(cliShort.isHeadless, isTrue);
      expect(cliShort.action, equals(CliAction.help));
    });

    test('--version and -v flags trigger version action', () {
      final cliLong = CliArgs.parse(['--version']);
      expect(cliLong.isHeadless, isTrue);
      expect(cliLong.action, equals(CliAction.version));

      final cliShort = CliArgs.parse(['-v']);
      expect(cliShort.isHeadless, isTrue);
      expect(cliShort.action, equals(CliAction.version));
    });
    test('--resize action parses width, height, percent, and output', () {
      final cli = CliArgs.parse([
        '--resize',
        'specimen.jpg',
        '-w',
        '1920',
        '-H',
        '1080',
        '-p',
        '50',
        '-o',
        'resized.png',
      ]);
      expect(cli.isHeadless, isTrue);
      expect(cli.action, equals(CliAction.resize));
      expect(cli.inputPath, equals('specimen.jpg'));
      expect(cli.resizeWidth, equals(1920));
      expect(cli.resizeHeight, equals(1080));
      expect(cli.resizePercent, equals(50.0));
      expect(cli.outputPath, equals('resized.png'));
    });

    test('-r short flag with inline parameters', () {
      final cli = CliArgs.parse([
        '-r',
        'specimen.png',
        '--width=1280',
        '--height=720',
        '--percent=75',
      ]);
      expect(cli.isHeadless, isTrue);
      expect(cli.action, equals(CliAction.resize));
      expect(cli.inputPath, equals('specimen.png'));
      expect(cli.resizeWidth, equals(1280));
      expect(cli.resizeHeight, equals(720));
      expect(cli.resizePercent, equals(75.0));
    });
  });

  group('CliArgs.computeDefaultElaPath', () {
    test('replaces extension with _ela.png', () {
      expect(
        CliArgs.computeDefaultElaPath('sample.jpg'),
        equals('sample_ela.png'),
      );
      expect(
        CliArgs.computeDefaultElaPath('/path/to/forensics.bmp'),
        equals('/path/to/forensics_ela.png'),
      );
    });

    test('appends _ela.png when no dot in filename', () {
      expect(
        CliArgs.computeDefaultElaPath('rawimage'),
        equals('rawimage_ela.png'),
      );
    });
  });

  group('CliArgs.computeDefaultResizePath', () {
    test('computes default _resized.png path', () {
      expect(
        CliArgs.computeDefaultResizePath('sample.jpg'),
        equals('sample_resized.png'),
      );
    });
  });
}
