import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_markdown_editor/live_markdown_editor.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/bottom_bar/notes_text_link_control.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/editor_bottom_bar.dart';
import 'package:mechanix_notes/features/notes/presentation/widgets/editor/markdown_controller_provider.dart';
import 'package:widgets/widgets.dart';

void main() {
  late MarkdownEditorController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = MarkdownEditorController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: MarkdownControllerProvider(
        controller: controller,
        focusNode: focusNode,
        child: const Scaffold(body: Center(child: EditorBottomBar())),
      ),
    );
  }

  group('EditorBottomBar Tests', () {
    testWidgets('renders NotesTextLinkControl in EditorBottomBar', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(NotesTextLinkControl), findsOneWidget);
      expect(find.byKey(const Key('notes_text_toggle')), findsOneWidget);
      expect(
        find.byKey(const Key('notes_text_contextual_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('notes_link_toggle')), findsOneWidget);
    });

    testWidgets('tapping H1 button toggles Header 1 format on current line', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'Hello world',
        selection: TextSelection.collapsed(offset: 5),
      );

      await tester.pumpWidget(buildTestWidget());

      final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
      expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);

      // Tap H1 button
      await tester.tap(h1Finder);
      await tester.pumpAndSettle();

      // Now H1 prefix is added and button is selected
      expect(controller.text, '# Hello world');
      expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isTrue);

      // Tap H1 button again to untoggle
      await tester.tap(h1Finder);
      await tester.pumpAndSettle();

      // H1 prefix is removed
      expect(controller.text, 'Hello world');
      expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);
    });

    testWidgets('switching to Link mode reveals link action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byKey(const Key('notes_link_code_button')), findsNothing);

      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notes_link_code_button')), findsOneWidget);
      expect(
        find.byKey(const Key('notes_link_checklist_button')),
        findsOneWidget,
      );

      // Tapping link code button executes without error
      await tester.tap(find.byKey(const Key('notes_link_code_button')));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'tapping Bold button toggles bold syntax and updates button active state',
      (tester) async {
        controller.value = const TextEditingValue(
          text: 'Hello world',
          selection: TextSelection(baseOffset: 0, extentOffset: 5),
        );

        await tester.pumpWidget(buildTestWidget());

        final boldFinder = find.byKey(const Key('notes_text_bold_button'));
        expect(
          tester.widget<MechanixIconButton>(boldFinder).isSelected,
          isFalse,
        );

        // Tap bold button
        await tester.tap(boldFinder);
        await tester.pumpAndSettle();

        // Bold is now applied
        expect(controller.text, '**Hello** world');
        expect(
          tester.widget<MechanixIconButton>(boldFinder).isSelected,
          isTrue,
        );

        // Select the bold formatted word and tap bold again to untoggle
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 9,
        );
        await tester.pumpAndSettle();

        await tester.tap(boldFinder);
        await tester.pumpAndSettle();

        expect(controller.text, 'Hello world');
        expect(
          tester.widget<MechanixIconButton>(boldFinder).isSelected,
          isFalse,
        );
      },
    );

    testWidgets('tapping Italic and Strikethrough toggles respective syntax', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'Testing styles',
        selection: TextSelection(baseOffset: 0, extentOffset: 7),
      );

      await tester.pumpWidget(buildTestWidget());

      final italicFinder = find.byKey(const Key('notes_text_italic_button'));
      final strikeFinder = find.byKey(
        const Key('notes_text_strikethrough_button'),
      );

      // Apply italic
      await tester.tap(italicFinder);
      await tester.pumpAndSettle();
      expect(controller.text, '*Testing* styles');
      expect(
        tester.widget<MechanixIconButton>(italicFinder).isSelected,
        isTrue,
      );

      // Select italic word and untoggle
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 9,
      );
      await tester.pumpAndSettle();
      await tester.tap(italicFinder);
      await tester.pumpAndSettle();
      expect(controller.text, 'Testing styles');

      // Select and apply strikethrough
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 7,
      );
      await tester.pumpAndSettle();
      await tester.tap(strikeFinder);
      await tester.pumpAndSettle();
      expect(controller.text, '~~Testing~~ styles');
      expect(
        tester.widget<MechanixIconButton>(strikeFinder).isSelected,
        isTrue,
      );
    });

    testWidgets('tapping Checklist button toggles checklist format', (
      tester,
    ) async {
      controller.value = const TextEditingValue(
        text: 'Buy groceries',
        selection: TextSelection.collapsed(offset: 4),
      );

      await tester.pumpWidget(buildTestWidget());

      // Switch to Link mode where checklist button is located
      await tester.tap(find.byKey(const Key('notes_link_toggle')));
      await tester.pumpAndSettle();

      final checklistFinder = find.byKey(
        const Key('notes_link_checklist_button'),
      );
      expect(
        tester.widget<MechanixIconButton>(checklistFinder).isSelected,
        isFalse,
      );

      // Tap checklist
      await tester.tap(checklistFinder);
      await tester.pumpAndSettle();

      expect(controller.text, '- [ ] Buy groceries');
      expect(
        tester.widget<MechanixIconButton>(checklistFinder).isSelected,
        isTrue,
      );

      // Tap checklist again to untoggle
      await tester.tap(checklistFinder);
      await tester.pumpAndSettle();

      expect(controller.text, 'Buy groceries');
      expect(
        tester.widget<MechanixIconButton>(checklistFinder).isSelected,
        isFalse,
      );
    });

    testWidgets(
      'newly created empty note with # has H1 active and Body inactive in EditorBottomBar',
      (tester) async {
        controller.value = const TextEditingValue(
          text: '# ',
          selection: TextSelection.collapsed(offset: 2),
        );

        await tester.pumpWidget(buildTestWidget());

        final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
        final bodyFinder = find.byKey(const Key('notes_text_body_button'));

        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isTrue);
        expect(
          tester.widget<MechanixIconButton>(bodyFinder).isSelected,
          isFalse,
        );
      },
    );

    testWidgets(
      'typing note title on H1 and pressing enter on second line has Body active',
      (tester) async {
        controller.value = const TextEditingValue(
          text: '# My Note Title\n',
          selection: TextSelection.collapsed(offset: 16),
        );

        await tester.pumpWidget(buildTestWidget());

        final h1Finder = find.byKey(const Key('notes_text_contextual_button'));
        final bodyFinder = find.byKey(const Key('notes_text_body_button'));

        // On line 2 (offset 16), H1 is inactive and body is active
        expect(tester.widget<MechanixIconButton>(h1Finder).isSelected, isFalse);
        expect(
          tester.widget<MechanixIconButton>(bodyFinder).isSelected,
          isTrue,
        );
      },
    );
  });
}
