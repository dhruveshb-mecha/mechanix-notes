import 'package:flutter/material.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:widgets/widgets.dart';

MarkdownEditorThemeData markdownEditorTheme(BuildContext context) {
  final colorScheme = context.colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final bodyLarge = textTheme.emphasized.bodyLarge ?? const TextStyle();
  final headlineLarge = textTheme.emphasized.headlineLarge ?? const TextStyle();
  final headlineSmall = textTheme.emphasized.headlineSmall ?? const TextStyle();
  final titleLarge = textTheme.titleLarge ?? const TextStyle();
  final titleMedium = textTheme.titleMedium ?? const TextStyle();
  final titleSmall = textTheme.titleSmall ?? const TextStyle();
  final bodyMedium = textTheme.bodyMedium ?? const TextStyle();

  final codeTextStyle =
      context.textTheme.titleSmall?.copyWith(
        color: colorScheme.onSurface,
        fontFamily: MechanixFontFamily.geistMono,
      ) ??
      const TextStyle();

  return MarkdownEditorThemeData(
    backgroundColor: colorScheme.surfaceContainerLowest,
    textColor: colorScheme.onSurface,
    mutedTextColor: colorScheme.onSurfaceVariant,
    accentColor: colorScheme.primary,
    selectionColor: colorScheme.primary.withValues(alpha: 0.25),
    caretColor: colorScheme.primary,
    highlightColor: colorScheme.primary.withValues(alpha: 0.15),
    codeBackgroundColor: colorScheme.surfaceContainer,
    fencedCodeBackgroundColor: colorScheme.surfaceContainer,
    quoteBorderColor: colorScheme.outlineVariant,
    taskBorderColor: colorScheme.onSurfaceVariant,
    taskCheckedColor: colorScheme.primary,
    bodyStyle: bodyLarge.copyWith(color: colorScheme.onSurface),
    codeStyle: codeTextStyle,
    headingStyles: [
      headlineLarge.copyWith(color: colorScheme.onSurface, height: 1.2), // H1
      headlineSmall.copyWith(color: colorScheme.onSurface), // H2
      titleLarge.copyWith(color: colorScheme.onSurface), // H3
      titleMedium.copyWith(color: colorScheme.onSurface), // H4
      titleSmall.copyWith(color: colorScheme.onSurface), // H5
      bodyMedium.copyWith(color: colorScheme.onSurface), // H6
    ],
    headingBlockPadding: const [
      EdgeInsets.only(top: 24, bottom: 24), // H1 block padding
      EdgeInsets.only(top: 24, bottom: 24), // H2 block padding
      EdgeInsets.zero, // H3
      EdgeInsets.zero, // H4
      EdgeInsets.zero, // H5
      EdgeInsets.zero, // H6
    ],
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    maxContentWidth: 4000.0,
    taskSize: 18,
  );
}
