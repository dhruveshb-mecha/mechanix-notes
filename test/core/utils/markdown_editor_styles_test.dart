import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/core/utils/markdown_editor_styles.dart';
import 'package:widgets/widgets.dart';

void main() {
  group('markdownEditorTheme Tests', () {
    testWidgets('resolves theme properties from MechanixTheme.dark context', (
      WidgetTester tester,
    ) async {
      late MarkdownEditorThemeData themeData;

      await tester.pumpWidget(
        MaterialApp(
          theme: MechanixTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                themeData = markdownEditorTheme(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        themeData.backgroundColor,
        MechanixTheme.dark.colorScheme.surfaceContainerLowest,
      );
      expect(themeData.textColor, MechanixTheme.dark.colorScheme.onSurface);
      expect(
        themeData.mutedTextColor,
        MechanixTheme.dark.colorScheme.onSurfaceVariant,
      );
      expect(themeData.accentColor, MechanixTheme.dark.colorScheme.primary);
      expect(themeData.caretColor, MechanixTheme.dark.colorScheme.primary);
      expect(
        themeData.codeBackgroundColor,
        MechanixTheme.dark.colorScheme.surfaceContainer,
      );
      expect(
        themeData.quoteBorderColor,
        MechanixTheme.dark.colorScheme.outlineVariant,
      );
      expect(
        themeData.taskBorderColor,
        MechanixTheme.dark.colorScheme.onSurfaceVariant,
      );
      expect(
        themeData.taskCheckedColor,
        MechanixTheme.dark.colorScheme.primary,
      );
      expect(themeData.taskSize, 18);
      expect(themeData.contentPadding, const EdgeInsets.all(24));
      expect(themeData.headingStyles.length, 6);
      expect(
        themeData.codeStyle.fontFamily,
        contains(MechanixFontFamily.geistMono),
      );
    });
  });
}
