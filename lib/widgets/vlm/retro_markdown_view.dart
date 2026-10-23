import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../theme/app_theme.dart';

/// Retro CRT-themed Markdown renderer for VLM forensic responses.
///
/// Features phosphor-green body text, amber bold callouts, cyan headers and code,
/// and retro steel-bordered code containers wrapped in [SelectionArea] for seamless
/// mouse text selection and clipboard copying.
class RetroMarkdownView extends StatelessWidget {
  const RetroMarkdownView({
    super.key,
    required this.data,
  });

  final String data;

  @override
  Widget build(BuildContext context) {
    // Append newline to avoid EOF regex parsing bugs with trailing code fences
    final displayData = data.endsWith('\n') ? data : '$data\n';

    final styleSheet = MarkdownStyleSheet(
      p: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: AppTheme.xCopyGreen,
        height: 1.4,
        letterSpacing: 0.5,
      ),
      h1: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.xCopyGreen,
        letterSpacing: 1.0,
      ),
      h2: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: AppTheme.xCopyCyan,
        letterSpacing: 0.8,
      ),
      h3: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        fontWeight: FontWeight.bold,
        color: AppTheme.xCopyAmber,
        letterSpacing: 0.6,
      ),
      h4: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.xCopyCyanDim,
      ),
      strong: const TextStyle(
        fontFamily: 'monospace',
        fontWeight: FontWeight.bold,
        color: AppTheme.xCopyAmber,
      ),
      em: const TextStyle(
        fontFamily: 'monospace',
        fontStyle: FontStyle.italic,
        color: AppTheme.xCopyCyan,
      ),
      code: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: AppTheme.xCopyCyan,
        backgroundColor: Colors.transparent,
      ),
      codeblockPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      codeblockDecoration: BoxDecoration(
        color: AppTheme.xCopyCrtBlack,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: AppTheme.xCopySteelDark,
          width: 1.0,
        ),
      ),
      blockquote: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: AppTheme.xCopySteelLight,
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppTheme.xCopyCyan,
            width: 3.0,
          ),
        ),
      ),
      listBullet: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: AppTheme.xCopyAmber,
      ),
      tableHead: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: AppTheme.xCopyCyan,
      ),
      tableBody: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: AppTheme.xCopyGreen,
      ),
      tableBorder: TableBorder.all(
        color: AppTheme.xCopySteelDark,
        width: 1.0,
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.xCopySteelDark,
            width: 1.0,
          ),
        ),
      ),
    );

    return SelectionArea(
      child: MarkdownBody(
        data: displayData,
        selectable: false,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        styleSheet: styleSheet,
      ),
    );
  }
}
