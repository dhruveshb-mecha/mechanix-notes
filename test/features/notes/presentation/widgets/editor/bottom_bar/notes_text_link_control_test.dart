import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/bottom_bar/notes_text_link_control.dart';
import 'package:widgets/widgets.dart';

void main() {
  Widget buildTestWidget({
    NotesBottomBarMode? mode,
    NotesBottomBarMode initialMode = NotesBottomBarMode.text,
    ValueChanged<NotesBottomBarMode>? onModeChanged,
    VoidCallback? onTextContextualPressed,
    VoidCallback? onLinkContextualPressed,
    VoidCallback? onCodePressed,
    VoidCallback? onChecklistPressed,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: NotesTextLinkControl(
            mode: mode,
            initialMode: initialMode,
            onModeChanged: onModeChanged,
            onTextContextualPressed: onTextContextualPressed,
            onLinkContextualPressed: onLinkContextualPressed,
            onCodePressed: onCodePressed,
            onChecklistPressed: onChecklistPressed,
            enabled: enabled,
          ),
        ),
      ),
    );
  }

  group('NotesTextLinkControl Tests', () {
    testWidgets('1. Text toggle is selected by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final textToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_text_toggle')),
      );
      expect(textToggle.isSelected, isTrue);
    });

    testWidgets('2. Text contextual button is visible initially', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byKey(const Key('notes_text_contextual_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notes_link_image_button')),
        findsNothing,
      );
    });

    testWidgets('3. Link toggle is initially unselected', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final linkToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_link_toggle')),
      );
      expect(linkToggle.isSelected, isFalse);
    });

    testWidgets('4. Tapping Link changes active mode to Link', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      final linkToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_link_toggle')),
      );
      final textToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_text_toggle')),
      );

      expect(linkToggle.isSelected, isTrue);
      expect(textToggle.isSelected, isFalse);
    });

    testWidgets('5. Link action buttons become visible in Link mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('notes_link_code_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notes_link_checklist_button')),
        findsOneWidget,
      );
    });

    testWidgets(
      '6. Text contextual button is hidden when Link mode is active',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.byKey(const Key('notes_link_toggle')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('notes_text_contextual_button')),
          findsNothing,
        );
      },
    );

    testWidgets('7. Tapping Text switches back correctly to Text mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Switch to Link
      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('notes_link_code_button')),
        findsOneWidget,
      );

      // Switch back to Text
      await tester.tap(find.byKey(const Key('notes_text_toggle')));
      await tester.pumpAndSettle();

      final textToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_text_toggle')),
      );
      final linkToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_link_toggle')),
      );

      expect(textToggle.isSelected, isTrue);
      expect(linkToggle.isSelected, isFalse);
      expect(
        find.byKey(const Key('notes_text_contextual_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notes_link_code_button')),
        findsNothing,
      );
    });

    testWidgets('8. Correct callbacks are triggered on mode and action taps', (
      tester,
    ) async {
      NotesBottomBarMode? changedMode;
      var textActionCount = 0;
      var codeActionCount = 0;

      await tester.pumpWidget(
        buildTestWidget(
          onModeChanged: (mode) => changedMode = mode,
          onTextContextualPressed: () => textActionCount++,
          onCodePressed: () => codeActionCount++,
        ),
      );

      // Tap text contextual button
      await tester.tap(find.byKey(const Key('notes_text_contextual_button')));
      await tester.pumpAndSettle();
      expect(textActionCount, 1);
      expect(codeActionCount, 0);

      // Switch mode to Link
      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();
      expect(changedMode, NotesBottomBarMode.link);

      // Tap link code button
      await tester.tap(find.byKey(const Key('notes_link_code_button')));
      await tester.pumpAndSettle();
      expect(codeActionCount, 1);
    });

    testWidgets('9. Disabled behavior prevents interaction and callbacks', (
      tester,
    ) async {
      NotesBottomBarMode? changedMode;
      var actionCount = 0;

      await tester.pumpWidget(
        buildTestWidget(
          enabled: false,
          onModeChanged: (mode) => changedMode = mode,
          onTextContextualPressed: () => actionCount++,
        ),
      );

      // Try tapping Link toggle when disabled
      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();
      expect(changedMode, isNull);

      // Try tapping Text contextual button when disabled
      await tester.tap(find.byKey(const Key('notes_text_contextual_button')));
      await tester.pumpAndSettle();
      expect(actionCount, 0);

      final textToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_text_toggle')),
      );
      expect(textToggle.onPressed, isNull);
    });

    testWidgets('10. Controlled mode respects external mode updates', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(mode: NotesBottomBarMode.link));

      final linkToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_link_toggle')),
      );
      final textToggle = tester.widget<MechanixIconButton>(
        find.byKey(const Key('notes_text_toggle')),
      );

      expect(linkToggle.isSelected, isTrue);
      expect(textToggle.isSelected, isFalse);
      expect(
        find.byKey(const Key('notes_link_code_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notes_text_contextual_button')),
        findsNothing,
      );
    });

    testWidgets('11. Text mode renders all 7 formatting action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byKey(const Key('notes_text_contextual_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notes_text_h2_button')), findsOneWidget);
      expect(find.byKey(const Key('notes_text_body_button')), findsOneWidget);
      expect(find.byKey(const Key('notes_text_bold_button')), findsOneWidget);
      expect(find.byKey(const Key('notes_text_italic_button')), findsOneWidget);
      expect(
        find.byKey(const Key('notes_text_underline_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notes_text_strikethrough_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('notes_link_checklist_button')),
        findsNothing,
      );
    });

    testWidgets(
      '12. Link mode renders active action buttons and hides unimplemented buttons',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(initialMode: NotesBottomBarMode.link),
        );

        expect(find.byKey(const Key('notes_link_code_button')), findsOneWidget);
        expect(
          find.byKey(const Key('notes_link_checklist_button')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('notes_link_image_button')), findsNothing);
        expect(find.byKey(const Key('notes_link_file_button')), findsNothing);
        expect(find.byKey(const Key('notes_link_music_button')), findsNothing);
      },
    );

    testWidgets('13. Active formatting button has correct selected background and foreground colors', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.dark(
              onSurface: Color(0xFFF5F5F5),
              onSurfaceVariant: Color(0xFFCAC4D0),
            ),
          ),
          home: const Scaffold(
            body: Center(
              child: NotesTextLinkControl(
                isBoldActive: true,
              ),
            ),
          ),
        ),
      );

      final boldButtonFinder = find.byKey(const Key('notes_text_bold_button'));
      final iconButton = tester.widget<IconButton>(
        find.descendant(
          of: boldButtonFinder,
          matching: find.byType(IconButton),
        ),
      );

      final bg = iconButton.style?.backgroundColor?.resolve({WidgetState.selected});
      final fg = iconButton.style?.foregroundColor?.resolve({WidgetState.selected});
      final iconColor = iconButton.style?.iconColor?.resolve({WidgetState.selected});

      expect(bg, const Color(0xFFCAC4D0).withValues(alpha: 0.08));
      expect(fg, const Color(0xFFF5F5F5));
      expect(iconColor, const Color(0xFFF5F5F5));

      final italicButtonFinder = find.byKey(const Key('notes_text_italic_button'));
      final unselectedIconButton = tester.widget<IconButton>(
        find.descendant(
          of: italicButtonFinder,
          matching: find.byType(IconButton),
        ),
      );
      final unselectedBg = unselectedIconButton.style?.backgroundColor?.resolve({});
      expect(unselectedBg, Colors.transparent);
    });
  });
}
